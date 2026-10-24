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

    /// 检出标签需要没有进行中的操作。
    func canCheckoutTag(_ reference: RepositoryReference) -> Bool {
        canWrite && context?.operation == nil && reference.isTag
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

    /// 检出标签成分离 HEAD；被本地改动挡住时与检出分支一样询问是否先储藏。
    func checkoutTag(_ reference: RepositoryReference) {
        guard canCheckoutTag(reference) else {
            return
        }

        let id = reference.id

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).checkoutTag(id)
            },
            title: AppLocalization.text("tag.checkout"),
            offersAutoStash: true
        )
    }

    /// 在历史中显示标签：切到全部历史并选中它所指的提交。
    #warning("TODO: 所指提交不在历史的第一页时选择会被丢弃；需要一个能定位任意提交的历史入口")
    func revealInHistory(_ reference: RepositoryReference) {
        history.showsCommitPage = false
        history.selectedReferences = []
        history.selectedIDs = [reference.objectID]
        activeView = .history
        onActiveViewChange?()
    }
}
