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
            title: AppLocalization.text(pinned ? "branch.pin" : "branch.unpin"),
            undo: .reversible
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
            title: AppLocalization.text(archived ? "branch.archive" : "branch.unarchive"),
            undo: .reversible
        )
    }

    /// 在历史中显示标签、分支或提交：切到全部历史并选中这个提交，提交不在已加载的分页里时继续加载去找。
    ///
    /// - Parameter objectID: 提交的完整哈希，引用传它所指的对象。
    func revealInHistory(_ objectID: String) {
        history.showsCommitPage = false
        history.locate(objectID)
        activeView = .history
        onActiveViewChange?()
    }

    /// 在历史里只看一个引用，与侧边栏单击分支或标签相同。
    func showHistory(of reference: RepositoryReference) {
        history.showsCommitPage = false
        history.selectedReference = reference.id
        activeView = .history
        onActiveViewChange?()
    }

    /// 检出分支，保留 Git 对本地修改的覆盖保护：本地分支直接检出；远端分支检出已有的跟踪分支，或原子创建并检出同名跟踪分支。
    ///
    /// - Parameters:
    ///   - reference: 要检出的本地或远端分支。
    ///   - request: 打开分支操作表单；同名本地分支已存在却不跟踪这个远端分支时，在跟踪表单里让用户指定名称。
    func checkoutBranch(_ reference: RepositoryReference, request: (RepositoryActionRequest) -> Void) {
        guard canCheckout(reference) else {
            return
        }

        guard reference.isRemote else {
            performGit(
                { runner, _ in
                    try await RepositoryReferences(runner: runner).checkout(reference.id)
                },
                title: AppLocalization.text("branch.checkout"),
                offersAutoStash: true,
                undo: .reversible
            )
            return
        }

        guard let snapshot = history.snapshot, let remote = snapshot.remote(for: reference) else {
            return
        }

        if let existing = snapshot.references.first(where: { $0.isLocal && $0.upstream == reference.id }) {
            checkoutBranch(existing, request: request)
            return
        }

        let name = String(reference.id.dropFirst(("refs/remotes/" + remote.name + "/").count))

        // 同名本地分支可能有不同含义，保留它并让用户在跟踪表单中指定名称。
        if snapshot.references.contains(where: { $0.id == "refs/heads/" + name }) {
            request(RepositoryActionRequest(kind: .track, reference: reference.id))
            return
        }

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner)
                    .create(
                        name: name,
                        startingAt: reference.id,
                        track: true,
                        checkout: true
                    )
            },
            title: AppLocalization.text("branch.checkout"),
            offersAutoStash: true,
            undo: .reversible
        )
    }
}
