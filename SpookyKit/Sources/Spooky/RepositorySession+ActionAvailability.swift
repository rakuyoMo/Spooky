import SpookyKit

extension RepositorySession {
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

    /// 检出需要当前分支以外的本地分支，且没有进行中的操作。
    var canCheckout: Bool {
        canWrite && context?.operation == nil
            && history.branches.contains { $0.isLocal && $0.id != currentBranchID }
    }

    /// 当前分支已附着、已有提交且没有进行中的操作。
    private var hasCurrentBranch: Bool {
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
        canWrite && entries.contains(where: \.hasUnstagedChanges)
    }

    /// 所选文件中存在已暂存的改动。
    func canUnstage(_ entries: [StatusEntry]) -> Bool {
        canWrite && entries.contains(where: \.hasStagedChanges)
    }

    /// 丢弃需要至少一个文件，执行前仍会确认。
    func canDiscard(_ entries: [StatusEntry]) -> Bool {
        canWrite && !entries.isEmpty
    }

    /// 采用一侧与标记已解决只作用于冲突文件。
    func canResolve(_ entries: [StatusEntry]) -> Bool {
        canWrite && entries.contains { $0.kind == .conflicted }
    }
}
