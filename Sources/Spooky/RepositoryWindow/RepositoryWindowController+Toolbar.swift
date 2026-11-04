import AppKit
import SwiftUI

// MARK: - RepositoryToolbar

/// 仓库窗口工具栏的标识与排布；项的标识写进工具栏的自动保存配置，所有仓库窗口共用一套。
enum RepositoryToolbar {
    /// 工具栏标识：标识相同的工具栏共用一套自定义配置。
    static let identifier = NSToolbar.Identifier("Spooky.MainToolbar")

    /// 仓库管理的入口，显示仓库管理时呈选中状态。
    static let repositories = NSToolbarItem.Identifier("repositories")

    /// 跟随侧边栏分隔线的分隔符。
    static let sidebarSeparator = NSToolbarItem.Identifier("sidebarSeparator")

    /// 跟随内层分栏第一条分隔线的分隔符，插在侧边栏分隔符之后；只显示图标、窗口显示仓库且当前视图有内层分栏时出现。
    static let detailSeparator = NSToolbarItem.Identifier("detailSeparator")

    /// 回到父仓库；本仓库不是子模块时隐藏。
    static let parentRepository = NSToolbarItem.Identifier("parentRepository")

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

    /// 最近克隆的气泡；有克隆时才显示。
    static let clone = NSToolbarItem.Identifier("clone")

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

    /// 在 Finder 中显示。
    static let finder = NSToolbarItem.Identifier("finder")

    /// 在终端中打开。
    static let terminal = NSToolbarItem.Identifier("terminal")

    /// 默认排布：侧边栏上方是仓库管理入口，主视图上方依次是父仓库、后退 / 前进、快捷操作、主机前缀、同步与合并、储藏、刷新、关闭仓库与搜索框。
    static let defaultItems: [NSToolbarItem.Identifier] = [
        .flexibleSpace, repositories, sidebarSeparator, parentRepository, navigation, .flexibleSpace,
        quickActions, host, sync, synchronize, merge, stashes, refresh, clone, closeRepository, search,
    ]

    /// 自定义面板里可选的项：默认项之外另有新建分支、安全强推、推送任意版本、Finder 与终端，以及系统的空白。
    static let allowedItems: [NSToolbarItem.Identifier] = [
        repositories, sidebarSeparator, parentRepository, navigation, quickActions, host, sync, synchronize, merge,
        stashes, refresh, clone, closeRepository, search, createBranch, forcePush, pushTo, finder, terminal,
        .space, .flexibleSpace,
    ]

    /// 不能移除或移动的项：父仓库在仓库是子模块时出现，主机前缀标明服务器仓库，Clone 在有克隆时出现，
    /// 跟随内层分栏的分隔符在有内层分栏时出现，不显示时都隐藏而不移除。
    static let immovableItems: Set<NSToolbarItem.Identifier> = [parentRepository, host, clone, detailSeparator]
}

// MARK: - Toolbar

extension RepositoryWindowController {
    /// 仓库窗口里仓库动作按钮的标签键、图标与动作。
    private static let buttons: [NSToolbarItem.Identifier: (
        label: String,
        palette: String,
        icon: ToolbarButtonIcon,
        action: Selector
    )] = [
        RepositoryToolbar.quickActions: (
            "toolbar.quickActions", "toolbar.quickActions", .symbol("wand.and.stars"), #selector(showQuickActions)
        ),
        RepositoryToolbar.refresh: (
            "action.refresh", "action.refresh", .symbol("arrow.clockwise"), #selector(refreshRepository)
        ),
        RepositoryToolbar.closeRepository: (
            "action.closeRepository", "action.closeRepository", .symbol("xmark.circle"), #selector(closeRepository)
        ),
        RepositoryToolbar.createBranch: (
            "toolbar.createBranch", "toolbar.createBranch", .symbol("arrow.branch"), #selector(createBranch)
        ),
        RepositoryToolbar.forcePush: (
            "toolbar.forcePush", "toolbar.forcePush", .image(TransferIcon.forcePush), #selector(forcePushWithLease)
        ),
        RepositoryToolbar.pushTo: (
            "toolbar.pushTo", "toolbar.pushTo", .image(TransferIcon.pushTo), #selector(pushRevision)
        ),
        RepositoryToolbar.finder: (
            "toolbar.finder", "action.revealFinder", .symbol("finder"), #selector(revealInFinder)
        ),
        RepositoryToolbar.terminal: (
            "toolbar.terminal", "action.openTerminal", .symbol("apple.terminal"), #selector(openInTerminal)
        ),
    ]

    /// 按钮与分段的提示，按动作查找：提示键，只显示图标时加在提示前面的标签键，以及服务器仓库里是否加主机前缀。
    ///
    /// 同步一组的提示随 ⌥ 切换，由同步一组自己设置，不在表里。
    private static let tips: [Selector: (tip: String, label: String?, showsHost: Bool)] = [
        #selector(showRepositories): ("toolbar.bookmarks.tip", "toolbar.bookmarks", false),
        #selector(navigateBack): ("navigation.back.tip", "toolbar.previous", false),
        #selector(navigateForward): ("navigation.forward.tip", "toolbar.next", false),
        #selector(applyStash): ("toolbar.applyStash.tip", "stash.apply", false),
        #selector(saveStash): ("toolbar.saveStash.tip", "stash.save", false),
        #selector(showQuickActions): ("toolbar.quickActions.tip", "toolbar.quickActions", true),
        #selector(refreshRepository): ("action.refresh", nil, true),
        #selector(closeRepository): ("action.closeRepository", nil, true),
        #selector(createBranch): ("toolbar.createBranch.tip", nil, true),
        #selector(forcePushWithLease): ("toolbar.forcePush.tip", nil, true),
        #selector(pushRevision): ("toolbar.pushTo", nil, true),
        #selector(revealInFinder): ("action.revealFinder", "toolbar.finder", true),
        #selector(openInTerminal): ("action.openTerminal", "toolbar.terminal", true),
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

        // 父仓库项不能移除；之前保存的配置里没有它时补在后退 / 前进之前
        if !toolbar.items.contains(where: { $0.itemIdentifier == RepositoryToolbar.parentRepository }) {
            let index = toolbar.items.firstIndex { $0.itemIdentifier == RepositoryToolbar.navigation } ?? 0
            toolbar.insertItem(withItemIdentifier: RepositoryToolbar.parentRepository, at: index)
        }

        // 显示方式改变后重写提示、更新跟随分隔符；别的仓库窗口改的显示方式同步过来时同样如此
        displayModeObservation = toolbar.observe(\.displayMode) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.updateToolbarItems()
            }
        }

        updateToolbarItems()
        observeClones()
        observeSuperproject()
    }

    /// 工具栏 Clone 项：开关最近克隆的气泡，点气泡外面关闭。
    @objc
    func toggleRecentClones(_ sender: NSToolbarItem) {
        if let clonePopover, clonePopover.isShown {
            clonePopover.close()
            return
        }

        guard let coordinator else {
            return
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: RecentClonesView(
            clones: coordinator.clones,
            open: { [weak self, weak popover] location in
                popover?.close()

                guard let self else {
                    return
                }

                coordinator.openRepository(at: location, from: self, inNewWindow: false)
            },
            openInTerminal: { [weak self] in self?.openLocationInTerminal($0) }
        ))

        clonePopover = popover
        popover.show(relativeTo: sender)
    }

    /// 默认排布。
    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        RepositoryToolbar.defaultItems
    }

    /// 自定义面板里可选的项。
    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        RepositoryToolbar.allowedItems
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

        case RepositoryToolbar.parentRepository:
            return makeParentRepositoryItem()

        case RepositoryToolbar.host:
            return makeHostItem()

        case RepositoryToolbar.clone:
            return makeCloneItem()

        case RepositoryToolbar.stashes:
            return makeStashToolbarItem(identifier)

        case RepositoryToolbar.search:
            return makeSearchItem(identifier)

        case RepositoryToolbar.sidebarSeparator:
            // 跟随外层分栏的第一条分隔线；换外层分栏时由 trackSidebar(of:) 改跟新的分隔线
            let split = (window?.contentViewController as? NSSplitViewController)?.splitView ?? NSSplitView()
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: split, dividerIndex: 0)

        case RepositoryToolbar.detailSeparator:
            return makeDetailSeparator()

        default:
            return makeButton(identifier)
        }
    }

    /// 换视图、换仓库或换显示方式后刷新工具栏：仓库管理入口的选中状态、主机前缀、搜索框、跟随内层分栏的分隔符与各项的提示，
    /// 再重新校验可用性。
    func updateToolbarItems() {
        guard let toolbar = window?.toolbar else {
            return
        }

        insertDetailSeparatorIfNeeded(in: toolbar)

        for item in toolbar.items {
            switch item.itemIdentifier {
            case RepositoryToolbar.repositories:
                (item as? NSToolbarItemGroup)?.setSelected(showsManager, at: 0)

            case RepositoryToolbar.host:
                updateHostItem(item)

            case RepositoryToolbar.clone:
                item.isHidden = coordinator?.clones.isEmpty ?? true

            case RepositoryToolbar.parentRepository:
                item.isHidden = showsManager || session.superprojectLocation == nil

            case RepositoryToolbar.search:
                if let item = item as? NSSearchToolbarItem {
                    configureSearchItem(item)
                }

            case RepositoryToolbar.detailSeparator:
                updateDetailSeparator(item)

            default:
                break
            }

            // 提示随显示方式与仓库变化，分段组逐段重写
            for subitem in (item as? NSToolbarItemGroup)?.subitems ?? [item] {
                updateTip(of: subitem)
            }
        }

        // 同步一组的提示随 ⌥ 切换，并在最后统一校验
        updateQuickToolbarItems(option: NSApp.keyWindow === window && NSEvent.modifierFlags.contains(.option))
    }

    /// 让侧边栏分隔符跟随新的外层分栏。
    func trackSidebar(of split: NSSplitViewController) {
        let item = window?.toolbar?.items.first { $0.itemIdentifier == RepositoryToolbar.sidebarSeparator }
        (item as? NSTrackingSeparatorToolbarItem)?.splitView = split.splitView
    }

    /// 按提示表设置一个按钮或分段的提示；动作不在表里的项不动。
    func updateTip(of item: NSToolbarItem) {
        guard let action = item.action, let entry = Self.tips[action] else {
            return
        }

        item.toolTip = toolbarTip(
            AppLocalization.text(entry.tip),
            label: entry.label.map { AppLocalization.text($0) },
            showsHost: entry.showsHost
        )
    }

    /// 工具栏项的提示：只显示图标时在前面加上 “<标签>: ”，`label` 为 nil 的项不加；
    /// `showsHost` 的项在服务器仓库里再在最前面加主机前缀，分不清是哪台机器上的仓库时不至于点错。
    ///
    /// - Parameters:
    ///   - tip: 提示正文。
    ///   - label: 只显示图标时加在提示前面的标签。
    ///   - showsHost: 服务器仓库里是否加主机前缀。
    func toolbarTip(_ tip: String, label: String?, showsHost: Bool) -> String {
        var text = tip

        if let label, window?.toolbar?.displayMode == .iconOnly {
            text = AppLocalization.text("toolbar.labeledTip", label, tip)
        }

        let host = showsHost && !showsManager ? session.repository?.host : nil
        return host.map { $0 + ": " + text } ?? text
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 仓库管理入口 Bookmarks：单段的分段控件，显示仓库管理时选中；单选模式不能取消选中，按多选模式逐段设置。
    /// 窗口变窄时最后才进溢出菜单。
    private func makeRepositoriesItem() -> NSToolbarItem {
        let group = NSToolbarItemGroup(
            itemIdentifier: RepositoryToolbar.repositories,
            images: [NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil) ?? NSImage()],
            selectionMode: .selectAny,
            labels: [AppLocalization.text("toolbar.bookmarks")],
            target: self,
            action: nil
        )
        group.controlRepresentation = .expanded
        group.paletteLabel = AppLocalization.text("toolbar.bookmarks")
        group.visibilityPriority = .high
        group.setSelected(showsManager, at: 0)

        for segment in group.subitems {
            segment.target = self
            segment.action = #selector(showRepositories)
            updateTip(of: segment)
        }

        return group
    }

    /// Clone：有克隆时才显示，点按开关最近克隆的气泡。
    private func makeCloneItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: RepositoryToolbar.clone)
        item.label = AppLocalization.text("toolbar.clone")
        item.paletteLabel = item.label
        item.toolTip = item.label
        item.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: item.label)
        item.target = self
        item.action = #selector(toggleRecentClones(_:))
        item.isHidden = coordinator?.clones.isEmpty ?? true
        return item
    }

    /// 有了第一个克隆或清空后，Clone 项随之出现或隐藏。
    private func observeClones() {
        withObservationTracking {
            _ = coordinator?.clones.items
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let item = window?.toolbar?.items.first { $0.itemIdentifier == RepositoryToolbar.clone }
                item?.isHidden = coordinator?.clones.isEmpty ?? true
                observeClones()
            }
        }
    }

    /// 父仓库：排在标题之前，本仓库不是子模块时隐藏，窗口变窄时最后才进溢出菜单。
    private func makeParentRepositoryItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: RepositoryToolbar.parentRepository)
        item.label = AppLocalization.text("toolbar.parentRepository")
        item.paletteLabel = item.label
        item.toolTip = AppLocalization.text("toolbar.parentRepository.tip")
        item.image = NSImage(systemSymbolName: "arrow.turn.left.up", accessibilityDescription: item.label)
        item.visibilityPriority = .high
        item.isNavigational = true
        item.target = self
        item.action = #selector(showParentRepository)
        item.isHidden = showsManager || session.superprojectLocation == nil
        return item
    }

    /// 读到父仓库或换了仓库后，父仓库项随之出现或隐藏。
    private func observeSuperproject() {
        withObservationTracking {
            _ = session.submodules.superproject
            _ = session.repository
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let item = window?.toolbar?.items.first { $0.itemIdentifier == RepositoryToolbar.parentRepository }
                item?.isHidden = showsManager || session.superprojectLocation == nil
                observeSuperproject()
            }
        }
    }

    /// Prev | Next：按本窗口的后退 / 前进记录启用，排在标题之前。
    private func makeNavigationItem() -> NSToolbarItem {
        let segments: [(label: String, symbol: String, action: Selector)] = [
            ("toolbar.previous", "chevron.left", #selector(navigateBack)),
            ("toolbar.next", "chevron.right", #selector(navigateForward)),
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
            updateTip(of: segment)
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

    /// 按当前仓库与显示方式写入主机前缀，或隐藏它；主机前缀在工具栏上只出现一次：
    /// 显示标签时由标签写出，只显示图标时由视图写出。
    private func updateHostItem(_ item: NSToolbarItem) {
        let host = showsManager ? nil : session.repository?.host
        item.label = host.map { $0 + ":" } ?? ""
        item.isHidden = host == nil

        // 标签在每种显示方式下都写着主机前缀，溢出菜单拿它作菜单项的标题；视图只在不显示标签时写出
        let label = item.view as? NSTextField
        label?.stringValue = window?.toolbar?.displayMode == .iconOnly ? item.label : ""
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

        switch button.icon {
        case .symbol(let name):
            item.image = NSImage(systemSymbolName: name, accessibilityDescription: item.paletteLabel)

        case .image(let image):
            item.image = image
        }

        item.target = self
        item.action = button.action
        updateTip(of: item)

        // 新建分支与安全强推在窗口变窄时最后才进溢出菜单
        if [RepositoryToolbar.createBranch, RepositoryToolbar.forcePush].contains(identifier) {
            item.visibilityPriority = .high
        }

        return item
    }
}

// MARK: - Detail Separator

extension RepositoryWindowController {
    /// 跟随分隔符要跟的分栏与分隔线，以及是否显示：只显示图标且当前视图有内层分栏时，显示并跟内层分栏的第一条分隔线；
    /// 其余时候隐藏，停在外层分栏末尾之后并不存在的那条分隔线上，不与侧边栏分隔符跟同一条。窗口换成整页、没有分栏时为 nil。
    private var detailSeparatorTarget: (splitView: NSSplitView, divider: Int, isShown: Bool)? {
        if window?.toolbar?.displayMode == .iconOnly, let inner = innerSplit {
            return (inner.splitView, 0, true)
        }

        guard let outer = window?.contentViewController as? NSSplitViewController else {
            return nil
        }

        return (outer.splitView, outer.splitViewItems.count - 1, false)
    }

    /// 跟随分隔符：跟的分栏必须在本窗口里，窗口换成整页时不建，回到有内层分栏的视图后再插入；
    /// 别的仓库窗口插入它时会同步到本窗口，本窗口已经有了就不再建第二个。
    private func makeDetailSeparator() -> NSToolbarItem? {
        let exists = window?.toolbar?.items.contains {
            $0.itemIdentifier == RepositoryToolbar.detailSeparator
        } ?? false

        guard let target = detailSeparatorTarget, !exists else {
            return nil
        }

        let item = NSTrackingSeparatorToolbarItem(
            identifier: RepositoryToolbar.detailSeparator,
            splitView: target.splitView,
            dividerIndex: target.divider
        )
        item.isHidden = !target.isShown
        return item
    }

    /// 需要显示跟随分隔符而工具栏里还没有时，把它插在侧边栏分隔符之后；侧边栏分隔符被移出工具栏时不插。
    ///
    /// 同一标识的工具栏按位置同步删除，删掉它会连带删掉别的仓库窗口同一位置上的项，所以插入后一直留着，不需要时隐藏。
    private func insertDetailSeparatorIfNeeded(in toolbar: NSToolbar) {
        let identifiers = toolbar.items.map(\.itemIdentifier)

        guard
            detailSeparatorTarget?.isShown ?? false,
            !identifiers.contains(RepositoryToolbar.detailSeparator),
            let sidebar = identifiers.firstIndex(of: RepositoryToolbar.sidebarSeparator)
        else {
            return
        }

        toolbar.insertItem(withItemIdentifier: RepositoryToolbar.detailSeparator, at: sidebar + 1)
    }

    /// 跟随分隔符改跟当前的目标；窗口换成整页时隐藏，仍跟着原来的分栏。
    private func updateDetailSeparator(_ item: NSToolbarItem) {
        guard let item = item as? NSTrackingSeparatorToolbarItem else {
            return
        }

        guard let target = detailSeparatorTarget else {
            item.isHidden = true
            return
        }

        item.isHidden = !target.isShown

        guard item.splitView !== target.splitView || item.dividerIndex != target.divider else {
            return
        }

        // 换跟的中途也不能与侧边栏分隔符跟同一条分隔线：跟内层时先换分栏再改分隔线，停到外层时先改分隔线再换分栏
        if target.isShown {
            item.splitView = target.splitView
            item.dividerIndex = target.divider
        } else {
            item.dividerIndex = target.divider
            item.splitView = target.splitView
        }
    }
}

// MARK: - ToolbarButtonIcon

/// 仓库动作按钮的图标：SF 符号，或随 App 打包的模板图。
private enum ToolbarButtonIcon {
    /// SF 符号的名字。
    case symbol(String)

    /// 随 App 打包的模板图。
    case image(NSImage)
}
