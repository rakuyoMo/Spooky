import Foundation
import SpookyKit

// MARK: - RepositoryOperationDrop

/// 提交、提交里的文件、分支与标签拖到侧边栏落点时的改写、标签、改名与发布动作；可用条件与对应的菜单项相同。
///
/// - 提交拖到工作区或 HEAD 分支是摘取，可以多选；按住 ⌥ 是反转
/// - 提交变更集里的单个文件拖到工作区或 HEAD 分支：只摘取这个文件
/// - 按住 ⌥ 把本地分支拖到工作区或 HEAD 分支：把 HEAD 变基到它上面
/// - 提交或本地分支拖到 Tags 标题或标签文件夹：新建标签
/// - 本地分支拖进分支文件夹、远端分支拖进同一远端的文件夹：改名为 “文件夹/原名末段”
/// - 标签拖到远端：发布到这个远端
/// - 本地分支拖到 Worktrees 标题：以它新建工作树
enum RepositoryOperationDrop {
    /// 摘取这些提交，按列表顺序。
    case cherryPick([String])

    /// 反转这些提交，按列表顺序。
    case revert([String])

    /// 只摘取这个提交里的这个文件。
    case cherryPickFile(CommitFileChange, HistoryCommit)

    /// 把 HEAD 变基到这个分支上。
    case rebase(RepositoryReference)

    /// 以这个版本为起点新建标签。
    case createTag(String)

    /// 把分支改成这个名字；远端分支是远端上的短名。
    case moveBranch(RepositoryReference, to: String)

    /// 把这个标签发布到这个远端。
    case publishTag(String, remote: String)

    /// 以这个分支新建工作树，值是分支名。
    case createWorktree(String)

    /// 悬停时显示的动作名。
    var titleKey: String {
        switch self {
        case .cherryPick: "rewrite.cherryPick"
        case .revert: "rewrite.revert"
        case .cherryPickFile: "files.applyPatch"
        case .rebase: "sync.rebaseHead"
        case .createTag: "tag.create.submit"
        case .moveBranch: "branch.moveHere"
        case .publishTag: "tag.publish"
        case .createWorktree: "worktree.create"
        }
    }

    /// 按来源、落点、⌥ 与多选查动作表；不可用或不在表里时为 nil。
    ///
    /// - Parameters:
    ///   - payloads: 本次拖动的全部来源；多项只来自历史里多选的提交。
    ///   - alternate: 是否按住 ⌥。
    @MainActor
    init?(
        payloads: [RepositoryDragPayload],
        destination: RepositoryDropDestination,
        alternate: Bool,
        session: RepositorySession
    ) {
        guard
            let first = payloads.first,
            payloads.allSatisfy({ $0.repository == session.repository }),
            payloads.count == 1 || payloads.allSatisfy({ $0.kind == .commit })
        else { return nil }

        switch (first.kind, destination) {
        case (.commit, .head):
            guard session.canRewrite else { return nil }

            let commits = payloads.map(\.reference)
            self = alternate ? .revert(commits) : .cherryPick(commits)

        case (.commitFile, .head):
            guard !alternate, let file = Self.commitFile(first, in: session) else { return nil }

            self = .cherryPickFile(file.change, file.commit)

        case (.local, .head):
            guard
                alternate,
                let source = session.history.branches.first(where: { $0.id == first.reference }),
                session.canRebase,
                session.canMerge(source)
            else { return nil }

            self = .rebase(source)

        case (.commit, .tags), (.commit, .tagFolder), (.local, .tags), (.local, .tagFolder):
            guard payloads.count == 1, !alternate, session.canCreateTag else { return nil }

            self = .createTag(first.reference)

        case (.local, .branchFolder(let folder)), (.remote, .remoteBranchFolder(_, let folder)):
            guard
                !alternate,
                let move = Self.move(first, into: folder, destination: destination, in: session)
            else { return nil }

            self = .moveBranch(move.branch, to: move.name)

        case (.tag, .remote(let remote)):
            guard
                !alternate,
                session.canPublishTag,
                let tag = session.tags.first(where: { $0.id == first.reference })
            else { return nil }

            self = .publishTag(tag.name, remote: remote)

        case (.local, .worktrees):
            guard
                !alternate,
                session.canWrite,
                let branch = session.history.branches.first(where: { $0.id == first.reference })
            else { return nil }

            self = .createWorktree(branch.name)

        default:
            return nil
        }
    }

    /// 摘取、反转、变基、新建标签与新建工作树打开各自的对话框；单个文件、改名直接执行；发布打开预选了远端的发布对话框。
    @MainActor
    func perform(in session: RepositorySession) {
        switch self {
        case .cherryPick(let commits):
            session.requestCherryPick(commits)

        case .revert(let commits):
            session.requestRevert(commits)

        case .cherryPickFile(let change, let commit):
            session.cherryPickFile(change, from: commit)

        case .rebase(let branch):
            session.requestSyncDialog(.rebase, preselecting: branch.id)

        case .createTag(let revision):
            session.requestReference(.createTag(revision: revision))

        case .moveBranch(let branch, let name):
            Self.rename(branch, to: name, in: session)

        case .publishTag(let tag, let remote):
            session.requestReference(.publishTag(tag, remote: remote))

        case .createWorktree(let branch):
            session.requestWorktree(.add(revision: branch))
        }
    }
}

// MARK: - Private

extension RepositoryOperationDrop {
    /// 拖动的文件与它所在的提交；文件只能来自当前显示的提交详情。
    @MainActor
    private static func commitFile(
        _ payload: RepositoryDragPayload,
        in session: RepositorySession
    ) -> (change: CommitFileChange, commit: HistoryCommit)? {
        let history = session.history

        guard
            session.canWrite,
            let commit = history.selectedCommit,
            commit.id == payload.reference,
            let change = history.changes.first(where: { $0.path == payload.path })
        else { return nil }

        return (change, commit)
    }

    /// 拖进文件夹后的新名字：“文件夹/原名末段”；与原名相同、新名字已被占用或不可管理时为 nil。
    ///
    /// 本地分支只能进本地分支的文件夹，远端分支只能进同一个远端下的文件夹。
    @MainActor
    private static func move(
        _ payload: RepositoryDragPayload,
        into folder: String,
        destination: RepositoryDropDestination,
        in session: RepositorySession
    ) -> (branch: RepositoryReference, name: String)? {
        guard
            let source = session.history.branches.first(where: { $0.id == payload.reference }),
            session.canManage(source)
        else { return nil }

        // 远端分支按它在远端上的短名改名，命名空间是这个远端
        var current = source.name
        var prefix = "refs/heads/"

        if case .remoteBranchFolder(let remote, _) = destination {
            guard let parts = session.remoteParts(of: source), parts.remote == remote else {
                return nil
            }

            current = parts.branch
            prefix = "refs/remotes/" + remote + "/"
        }

        let last = current.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? current
        let name = folder + "/" + last

        // 读不到引用时按已被占用处理
        let taken = session.history.snapshot?.references.contains { $0.id == prefix + name } ?? true

        guard name != current, !taken else {
            return nil
        }

        return (source, name)
    }

    /// 本地分支直接改名；远端分支在远端上新建再删除原名字。
    @MainActor
    private static func rename(_ branch: RepositoryReference, to name: String, in session: RepositorySession) {
        guard let parts = session.remoteParts(of: branch) else {
            session.performGit(
                { runner, _ in try await RepositoryReferences(runner: runner).rename(branch.id, to: name) },
                title: AppLocalization.text("branch.rename"),
                undo: .reversible
            )
            return
        }

        session.performGit(
            { runner, output in
                try await RepositoryReferences(runner: runner)
                    .renameRemoteBranch(parts.branch, on: parts.remote, to: name, onOutput: output)
            },
            title: AppLocalization.text("branch.renameRemote"),
            activityKind: .remote
        )
    }
}

// MARK: - CommitFileDragging

/// 提交详情里变更集文件的拖动来源：拖到工作区或 HEAD 分支时只摘取这个文件。
@MainActor
enum CommitFileDragging {
    /// 详情显示的提交里这个文件的载荷；仓库已关闭或没有选中提交时返回空的拖动内容。
    static func provider(_ file: CommitFileChange, session: RepositorySession) -> NSItemProvider {
        guard let repository = session.repository, let commit = session.history.selectedCommit else {
            return NSItemProvider()
        }

        return RepositoryDragPayload(
            repository: repository,
            kind: .commitFile,
            reference: commit.id,
            path: file.path
        )
        .provider()
    }
}
