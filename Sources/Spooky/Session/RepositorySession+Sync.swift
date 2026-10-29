import Foundation
import SpookyKit

// MARK: - SyncPreferences

/// 获取、拉取、推送与合并对话框记住的选项；跳过对话框的快速操作与自动获取沿用它们。
enum SyncPreferences {
    /// 获取对话框是否获取全部远端。
    static var fetchAllRemotes: Bool { bool("fetchAllRemotes", default: true) }

    /// 获取时清理远端已删除的分支。
    static var fetchPrune: Bool { bool("fetchPrune") }

    /// 获取时另取全部标签。
    static var fetchAllTags: Bool { bool("fetchAllTags") }

    /// 获取时同时获取子模块。
    static var fetchSubmodules: Bool { bool("fetchSubmodules") }

    /// 拉取以变基代替合并。
    static var pullRebase: Bool { bool("pullUseRebase") }

    /// 拉取时校验取回提交的签名。
    static var pullVerifySignatures: Bool { bool("pullVerifySignatures") }

    /// 推送的全部标签与子模块选项；跳过钩子不记忆。
    static var push: PushOptions {
        var options = PushOptions()
        options.allTags = bool("pushAllTags")

        if bool("pushRecurseSubmodules") {
            let mode = UserDefaults.standard.string(forKey: "pushSubmoduleMode") ?? ""
            options.submodules = SubmodulePushMode(rawValue: mode) ?? .onDemand
        }

        return options
    }

    /// 合并的提交方式与签名校验；跳过钩子不记忆。
    static var merge: MergeOptions {
        var options = MergeOptions()
        options.alwaysCreateCommit = bool("mergeAlwaysCreateCommit")

        // 自动提交只在总是生成合并提交时可改，其余情况固定为提交
        options.commit = options.alwaysCreateCommit ? bool("mergeAutoCommit", default: true) : true
        options.verifySignatures = bool("mergeVerifySignatures")
        return options
    }

    /// 读取布尔偏好；没写过时取对话框里的默认值。
    private static func bool(_ key: String, default value: Bool = false) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }
}

// MARK: - SyncProgress

/// 一次同步走到了哪一步：每步开始时更新 Activity 的状态，失败时据此说明停在哪一步、哪些步骤已完成。
@MainActor
final class SyncProgress {
    /// 正在执行的步骤。
    private(set) var step: SyncStep? = nil

    /// 同步所在的仓库，用来找到它正在运行的 Activity。
    private let repository: RepositoryLocation?

    /// 同步记进的 Activity 列表。
    private let activities: RepositoryActivities

    /// 停在哪一步、哪些步骤已完成的说明；还没开始任何步骤时为 nil。
    var failureNote: String? {
        guard let step else {
            return nil
        }

        let completed = SyncStep.allCases.filter { $0 < step }.map(Self.name)

        guard !completed.isEmpty else {
            return AppLocalization.text("sync.stoppedFirst", Self.name(step))
        }

        return AppLocalization.text(
            "sync.stopped",
            Self.name(step),
            ListFormatter.localizedString(byJoining: completed)
        )
    }

    /// 为指定仓库的一次同步记录进度。
    ///
    /// - Parameters:
    ///   - repository: 同步所在的仓库。
    ///   - activities: 同步记进的 Activity 列表。
    init(repository: RepositoryLocation?, activities: RepositoryActivities) {
        self.repository = repository
        self.activities = activities
    }

    /// 步骤的显示名称。
    static func name(_ step: SyncStep) -> String {
        switch step {
        case .fetch: AppLocalization.text("sync.fetch")
        case .pull: AppLocalization.text("sync.pull")
        case .push: AppLocalization.text("sync.push")
        }
    }

    /// 记下开始的步骤，并把仓库正在运行的 Activity 状态换成这一步。
    func begin(_ step: SyncStep) {
        self.step = step

        let state =
            switch step {
            case .fetch: "sync.step.fetch"
            case .pull: "sync.step.pull"
            case .push: "sync.step.push"
            }

        activities.items
            .first { $0.repository == repository && $0.cancel != nil }?
            .state = state
    }
}

// MARK: - Sync & Quick Actions

extension RepositorySession {
    /// Sync 与快速同步需要可同步的当前分支与远端分支，规则与拉取相同。
    var canSync: Bool { canPull }

    /// 变基当前分支需要可同步的当前分支与其它分支，规则与合并相同。
    var canRebase: Bool { canMerge }

    /// 把任意版本推到远端引用：需要远端，且仓库至少有一个提交。
    var canPushRevision: Bool {
        canFetch && status?.branch.oid != nil
    }

    /// HEAD 所在的本地分支；分离或未出生时为 nil。
    var headBranch: RepositoryReference? {
        guard let head = status?.branch.head else {
            return nil
        }

        return history.branches.first { $0.id == "refs/heads/" + head }
    }

    /// 自动获取：获取全部远端（跳过设了 skipFetchAll 的），不询问凭据，失败只记进 Activity。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func autoFetch() -> Bool {
        let prune = SyncPreferences.fetchPrune
        let tags = SyncPreferences.fetchAllTags
        let submodules = SyncPreferences.fetchSubmodules

        return performGit(
            { runner, output in
                // 后台获取不能弹出输入框，只用已存的凭据
                try await RemoteCallbackRequest.$allowsInteraction.withValue(false) {
                    _ = try await RepositorySync(runner: runner)
                        .fetch(prune: prune, allTags: tags, submodules: submodules, onOutput: output)
                }
            },
            title: AppLocalization.text("sync.autoFetch"),
            activityKind: .remote,
            reportsFailure: false,
            undo: .unrecorded
        )
    }

    /// 同步当前分支与所选远端分支：依次获取、拉取、推送，Activity 的状态随步骤变化，失败时说明停在哪一步。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - branch: 远端上的完整分支引用名。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func sync(remote: String, branch: String, options: SyncOptions) -> Bool {
        let progress = SyncProgress(repository: repository, activities: activities)

        return performGit(
            { runner, output in
                try await RepositorySync(runner: runner)
                    .sync(
                        remote: remote,
                        branch: branch,
                        options: options,
                        onStep: { step in await progress.begin(step) },
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.sync"),
            activityKind: .remote,
            offersAutoStash: true,
            failureNote: { progress.failureNote }
        )
    }

    /// 快速获取：远端取自参数；未指定时按获取对话框的选择获取全部远端，或 HEAD 跟踪的远端。
    func quickFetch(remote: String? = nil) {
        let target = remote ?? (SyncPreferences.fetchAllRemotes ? nil : headBranch?.upstreamRemote)
        let prune = SyncPreferences.fetchPrune
        let tags = SyncPreferences.fetchAllTags
        let submodules = SyncPreferences.fetchSubmodules

        performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .fetch(
                        remote: target,
                        prune: prune,
                        allTags: tags,
                        submodules: submodules,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.quickFetch"),
            activityKind: .remote
        )
    }

    /// 快速拉取：把指定的远端分支并入 HEAD；未指定时拉取 HEAD 的跟踪分支。
    func quickPull(from reference: RepositoryReference? = nil) {
        var remote: String? = nil
        var branch: String? = nil

        if let reference {
            guard let owner = history.snapshot?.remote(for: reference) else {
                reportUnavailable(RepositorySyncError.missingRemote)
                return
            }

            remote = owner.name
            branch = "refs/heads/" + reference.id.dropFirst(("refs/remotes/" + owner.name + "/").count)
        } else if headBranch?.upstreamBranch == nil {
            reportUnavailable(RepositorySyncError.missingUpstream)
            return
        }

        let rebase = SyncPreferences.pullRebase
        let verify = SyncPreferences.pullVerifySignatures

        performGit(
            { [remote, branch] runner, output in
                try await RepositorySync(runner: runner)
                    .pull(
                        remote: remote,
                        branch: branch,
                        rebase: rebase,
                        verifySignatures: verify,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.quickPull"),
            activityKind: .remote,
            offersAutoStash: true
        )
    }

    /// 快速推送：把指定的本地分支（默认 HEAD）推到它的跟踪分支；没有跟踪分支时说明原因。
    func quickPush(_ reference: RepositoryReference? = nil) {
        guard
            let local = reference ?? headBranch,
            let remote = local.upstreamRemote,
            remote != ".",
            let upstream = local.upstreamBranch,
            upstream.hasPrefix("refs/heads/")
        else {
            reportUnavailable(RepositorySyncError.missingUpstream)
            return
        }

        let options = SyncPreferences.push

        performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .push(
                        branch: local.name,
                        remote: remote,
                        destination: String(upstream.dropFirst("refs/heads/".count)),
                        setUpstream: false,
                        options: options,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.quickPush"),
            activityKind: .remote
        )
    }

    /// 快速同步：HEAD 与它的跟踪分支同步；没有跟踪分支时说明原因。
    func quickSync() {
        guard
            let head = headBranch,
            let remote = head.upstreamRemote,
            remote != ".",
            let upstream = head.upstreamBranch
        else {
            reportUnavailable(RepositorySyncError.missingUpstream)
            return
        }

        var options = SyncOptions()
        options.rebase = SyncPreferences.pullRebase
        options.verifySignatures = SyncPreferences.pullVerifySignatures
        options.push = SyncPreferences.push

        sync(remote: remote, branch: upstream, options: options)
    }

    /// 快速合并：把指定的分支并入 HEAD；未指定时合并 HEAD 的跟踪分支。
    func quickMerge(_ reference: RepositoryReference? = nil) {
        guard let target = reference?.id ?? headBranch?.upstream else {
            reportUnavailable(RepositorySyncError.missingUpstream)
            return
        }

        let options = SyncPreferences.merge

        performGit(
            { runner, output in
                try await RepositorySync(runner: runner).merge(target, options: options, onOutput: output)
            },
            title: AppLocalization.text("sync.quickMerge"),
            offersAutoStash: true,
            undo: .reversible
        )
    }

    /// 快速变基：把 HEAD 变基到指定的分支上；未指定时变基到 HEAD 的跟踪分支。
    func quickRebase(onto reference: RepositoryReference? = nil) {
        guard let target = reference?.id ?? headBranch?.upstream else {
            reportUnavailable(RepositorySyncError.missingUpstream)
            return
        }

        performGit(
            { runner, output in
                try await RepositorySync(runner: runner).rebase(onto: target, onOutput: output)
            },
            title: AppLocalization.text("sync.quickRebase"),
            offersAutoStash: true,
            undo: .reversible
        )
    }

    /// 快速操作无法开始时说明原因，与写入失败使用同一个错误 sheet。
    private func reportUnavailable(_ error: RepositorySyncError) {
        onFailure?(AppFailure(error: error, opening: false, location: repository, writing: true))
    }
}
