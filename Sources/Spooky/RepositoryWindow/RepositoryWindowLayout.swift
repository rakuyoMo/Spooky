import AppKit

// MARK: - RepositoryWindowLayout

/// 仓库视图的版式，由窗口内容区的宽度决定。
enum RepositoryWindowLayout: Equatable {
    /// 常规版式：侧边栏、列表与详情左右分栏。
    case regular

    /// 极窄版式：侧边栏收成一行视图导航，列表与详情上下排列。
    case narrow

    /// 内容区窄于这个宽度时用极窄版式，与官网演示窗口换成紧凑版式的宽度相同。
    ///
    /// 常规版式里各视图的最小宽度都比它小，窗口在任何视图里都能收窄到这里。
    static let narrowThreshold: CGFloat = 820

    /// 极窄版式里内容区的最小宽度：视图导航排得下，默认排布的工具栏在标题后面还留得住 Fetch | Pull | Push。
    static let narrowMinimumWidth: CGFloat = 480

    /// 极窄版式里内层分栏上面一栏的最小高度。
    static let narrowListMinimumHeight: CGFloat = 120

    /// 按内容区的宽度取版式。
    ///
    /// - Parameter contentWidth: 窗口内容区的宽度。
    static func fitting(contentWidth: CGFloat) -> Self {
        contentWidth < narrowThreshold ? .narrow : .regular
    }
}
