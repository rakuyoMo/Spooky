import AppKit
import SpookyKit
import Synchronization

// MARK: - ForceDeletionOffer

/// 普通删除因未合并失败：带上要强制删除的分支与原来的选项，询问后按原选项强制删除。
struct ForceDeletionOffer: Error {
    /// 未合并分支的完整引用名。
    let branches: [String]

    /// 原来的删除是否同时删除跟踪的远端分支。
    let deletingUpstream: Bool

    /// 失败的说明与 Git 原文。
    let failure: ReferenceError
}

// MARK: - PendingForceDeletion

/// 多选删除只删掉一部分时，写操作里记下、结束后再询问的强制删除。
private final class PendingForceDeletion: Sendable {
    /// 未合并分支的询问；全部删掉时为 nil。
    let offer = Mutex<ForceDeletionOffer?>(nil)
}

// MARK: - Availability

extension RepositorySession {
    /// 快照里的本地标签，按名称排序。
    var tags: [RepositoryReference] {
        history.snapshot?.references.filter { $0.id.hasPrefix("refs/tags/") } ?? []
    }

    /// 新建标签需要仓库里已有提交。
    var canCreateTag: Bool {
        canWrite && (status?.branch.oid != nil || !(history.snapshot?.references.isEmpty ?? true))
    }

    /// 发布标签需要本地标签与远端。
    var canPublishTag: Bool {
        canWrite && !tags.isEmpty && !(history.snapshot?.remotes.isEmpty ?? true)
    }

    /// 版本框列表里的引用：本地分支、各远端的远端分支、标签依次成组，按 ``ReferenceOrder/candidates(_:in:)``；远端的 HEAD 不列出。
    var revisionReferences: [RepositoryReference] {
        ReferenceOrder.candidates(history.branches + tags, in: history.snapshot)
    }

    /// 远端名：名为 origin 的在最前，其余按名字；远端下拉的候选与没有上游时的默认远端都取这个顺序。
    var orderedRemoteNames: [String] {
        (history.snapshot?.remotes.map(\.name) ?? []).sorted(by: ReferenceOrder.precedes(remote:_:))
    }

    /// 名字是已有本地分支的文件夹（如已有 `feature/login` 时的 `feature`）；改名时不算被改名的分支自己。
    ///
    /// - Parameters:
    ///   - name: 新的分支名。
    ///   - excluded: 被改名的分支的完整引用名。
    func isBranchFolder(_ name: String, excluding excluded: String? = nil) -> Bool {
        history.branches.contains { $0.isLocal && $0.id != excluded && $0.name.hasPrefix(name + "/") }
    }

    /// 非当前的本地分支只落后于上游、没有自己的提交时才能快进。
    func canFastForward(_ reference: RepositoryReference) -> Bool {
        guard
            canWrite,
            reference.isLocal,
            reference.name != status?.branch.head,
            let counts = history.divergence[reference.id]
        else {
            return false
        }

        return counts.ahead == 0 && counts.behind > 0
    }

    /// 本地分支或远端分支的重命名、跟踪与父分支设置只要求仓库可写。
    func canManage(_ reference: RepositoryReference) -> Bool {
        canWrite && (reference.isLocal || reference.isRemote)
    }

    /// 删除远端分支需要所选都是远端分支。
    func canDeleteRemoteBranches(_ references: [RepositoryReference]) -> Bool {
        canWrite && !references.isEmpty && references.allSatisfy(\.isRemote)
    }

    /// 把版本框里的短名换成完整引用名，同名时按本地分支、远端分支、标签的顺序取；其余写法原样交给 Git。
    func revision(for text: String) -> String {
        revisionReferences.first { $0.id == text || $0.name == text }?.id ?? text
    }

    /// 远端分支所属的远端与它在远端上的短名；远端名按最长前缀匹配，可以含斜杠。
    func remoteParts(of reference: RepositoryReference) -> (remote: String, branch: String)? {
        guard reference.isRemote, let remote = history.snapshot?.remote(for: reference) else {
            return nil
        }

        return (remote.name, String(reference.id.dropFirst(("refs/remotes/" + remote.name + "/").count)))
    }
}

// MARK: - Branch Actions

extension RepositorySession {
    /// 交给窗口呈现引用管理的对话框或询问。
    func requestReference(_ request: ReferenceRequest) {
        onReferenceRequest?(request)
    }

    /// 把非当前分支快进到上游；不能快进时报告原因，不改动工作区。
    func fastForward(_ reference: RepositoryReference) {
        guard canFastForward(reference) else {
            return
        }

        performGit(
            { runner, output in
                try await RepositoryReferences(runner: runner).fastForward(reference.id, onOutput: output)
            },
            title: AppLocalization.text("branch.fastForward", reference.name),
            undo: .reversible,
            available: { $0.canFastForward(reference) }
        )
    }

    /// 设置本地分支的上游；已经跟踪它时什么都不做。
    func setUpstream(_ upstream: RepositoryReference, for branch: RepositoryReference) {
        guard canManage(branch), branch.upstream != upstream.id else {
            return
        }

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setUpstream(upstream.id, for: branch.id)
            },
            title: AppLocalization.text("branch.tracking.set"),
            touchesWorkingCopy: false,
            undo: .reversible,
            available: { $0.canManage(branch) }
        )
    }

    /// 取消本地分支的上游；没有上游时什么都不做。
    func unsetUpstream(of branch: RepositoryReference) {
        guard canManage(branch), branch.upstream != nil else {
            return
        }

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).unsetUpstream(of: branch.id)
            },
            title: AppLocalization.text("branch.tracking.remove"),
            touchesWorkingCopy: false,
            undo: .reversible,
            available: { $0.canManage(branch) }
        )
    }

    /// 把本地分支的父分支设为另一个分支，可以撤销；父分支子菜单的建议与设置父分支对话框共用。
    ///
    /// - Parameters:
    ///   - parent: 父分支的完整引用名。
    ///   - branch: 要设置父分支的本地分支。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func setParent(_ parent: String, of branch: RepositoryReference) -> Bool {
        guard canManage(branch), branch.isLocal, parent != branch.id else {
            return false
        }

        let id = branch.id

        return performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setParent(parent, of: id)
            },
            title: AppLocalization.text("branch.parent.set"),
            touchesWorkingCopy: false,
            undo: .reversible,
            available: { $0.canManage(branch) }
        )
    }

    /// 移除本地分支的父分支；本来没有父分支时同样成功。
    func removeParent(of branch: RepositoryReference) {
        guard canManage(branch), branch.isLocal else {
            return
        }

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setParent(nil, of: branch.id)
            },
            title: AppLocalization.text("branch.parent.remove"),
            touchesWorkingCopy: false,
            undo: .reversible,
            available: { $0.canManage(branch) }
        )
    }

    /// 删除本地分支；普通删除因未合并失败时，询问是否按原选项强制删除。
    ///
    /// 多选的普通删除只删掉一部分时，删掉的先按实际个数记撤销，写操作结束后再询问未合并的。
    /// 连同跟踪的远端分支一起删除的，撤销时先在远端重建远端分支。
    ///
    /// - Parameters:
    ///   - branches: 本地分支的完整引用名。
    ///   - force: 是否强制删除。
    ///   - deletingUpstream: 是否同时删除跟踪的远端分支，只用于一个分支。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func deleteBranches(_ branches: [String], force: Bool, deletingUpstream: Bool) -> Bool {
        let tracked = deletingUpstream && branches.count == 1
        let upstream = tracked
            ? history.branches.first { $0.id == branches.first }?.upstreamRemote
            : nil

        let pending = PendingForceDeletion()

        return performGit(
            { runner, output in
                let references = RepositoryReferences(runner: runner)

                do {
                    if tracked, let branch = branches.first {
                        try await references.delete(branch, force: force, deletingUpstream: true, onOutput: output)
                    } else {
                        try await references.delete(branches, force: force)
                    }
                } catch let error as ReferenceError {
                    guard case .unmergedBranches(let names, _) = error else { throw error }

                    let offer = ForceDeletionOffer(branches: names, deletingUpstream: tracked, failure: error)

                    // 一个也没删掉时整体失败，失败处理改为询问
                    guard !names.isEmpty, names.count < branches.count else { throw offer }

                    pending.offer.withLock { $0 = offer }

                    let key = branches.count - names.count == 1 ? "branch.delete" : "branch.deleteMultiple"
                    UndoSteps.current?.rename(AppLocalization.text(key))
                }
            },
            title: AppLocalization.text(branches.count == 1 ? "branch.delete" : "branch.deleteMultiple"),
            target: tracked ? .push(upstream) : nil,
            touchesWorkingCopy: false,
            undo: tracked ? .deletingBranch(withUpstream: branches[0]) : .reversible
        ) { [weak self] in
            if let offer = pending.offer.withLock({ $0 }) {
                self?.onReferenceRequest?(.forceDelete(offer))
            }
        }
    }

    /// 写入失败是未合并分支的普通删除时，改为询问是否强制删除；返回是否已经接手。
    func offerForceDeletion(after error: any Error) -> Bool {
        guard let offer = error as? ForceDeletionOffer, let onReferenceRequest else {
            return false
        }

        onReferenceRequest(.forceDelete(offer))
        return true
    }
}

// MARK: - Remote Actions

extension RepositorySession {
    /// 在远端视图里显示一个远端的设置与远端分支。
    func showRemote(_ name: String) {
        selectedRemote = name
        history.showsCommitPage = false
        activeView = .remote
        onActiveViewChange?()
    }

    /// 把全部本地标签推送到远端；与其它推送一样不进撤销记录。
    func pushAllTags(to remote: String) {
        performGit(
            { runner, output in
                try await RepositoryTags(runner: runner).pushAll(to: remote, onOutput: output)
            },
            title: AppLocalization.text("tag.pushAll", remote),
            target: .push(remote),
            touchesWorkingCopy: false,
            undo: .unrecorded
        )
    }

    /// 设置自动获取与获取全部远端时是否跳过这个远端。
    func setSkipsFetchAll(_ skips: Bool, for remote: String) {
        performGit(
            { runner, _ in
                try await RepositoryRemotes(runner: runner).setSkipsFetchAll(skips, for: remote)
            },
            title: AppLocalization.text("remote.skipFetchAll.title"),
            touchesWorkingCopy: false,
            undo: .changingRemote(remote)
        )
    }

    /// 确认后删除推送地址，此后推送用获取地址。
    func confirmUnsetPushURL(of remote: String) {
        let repository = repository
        let title = AppLocalization.text("remote.pushURL.unset")

        onConfirm?(ConfirmationRequest(
            title: title,
            message: AppLocalization.text("remote.pushURL.unset.confirm"),
            submitTitle: AppLocalization.text("remote.pushURL.unset.submit")
        ) { [weak self] in
            guard let self, self.repository == repository else { return }

            performGit(
                { runner, _ in try await RepositoryRemotes(runner: runner).unsetPushURL(of: remote) },
                title: title,
                touchesWorkingCopy: false,
                undo: .changingRemote(remote)
            )
        })
    }

    /// 确认后删除一条 refspec。
    func confirmRemoveRefspec(_ refspec: String, from remote: String, push: Bool) {
        let repository = repository
        let title = AppLocalization.text(push ? "remote.refspec.deletePush" : "remote.refspec.deleteFetch")

        onConfirm?(ConfirmationRequest(
            title: title,
            message: AppLocalization.text("remote.refspec.delete.confirm", refspec),
            submitTitle: AppLocalization.text("remote.action.delete")
        ) { [weak self] in
            guard let self, self.repository == repository else { return }

            performGit(
                { runner, _ in
                    try await RepositoryRemotes(runner: runner).removeRefspec(refspec, from: remote, push: push)
                },
                title: title,
                touchesWorkingCopy: false,
                undo: .changingRemote(remote)
            )
        })
    }

    /// 在浏览器中打开远端的网页；地址换算不出时报告原因。
    func openRemoteInBrowser(_ remote: String) {
        guard let runner, let repository else {
            return
        }

        Task { [weak self] in
            do {
                let configuration = try await RepositoryRemotes(runner: runner).configurations()
                    .first { $0.name == remote }

                guard let url = configuration?.webURL else {
                    throw ReferenceError.noWebAddress(configuration?.url ?? remote)
                }

                NSWorkspace.shared.open(url)
            } catch {
                self?.onFailure?(AppFailure(error: error, opening: false, location: repository))
            }
        }
    }
}
