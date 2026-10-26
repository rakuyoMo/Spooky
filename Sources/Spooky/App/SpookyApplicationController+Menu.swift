import AppKit
import SpookyKit

// MARK: - Menu

extension SpookyApplicationController {
    /// 主菜单只提供已有功能及必要的系统窗口、文本动作。
    func configureMenu() {
        let menu = NSMenu()
        NSApp.mainMenu = menu

        configureApplicationMenu(in: menu)
        configureFileMenu(in: menu)
        configureEditMenu(in: menu)
        configureViewMenu(in: menu)
        configureRepositoryMenu(in: menu)
        configureWorkingCopyMenu(in: menu)
        configureWindowMenu(in: menu)
        configureHelpMenu(in: menu)
    }

    /// 应用菜单：关于、检查更新、设置、隐藏与退出。
    private func configureApplicationMenu(in menu: NSMenu) {
        let application = addMenu("app.name", to: menu)
        addItem("menu.about", action: #selector(showAbout), target: self, to: application)

        // 检查与下载进行中时由更新器禁用这一项
        addItem(
            "updates.check",
            action: #selector(UpdateController.checkForUpdates(_:)),
            target: UpdateController.shared,
            to: application
        )

        application.addItem(.separator())
        addItem("settings.title", action: #selector(showSettings), key: ",", target: self, to: application)

        application.addItem(.separator())
        addItem("menu.hide", action: #selector(NSApplication.hide(_:)), key: "h", to: application)
        addItem(
            "menu.hideOthers",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            key: "h",
            modifiers: [.command, .option],
            to: application
        )
        addItem("menu.showAll", action: #selector(NSApplication.unhideAllApplications(_:)), to: application)

        application.addItem(.separator())
        addItem("menu.quit", action: #selector(NSApplication.terminate(_:)), key: "q", to: application)
    }

    /// File 菜单：新窗口与新标签、打开本机或服务器仓库、最近仓库、快捷操作、克隆，以及关闭与仓库位置的动作。
    private func configureFileMenu(in menu: NSMenu) {
        let file = addMenu("menu.file", to: menu)
        addItem("menu.newWindow", action: #selector(newWindow), key: "n", target: self, to: file)

        // 由前台的仓库窗口加到它的标签组；没有仓库窗口在前台时开新窗口
        addItem("menu.newTab", action: #selector(NSResponder.newWindowForTab(_:)), key: "t", to: file)
        addItem("action.openLocal", action: #selector(openRepositoryPanel), key: "o", target: self, to: file)

        addItem("action.addRemote", action: #selector(addRemoteRepository), target: self, to: file)
        let recentMenu = addMenu("menu.openRecent", to: file)
        recentMenu.delegate = self
        addItem(
            "quickActions.menu",
            action: #selector(RepositoryWindowController.showQuickActions),
            key: "a",
            modifiers: [.command, .shift],
            to: file
        )

        file.addItem(.separator())
        addItem(
            "clone.menu",
            action: #selector(cloneRepository),
            key: "c",
            modifiers: [.control, .command],
            target: self,
            to: file
        )

        file.addItem(.separator())
        addItem("action.closeRepository", action: #selector(RepositoryWindowController.closeRepository), to: file)
        addItem("menu.closeWindow", action: #selector(NSWindow.performClose(_:)), key: "w", to: file)

        file.addItem(.separator())
        addItem("action.revealFinder", action: #selector(RepositoryWindowController.revealInFinder), to: file)
        addItem("action.openTerminal", action: #selector(RepositoryWindowController.openInTerminal), to: file)
    }

    /// Edit 菜单：撤销与重做、系统文本动作、提交信息的段落重排与查找。
    private func configureEditMenu(in menu: NSMenu) {
        let edit = addMenu("menu.edit", to: menu)

        // 标题与可用性由窗口的撤销管理器在每次打开菜单时给出
        addItem("menu.undo", action: Selector(("undo:")), key: "z", to: edit)
        addItem("menu.redo", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift], to: edit)

        edit.addItem(.separator())
        addItem("menu.cut", action: #selector(NSText.cut(_:)), key: "x", to: edit)
        addItem("menu.copy", action: #selector(NSText.copy(_:)), key: "c", to: edit)
        addItem("menu.paste", action: #selector(NSText.paste(_:)), key: "v", to: edit)
        addItem("menu.selectAll", action: #selector(NSText.selectAll(_:)), key: "a", to: edit)
        addItem(
            "commit.reformatParagraph",
            action: #selector(CommitMessageTextView.reformatParagraph(_:)),
            key: "w",
            modifiers: [.command, .shift],
            to: edit
        )

        edit.addItem(.separator())
        let find = addMenu("menu.find", to: edit)
        addItem("action.find", action: #selector(RepositoryWindowController.focusSearch), key: "f", to: find)

        // 按住 ⌥ 时 Find… 换成 Search，同样聚焦工具栏搜索框
        let search = NSMenuItem(
            title: AppLocalization.text("action.search"),
            action: #selector(RepositoryWindowController.focusSearch),
            keyEquivalent: "f"
        )
        search.keyEquivalentModifierMask = [.command, .option]
        search.isAlternate = true
        find.addItem(search)
    }

    /// View 菜单：仓库管理、工作区、历史、储藏与 Reflog 视图，后退与前进，工作区文件列表、历史与 Diff 的显示选项，刷新，窗口标题与工具栏，以及全屏。
    private func configureViewMenu(in menu: NSMenu) {
        let view = addMenu("menu.view", to: menu)
        addItem(
            "menu.showRepositories",
            action: #selector(showRepositoryManager),
            key: "r",
            modifiers: [.control, .command],
            target: self,
            to: view
        )

        view.addItem(.separator())
        addItem("menu.showWorkingCopy", action: #selector(RepositoryWindowController.showWorkingCopy), key: "1", to: view)
        addItem("menu.showHistory", action: #selector(RepositoryWindowController.showHistory), key: "2", to: view)
        addItem("stash.show", action: #selector(RepositoryWindowController.showStashes), key: "3", to: view)
        addItem("pr.show.menu", action: #selector(RepositoryWindowController.showPullRequests), key: "4", to: view)
        addItem(
            "review.show",
            action: #selector(RepositoryWindowController.showBranchesReview),
            key: "5",
            to: view
        )
        addItem("reflog.show", action: #selector(RepositoryWindowController.showReflog), key: "6", to: view)
        addItem(
            "history.showHead",
            action: #selector(RepositoryWindowController.showHeadBranch),
            key: "0",
            to: view
        )

        view.addItem(.separator())
        addItem("navigation.back", action: #selector(RepositoryWindowController.navigateBack), key: "[", to: view)
        addItem(
            "navigation.forward",
            action: #selector(RepositoryWindowController.navigateForward),
            key: "]",
            to: view
        )

        view.addItem(.separator())
        configureWorkingCopyStatusMenu(in: view)
        configureHistoryMenu(in: view)
        configureSidebarMenu(in: view)

        view.addItem(.separator())
        configureHistoryDiffsMenu(in: view)
        configureDiffContextMenu(in: view)

        view.addItem(.separator())
        addItem("action.refresh", action: #selector(RepositoryWindowController.refreshRepository), key: "r", to: view)

        // 窗口标题与工具栏：标题的显示偏好所有仓库窗口共用，工具栏的显示与排布由工具栏自动保存
        view.addItem(.separator())
        addItem("menu.hideWindowTitle", action: #selector(RepositoryWindowController.toggleWindowTitle), to: view)
        addItem("menu.showToolbar", action: #selector(NSWindow.toggleToolbarShown(_:)), to: view)
        addItem("menu.customizeToolbar", action: #selector(NSWindow.runToolbarCustomizationPalette(_:)), to: view)

        view.addItem(.separator())
        addItem(
            "menu.fullscreen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            key: "f",
            modifiers: [.control, .command],
            to: view
        )
    }

    /// 工作区状态子菜单：平铺与树形、显示未改动、被忽略与 assume-unchanged 的文件。
    private func configureWorkingCopyStatusMenu(in view: NSMenu) {
        let status = addMenu("files.statusMenu", to: view)
        addItem(
            "working.tree",
            action: #selector(RepositoryWindowController.viewAsTree),
            key: "t",
            modifiers: [.control, .command],
            to: status
        )
        addItem(
            "working.list",
            action: #selector(RepositoryWindowController.viewAsList),
            key: "l",
            modifiers: [.control, .command],
            to: status
        )

        status.addItem(.separator())
        addItem(
            "files.showNonModified",
            action: #selector(RepositoryWindowController.toggleNonModifiedItems),
            key: "m",
            modifiers: [.control, .command],
            to: status
        )
        addItem(
            "files.showIgnored",
            action: #selector(RepositoryWindowController.toggleIgnoredItems),
            key: "i",
            modifiers: [.control, .command],
            to: status
        )
        addItem(
            "files.showAssumeUnchanged",
            action: #selector(RepositoryWindowController.toggleAssumeUnchangedItems),
            key: "u",
            modifiers: [.control, .command],
            to: status
        )
    }

    /// 历史子菜单：与列表头设置按钮相同的提交图、第一父、排序、分组、行高与签名校验。
    private func configureHistoryMenu(in view: NSMenu) {
        let history = addMenu("history.title", to: view)
        HistoryViewMenu.addItems(to: history, keyEquivalents: true)
    }

    /// 变更集子菜单：全部展开、全部收起与自动展开阈值。
    private func configureHistoryDiffsMenu(in view: NSMenu) {
        let changes = addMenu("history.diffs", to: view)
        addItem(
            "history.expandAll",
            action: #selector(RepositoryWindowController.expandChanges),
            key: "\u{f703}",
            modifiers: [.control, .command],
            to: changes
        )
        addItem(
            "history.collapseAll",
            action: #selector(RepositoryWindowController.collapseChanges),
            key: "\u{f702}",
            modifiers: [.control, .command],
            to: changes
        )

        changes.addItem(.separator())

        for threshold in [0, 5, 10, 15, 20, 25, 50, Int.max] {
            let title =
                threshold == 0
                    ? AppLocalization.text("history.autoExpand.never")
                    : (
                        threshold == Int.max
                            ? AppLocalization.text("history.autoExpand.always")
                            : AppLocalization.text("history.autoExpand.items", threshold)
                    )

            let item = NSMenuItem(
                title: title,
                action: #selector(RepositoryWindowController.setAutoExpand(_:)),
                keyEquivalent: ""
            )
            item.tag = threshold
            changes.addItem(item)
        }
    }

    /// Diff 上下文行数子菜单：每个档位一项，当前值打勾。
    private func configureDiffContextMenu(in view: NSMenu) {
        let context = addMenu("diff.contextMenu", to: view)

        for lines in DiffOptions.contextChoices {
            let item = NSMenuItem(
                title: DiffPreferences.contextTitle(lines),
                action: #selector(RepositoryWindowController.setDiffContextLines(_:)),
                keyEquivalent: ""
            )
            item.tag = lines
            context.addItem(item)
        }
    }

    /// Repository 菜单：获取、拉取、同步与推送，发布分支、标签与仓库，获取与更新子模块，添加远端、子模块与工作树，新建分支、标签与请求，导出与比较版本，LFS，以及打开比较工具。
    private func configureRepositoryMenu(in menu: NSMenu) {
        let repository = addMenu("menu.repository", to: menu)
        configureSyncItems(in: repository)

        addItem("sync.publish", action: #selector(RepositoryWindowController.publishBranch), to: repository)
        addItem("tag.publishMainMenu", action: #selector(RepositoryWindowController.publishTag), to: repository)
        addItem("publish.menu", action: #selector(RepositoryWindowController.publishRepository), to: repository)

        repository.addItem(.separator())
        addItem("menu.fetchSubmodule", action: #selector(RepositoryWindowController.fetchSubmodule), to: repository)
        addItem("menu.fetchAllSubmodules", action: #selector(RepositoryWindowController.fetchAllSubmodules), to: repository)
        addItem("menu.updateSubmodule", action: #selector(RepositoryWindowController.updateSubmodule), to: repository)
        addItem("menu.updateAllSubmodules", action: #selector(RepositoryWindowController.updateAllSubmodules), to: repository)

        repository.addItem(.separator())
        addItem("remote.addMainMenu", action: #selector(RepositoryWindowController.addRemote), to: repository)
        addItem("menu.addSubmodule", action: #selector(RepositoryWindowController.addSubmodule), to: repository)
        addItem("menu.addWorktree", action: #selector(RepositoryWindowController.addWorktree), to: repository)

        repository.addItem(.separator())
        addItem(
            "branch.create",
            action: #selector(RepositoryWindowController.createBranch),
            key: "b",
            to: repository
        )
        addItem(
            "tag.createMenu",
            action: #selector(RepositoryWindowController.createTag),
            key: "t",
            modifiers: [.shift, .command],
            to: repository
        )

        repository.addItem(.separator())
        addItem(
            "pr.create.menu",
            action: #selector(RepositoryWindowController.createPullRequest),
            key: "p",
            modifiers: [.control, .command],
            to: repository
        )

        repository.addItem(.separator())
        addItem("export.menu", action: #selector(RepositoryWindowController.exportRevision), to: repository)
        addItem("compare.menu", action: #selector(RepositoryWindowController.compareRevisions), to: repository)

        repository.addItem(.separator())
        configureLFSMenu(in: repository)

        repository.addItem(.separator())
        addItem(
            "externalTool.openDiffTool",
            action: #selector(RepositoryWindowController.openDiffTool),
            key: "d",
            modifiers: [.shift, .command],
            to: repository
        )
    }

    /// LFS 子菜单：更新钩子，LFS 对象的获取、拉取与推送，以及新建跟踪规则。
    private func configureLFSMenu(in repository: NSMenu) {
        let lfs = addMenu("lfs.menu", to: repository)
        addItem("lfs.menu.update", action: #selector(RepositoryWindowController.updateLFS), to: lfs)

        lfs.addItem(.separator())
        addItem("lfs.menu.fetch", action: #selector(RepositoryWindowController.fetchLFS), to: lfs)
        addItem("lfs.menu.pull", action: #selector(RepositoryWindowController.pullLFS), to: lfs)
        addItem("lfs.menu.push", action: #selector(RepositoryWindowController.pushLFS), to: lfs)

        lfs.addItem(.separator())
        addItem("lfs.menu.track", action: #selector(RepositoryWindowController.trackLFS), to: lfs)
    }

    /// 获取、拉取、同步与推送各项，按住 ⌥ 换成快速操作；后接安全强推与推送任意版本。
    private func configureSyncItems(in repository: NSMenu) {
        addItem(
            "sync.fetch",
            action: #selector(RepositoryWindowController.fetch),
            key: "f",
            modifiers: [.shift, .command],
            to: repository
        )
        addAlternate(
            "sync.quickFetch",
            action: #selector(RepositoryWindowController.quickFetch),
            key: "f",
            to: repository
        )
        addItem("sync.fetchAll", action: #selector(RepositoryWindowController.fetchAll), to: repository)
        addItem(
            "sync.pull",
            action: #selector(RepositoryWindowController.pull),
            key: "p",
            modifiers: [.shift, .command],
            to: repository
        )
        addAlternate(
            "sync.quickPull",
            action: #selector(RepositoryWindowController.quickPull),
            key: "p",
            to: repository
        )
        addItem(
            "sync.syncMenu",
            action: #selector(RepositoryWindowController.sync),
            key: "y",
            modifiers: [.shift, .command],
            to: repository
        )
        addAlternate(
            "sync.quickSync",
            action: #selector(RepositoryWindowController.quickSync),
            key: "y",
            to: repository
        )
        addItem(
            "sync.push",
            action: #selector(RepositoryWindowController.push),
            key: "u",
            modifiers: [.shift, .command],
            to: repository
        )
        addAlternate(
            "sync.quickPush",
            action: #selector(RepositoryWindowController.quickPush),
            key: "u",
            to: repository
        )
        addItem(
            "sync.forcePushMenu",
            action: #selector(RepositoryWindowController.forcePushWithLease),
            key: "u",
            modifiers: [.control, .command],
            to: repository
        )
        addItem(
            "sync.pushToMenu",
            action: #selector(RepositoryWindowController.pushRevision),
            to: repository
        )
    }

    /// Working Copy 菜单：检出版本、合并与变基（按住 ⌥ 换成快速操作）、变基到别处与应用补丁，储藏，提交与暂存，丢弃改动与重置 HEAD，以及用比较工具比较。
    private func configureWorkingCopyMenu(in menu: NSMenu) {
        let working = addMenu("workspace.title", to: menu)
        addItem(
            "rewrite.checkout.menu",
            action: #selector(RepositoryWindowController.checkoutRevision),
            key: "b",
            modifiers: [.shift, .command],
            to: working
        )
        addItem(
            "sync.merge",
            action: #selector(RepositoryWindowController.merge),
            key: "m",
            modifiers: [.shift, .command],
            to: working
        )
        addAlternate(
            "sync.quickMerge",
            action: #selector(RepositoryWindowController.quickMerge),
            key: "m",
            to: working
        )
        addItem(
            "sync.rebaseMenu",
            action: #selector(RepositoryWindowController.rebase),
            key: "r",
            modifiers: [.shift, .command],
            to: working
        )
        addAlternate(
            "sync.quickRebase",
            action: #selector(RepositoryWindowController.quickRebase),
            key: "r",
            to: working
        )
        addItem(
            "rewrite.rebaseOnto.menu",
            action: #selector(RepositoryWindowController.rebaseOnto),
            key: "r",
            modifiers: [.control, .shift, .command],
            to: working
        )
        addItem("files.applyPatch.menu", action: #selector(RepositoryWindowController.applyPatch), to: working)

        working.addItem(.separator())
        addItem(
            "stash.saveMenu", action: #selector(RepositoryWindowController.saveStash),
            key: "s", modifiers: [.shift, .command], to: working
        )
        addItem(
            "stash.applyMenu", action: #selector(RepositoryWindowController.applyStash),
            key: "s", modifiers: [.option, .shift, .command], to: working
        )
        addItem(
            "stash.snapshotMenu", action: #selector(RepositoryWindowController.createSnapshot),
            key: "s", modifiers: [.control, .shift, .command], to: working
        )

        working.addItem(.separator())
        addItem(
            "working.commit", action: #selector(RepositoryWindowController.composeCommit),
            key: "c", modifiers: [.shift, .command], to: working
        )
        addItem("working.stage", action: #selector(RepositoryWindowController.stageSelected), to: working)
        addItem("working.unstage", action: #selector(RepositoryWindowController.unstageSelected), to: working)
        addItem(
            "working.stageAll", action: #selector(RepositoryWindowController.stageAll),
            key: "e", modifiers: [.shift, .command], to: working
        )
        addItem(
            "working.unstageAll", action: #selector(RepositoryWindowController.unstageAll),
            key: "e", modifiers: [.option, .shift, .command], to: working
        )

        working.addItem(.separator())
        addItem(
            "working.discard", action: #selector(RepositoryWindowController.discardSelected),
            key: "\u{8}", modifiers: [.shift, .command], to: working
        )
        addItem("working.discardAll", action: #selector(RepositoryWindowController.discardAll), to: working)
        addItem("rewrite.reset.menu", action: #selector(RepositoryWindowController.resetHead), to: working)

        configureCompareMenu(in: working)
    }

    /// Working Copy 菜单末尾的 Compare 子菜单：用比较工具比较所选文件的工作区、暂存区与 HEAD 版本。
    private func configureCompareMenu(in working: NSMenu) {
        working.addItem(.separator())

        let compare = addMenu("externalTool.compare", to: working)
        addItem(
            "externalTool.compare.workingTreeToBase",
            action: #selector(RepositoryWindowController.compareWorkingTreeToBase),
            key: "d",
            modifiers: [.control, .shift, .command],
            to: compare
        )
        addItem(
            "externalTool.compare.workingTreeToIndex",
            action: #selector(RepositoryWindowController.compareWorkingTreeToIndex),
            to: compare
        )
        addItem(
            "externalTool.compare.indexToBase",
            action: #selector(RepositoryWindowController.compareIndexToBase),
            to: compare
        )
    }

    /// Window 菜单：Activity 与系统窗口动作，并登记为应用的窗口菜单。
    private func configureWindowMenu(in menu: NSMenu) {
        let window = addMenu("menu.window", to: menu)
        NSApp.windowsMenu = window

        addItem(
            "activity.title",
            action: #selector(showActivity),
            key: "0",
            modifiers: [.control, .command],
            target: self,
            to: window
        )
        addItem("menu.minimize", action: #selector(NSWindow.performMiniaturize(_:)), key: "m", to: window)
        addItem("menu.zoom", action: #selector(NSWindow.performZoom(_:)), to: window)
        addItem("menu.bringAll", action: #selector(NSApplication.arrangeInFront(_:)), to: window)
    }

    /// 创建带本地化标题的子菜单。
    func addMenu(_ key: String, to parent: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: AppLocalization.text(key), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)
        item.submenu = submenu
        parent.addItem(item)
        return submenu
    }

    /// 按住 ⌥ 时替换上一项的快速操作：同一个按键，修饰键是 ⌥⇧⌘。
    private func addAlternate(_ key: String, action: Selector, key shortcut: String, to menu: NSMenu) {
        addItem(key, action: action, key: shortcut, modifiers: [.option, .shift, .command], to: menu)
        menu.items.last?.isAlternate = true
    }

    /// 统一菜单文案、快捷键和响应链目标。
    func addItem(
        _ key: String,
        action: Selector,
        key shortcut: String = "",
        modifiers: NSEvent.ModifierFlags = .command,
        target: AnyObject? = nil,
        to menu: NSMenu
    ) {
        let item = NSMenuItem(title: AppLocalization.text(key), action: action, keyEquivalent: shortcut)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        menu.addItem(item)
    }
}
