import AppKit
import SwiftUI

// MARK: - Layout

extension RepositoryWindowController {
    /// 仓库视图外层分栏的 autosave 名称。
    static let repositorySplitName = "Spooky.Repository"

    /// 极窄版式里内层分栏 autosave 名称的后缀：上下排列时保存的是高度，与常规版式的宽度分开。
    private static let narrowSplitSuffix = ".Narrow"

    /// 内容区现在的宽度对应的版式。
    var fittingLayout: RepositoryWindowLayout {
        .fitting(contentWidth: window?.contentView?.frame.width ?? Self.defaultContentSize.width)
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

    /// 窗口的宽度越过极窄版式的界线时换版式；常规版式里随着窗口变宽，继续放回进入极窄版式时记下的分栏宽度。
    func windowDidResize(_: Notification) {
        guard !showsManager, session.repository != nil else {
            return
        }

        guard fittingLayout == layout else {
            configureRepositoryView()
            return
        }

        applyRegularSplitWidths()
    }
}

// MARK: - Private

extension RepositoryWindowController {
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
