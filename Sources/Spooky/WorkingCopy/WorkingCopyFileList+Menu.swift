import AppKit
import SpookyKit

// MARK: - Context Menu

extension WorkingCopyFileList.Coordinator {
    /// 右键点击已选行时作用于整个选区，否则只处理该行；菜单按打开、路径、系统、文件、冲突、丢弃与储藏、查看、规则分组。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        guard let outline, let node = outline.item(atRow: outline.clickedRow) as? WorkingCopyFileList.Node else {
            return
        }

        menuEntries = outline.isRowSelected(outline.clickedRow) ? session.selectedEntries : node.entries

        addOpenItems(to: menu)
        addPathItems(to: menu)
        addSystemItems(to: menu)
        addFileItems(to: menu)
        addConflictItems(to: menu)
        addDiscardItems(to: menu)
        addViewItems(to: menu)
        addRuleItems(to: menu)
    }

    /// 空格按偏好切换暂存或打开 Quick Look；没有选中文件时响铃。
    func spacePressed() {
        let entries = session.selectedEntries

        guard !entries.isEmpty else {
            NSSound.beep()
            return
        }

        let action = UserDefaults.standard.string(forKey: WorkingCopyPreferences.spacebarAction)
            .flatMap(WorkingCopyPreferences.SpacebarAction.init(rawValue:)) ?? .toggleStaging

        guard action == .toggleStaging else {
            toggleQuickLook(entries)
            return
        }

        // 存在可暂存的改动就全部暂存，否则全部取消暂存
        let stageable = entries.filter(\.isStageable)
        session.stage(stageable, staged: stageable.contains(where: \.hasUnstagedChanges))
    }

    /// ⌘⌫ 删除所选文件：本机直接移到废纸篓，服务器上确认后永久删除；没有可删除的文件时响铃。
    func deletePressed() {
        let entries = session.selectedEntries

        guard session.canDelete(entries) else {
            NSSound.beep()
            return
        }

        session.delete(entries)
    }

    /// 打开或关闭 Quick Look：先让列表成为第一响应者，面板才会向列表索取预览项。
    func toggleQuickLook(_ entries: [StatusEntry]) {
        outline?.window?.makeFirstResponder(outline)
        quickLook.toggle(entries)
    }

    /// 双击文件按偏好打开或比较；双击目录展开或收起。
    @objc
    func doubleClicked(_: Any?) {
        guard let outline, let node = outline.item(atRow: outline.clickedRow) as? WorkingCopyFileList.Node else {
            return
        }

        guard let entry = node.entry else {
            outline.isItemExpanded(node) ? outline.collapseItem(node) : outline.expandItem(node)
            return
        }

        session.performDoubleClickAction(entry)
    }
}

// MARK: - Menu Groups

extension WorkingCopyFileList.Coordinator {
    /// 打开：用默认程序打开文件。
    private func addOpenItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("files.open", action: #selector(openMenu), enabled: session.canOpen(menuEntries), to: menu)
    }

    /// 路径：复制带主机前缀的完整路径与仓库内的相对路径。
    private func addPathItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("action.copyPath", action: #selector(copyAbsolute), enabled: true, to: menu)
        add("working.copyRelative", action: #selector(copyRelative), enabled: true, to: menu)
    }

    /// 系统：Quick Look、Finder 与终端；Finder 只能显示本机文件。
    private func addSystemItems(to menu: NSMenu) {
        beginGroup(in: menu)

        let title: String =
            if quickLook.isVisible {
                AppLocalization.text("files.quickLook.close")
            } else {
                countedTitle(single: "files.quickLook.single", multiple: "files.quickLook.multiple")
            }

        add(title: title, action: #selector(quickLookMenu), enabled: session.canOpen(menuEntries), to: menu)
        add(
            "action.revealFinder",
            action: #selector(reveal),
            enabled: session.repository?.localURL != nil,
            to: menu
        )
        add("action.openTerminal", action: #selector(terminal), enabled: true, to: menu)
    }

    /// 文件：暂存、取消暂存、停止跟踪、删除与移动；服务器上的删除是永久删除。
    private func addFileItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("working.stage", action: #selector(stageMenu), enabled: session.canStage(menuEntries), to: menu)
        add("working.unstage", action: #selector(unstageMenu), enabled: session.canUnstage(menuEntries), to: menu)
        add(
            title: countedTitle(single: "files.untrack.single", multiple: "files.untrack.multiple"),
            action: #selector(untrackMenu),
            enabled: session.canUntrack(menuEntries),
            to: menu
        )
        add(
            session.repository?.host == nil ? "files.trash" : "files.delete",
            action: #selector(deleteMenu),
            enabled: session.canDelete(menuEntries),
            to: menu
        )
        add("files.move.menu", action: #selector(moveMenu), enabled: session.canMove(menuEntries), to: menu)
    }

    /// 冲突：解决合并冲突与恢复合并冲突版本两个子菜单，可用性按所选文件逐项判断。
    private func addConflictItems(to menu: NSMenu) {
        beginGroup(in: menu)
        ConflictMenu.add(to: menu, entries: menuEntries, session: session)
    }

    /// 丢弃与储藏：丢弃改动、储藏与快照所选文件、恢复到指定版本；覆盖工作区的操作执行前确认。
    private func addDiscardItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("working.discard", action: #selector(discardMenu), enabled: session.canDiscard(menuEntries), to: menu)
        addStashItems(to: menu, entries: menuEntries)
        add("files.revert.menu", action: #selector(revertMenu), enabled: session.canRevert(menuEntries), to: menu)
    }

    /// 查看：原文、Blame 与文件历史，只对单个文件提供。
    private func addViewItems(to menu: NSMenu) {
        let items = session.fileViewMenuItems(for: menuEntries)

        guard !items.isEmpty else { return }

        beginGroup(in: menu)
        items.forEach(menu.addItem)
    }

    /// 规则：忽略、排除与 assume-unchanged 标记的子菜单。
    private func addRuleItems(to menu: NSMenu) {
        beginGroup(in: menu)
        addPatternMenu("files.ignore", file: .gitignore, to: menu)
        addPatternMenu("files.exclude", file: .exclude, to: menu)

        let mark = submenu("files.mark", in: menu)
        add(
            "files.assumeUnchanged.set",
            action: #selector(setAssumeUnchanged),
            enabled: session.canMarkAssumeUnchanged(menuEntries, true),
            to: mark
        )
        add(
            "files.assumeUnchanged.unset",
            action: #selector(unsetAssumeUnchanged),
            enabled: session.canMarkAssumeUnchanged(menuEntries, false),
            to: mark
        )
    }

    /// 忽略或排除子菜单：只匹配所选项、同名项、同类型文件，或输入自定义规则。
    private func addPatternMenu(_ key: String, file: IgnoreFile, to menu: NSMenu) {
        let patterns = submenu(key, in: menu)
        let prefix = file == .gitignore ? "files.ignore" : "files.exclude"
        let enabled = session.canIgnore(menuEntries)
        let action = file == .gitignore ? #selector(ignoreMenu(_:)) : #selector(excludeMenu(_:))

        // 类型规则取第一个文件的扩展名；目录与没有扩展名的文件没有类型规则
        let first = menuEntries.first.map { WorkingCopyFileList.fileName(of: $0.path) }
        let directory = menuEntries.first?.path.hasSuffix("/") ?? false
        let suffix = directory ? "" : WorkingCopyOperations.pathExtension(of: first ?? "")
        let single = menuEntries.count == 1

        let titles = [
            single
                ? AppLocalization.text(prefix + ".item")
                : AppLocalization.text(prefix + ".items", menuEntries.count),
            single
                ? AppLocalization.text(prefix + ".name.single", first ?? "")
                : AppLocalization.text(prefix + ".name"),
            single && !suffix.isEmpty
                ? AppLocalization.text(prefix + ".type.single", suffix)
                : AppLocalization.text(prefix + ".type"),
            AppLocalization.text(prefix + ".custom"),
        ]

        for (tag, title) in titles.enumerated() {
            let item = add(title: title, action: action, enabled: enabled && (tag != 2 || !suffix.isEmpty), to: patterns)
            item.tag = tag
        }
    }
}

// MARK: - Menu Actions

extension WorkingCopyFileList.Coordinator {
    /// 用默认程序打开所选文件。
    @objc
    private func openMenu() { session.open(menuEntries) }

    /// 打开或关闭 Quick Look 面板。
    @objc
    private func quickLookMenu() { toggleQuickLook(menuEntries) }

    /// 菜单暂存所选条目。
    @objc
    private func stageMenu() { session.stage(menuEntries.filter(\.isStageable), staged: true) }

    /// 菜单取消暂存所选条目。
    @objc
    private func unstageMenu() { session.stage(menuEntries.filter(\.isStageable), staged: false) }

    /// 停止跟踪前由会话确认影响范围。
    @objc
    private func untrackMenu() { session.untrack(menuEntries) }

    /// 删除前由会话确认影响范围。
    @objc
    private func deleteMenu() { session.delete(menuEntries) }

    /// 移动表单由窗口呈现。
    @objc
    private func moveMenu() {
        guard let entry = menuEntries.first else { return }
        session.onFileRequest?(.form(.move(entry)))
    }

    /// 丢弃必须经过会话的确认入口。
    @objc
    private func discardMenu() { session.discard(menuEntries) }

    /// 恢复到指定版本的表单由窗口呈现。
    @objc
    private func revertMenu() { session.onFileRequest?(.form(.revert(menuEntries))) }

    /// 写入 `.gitignore`：菜单项的 tag 依次对应所选项、同名项、同类型与自定义规则。
    @objc
    private func ignoreMenu(_ sender: NSMenuItem) { addPatterns(tag: sender.tag, file: .gitignore) }

    /// 写入 `info/exclude`，tag 的含义与忽略菜单相同。
    @objc
    private func excludeMenu(_ sender: NSMenuItem) { addPatterns(tag: sender.tag, file: .exclude) }

    /// 设置 assume-unchanged 标记。
    @objc
    private func setAssumeUnchanged() { session.setAssumeUnchanged(menuEntries, true) }

    /// 清除 assume-unchanged 标记。
    @objc
    private func unsetAssumeUnchanged() { session.setAssumeUnchanged(menuEntries, false) }

    /// 复制远端路径时保留主机前缀。
    @objc
    private func copyAbsolute() {
        guard let repository = session.repository else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            menuEntries.map { repository.displayPath + "/" + $0.path }.joined(separator: "\n"),
            forType: .string
        )
    }

    /// 相对路径适合提交信息与终端中的仓库内引用。
    @objc
    private func copyRelative() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(menuEntries.map(\.path).joined(separator: "\n"), forType: .string)
    }

    /// 只有本机条目才交给 Finder。
    @objc
    private func reveal() {
        guard let root = session.repository?.localURL else { return }

        NSWorkspace.shared.activateFileViewerSelecting(menuEntries.map { root.appending(path: $0.path) })
    }

    /// 终端沿用当前仓库已实现的应用选择。
    @objc
    private func terminal() {
        NSApp.sendAction(#selector(RepositoryWindowController.openInTerminal), to: nil, from: outline)
    }
}

// MARK: - Private

extension WorkingCopyFileList.Coordinator {
    /// 按菜单项的 tag 生成规则或请求自定义规则表单。
    private func addPatterns(tag: Int, file: IgnoreFile) {
        let scopes: [IgnorePatternScope] = [.items, .name, .type]

        guard scopes.indices.contains(tag) else {
            session.onFileRequest?(.form(.pattern(file, menuEntries)))
            return
        }

        session.ignore(menuEntries, scope: scopes[tag], in: file)
    }

    /// 一个文件时点名，多个时写出数量。
    private func countedTitle(single: String, multiple: String) -> String {
        guard menuEntries.count == 1, let entry = menuEntries.first else {
            return AppLocalization.text(multiple, menuEntries.count)
        }

        return AppLocalization.text(single, WorkingCopyFileList.fileName(of: entry.path))
    }

    /// 新的一组菜单项前加分隔线；菜单开头和连续的分隔线不加。
    private func beginGroup(in menu: NSMenu) {
        guard let last = menu.items.last, !last.isSeparatorItem else { return }

        menu.addItem(.separator())
    }

    /// 带本地化标题的子菜单。
    private func submenu(_ key: String, in menu: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: AppLocalization.text(key), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)
        submenu.autoenablesItems = false
        item.submenu = submenu
        menu.addItem(item)
        return submenu
    }

    /// 按资源键添加菜单项，可用性由当前会话决定。
    private func add(_ key: String, action: Selector, enabled: Bool, to menu: NSMenu) {
        add(title: AppLocalization.text(key), action: action, enabled: enabled, to: menu)
    }

    /// 菜单可用性由当前会话决定，不依赖响应链的隐式校验。
    @discardableResult
    private func add(title: String, action: Selector, enabled: Bool, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
        return item
    }
}
