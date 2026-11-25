import AppKit
import SwiftUI

// MARK: - Layout

extension RepositoryWindowController {
    /// 仓库视图外层分栏的 autosave 名称。
    static let repositorySplitName = "Spooky.Repository"

    /// 仓库管理分栏的 autosave 名称。
    private static let managerSplitName = "Spooky.Repositories"

    /// 极窄版式里上下排列的分栏 autosave 名称的后缀：保存的是高度，与常规版式的宽度分开。
    private static let narrowSplitSuffix = ".Narrow"

    /// 还没有记下宽度时，仓库管理侧边栏的宽度。
    private static let managerSidebarWidth: CGFloat = 260

    /// 现在该用的版式：按 View › Window Layout 的选择与内容区的宽度取。
    var fittingLayout: RepositoryWindowLayout {
        .fitting(
            contentWidth: window?.contentView?.frame.width ?? Self.defaultContentSize.width,
            mode: .current
        )
    }

    /// 窗口现在排成的是不是极窄版式；丢失页与克隆进度页不分版式。
    var showsNarrowLayout: Bool {
        narrowContent != nil || showsManager && layout == .narrow
    }

    /// 常规版式里外层分栏与当前内层分栏首栏的宽度，键是分栏的 autosave 名称。
    private var currentSplitWidths: [String: CGFloat] {
        var widths: [String: CGFloat] = [:]

        for split in [outerSplit, innerSplit] {
            guard let split, let name = split.splitView.autosaveName, let first = split.splitViewItems.first else {
                continue
            }

            widths[name] = first.viewController.view.frame.width
        }

        return widths
    }

    /// NSSplitView 按 autosave 名称保存各栏位置的偏好键。
    static func splitFramesKey(_ name: String) -> String {
        "NSSplitView Subview Frames " + name
    }

    /// 主视图里列表与详情的分栏：常规版式左右排列，极窄版式上下排列，两种版式按各自的名称保存尺寸。
    ///
    /// - Parameter name: 常规版式里分栏的 autosave 名称。
    func makeInnerSplit(name: String) -> NSSplitViewController {
        let split = NSSplitViewController()
        split.splitView.isVertical = layout == .regular
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName(layout == .regular ? name : name + Self.narrowSplitSuffix, of: split)
        return split
    }

    /// 内层分栏里列表一栏的最小尺寸：常规版式是给定的最小宽度，极窄版式是上面一栏的最小高度。
    ///
    /// - Parameter regularWidth: 常规版式里列表的最小宽度。
    func listMinimumThickness(_ regularWidth: CGFloat) -> CGFloat {
        layout == .regular ? regularWidth : RepositoryWindowLayout.narrowListMinimumHeight
    }

    /// 极窄版式的仓库视图：顶部一行视图导航，下面是当前主视图；仓库内切换只替换主视图，视图导航与侧边栏留着。
    ///
    /// - Parameter detail: 当前主视图。
    func installNarrowContent(detail: NSViewController) {
        outerSplit = nil

        if let narrowContent, window?.contentViewController === narrowContent {
            narrowContent.replaceDetail(with: detail)
            window?.contentView?.layoutSubtreeIfNeeded()
            return
        }

        let navigation = NSHostingController(rootView: CompactNavigationBar(
            session: session,
            state: compactNavigation,
            toggleSidebar: { [weak self] in
                guard let self else {
                    return
                }

                setCompactSidebarShown(!compactNavigation.showsSidebar)
            },
            show: { [weak self] in self?.showCompactView($0) }
        ))

        let content = NarrowRepositoryViewController(
            navigation: navigation,
            sidebar: NSHostingController(rootView: makeSidebarView()),
            detail: detail
        )
        content.onDismissSidebar = { [weak self] in self?.setCompactSidebarShown(false) }
        narrowContent = content
        install(content)

        // 键盘焦点先落在内容的根视图上，提交信息框不因为换版式或打开仓库进入编辑
        window?.initialFirstResponder = content.view
        window?.makeFirstResponder(content.view)
    }

    /// 仓库管理按现在该用的版式装入窗口：常规版式里书签列表是左边的侧边栏，极窄版式里书签列表在上、详情在下。
    ///
    /// - Parameters:
    ///   - sidebar: 书签列表。
    ///   - detail: 详情区。
    func installManager(sidebar: NSViewController, detail: NSViewController) {
        layout = fittingLayout

        // 常规版式沿用左右分栏，书签列表是带侧边栏材质的一栏
        guard layout == .narrow else {
            installOuterSplit(
                sidebar: sidebar,
                detail: detail,
                name: Self.managerSplitName,
                sidebarWidth: Self.managerSidebarWidth
            )
            return
        }

        // 极窄版式另建上下排列的分栏，分隔线的位置记在自己的名称下
        let name = Self.managerSplitName + Self.narrowSplitSuffix
        let split = NSSplitViewController()
        split.splitView.isVertical = false
        split.splitView.dividerStyle = .thin
        Self.setAutosaveName(name, of: split)

        // 书签列表不可折叠；窗口变矮时先压详情，变高时多出的高度也给详情
        let listItem = NSSplitViewItem(viewController: sidebar)
        listItem.minimumThickness = RepositoryWindowLayout.narrowManagerListMinimumHeight
        listItem.holdingPriority = .init(485)
        listItem.canCollapse = false

        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.holdingPriority = .init(480)

        split.addSplitViewItem(listItem)
        split.addSplitViewItem(detailItem)

        // 内容区的最小宽度与极窄版式的仓库视图相同
        split.view.widthAnchor
            .constraint(greaterThanOrEqualToConstant: RepositoryWindowLayout.narrowMinimumWidth)
            .isActive = true

        outerSplit = split
        narrowContent = nil
        install(split)

        // 首次使用或恢复失败后列表与详情各占一半的高度，此后交给 NSSplitView 的 autosave 恢复
        if UserDefaults.standard.object(forKey: Self.splitFramesKey(name)) == nil {
            split.splitView.setPosition(split.splitView.bounds.height / 2, ofDividerAt: 0)
        }
    }

    /// 把内容换进窗口。
    ///
    /// - Parameter content: 换入的窗口内容。
    func install(_ content: NSViewController) {
        // 换入的内容先取当前内容尺寸：AppKit 会把窗口缩放到新视图的尺寸，缩小的窗口还会改写分栏的宽度记录。
        if let size = window?.contentView?.frame.size {
            content.view.setFrameSize(size)
        }

        // 盖在主视图上的侧边栏随换下的内容一起收起
        compactNavigation.showsSidebar = false
        window?.contentViewController = content
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    /// 观察分隔线的移动，记下常规版式里各分栏首栏定下的宽度。
    func observeSplitDividers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(splitViewDidResize(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: nil
        )
    }

    /// 极窄版式里显示或收起盖在主视图上的侧边栏。
    ///
    /// - Parameter shown: 是否显示。
    func setCompactSidebarShown(_ shown: Bool) {
        compactNavigation.showsSidebar = shown
        narrowContent?.showsSidebar = shown
    }

    /// 进入极窄版式之前，记下正在显示的分栏定下的宽度；还没有放回的不覆盖。
    func rememberRegularSplitWidths() {
        guard outerSplit?.splitView.autosaveName == Self.repositorySplitName else {
            return
        }

        let displayed = currentSplitWidths
        regularSplitWidths.merge(settledSplitWidths.filter { displayed[$0.key] != nil }) { remembered, _ in remembered }
    }

    /// 常规版式的分栏装入窗口之后：进入极窄版式时记过宽度的放回，其余的以现在的宽度为定下的宽度。
    func settleRegularSplitWidths() {
        guard layout == .regular else {
            return
        }

        applyRegularSplitWidths()

        for (name, width) in currentSplitWidths where regularSplitWidths[name] == nil {
            settledSplitWidths[name] = width
        }
    }

    /// 该用的版式与现在排成的不同时，重排仓库管理或仓库视图；丢失页与克隆进度页不分版式。
    ///
    /// - Returns: 是否重排过。
    @discardableResult
    func refitLayout() -> Bool {
        guard fittingLayout != layout, showsManager || session.repository != nil else {
            return false
        }

        // 仓库管理换分栏的方向，仓库视图按新版式重建容器
        if showsManager {
            rearrangeManager()
        } else {
            configureRepositoryView()
        }

        return true
    }

    /// 窗口的宽度越过极窄版式的界线时换版式；常规版式的仓库视图随着窗口变宽，继续放回进入极窄版式时记下的分栏宽度。
    func windowDidResize(_: Notification) {
        guard !refitLayout(), !showsManager, session.repository != nil else {
            return
        }

        applyRegularSplitWidths()
    }

    /// View › Window Layout 的三项：记下取版式的方式，所有仓库窗口一起按它重排。
    @objc
    func setLayoutMode(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: RepositoryWindowLayoutMode.key)

        // 发起的窗口先生效，再同步其它仓库窗口
        refitLayout()

        for controller in coordinator?.windows ?? [] where controller !== self {
            controller.refitLayout()
        }
    }

    /// View › Window Layout 各项的可用性，当前的选择打勾；动作不属于本组时为 nil。
    func layoutAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        guard item.action == #selector(setLayoutMode(_:)) else {
            return nil
        }

        // 标签是取版式方式的原始值，与偏好里记下的相同的那一项打勾
        if let item = item as? NSMenuItem {
            item.state = item.tag == RepositoryWindowLayoutMode.current.rawValue ? .on : .off
        }

        return true
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 仓库管理换版式：沿用同一份书签列表与详情区，选中、展开与读到的仓库概况都留着。
    private func rearrangeManager() {
        guard let split = outerSplit, split.splitViewItems.count == 2 else {
            return
        }

        // 换下的分栏不再保存：各栏取走之后，它会把名下记着的分隔线位置写成空记录
        split.splitView.autosaveName = nil

        // 列表与详情先从换下的分栏里取出，再装进新的分栏
        let controllers = split.splitViewItems.map(\.viewController)
        split.splitViewItems.forEach(split.removeSplitViewItem)

        installManager(sidebar: controllers[0], detail: controllers[1])

        // 侧边栏分隔符与各项的可见优先级随版式变
        updateToolbarItems()
    }

    /// 视图导航切换三个视图，与侧边栏的行、⌘1 至 ⌘3 使用相同状态。
    private func showCompactView(_ view: RepositoryView) {
        switch view {
        case .workingCopy:
            showWorkingCopy()

        case .history:
            showHistory()

        default:
            showStashes()
        }
    }

    /// 常规版式里把进入极窄版式时记下的宽度放回正在显示的分栏；窗口不够宽时分栏按各栏的最小宽度收住，
    /// 留着记下的宽度，等窗口变宽再放，放到位后不再记着。
    private func applyRegularSplitWidths() {
        guard layout == .regular, !regularSplitWidths.isEmpty else {
            return
        }

        isArrangingSplits = true
        defer { isArrangingSplits = false }

        // 外层先放回，内层再按放回后的详情宽度定位
        for split in [outerSplit, innerSplit] {
            guard
                let split, let name = split.splitView.autosaveName,
                let width = regularSplitWidths[name], let first = split.splitViewItems.first
            else {
                continue
            }

            window?.contentView?.layoutSubtreeIfNeeded()
            split.splitView.setPosition(width, ofDividerAt: 0)
            split.splitView.layoutSubtreeIfNeeded()

            if abs(first.viewController.view.frame.width - width) < 0.5 {
                regularSplitWidths[name] = nil
            }
        }
    }

    /// 常规版式里分隔线被移动后，所在分栏首栏现在的宽度就是定下的宽度，进入极窄版式时记下的不再放回。
    ///
    /// 窗口缩放带来的分栏变化不带分隔线的序号，不算在内。
    @objc
    private func splitViewDidResize(_ notification: Notification) {
        guard
            layout == .regular, !showsManager, !isArrangingSplits,
            notification.userInfo?["NSSplitViewDividerIndex"] != nil,
            let splitView = notification.object as? NSSplitView
        else {
            return
        }

        for split in [outerSplit, innerSplit] {
            guard
                let split, split.splitView === splitView,
                let name = splitView.autosaveName, let first = split.splitViewItems.first
            else {
                continue
            }

            settledSplitWidths[name] = first.viewController.view.frame.width
            regularSplitWidths[name] = nil
        }
    }
}
