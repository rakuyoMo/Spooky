import SpookyKit

extension RepositorySession {
    /// 仓库能接受写入：有仓库，服务器仓库已连上。仓库正有写操作时同样为真，新的写操作排进队列。
    var canWrite: Bool {
        guard let repository else {
            return false
        }

        return repository.host == nil || connectionState == .connected
    }

    /// 文件列表的勾选与文件动作能否点：仓库能接受写入，改动工作区或索引的写操作又没有在执行（文件列表没有变灰），
    /// 本会话的暂存执行期间只有勾选框可点；获取、推送这类写操作执行或排队时照样可点，点了排队。
    var canWriteFiles: Bool {
        canWrite && !isWorkingCopyLocked && !isStaging
    }

    /// 文件列表的勾选框能否点：文件动作可用，或本会话正在暂存、新的请求并进它。
    var canToggleStaging: Bool {
        canWriteFiles || isStaging
    }

    /// 这个仓库有用户发起的写操作在执行或排队，不论是哪个窗口提交的；只有后台自动获取在执行时为假。
    var hasUserWrite: Bool {
        repository.map(RepositoryWriteQueue.shared.hasUserWrite(in:)) ?? false
    }

    /// 改动工作区或索引的写操作正在执行（含别的窗口提交的），又不是本会话正在合并请求的暂存；文件列表的图标与文件名随之变灰。
    var isWorkingCopyLocked: Bool {
        guard let repository, let write = RepositoryWriteQueue.shared.executing(in: repository) else {
            return false
        }

        return write.touchesWorkingCopy && !isStaging
    }

    /// 新建请求的条件：有远端属于已登录账号的托管服务，对应到一个账号或同一实例上有几个账号待选都算。
    var canCreatePullRequest: Bool {
        let associations = PullRequestAssociations.load()
        let accounts = pullRequests.accounts.items

        return pullRequests.remotes.contains { remote in
            guard let url = remote.url else { return false }

            switch PullRequestTarget.resolve(remoteURL: url, accounts: accounts, associations: associations) {
            case .resolved, .chooseAccount: return true
            case .noAccount, .unsupported: return false
            }
        }
    }

    /// 菜单、工具栏、右键菜单与拖放共用的获取条件：需要已配置远端。
    var canFetch: Bool {
        canWrite && hasRemotes
    }

    /// 拉取需要可同步的当前分支，以及至少一个远端分支。
    var canPull: Bool {
        canWrite && hasCurrentBranch && history.branches.contains(where: \.isRemote)
    }

    /// 推送当前分支需要已出生的本地分支与远端。
    var canPush: Bool {
        canWrite && status?.branch.head != nil && status?.branch.oid != nil && hasRemotes
    }

    /// 没有远端时推送 HEAD 的入口改为发布仓库；引用快照还没读出时不算没有远端。
    var pushPublishesRepository: Bool {
        history.snapshot?.remotes.isEmpty ?? false
    }

    /// 工具栏、主菜单与工作区右键的 Push：有远端时同 ``canPush``；没有远端时转到发布仓库，
    /// 仍要求 HEAD 是已有提交的本地分支，并且能发布仓库。
    var canPushHead: Bool {
        guard pushPublishesRepository else {
            return canPush
        }

        return status?.branch.head != nil && status?.branch.oid != nil && canPublishRepository
    }

    /// 发布仓库把新仓库建在登录的账号下，没有账号时不可用。
    var canPublishRepository: Bool {
        canWrite && !pullRequests.accounts.items.isEmpty
    }

    /// 发布需要本地分支与远端。
    var canPublish: Bool {
        canWrite && history.branches.contains(where: \.isLocal) && hasRemotes
    }

    /// 合并需要可同步的当前分支，以及它以外的分支。
    var canMerge: Bool {
        canWrite && hasCurrentBranch && history.branches.contains { $0.id != currentBranchID }
    }

    /// 新建分支需要 HEAD 已有提交，且没有进行中的操作。
    var canCreateBranch: Bool {
        canWrite && status?.branch.oid != nil && context?.operation == nil
    }

    /// 从指定引用或提交新建分支，起点不依赖当前 HEAD。
    var canCreateBranchFromReference: Bool {
        canWrite && context?.operation == nil
    }

    /// 当前分支已附着、已有提交且没有进行中的操作。
    var hasCurrentBranch: Bool {
        status?.branch.head != nil && status?.branch.oid != nil && context?.operation == nil
    }

    /// 至少配置了一个远端。
    private var hasRemotes: Bool {
        history.snapshot.map { !$0.remotes.isEmpty } ?? false
    }

    /// 当前分支的完整引用名；分离或未出生时为空。
    private var currentBranchID: String {
        status?.branch.head.map { "refs/heads/" + $0 } ?? ""
    }

    /// 双击或右键检出指定分支；远端分支检出已有或新建的跟踪分支。
    func canCheckout(_ reference: RepositoryReference) -> Bool {
        canWrite && context?.operation == nil && (reference.isRemote || reference.id != currentBranchID)
    }

    /// 把指定分支合并到当前分支。
    func canMerge(_ reference: RepositoryReference) -> Bool {
        canWrite && hasCurrentBranch && reference.id != currentBranchID
    }

    /// 从指定远端分支拉取到当前分支。
    func canPull(from reference: RepositoryReference) -> Bool {
        canWrite && hasCurrentBranch && reference.isRemote
    }

    /// 推送或发布指定的本地分支。
    func canPush(_ reference: RepositoryReference) -> Bool {
        canWrite && hasRemotes && reference.isLocal
    }

    /// 安全强推指定的本地分支：租约要拿上游作比较，上游须是仍然存在的远端分支。
    func canForcePush(_ reference: RepositoryReference) -> Bool {
        guard canPush(reference), let upstream = reference.upstream else {
            return false
        }

        return history.branches.contains { $0.isRemote && $0.id == upstream }
    }

    /// 为指定远端分支新建跟踪分支。
    func canTrack(_ reference: RepositoryReference) -> Bool {
        canCreateBranchFromReference && reference.isRemote
    }

    /// 删除只针对本地分支，当前分支不能删除。
    func canDelete(_ references: [RepositoryReference]) -> Bool {
        canWrite && !references.isEmpty && references.allSatisfy(\.isLocal)
            && !references.contains { $0.id == currentBranchID }
    }

    /// 所选文件中存在未暂存的改动。
    func canStage(_ entries: [StatusEntry]) -> Bool {
        canWriteFiles && entries.contains(where: \.hasUnstagedChanges)
    }

    /// 所选文件中存在已暂存的改动。
    func canUnstage(_ entries: [StatusEntry]) -> Bool {
        canWriteFiles && entries.contains(where: \.hasStagedChanges)
    }

    /// 丢弃需要至少一个有改动的文件，未改动与被忽略的文件没有可丢弃的内容；执行前仍会确认。
    func canDiscard(_ entries: [StatusEntry]) -> Bool {
        canWriteFiles && entries.contains { $0.kind != .unchanged && $0.kind != .ignored }
    }

    /// 采用一侧与标记已解决只作用于冲突文件。
    func canResolve(_ entries: [StatusEntry]) -> Bool {
        canWriteFiles && entries.contains { $0.kind == .conflicted }
    }
}
