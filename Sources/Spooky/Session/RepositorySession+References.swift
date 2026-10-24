import AppKit
import SpookyKit

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

    /// 版本框列表里的引用：本地分支、远端分支、标签依次排列，远端的 HEAD 不列出。
    var revisionReferences: [RepositoryReference] {
        let branches = history.branches
        return branches.filter(\.isLocal) + branches.filter(\.isRemote) + tags
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
            undo: .reversible
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
            undo: .reversible
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
            undo: .reversible
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
            undo: .reversible
        )
    }

    /// 删除本地分支；普通删除因未合并失败时，询问是否按原选项强制删除。
    ///
    /// - Parameters:
    ///   - branches: 本地分支的完整引用名。
    ///   - force: 是否强制删除。
    ///   - deletingUpstream: 是否同时删除跟踪的远端分支，只用于一个分支。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func deleteBranches(_ branches: [String], force: Bool, deletingUpstream: Bool) -> Bool {
        let tracked = deletingUpstream && branches.count == 1

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
                    throw ForceDeletionOffer(branches: names, deletingUpstream: tracked, failure: error)
                }
            },
            title: AppLocalization.text(branches.count == 1 ? "branch.delete" : "branch.deleteMultiple"),
            undo: tracked ? .irreversible : .reversible
        )
    }

    /// 写入失败是未合并分支的普通删除时，改为询问是否强制删除；返回是否已经接手。
    func offerForceDeletion(after error: any Error) -> Bool {
        guard let offer = error as? ForceDeletionOffer, let onReferenceRequest else {
            return false
        }

        let failure = AppFailure(error: offer.failure, opening: false, location: repository, writing: true)
        onReferenceRequest(.forceDelete(offer, failure))
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

    /// 把全部本地标签推送到远端。
    func pushAllTags(to remote: String) {
        performGit(
            { runner, output in
                try await RepositoryTags(runner: runner).pushAll(to: remote, onOutput: output)
            },
            title: AppLocalization.text("tag.pushAll", remote)
        )
    }

    /// 设置自动获取与获取全部远端时是否跳过这个远端。
    func setSkipsFetchAll(_ skips: Bool, for remote: String) {
        performGit(
            { runner, _ in
                try await RepositoryRemotes(runner: runner).setSkipsFetchAll(skips, for: remote)
            },
            title: AppLocalization.text("remote.skipFetchAll.title")
        )
    }

    /// 确认后删除推送地址，此后推送用获取地址。
    func confirmUnsetPushURL(of remote: String) {
        let repository = repository

        onConfirm?(
            AppLocalization.text("remote.pushURL.unset"),
            AppLocalization.text("remote.pushURL.unset.confirm"),
            { [weak self] in
                guard let self, self.repository == repository else { return }

                performGit(
                    { runner, _ in try await RepositoryRemotes(runner: runner).unsetPushURL(of: remote) },
                    title: AppLocalization.text("remote.pushURL.unset")
                )
            },
            nil
        )
    }

    /// 确认后删除一条 refspec。
    func confirmRemoveRefspec(_ refspec: String, from remote: String, push: Bool) {
        let repository = repository
        let title = AppLocalization.text(push ? "remote.refspec.deletePush" : "remote.refspec.deleteFetch")

        onConfirm?(
            title,
            AppLocalization.text("remote.refspec.delete.confirm", refspec),
            { [weak self] in
                guard let self, self.repository == repository else { return }

                performGit(
                    { runner, _ in
                        try await RepositoryRemotes(runner: runner).removeRefspec(refspec, from: remote, push: push)
                    },
                    title: title
                )
            },
            nil
        )
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
