import AppKit

// MARK: - RepositoryToolbar

/// 仓库窗口工具栏的标识与排布；项的标识写进工具栏的自动保存配置，所有仓库窗口共用一套。
enum RepositoryToolbar {
    /// 工具栏标识：标识相同的工具栏共用一套自定义配置。
    static let identifier = NSToolbar.Identifier("Spooky.MainToolbar")

    /// 仓库管理的入口，显示仓库管理时呈选中状态。
    static let repositories = NSToolbarItem.Identifier("repositories")

    /// 跟随侧边栏分隔线的分隔符。
    static let sidebarSeparator = NSToolbarItem.Identifier("sidebarSeparator")

    /// 后退 | 前进。
    static let navigation = NSToolbarItem.Identifier("navigation")

    /// 快捷操作面板。
    static let quickActions = NSToolbarItem.Identifier("quickActions")

    /// 服务器仓库的主机前缀，本机仓库与仓库管理中隐藏。
    static let host = NSToolbarItem.Identifier("host")

    /// Fetch | Pull | Push。
    static let sync = NSToolbarItem.Identifier("sync")

    /// Sync。
    static let synchronize = NSToolbarItem.Identifier("synchronize")

    /// Merge | Rebase。
    static let merge = NSToolbarItem.Identifier("merge")

    /// Apply | Save 储藏。
    static let stashes = NSToolbarItem.Identifier("stashes")

    /// 刷新。
    static let refresh = NSToolbarItem.Identifier("refresh")

    /// 关闭仓库，回到仓库管理。
    static let closeRepository = NSToolbarItem.Identifier("closeRepository")

    /// 过滤当前视图列表的搜索框。
    static let search = NSToolbarItem.Identifier("search")

    /// 新建分支。
    static let createBranch = NSToolbarItem.Identifier("createBranch")

    /// 安全强推。
    static let forcePush = NSToolbarItem.Identifier("forcePush")

    /// 推送任意版本。
    static let pushTo = NSToolbarItem.Identifier("pushTo")

    /// 推送到 Gerrit 评审；只在 Integration 里开启 Gerrit 推送后出现在自定义面板里。
    static let gerritPush = NSToolbarItem.Identifier("gerritPush")

    /// 全部暂存，按住 ⌥ 且有已暂存的改动时换成全部取消暂存。
    static let stageAll = NSToolbarItem.Identifier("stageAll")

    /// 聚焦提交信息的标题。
    static let commit = NSToolbarItem.Identifier("commit")

    /// 在 Finder 中显示。
    static let finder = NSToolbarItem.Identifier("finder")

    /// 在终端中打开。
    static let terminal = NSToolbarItem.Identifier("terminal")

    /// 默认排布：侧边栏上方是仓库管理入口，主视图上方依次是后退 / 前进、快捷操作、主机前缀、同步与合并、储藏、刷新、关闭仓库与搜索框。
    static let defaultItems: [NSToolbarItem.Identifier] = [
        .flexibleSpace, repositories, sidebarSeparator, navigation, .flexibleSpace,
        quickActions, host, sync, synchronize, merge, stashes, refresh, closeRepository, search,
    ]

    /// 自定义面板里可选的项：默认项之外另有新建分支、安全强推、推送任意版本、Finder、终端、全部暂存与提交，以及系统的空白。
    static let allowedItems: [NSToolbarItem.Identifier] = [
        repositories, sidebarSeparator, navigation, quickActions, host, sync, synchronize, merge, stashes,
        refresh, closeRepository, search, createBranch, forcePush, pushTo, finder, terminal,
        stageAll, commit, .space, .flexibleSpace,
    ]

    /// 不能移除或移动的项：主机前缀标明服务器仓库，不显示时隐藏而不移除。
    static let immovableItems: Set<NSToolbarItem.Identifier> = [host]
}

// MARK: - Toolbar

extension RepositoryWindowController {
    /// 仓库窗口里仓库动作按钮的标签键、符号与动作。
    private static let buttons: [NSToolbarItem.Identifier: (label: String, palette: String, symbol: String, action: Selector)] = [
        RepositoryToolbar.quickActions: (
            "toolbar.quickActions", "toolbar.quickActions", "wand.and.stars", #selector(showQuickActions)
        ),
        RepositoryToolbar.refresh: ("action.refresh", "action.refresh", "arrow.clockwise", #selector(refreshRepository)),
        RepositoryToolbar.closeRepository: (
            "action.closeRepository", "action.closeRepository", "xmark.circle", #selector(closeRepository)
        ),
        RepositoryToolbar.createBranch: (
            "toolbar.createBranch", "toolbar.createBranch", "arrow.branch", #selector(createBranch)
        ),
        RepositoryToolbar.forcePush: (
            "toolbar.forcePush", "toolbar.forcePush", "arrow.up.circle.fill", #selector(forcePushWithLease)
        ),
        RepositoryToolbar.pushTo: ("toolbar.pushTo", "toolbar.pushTo", "arrow.up.right.circle", #selector(pushRevision)),
        RepositoryToolbar.gerritPush: (
            "toolbar.gerritPush", "toolbar.gerritPush", "arrow.up.circle", #selector(pushToGerritRemote)
        ),
        RepositoryToolbar.stageAll: ("working.stageAll", "working.stageAll", "checkmark.square", #selector(stageAll)),
        RepositoryToolbar.commit: ("working.commit", "working.commit", "checkmark.circle", #selector(composeCommit)),
        RepositoryToolbar.finder: ("toolbar.finder", "action.revealFinder", "finder", #selector(revealInFinder)),
        RepositoryToolbar.terminal: ("toolbar.terminal", "action.openTerminal", "apple.terminal", #selector(openInTerminal)),
    ]

    /// 建立窗口唯一的工具栏：默认只显示图标，可以自定义，排布与显示方式自动保存并在所有仓库窗口间同步。
    func configureToolbar() {
        let toolbar = NSToolbar(identifier: RepositoryToolbar.identifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true

        // 先设好默认显示方式，再读入保存的配置覆盖它
        toolbar.autosavesConfiguration = true
        window?.toolbar = toolbar
        updateToolbarItems()
    }

    /// 默认排布。
    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        RepositoryToolbar.defaultItems
    }

    /// 自定义面板里可选的项；开启 Gerrit 推送后另有 Gerrit Push。
    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        RepositoryToolbar.allowedItems + (GerritPush.isEnabled ? [RepositoryToolbar.gerritPush] : [])
    }

    /// 不能移除或移动的项。
    func toolbarImmovableItemIdentifiers(_: NSToolbar) -> Set<NSToolbarItem.Identifier> {
        RepositoryToolbar.immovableItems
    }

    /// 按标识创建工具栏项；同步、储藏与搜索框由各自的扩展创建。
    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        // Fetch | Pull | Push、Sync 与 Merge | Rebase 随 ⌥ 切换成快速操作
        if let item = makeSyncToolbarItem(identifier) {
            return item
        }

        switch identifier {
        case RepositoryToolbar.repositories:
            return makeRepositoriesItem()

        case RepositoryToolbar.navigation:
            return makeNavigationItem()

        case RepositoryToolbar.host:
            return makeHostItem()

        case RepositoryToolbar.stashes:
            return makeStashToolbarItem(identifier)

        case RepositoryToolbar.search:
            return makeSearchItem(identifier)

        case RepositoryToolbar.sidebarSeparator:
            // 跟随外层分栏的第一条分隔线；换外层分栏时由 trackSidebar(of:) 改跟新的分隔线
            let split = (window?.contentViewController as? NSSplitViewController)?.splitView ?? NSSplitView()
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: split, dividerIndex: 0)

        default:
            return makeButton(identifier)
        }
    }

    /// 换视图或换仓库后刷新工具栏：仓库管理入口的选中状态、主机前缀、搜索框与带主机前缀的提示，再重新校验可用性。
    func updateToolbarItems() {
        guard let toolbar = window?.toolbar else {
            return
        }

        for item in toolbar.items {
            switch item.itemIdentifier {
            case RepositoryToolbar.repositories:
                (item as? NSToolbarItemGroup)?.setSelected(showsManager, at: 0)

            case RepositoryToolbar.host:
                updateHostItem(item)

            case RepositoryToolbar.search:
                if let item = item as? NSSearchToolbarItem {
                    configureSearchItem(item)
                }

            case RepositoryToolbar.stageAll:
                updateStageAllItem(item, option: NSApp.keyWindow === window && NSEvent.modifierFlags.contains(.option))

            default:
                updateButtonTip(item)
            }
        }

        // 快速操作的提示同样带主机前缀，并在最后统一校验
        updateQuickToolbarItems(option: NSApp.keyWindow === window && NSEvent.modifierFlags.contains(.option))
    }

    /// 按住 ⌥ 且有已暂存的改动时，全部暂存按钮换成全部取消暂存；标题与提示一起换。
    func updateStageAllItem(_ item: NSToolbarItem, option: Bool) {
        let unstage = option && (session.status?.entries.contains(where: \.hasStagedChanges) ?? false)
        let title = AppLocalization.text(unstage ? "working.unstageAll" : "working.stageAll")
        let host = showsManager ? nil : session.repository?.host

        item.label = title
        item.toolTip = host.map { $0 + ": " + title } ?? title
    }

    /// 让侧边栏分隔符跟随新的外层分栏。
    func trackSidebar(of split: NSSplitViewController) {
        let item = window?.toolbar?.items.first { $0.itemIdentifier == RepositoryToolbar.sidebarSeparator }
        (item as? NSTrackingSeparatorToolbarItem)?.splitView = split.splitView
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 仓库管理入口：单段的分段控件，显示仓库管理时选中；单选模式不能取消选中，按多选模式逐段设置。
    private func makeRepositoriesItem() -> NSToolbarItem {
        let group = NSToolbarItemGroup(
            itemIdentifier: RepositoryToolbar.repositories,
            images: [NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil) ?? NSImage()],
            selectionMode: .selectAny,
            labels: [AppLocalization.text("repositories.title")],
            target: self,
            action: nil
        )
        group.controlRepresentation = .expanded
        group.paletteLabel = AppLocalization.text("repositories.title")
        group.setSelected(showsManager, at: 0)

        for segment in group.subitems {
            segment.target = self
            segment.action = #selector(showRepositories)
            segment.toolTip = AppLocalization.text("menu.showRepositories")
        }

        return group
    }

    /// 后退 | 前进：按本窗口的后退 / 前进记录启用，排在标题之前。
    private func makeNavigationItem() -> NSToolbarItem {
        let segments: [(label: String, tip: String, symbol: String, action: Selector)] = [
            ("navigation.back", "navigation.back.tip", "chevron.left", #selector(navigateBack)),
            ("navigation.forward", "navigation.forward.tip", "chevron.right", #selector(navigateForward)),
        ]

        let group = NSToolbarItemGroup(
            itemIdentifier: RepositoryToolbar.navigation,
            images: segments.map {
                // 取不到符号时以空图占位，分段数与标签保持一致。
                NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) ?? NSImage()
            },
            selectionMode: .momentary,
            labels: segments.map { AppLocalization.text($0.label) },
            target: self,
            action: nil
        )
        group.controlRepresentation = .expanded
        group.paletteLabel = AppLocalization.text("navigation.title")
        group.isNavigational = true

        // 每段带上自己的动作，工具栏自动校验时逐段决定可用性
        for (segment, entry) in zip(group.subitems, segments) {
            segment.target = self
            segment.action = entry.action
            segment.toolTip = AppLocalization.text(entry.tip)
        }

        return group
    }

    /// 主机前缀：服务器仓库显示 “主机别名:”，本机仓库与仓库管理中隐藏。
    private func makeHostItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: RepositoryToolbar.host)
        item.paletteLabel = AppLocalization.text("toolbar.host")

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        item.view = label

        updateHostItem(item)
        return item
    }

    /// 按当前仓库写入主机前缀，或隐藏它。
    private func updateHostItem(_ item: NSToolbarItem) {
        let host = showsManager ? nil : session.repository?.host
        item.label = host.map { $0 + ":" } ?? ""
        item.isHidden = host == nil

        let label = item.view as? NSTextField
        label?.stringValue = item.label
        label?.setAccessibilityLabel(session.repository?.displayPath)
    }

    /// 仓库动作按钮；标识不在按钮表里时返回 nil。
    private func makeButton(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        guard let button = Self.buttons[identifier] else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = AppLocalization.text(button.label)
        item.paletteLabel = AppLocalization.text(button.palette)
        item.image = NSImage(systemSymbolName: button.symbol, accessibilityDescription: item.paletteLabel)
        item.target = self
        item.action = button.action
        updateButtonTip(item)
        return item
    }

    /// 仓库动作按钮的提示：服务器仓库带主机前缀，分不清是哪台机器上的仓库时不至于点错。
    private func updateButtonTip(_ item: NSToolbarItem) {
        guard let button = Self.buttons[item.itemIdentifier] else {
            return
        }

        let tip = AppLocalization.text(button.palette)
        let host = showsManager ? nil : session.repository?.host
        item.toolTip = host.map { $0 + ": " + tip } ?? tip
    }
}
