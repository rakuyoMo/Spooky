import Foundation

// MARK: - HistoryScopeMemory

/// 一个历史范围上次的选中与滚动位置。
struct HistoryScopeMemory: Equatable {
    /// 离开这个范围时选中的提交。
    var selection = Set<String>()

    /// 离开这个范围时列表可见区顶边的位置；还没有记下时为 nil。
    var scrollOffset: CGFloat? = nil
}

// MARK: - Scope Memory

extension RepositoryHistoryState {
    /// 换范围时记下离开的范围的选中，换成新范围上次的选中；没看过的范围先不选，读完后选中第一行。
    /// 新范围读完后列表滚回它上次的位置，没看过的范围从顶部开始。
    ///
    /// 回到历史查找提交、恢复窗口等入口在换范围之后再设选中，以它们设的为准。
    ///
    /// - Parameter old: 离开的范围，即换之前选中的引用。
    func switchScope(from old: Set<String>) {
        scopeMemories[old, default: HistoryScopeMemory()].selection = selectedIDs
        selectedIDs = scopeMemories[selectedReferences]?.selection ?? []
        pendingScroll = scopeMemories[selectedReferences]?.scrollOffset ?? 0
    }

    /// 记下一个范围的列表滚到的位置。
    ///
    /// - Parameters:
    ///   - offset: 列表可见区顶边的位置。
    ///   - scope: 范围，即选中的引用。
    func rememberScroll(_ offset: CGFloat, for scope: Set<String>) {
        scopeMemories[scope, default: HistoryScopeMemory()].scrollOffset = offset
    }
}
