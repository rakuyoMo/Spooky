import SpookyKit

// MARK: - CommitDetailContent

/// 提交详情实际显示的内容，视图与变更集命令使用同一判定。
enum CommitDetailContent {
    /// 历史里打开的版本比较。
    case comparison(RevisionComparisonState)

    /// 单选提交的变更集或文件树。
    case commit(HistoryCommit)

    /// 没有单个有效提交时的选择提示。
    case selection
}

// MARK: - Changeset Commands

extension RepositorySession {
    /// 当前可见的变更集已完成文件列表读取，并且至少有一个文件。
    var canExpandChanges: Bool { visibleChangeset != nil }

    /// 历史比较只占用历史自己的详情，不覆盖 Reflog 的提交。
    func commitDetailContent(for state: RepositoryHistoryState) -> CommitDetailContent {
        if state === history, comparison.isActive {
            return .comparison(comparison)
        }

        if let commit = state.selectedCommit {
            return .commit(commit)
        }

        return .selection
    }

    /// 展开或折叠当前实际显示的变更集，隐藏详情与不可用内容保持不变。
    func expandChanges(_ expanded: Bool) {
        switch visibleChangeset {
        case .history(let state): state.expandAll(expanded)
        case .comparison(let state): state.expandAll(expanded)
        case .stash: stashes.expandAll(expanded)
        case nil: break
        }
    }
}

// MARK: - Private

extension RepositorySession {
    /// 已通过可见性和读取状态检查的命令接收者。
    private enum Changeset {
        /// 历史或 Reflog 的提交详情。
        case history(RepositoryHistoryState)

        /// 历史、分支整理或请求详情里的版本比较。
        case comparison(RevisionComparisonState)

        /// 当前单选储藏。
        case stash
    }

    /// 仅从当前页面寻找接收者，不回退到被遮住的历史或比较。
    private var visibleChangeset: Changeset? {
        switch activeView {
        case .history:
            guard !history.showsCommitPage else { return nil }
            return changeset(in: history)

        case .stashes:
            guard
                stashes.selectedStash != nil,
                !stashes.isLoadingChanges,
                !stashes.changes.isEmpty
            else { return nil }
            return .stash

        case .reflog:
            guard
                let entry = reflog.selectedEntry,
                reflog.detail.selectedCommit?.id == entry.commit.id
            else { return nil }
            return changeset(in: reflog.detail)

        case .branchesReview:
            guard
                branchesReview.selectedIDs.count == 1,
                let id = branchesReview.selectedIDs.first,
                history.branches.contains(where: { $0.id == id })
            else { return nil }
            return changeset(in: branchesReview.comparison)

        case .pullRequests:
            guard
                pullRequests.detail != nil,
                pullRequests.page == .changeset,
                !pullRequests.needsFetch
            else { return nil }
            return changeset(in: pullRequests.comparison)

        default:
            return nil
        }
    }

    /// 提交详情的比较优先；比较的 Commits 分段不能落到背后的提交。
    private func changeset(in state: RepositoryHistoryState) -> Changeset? {
        switch commitDetailContent(for: state) {
        case .comparison(let comparison):
            return changeset(in: comparison)

        case .commit:
            guard !state.showsTree, !state.isLoadingChanges, !state.changes.isEmpty else { return nil }
            return .history(state)

        case .selection:
            return nil
        }
    }

    /// 比较必须正在显示有文件且已读完的 Changeset。
    private func changeset(in state: RevisionComparisonState) -> Changeset? {
        guard
            state.isActive,
            state.showsChangeset,
            !state.isLoadingChanges,
            !state.changes.isEmpty
        else { return nil }
        return .comparison(state)
    }
}
