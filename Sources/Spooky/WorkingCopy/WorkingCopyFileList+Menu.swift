import AppKit
import SpookyKit

// MARK: - Context Menu

extension WorkingCopyFileList.Coordinator {
    /// 终端打开的位置：单个文件进所在目录，目录进该目录，没有作用对象时进仓库根目录；作用于多个对象时没有位置。
    ///
    /// 服务器仓库进入服务器上对应的目录。
    var terminalLocation: RepositoryLocation? {
        guard let repository = session.repository, menuTargets.count <= 1 else { return nil }

        guard let target = menuTargets.first else { return repository }

        // 目录取自身，文件取所在目录；未跟踪的目录条目以 “/” 结尾
        let path = target.path.hasSuffix("/") ? String(target.path.dropLast()) : target.path
        let isDirectory = target.entry == nil || target.path.hasSuffix("/")
        let directory = isDirectory ? path : path.split(separator: "/").dropLast().joined(separator: "/")

        guard !directory.isEmpty else { return repository }

        let absolute = repository.path + "/" + directory

        switch repository {
        case .local: return .local(path: absolute)
        case .remote(let host, _): return .remote(host: host, path: absolute)
        }
    }

    /// 右键菜单打开前按点击的位置重建。
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let outline else { return }

        buildMenu(menu, clickedRow: outline.clickedRow)
    }

    /// 点在选区内或空白处时作用于整个选区，点在选区外只作用于被点的行，选区与详情都不变；空白处又没有选择时作用对象为空。
    ///
    /// 菜单按打开、路径、系统、文件、冲突、丢弃与储藏、查看、规则、LFS 与比较分组。
    func buildMenu(_ menu: NSMenu, clickedRow: Int) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        guard let outline else { return }

        let selected = outline.selectedRowIndexes.compactMap { outline.item(atRow: $0) as? WorkingCopyFileList.Node }

        // 作用对象在构建时算出一次，标题、可用性与执行都用这一份
        if
            let node = outline.item(atRow: clickedRow) as? WorkingCopyFileList.Node,
            !outline.isRowSelected(clickedRow)
        {
            menuTargets = [node]
            menuEntries = node.entries
        } else {
            menuTargets = selected
            menuEntries = selected.isEmpty ? [] : session.selectedEntries
        }

        addOpenItems(to: menu)
        addPathItems(to: menu)
        addSystemItems(to: menu)
        addFileItems(to: menu)
        addConflictItems(to: menu)
        addDiscardItems(to: menu)
        addViewItems(to: menu)
        addRuleItems(to: menu)
        addLFSMenu(to: menu)
        addCompareMenu(to: menu)
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

    /// ⌘⌫ 删除所选文件：直接移进废纸篓，服务器上没有可用的废纸篓时确认后永久删除；没有可删除的文件时响铃。
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
    /// 打开：用默认程序打开文件，或在 Open With ▸ 里选程序；程序列表在第一次展开时按所选文件读取。
    private func addOpenItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("files.open", action: #selector(openMenu), enabled: session.canOpen(menuEntries), to: menu)

        let entries = menuEntries
        let names = entries.filter(\.isOpenable).map(\.path)
        let root = session.repository?.localURL

        // 本机文件按实际文件判断能打开它的程序，服务器文件只能按文件名判断
        let openWith = OpenWithMenu(
            load: {
                root.map { root in OpenWithApplications.load(for: names.map { root.appending(path: $0) }) }
                    ?? OpenWithApplications.load(forNames: names)
            },
            open: { [session] application in session.open(entries, with: application) },
            other: { [session] in session.openWithOtherApplication(entries) }
        )

        menu.addItem(openWith.item(enabled: session.canOpen(entries)))
    }

    /// 路径：复制带主机前缀的完整路径与仓库内的相对路径；没有作用的条目时不可用。
    private func addPathItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("workspace.copyPathMenu", action: #selector(copyAbsolute), enabled: !menuEntries.isEmpty, to: menu)
        add("working.copyRelative", action: #selector(copyRelative), enabled: !menuEntries.isEmpty, to: menu)
    }

    /// 系统：Quick Look、Finder 与终端；服务器仓库的文件在 Finder 中按挂载位置显示，没有挂载时提示原因。
    ///
    /// 没有作用对象时 Quick Look 打开零项的预览，Finder 与终端以仓库根目录为目标。
    private func addSystemItems(to menu: NSMenu) {
        beginGroup(in: menu)

        let title: String =
            if quickLook.isVisible {
                AppLocalization.text("files.quickLook.close")
            } else {
                countedTitle(
                    single: "files.quickLook.single",
                    multiple: "files.quickLook.multiple",
                    generic: "files.spacebar.quickLook"
                )
            }

        add(
            title: title,
            action: #selector(quickLookMenu),
            enabled: menuTargets.isEmpty || session.canOpen(menuEntries),
            to: menu
        )

        let revealItem = add(
            title: AppLocalization.text("action.revealFinder"),
            action: #selector(reveal),
            enabled: session.canShowInFinder,
            to: menu
        )
        revealItem.toolTip = session.finderUnavailableTip

        add("action.openTerminal", action: #selector(terminal), enabled: terminalLocation != nil, to: menu)
    }

    /// 文件：暂存、取消暂存、停止跟踪、删除与移动；服务器上的删除是永久删除。
    private func addFileItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add(
            title: countedTitle(single: "working.stage.single", multiple: "working.stage.multiple", generic: "working.stage"),
            action: #selector(stageMenu),
            enabled: session.canStage(menuEntries),
            to: menu
        )
        add(
            title: countedTitle(
                single: "working.unstage.single",
                multiple: "working.unstage.multiple",
                generic: "working.unstage"
            ),
            action: #selector(unstageMenu),
            enabled: session.canUnstage(menuEntries),
            to: menu
        )
        add(
            title: countedTitle(single: "files.untrack.single", multiple: "files.untrack.multiple", generic: "files.untrack"),
            action: #selector(untrackMenu),
            enabled: session.canUntrack(menuEntries),
            to: menu
        )
        add(
            session.fileRemoval == .trash ? "files.trash" : "files.delete",
            action: #selector(deleteMenu),
            enabled: session.canDelete(menuEntries),
            to: menu
        )
        add("files.move.menu", action: #selector(moveMenu), enabled: session.canMove(menuEntries), to: menu)
    }

    /// 冲突：解决合并冲突与恢复合并冲突版本两个子菜单，以及用合并工具解决单个冲突文件；可用性按所选文件逐项判断。
    private func addConflictItems(to menu: NSMenu) {
        beginGroup(in: menu)
        ConflictMenu.add(to: menu, entries: menuEntries, names: menuTargets.map(\.name), session: session)
        add(
            "externalTool.openMergeTool",
            action: #selector(mergeToolMenu),
            enabled: session.canOpenMergeTool(menuEntries),
            to: menu
        )
    }

    /// 丢弃与储藏：丢弃改动、储藏与快照所选文件、恢复到指定版本；覆盖工作区的操作执行前确认。
    private func addDiscardItems(to menu: NSMenu) {
        beginGroup(in: menu)
        add("working.discard.menu", action: #selector(discardMenu), enabled: session.canDiscard(menuEntries), to: menu)
        addStashItems(to: menu, entries: menuEntries)
        add("files.revert.menu", action: #selector(revertMenu), enabled: session.canRevert(menuEntries), to: menu)
    }

    /// 查看：原文、Blame 与文件历史，只对单个文件提供；没有作用对象时以通用标题显示且不可用。
    private func addViewItems(to menu: NSMenu) {
        guard !menuTargets.isEmpty else {
            beginGroup(in: menu)

            for key in ["quickActions.showFile", "quickActions.showBlame", "quickActions.showFileHistory"] {
                let item = NSMenuItem(title: AppLocalization.text(key), action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }

            return
        }

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
        let set = add(
            title: AppLocalization.text("files.assumeUnchanged.set"),
            action: #selector(setAssumeUnchanged),
            enabled: false,
            to: mark
        )

        let unset = add(
            title: AppLocalization.text("files.assumeUnchanged.unset"),
            action: #selector(unsetAssumeUnchanged),
            enabled: false,
            to: mark
        )

        // 标记不在轮询里读取：打开菜单时读一次作用条目的实际标记，读到后再启用；读取失败时两项保持禁用
        let entries = menuEntries

        Task { [session] in
            guard let marked = await session.assumeUnchangedPaths(of: entries) else { return }

            set.isEnabled = session.canMarkAssumeUnchanged(entries, true, marked: marked)
            unset.isEnabled = session.canMarkAssumeUnchanged(entries, false, marked: marked)
        }
    }

    /// LFS ▸：逐个跟踪所选文件、跟踪同类型的全部文件，或输入自定义规则；执行时才检查 Git LFS 是否可用。
    private func addLFSMenu(to menu: NSMenu) {
        beginGroup(in: menu)

        let lfs = submenu("lfs.menu", in: menu)
        let single = menuEntries.count == 1
        let types = session.lfsTypePatterns(for: menuEntries)

        // 没有作用的文件时用单个文件的标题，不写出零个
        add(
            title: menuEntries.count > 1
                ? AppLocalization.text("lfs.trackFiles", menuEntries.count)
                : AppLocalization.text("lfs.trackFile"),
            action: #selector(trackLFSFiles),
            enabled: session.canTrackLFS(menuEntries),
            to: lfs
        )

        // 一个文件时写出它的扩展名，多个文件时按各自的扩展名跟踪
        let suffix = single ? types.first.map { String($0.dropFirst("*.".count)) } : nil

        add(
            title: suffix.map { AppLocalization.text("lfs.trackType.single", $0) } ?? AppLocalization.text("lfs.trackType"),
            action: #selector(trackLFSTypes),
            enabled: session.canWrite && !types.isEmpty,
            to: lfs
        )
        add("lfs.createPattern.menu", action: #selector(createLFSPattern), enabled: session.canWrite, to: lfs)
    }

    /// Compare ▸：总是列出工作区、暂存区与 HEAD 之间的三种比较，两侧没有差别时不可用；作用于单个对象时，
    /// 再隔一条分隔线列出我方、对方与共同祖先之间的三种比较，不是冲突文件时不可用。
    ///
    /// 没有作用对象时前三种比较整个工作区。
    private func addCompareMenu(to menu: NSMenu) {
        beginGroup(in: menu)

        let compare = submenu("externalTool.compare", in: menu)
        let entries = menuTargets.isEmpty ? session.status?.entries ?? [] : menuEntries

        for comparison in WorkingCopyComparison.allCases {
            guard !comparison.isConflictComparison || menuTargets.count == 1 else { continue }

            // 冲突比较与前三种之间隔一条分隔线
            if comparison == .oursToTheirs {
                compare.addItem(.separator())
            }

            let item = add(
                title: AppLocalization.text(comparison.titleKey),
                action: #selector(compareMenu(_:)),
                enabled: session.canCompare(entries, comparison),
                to: compare
            )
            item.representedObject = (comparison, entries)
        }
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

        // 没有作用的条目时第一项用单项的标题，不写出零项
        let titles = [
            menuEntries.count > 1
                ? AppLocalization.text(prefix + ".items", menuEntries.count)
                : AppLocalization.text(prefix + ".item"),
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

    /// 用合并工具解决所选的冲突文件。
    @objc
    private func mergeToolMenu() {
        guard let entry = menuEntries.first else { return }
        session.openMergeTool(entry)
    }

    /// 用比较工具按菜单项对应的方式比较打开菜单时算出的文件。
    @objc
    private func compareMenu(_ sender: NSMenuItem) {
        guard let (comparison, entries) = sender.representedObject as? (WorkingCopyComparison, [StatusEntry]) else {
            return
        }

        session.compare(entries, comparison)
    }

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

    /// 逐个跟踪所选文件。
    @objc
    private func trackLFSFiles() { session.trackLFS(menuEntries) }

    /// 跟踪与所选文件同类型的全部文件。
    @objc
    private func trackLFSTypes() { session.trackLFS(session.lfsTypePatterns(for: menuEntries)) }

    /// 自定义规则表单由窗口呈现，预填第一个所选文件的路径。
    @objc
    private func createLFSPattern() { session.onFileRequest?(.form(.lfsPattern(menuEntries))) }

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

    /// 交给 Finder 的是条目在这台 Mac 上的路径；服务器仓库按挂载位置换算，没有作用对象时显示仓库根目录。
    @objc
    private func reveal() {
        let urls =
            menuTargets.isEmpty
                ? [session.finderURL()].compactMap { $0 }
                : menuEntries.compactMap { session.finderURL($0.path) }

        guard !urls.isEmpty else { return }

        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// 在作用对象的目录里打开终端，沿用设置里选择的终端程序；错误显示在列表所在的窗口。
    @objc
    private func terminal() {
        guard let location = terminalLocation else { return }

        (outline?.window?.windowController as? RepositoryWindowController)?.openLocationInTerminal(location)
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

    /// 按作用的行点名或计数：一项时写出名称，多项时写出数量，没有作用对象时用通用标题；树形里一个目录算一项。
    private func countedTitle(single: String, multiple: String, generic: String) -> String {
        switch menuTargets.count {
        case 0: AppLocalization.text(generic)
        case 1: AppLocalization.text(single, menuTargets[0].name)
        default: AppLocalization.text(multiple, menuTargets.count)
        }
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
