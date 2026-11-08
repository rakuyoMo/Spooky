import AppKit
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
    /// 先核对它在历史里的位置，排得很靠后时询问；取消时视图、所选的引用、列表与选中的提交都不变。
    ///
    /// - Parameter objectID: 提交的完整哈希，引用传它所指的对象。
    func revealInHistory(_ objectID: String) {
        history.confirmLookup(objectID) { [weak self] in
            guard let self else {
                return
            }

            history.showsCommitPage = false
            history.locate(objectID)
            activeView = .history
            onActiveViewChange?()
        }
    }

    /// 在历史里只看一个引用，与侧边栏单击分支或标签相同；侧边栏展开并滚动到它的行。
    func showHistory(of reference: RepositoryReference) {
        history.showsCommitPage = false
        history.reveal([reference.id])
        activeView = .history
        onActiveViewChange?()
    }

    /// 侧边栏双击引用：HEAD 分支什么都不做；不能检出时响铃；标签检出成分离 HEAD，分支交给 ``checkoutBranch(_:in:)``。
    ///
    /// - Parameters:
    ///   - reference: 被双击的本地分支、远端分支或标签。
    ///   - target: 本地分支已在别的工作树检出时打开那个工作树的位置，按住 ⌘ 双击时是新标签页。
    ///   - beep: 不能检出时的提示音；测试换成记录调用。
    func doubleClick(
        _ reference: RepositoryReference,
        in target: RepositoryOpenTarget,
        beep: () -> Void = { NSSound.beep() }
    ) {
        // HEAD 分支已经检出，双击不响铃
        if reference.isLocal, reference.name == status?.branch.head {
            return
        }

        let available = reference.isTag ? canCheckoutRevision : canCheckout(reference)

        guard available else {
            beep()
            return
        }

        guard reference.isTag else {
            checkoutBranch(reference, in: target)
            return
        }

        checkout(revision: reference.id)
    }

    /// 检出分支，保留 Git 对本地修改的覆盖保护：本地分支直接检出，已在别的工作树检出时打开那个工作树；
    /// 远端分支检出已有的跟踪分支，有不跟踪它的同名本地分支时询问后检出那个分支并设好上游，都没有时原子创建并检出同名跟踪分支。
    ///
    /// 菜单、快捷操作与双击共用；不能检出时什么都不做，入口自己禁用或响铃。
    ///
    /// - Parameters:
    ///   - reference: 要检出的本地或远端分支。
    ///   - target: 本地分支已在别的工作树检出时打开那个工作树的位置。
    func checkoutBranch(_ reference: RepositoryReference, in target: RepositoryOpenTarget = .currentWindow) {
        guard canCheckout(reference) else {
            return
        }

        // 已在别的工作树检出的本地分支不能再检出，改为打开那个工作树
        if let worktree = worktrees.branchWorktrees[reference.id] {
            open(worktree, in: target)
            return
        }

        guard reference.isRemote else {
            performGit(
                { runner, _ in
                    try await RepositoryReferences(runner: runner).checkout(reference.id)
                },
                title: AppLocalization.text("branch.checkoutNamed", reference.name),
                offersAutoStash: true,
                undo: .reversible
            )
            return
        }

        guard let snapshot = history.snapshot, let remote = snapshot.remote(for: reference) else {
            return
        }

        if let existing = snapshot.references.first(where: { $0.isLocal && $0.upstream == reference.id }) {
            checkoutBranch(existing, in: target)
            return
        }

        let name = String(reference.id.dropFirst(("refs/remotes/" + remote.name + "/").count))

        // 同名本地分支可能有自己的提交，检出它并改设上游，不用远端分支的提交覆盖它
        if let local = snapshot.references.first(where: { $0.id == "refs/heads/" + name }) {
            confirmTrackingCheckout(local, upstream: reference)
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
            title: AppLocalization.text("branch.checkoutNamed", reference.name),
            offersAutoStash: true,
            undo: .reversible
        )
    }
}

// MARK: - Private

extension RepositorySession {
    /// 询问后检出同名的本地分支并把上游设为远端分支，询问里写出两个分支；取消时不执行任何 Git。
    ///
    /// 两步在一个写操作里先后执行：分支在别的工作树检出时说明原因、不写上游；上游设好后检出失败时说明上游已经改了。
    /// 结束后的完整刷新重新读出 HEAD、分支的提交与上游。
    ///
    /// - Parameters:
    ///   - branch: 与远端分支同名、没有跟踪它的本地分支。
    ///   - upstream: 被检出的远端分支。
    private func confirmTrackingCheckout(_ branch: RepositoryReference, upstream: RepositoryReference) {
        let repository = repository

        onConfirm?(ConfirmationRequest(
            title: AppLocalization.text("branch.trackExisting.title"),
            message: AppLocalization.text("branch.trackExisting.message", branch.name, upstream.name),
            submitTitle: AppLocalization.text("action.continue")
        ) { [weak self] in
            guard let self, self.repository == repository, canCheckout(upstream) else {
                return
            }

            // 询问期间两个分支有一个已被删除时不执行
            let references = history.snapshot?.references ?? []

            guard [branch.id, upstream.id].allSatisfy({ id in references.contains { $0.id == id } }) else {
                return
            }

            performGit(
                { runner, _ in
                    try await RepositoryReferences(runner: runner).checkout(branch.id, tracking: upstream.id)
                },
                title: AppLocalization.text("branch.checkoutNamed", branch.name),
                undo: .reversible
            )
        })
    }
}
