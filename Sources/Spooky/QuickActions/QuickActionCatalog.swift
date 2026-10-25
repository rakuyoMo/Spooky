import Foundation
import SpookyKit

// MARK: - QuickActionCatalog

/// 一个仓库窗口的快捷操作对象与动作。
///
/// 对象取自会话已经读到的状态，子模块、工作树、文件与提交在仓库所在的机器上只读查询；
/// 动作是否出现沿用菜单与右键菜单的可用性规则，不可用的动作不列出。
@MainActor
struct QuickActionCatalog {
    /// 像提交哈希的输入：5 到 64 位十六进制，按这一个提交查找，不按提交信息搜索。
    private static let hashPattern = /^[0-9a-fA-F]{5,64}$/

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 身份档案所在的偏好域。
    var defaults = UserDefaults.standard

    /// 主题与两种外观的主题选择。
    var themes = ThemeStore.shared

    /// 不需要执行 Git 的对象，按种类与各自的自然顺序：导航、分支（HEAD 在前）、远端、远端分支、标签、储藏、身份档案、外观与主题。
    func immediateObjects() -> [QuickActionObject] {
        let head = session.status?.branch.head.map { "refs/heads/" + $0 }
        let branches = session.history.branches
        let locals = branches.filter { $0.id == head } + branches.filter { $0.isLocal && $0.id != head }

        let navigation = QuickActionDestination.allCases.map(QuickActionObject.navigation)
        let remotes = session.history.snapshot?.remotes.map { QuickActionObject.remote($0.name) } ?? []
        let profiles = UserProfiles.decode(defaults.data(forKey: UserProfiles.key) ?? Data())

        return navigation
            + locals.map(QuickActionObject.branch)
            + remotes
            + branches.filter(\.isRemote).map(QuickActionObject.remoteBranch)
            + session.tags.map(QuickActionObject.tag)
            + session.stashes.entries.map(QuickActionObject.stash)
            + profiles.map(QuickActionObject.userProfile)
            + AppAppearance.allCases.map(QuickActionObject.appearance)
            + themes.themes.map { QuickActionObject.theme(id: $0.id, name: $0.name) }
    }

    /// 子模块与工作树，各执行一条只读的 Git 命令。
    func linkedObjects() async throws -> [QuickActionObject] {
        guard let runner = session.runner else {
            return []
        }

        let linked = LinkedRepositories(runner: runner)
        let submodules = try await linked.submodules()
        let worktrees = try await linked.worktrees()

        return submodules.map(QuickActionObject.submodule) + worktrees.map(QuickActionObject.worktree)
    }

    /// HEAD 树中的全部文件；结果只由 HEAD 的哈希决定，调用方按哈希复用。HEAD 未出生时为 nil。
    func headFiles() async throws -> (head: String, paths: [String])? {
        guard let runner = session.runner, let head = session.status?.branch.oid else {
            return nil
        }

        let entries = try await RepositoryFileViews(runner: runner).files(in: head)

        return (head, entries.filter { !$0.isSubmodule && !$0.isDirectory }.map(\.path))
    }

    /// 按查询找提交：像哈希时在全部引用可达的提交里只取这一个，否则从 HEAD 起按提交信息搜索，最多 100 条。
    func commits(matching query: String) async throws -> [QuickActionObject] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let runner = session.runner, let head = session.status?.branch.oid, !text.isEmpty else {
            return []
        }

        let history = RepositoryHistory(runner: runner)

        guard text.wholeMatch(of: Self.hashPattern) != nil else {
            let message = HistoryQuery(conditions: [HistorySearchCondition(kind: .message, text: text)])
            let page = try await history.page(roots: [head], query: message, limit: 100)

            return page.commits.map { QuickActionObject.commit($0, onHead: true) }
        }

        // 哈希在所有引用与 HEAD 可达的提交里解析，再判断它能否从 HEAD 到达
        let tips = session.history.snapshot?.references.filter { $0.objectType == "commit" }.map(\.objectID) ?? []
        let roots = Array(Set(tips + [head])).sorted()
        let lookup = HistoryQuery(conditions: [HistorySearchCondition(kind: .hash, text: text)])

        guard let commit = try await history.page(roots: roots, query: lookup, limit: 1).commits.first else {
            return []
        }

        return [.commit(commit, onHead: try await history.contains(commit.id, roots: [head]))]
    }
}

// MARK: - Actions

extension QuickActionCatalog {
    /// 对象的默认动作，即对象行按 ↩ 执行的那一个。
    func defaultAction(for object: QuickActionObject) -> QuickAction {
        switch object {
        case .navigation: .show
        case .branch, .remoteBranch, .tag: .showReferenceHistory
        case .worktree: .openWorktree
        case .remote: .showRemoteSettings
        case .submodule: .openSubmodule
        case .stash: .applyStash
        case .userProfile: .setCommitter
        case .appearance: .setAppearance
        case .theme: .applyTheme
        case .file: .showFile
        case .commit: .showCommit
        }
    }

    /// 对象当前可以执行的全部动作，默认动作在前；服务器仓库没有 Finder 类动作，换成复制带主机前缀的路径。
    func actions(for object: QuickActionObject) -> [QuickAction] {
        var actions: [QuickAction] = []

        for action in candidates(for: object) {
            let available = isRemote && action == .revealInFinder ? .copyPath : action

            if !actions.contains(available), isAvailable(available, for: object) {
                actions.append(available)
            }
        }

        return actions
    }

    /// 动作现在能否执行；规则与菜单、右键菜单里同一个动作的禁用条件相同。
    func isAvailable(_ action: QuickAction, for object: QuickActionObject) -> Bool {
        switch object {
        case .branch(let reference): isAvailable(action, branch: reference)
        case .remoteBranch(let reference): isAvailable(action, remoteBranch: reference)
        case .tag(let reference): isAvailable(action, tag: reference)
        case .commit(_, let onHead): isAvailable(action, commitOnHead: onHead)
        case .stash(let stash): action == .applyStash ? session.canApply(stash) : session.canDelete([stash])
        case .remote: isAvailable(remoteAction: action)
        case .userProfile(let profile): isAvailable(action, profile: profile)
        case .navigation, .file, .worktree, .submodule: isAvailable(locationAction: action)
        case .appearance, .theme: true
        }
    }
}

// MARK: - Candidates

extension QuickActionCatalog {
    /// 对象的全部动作，按菜单里的顺序排列，尚未按可用性筛选。
    private func candidates(for object: QuickActionObject) -> [QuickAction] {
        switch object {
        case .navigation(.workingCopy):
            [.show, .revealInFinder, .openInTerminal, .copyPath, .createSnapshot]

        case .navigation:
            [.show]

        case .branch:
            [
                .showReferenceHistory, .revealInHistory, .checkout, .mergeIntoHead, .rebaseHead,
                .mergeParent, .rebaseOnParent, .createBranch, .publish, .push, .fastForward,
                .delete, .rename, .pin, .unpin, .removeParent, .setParent, .copyName, .updateBranch,
                .archive, .unarchive, .skipAutoArchive, .includeInAutoArchive,
            ]

        case .remoteBranch:
            [
                .showReferenceHistory, .revealInHistory, .checkout, .track, .mergeIntoHead, .rebaseHead,
                .rename, .delete, .copyName,
            ]

        case .tag:
            [.showReferenceHistory, .revealInHistory, .checkout, .delete, .createBranch, .copyName]

        case .commit:
            [.showCommit, .copyHash, .revealInHistory, .createTag, .createBranch, .editCommit, .editMessage, .openDiffTool]

        default:
            otherCandidates(for: object)
        }
    }

    /// 储藏、文件、子模块、工作树、远端、身份档案、外观与主题的动作。
    private func otherCandidates(for object: QuickActionObject) -> [QuickAction] {
        switch object {
        case .stash: [.applyStash, .deleteStash]
        case .file: [.showFile, .showFileHistory, .showBlame, .openInEditor, .revealInFinder, .copyPath]
        case .submodule: [.openSubmodule]
        case .worktree: [.openWorktree, .openWorktreeInNewWindow, .revealInFinder, .openInTerminal]
        case .remote: [.showRemoteSettings, .fetch, .editConnection]
        case .userProfile: [.setCommitter, .setGlobalUser]
        case .theme: [.applyTheme]
        default: [.setAppearance]
        }
    }
}

// MARK: - Availability

extension QuickActionCatalog {
    /// 服务器仓库的路径在另一台机器上，不能交给 Finder。
    private var isRemote: Bool {
        session.repository?.host != nil
    }

    /// 当前分支的完整引用名；分离 HEAD 或未出生时为 nil。
    private var headBranch: String? {
        session.status?.branch.head.map { "refs/heads/" + $0 }
    }

    /// 本地分支：与侧边栏分支右键菜单、父分支菜单和分支整理的规则相同。
    private func isAvailable(_ action: QuickAction, branch: RepositoryReference) -> Bool {
        let metadata = session.history.snapshot?.metadata(for: branch.id) ?? BranchMetadata()
        let isHead = branch.id == headBranch
        let parent = session.parentBranch(of: branch)

        switch action {
        case .showReferenceHistory, .revealInHistory, .copyName: return true
        case .checkout: return session.canCheckout(branch)
        case .mergeIntoHead: return session.canMerge(branch)
        case .rebaseHead: return !isHead && session.canRebase
        case .mergeParent: return isHead && (parent.map { session.canMerge($0) } ?? false)
        case .rebaseOnParent: return isHead && parent != nil && session.canRebase
        case .createBranch: return session.canCreateBranchFromReference
        case .publish, .push: return session.canPush(branch)
        case .fastForward: return session.canFastForward(branch)
        case .delete: return session.canDelete([branch])
        case .rename, .setParent: return session.canManage(branch)
        case .removeParent: return session.canManage(branch) && metadata.parent != nil
        case .pin, .unpin: return session.canSetPinned([branch]) && metadata.isPinned == (action == .unpin)
        case .updateBranch: return session.canUpdateBranch(branch)
        case .archive, .unarchive: return session.canSetArchived([branch]) && metadata.isArchived == (action == .unarchive)
        case .skipAutoArchive, .includeInAutoArchive:
            return session.canSetArchived([branch]) && metadata.skipsAutoArchive == (action == .includeInAutoArchive)
        default: return false
        }
    }

    /// 远端分支：与侧边栏远端分支右键菜单的规则相同。
    private func isAvailable(_ action: QuickAction, remoteBranch: RepositoryReference) -> Bool {
        switch action {
        case .showReferenceHistory, .revealInHistory, .copyName: true
        case .checkout: session.canCheckout(remoteBranch)
        case .track: session.canTrack(remoteBranch)
        case .mergeIntoHead: session.canMerge(remoteBranch)
        case .rebaseHead: session.canRebase
        case .rename: session.canManage(remoteBranch)
        case .delete: session.canDeleteRemoteBranches([remoteBranch])
        default: false
        }
    }

    /// 标签：与侧边栏标签右键菜单的规则相同。
    private func isAvailable(_ action: QuickAction, tag _: RepositoryReference) -> Bool {
        switch action {
        case .showReferenceHistory, .revealInHistory, .copyName: true
        case .checkout: session.canCheckoutRevision
        case .delete: session.canWrite
        case .createBranch: session.canCreateBranchFromReference
        default: false
        }
    }

    /// 提交：与历史列表右键菜单的规则相同，改写类动作只对 HEAD 可达的提交出现。
    private func isAvailable(_ action: QuickAction, commitOnHead onHead: Bool) -> Bool {
        switch action {
        case .showCommit, .copyHash, .revealInHistory, .openDiffTool: true
        case .createTag: session.canCreateTag
        case .createBranch: session.canCreateBranchFromReference
        case .editCommit, .editMessage: onHead && session.canRewrite
        default: false
        }
    }

    /// 远端：与侧边栏远端右键菜单的规则相同。
    private func isAvailable(remoteAction action: QuickAction) -> Bool {
        switch action {
        case .showRemoteSettings: true
        case .fetch: session.canFetch
        case .editConnection: session.canWrite
        default: false
        }
    }

    /// 身份档案：与提交区身份菜单的规则相同，已经是当前身份的档案不再设为提交人。
    private func isAvailable(_ action: QuickAction, profile: UserProfile) -> Bool {
        guard session.canWrite else {
            return false
        }

        return action == .setGlobalUser || session.context?.committer != profile.name + " <" + profile.email + ">"
    }

    /// 导航、文件、子模块与工作树：Finder 只用于本机仓库，读取文件视图需要执行器，储藏快照沿用储藏的规则。
    private func isAvailable(locationAction action: QuickAction) -> Bool {
        switch action {
        case .revealInFinder: !isRemote
        case .createSnapshot: session.canSaveStash
        case .showFile, .showFileHistory, .showBlame, .openInEditor: session.runner != nil
        default: true
        }
    }
}
