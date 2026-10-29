import Foundation

// MARK: - View State

extension RepositorySession {
    /// 当前仓库的视图状态，切换仓库时存入窗口缓存。
    func captureViewState() -> RepositoryViewState {
        RepositoryViewState(
            // 文件视图与远端视图的目标不随仓库保存，切回时显示历史
            activeView: [.fileHistory, .fileContent, .remote].contains(activeView) ? .history : activeView,
            selectedID: selectedID,
            selectedIDs: selectedIDs,
            diffSide: diffSide,
            commitSubject: commitSubject,
            commitBody: commitBody,
            amend: amend,
            originalDraft: originalDraft,
            onlyConflicts: onlyConflicts,
            historyReferences: history.selectedReferences,
            historyCommits: history.selectedIDs
        )
    }

    /// 切回仓库时恢复视图状态；数据随后重新读取，失效的选区由刷新结果过滤。
    func restore(_ state: RepositoryViewState) {
        activeView = state.activeView
        commitSubject = state.commitSubject
        commitBody = state.commitBody
        amend = state.amend
        originalDraft = state.originalDraft
        onlyConflicts = state.onlyConflicts
        selectedIDs = state.selectedIDs

        // 先恢复选中行再恢复暂存侧，选中行的变更回调会重置暂存侧。
        selectedID = state.selectedID
        diffSide = state.diffSide
        history.restore(references: state.historyReferences, commits: state.historyCommits)
    }
}
