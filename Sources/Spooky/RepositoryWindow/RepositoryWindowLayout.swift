import AppKit

// MARK: - RepositoryWindowLayout

/// 仓库窗口的版式，按 `RepositoryWindowLayoutMode` 取。
enum RepositoryWindowLayout: Equatable {
    /// 常规版式：侧边栏、列表与详情左右分栏。
    case regular

    /// 极窄版式：仓库视图的侧边栏收成一行视图导航，列表与详情上下排列；仓库管理的列表在上、详情在下。
    case narrow

    /// 按宽度取版式时，内容区窄于这个宽度用极窄版式，与官网演示窗口换成紧凑版式的宽度相同。
    ///
    /// 常规版式里各视图的最小宽度都比它小，窗口在任何视图里都能收窄到这里。
    static let narrowThreshold: CGFloat = 820

    /// 极窄版式里内容区的最小宽度：视图导航排得下，默认排布的工具栏在标题后面还留得住 Fetch | Pull | Push。
    static let narrowMinimumWidth: CGFloat = 480

    /// 极窄版式里内层分栏上面一栏的最小高度。
    static let narrowListMinimumHeight: CGFloat = 120

    /// 极窄版式里仓库管理书签列表一栏在工具栏以下的最小高度：留得住分组标题、三行书签与底栏。
    static let narrowManagerListMinimumHeight: CGFloat = 150

    /// 取版式：固定了版式时不看宽度，否则内容区窄于界线时用极窄版式。
    ///
    /// - Parameters:
    ///   - contentWidth: 窗口内容区的宽度。
    ///   - mode: 取版式的方式。
    static func fitting(contentWidth: CGFloat, mode: RepositoryWindowLayoutMode) -> Self {
        switch mode {
        case .automatic:
            // 只有自动才看宽度，界线上算常规版式
            contentWidth < narrowThreshold ? .narrow : .regular

        case .narrow:
            .narrow

        case .regular:
            .regular
        }
    }
}

// MARK: - RepositoryWindowLayoutMode

/// 仓库窗口取版式的方式，由 View › Window Layout 选择；所有仓库窗口共用，存在偏好里。
enum RepositoryWindowLayoutMode: Int {
    /// 按内容区的宽度取。
    case automatic

    /// 不论宽度都用极窄版式。
    case narrow

    /// 不论宽度都用常规版式。
    case regular

    /// 保存选择的偏好键。
    static let key = "windowLayoutMode"

    /// 偏好里记下的选择；没有记录或记录无效时按宽度取。
    static var current: Self {
        // 没有记录时读出 0，正是按宽度取的原始值
        Self(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .automatic
    }
}
