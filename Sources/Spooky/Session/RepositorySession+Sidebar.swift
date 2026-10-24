import SpookyKit

// MARK: - Sidebar

extension RepositorySession {
    /// 置顶或取消置顶需要至少一个本地分支；菜单、拖放共用这条规则。
    func canSetPinned(_ references: [RepositoryReference]) -> Bool {
        canWrite && !references.isEmpty && references.allSatisfy(\.isLocal)
    }

    /// 归档或取消归档需要至少一个本地分支；菜单、拖放共用这条规则。
    func canSetArchived(_ references: [RepositoryReference]) -> Bool {
        canWrite && !references.isEmpty && references.allSatisfy(\.isLocal)
    }

    /// 置顶或取消置顶若干本地分支；配置写入经仓库写队列并记入 Activity，完成后的完整刷新读回新快照。
    func setPinned(_ pinned: Bool, branches: [RepositoryReference]) {
        guard canSetPinned(branches) else {
            return
        }

        let ids = branches.map(\.id)

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setPinned(pinned, branches: ids)
            },
            title: AppLocalization.text(pinned ? "branch.pin" : "branch.unpin")
        )
    }

    /// 归档或取消归档若干本地分支，写入方式与置顶相同。
    func setArchived(_ archived: Bool, branches: [RepositoryReference]) {
        guard canSetArchived(branches) else {
            return
        }

        let ids = branches.map(\.id)

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setArchived(archived, branches: ids)
            },
            title: AppLocalization.text(archived ? "branch.archive" : "branch.unarchive")
        )
    }

    /// 在历史中显示标签：切到全部历史并选中它所指的提交，提交不在已加载的分页里时继续加载去找。
    func revealInHistory(_ reference: RepositoryReference) {
        history.showsCommitPage = false
        history.locate(reference.objectID)
        activeView = .history
        onActiveViewChange?()
    }
}
