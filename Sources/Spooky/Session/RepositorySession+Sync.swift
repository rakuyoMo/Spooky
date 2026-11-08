import Foundation
import SpookyKit

// MARK: - SyncPreferences

/// 获取、拉取、推送与合并对话框记住的选项；跳过对话框的快速操作与自动获取沿用它们。
enum SyncPreferences {
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

    /// 获取对话框是否获取全部远端；没有保存值时不勾。
    static func fetchAllRemotes(in defaults: UserDefaults = .standard) -> Bool {
        bool("fetchAllRemotes", in: defaults)
    }

    /// 跳过对话框的获取（快速获取、自动获取与 Fetch All）的选项：清理与递归子模块读获取对话框保存的偏好，
    /// 清理没有保存值时勾选；全部标签只作用于在对话框里发起的获取。
    ///
    /// - Parameter defaults: 读取的偏好，测试使用独立的域。
    static func fetchOptions(in defaults: UserDefaults = .standard) -> (prune: Bool, submodules: Bool) {
        (bool("fetchPrune", default: true, in: defaults), bool("fetchSubmodules", in: defaults))
    }

    /// 读取布尔偏好；没写过时取对话框里的默认值。
    private static func bool(
        _ key: String,
        default value: Bool = false,
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }
}

// MARK: - SyncProgress

/// 一次同步走到了哪一步：每步开始时更新 Activity 记录的状态，推送另起一条记录；失败时据此说明停在哪一步、哪些步骤已完成。
@MainActor
final class SyncProgress {
    /// 正在执行的步骤。
    private(set) var step: SyncStep? = nil

    /// 推送那一步另起的记录连接的对象。
    private let push: ActivityTarget

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

    /// 为一次同步记录进度。
    ///
    /// - Parameter push: 推送那一步另起的记录连接的对象。
    init(push: ActivityTarget) {
        self.push = push
    }

    /// 步骤的显示名称。
    static func name(_ step: SyncStep) -> String {
        switch step {
        case .fetch: AppLocalization.text("sync.fetch")
        case .pull: AppLocalization.text("sync.pull")
        case .push: AppLocalization.text("sync.push")
        }
    }

    /// 记下开始的步骤，把正在写入的 Activity 记录的状态换成这一步。
    ///
    /// 获取与拉取写在同步开始时的拉取记录里，推送另起一条推送记录。
    func begin(_ step: SyncStep) {
        self.step = step

        let state =
            switch step {
            case .fetch: "sync.step.fetch"
            case .pull: "sync.step.pull"
            case .push: "sync.step.push"
            }

        if step == .push {
            ActivityRecording.send?(.next(push))
        }

        ActivityRecording.send?(.state(state))
    }
}

// MARK: - Sync & Quick Actions

extension RepositorySession {
    /// Sync HEAD 对话框的入口只要可同步的当前分支；没有远端或远端分支时也能打开，由对话框禁止提交。
    var canSync: Bool { canWrite && hasCurrentBranch }

    /// 变基当前分支需要可同步的当前分支与其它分支，规则与合并相同。
    var canRebase: Bool { canMerge }

    /// 把任意版本推到远端引用的对话框入口：仓库至少有一个提交；没有远端时也能打开，由对话框禁止提交。
    var canPushRevision: Bool {
        canWrite && status?.branch.oid != nil
    }

    /// HEAD 所在的本地分支；分离或未出生时为 nil。
    var headBranch: RepositoryReference? {
        guard let head = status?.branch.head else {
            return nil
        }

        return history.branches.first { $0.id == "refs/heads/" + head }
    }

    /// 同步当前分支与所选远端分支：依次获取、拉取、推送，Activity 的状态随步骤变化，失败时说明停在哪一步。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - branch: 远端上的完整分支引用名。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func sync(remote: String, branch: String, options: SyncOptions) -> Bool {
        // 拉取与推送各记一条，标题都只写远端分支；当前分支与它不同名时，传给 git 的仍是从当前分支推过去的 refspec
        let progress = SyncProgress(push: .push(remote, refspec: branch))

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
            target: .pull(remote, refspec: branch),
            offersAutoStash: true,
            failureNote: { progress.failureNote }
        )
    }

    /// 以核对过的远端版本为期望值，把指定的本地分支强推到远端分支；远端已不是这个版本时 Git 拒绝推送，不退回无条件强推。
    ///
    /// - Parameters:
    ///   - branch: 强推的本地分支，可以不是 HEAD 分支。
    ///   - target: 被覆盖的远端跟踪分支。
    ///   - lease: 期望远端分支仍指向的提交。
    ///   - skipHooks: 是否跳过推送钩子。
    /// - Returns: 是否已开始执行。
    @discardableResult
    func forcePush(
        _ branch: RepositoryReference,
        to target: RepositoryReference,
        lease: String,
        skipHooks: Bool
    ) -> Bool {
        guard branch.isLocal, let parts = remoteParts(of: target) else {
            return false
        }

        let local = branch.name
        let (remote, name) = parts

        var settings = PushOptions()
        settings.skipHooks = skipHooks
        let options = settings

        return performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .push(
                        branch: local,
                        remote: remote,
                        destination: name,
                        setUpstream: false,
                        options: options,
                        lease: lease,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.forcePush"),
            target: .push(remote, refspec: "refs/heads/" + local + ":refs/heads/" + name)
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

        // 没有指定时拉取 HEAD 跟踪的远端分支；跟踪的是本地分支时远端名是 “.”，记录的标题不写它
        let source = remote ?? headBranch?.upstreamRemote.flatMap { $0 == "." ? nil : $0 }
        let refspec = branch ?? headBranch?.upstreamBranch

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
            target: .pull(source, refspec: refspec),
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
            target: .push(remote, refspec: "refs/heads/" + local.name + ":" + upstream)
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

        performGit(
            mergeAction(target, options: SyncPreferences.merge),
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

    /// 合并的写操作，快速合并与合并对话框共用。
    ///
    /// 停在待解决的冲突上时不当作失败，切到工作区；横幅与冲突文件随写操作结束后的刷新出现。
    func mergeAction(
        _ revision: String,
        options: MergeOptions
    ) -> @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void {
        { [weak self] runner, output in
            let outcome = try await RepositorySync(runner: runner)
                .merge(revision, options: options, onOutput: output)

            guard outcome == .conflicts else {
                return
            }

            await MainActor.run {
                self?.activeView = .workingCopy
                self?.onActiveViewChange?()
            }
        }
    }

    /// 快速操作无法开始时说明原因，与写入失败使用同一个错误 sheet。
    private func reportUnavailable(_ error: RepositorySyncError) {
        onFailure?(AppFailure(error: error, opening: false, location: repository, writing: true))
    }
}
