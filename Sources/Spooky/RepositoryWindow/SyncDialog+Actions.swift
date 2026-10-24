import SpookyKit
import SwiftUI

// MARK: - Actions

extension SyncDialog {
    /// 本地与远端分支。
    private var branches: [RepositoryReference] { session.history.branches }

    /// 远端跟踪分支。
    private var remoteBranches: [RepositoryReference] { branches.filter(\.isRemote) }

    /// 推送部分的选项：全部标签、子模块与跳过钩子。
    private var pushOptions: PushOptions {
        var options = PushOptions()
        options.allTags = pushAllTags
        options.skipHooks = skipHooks

        if pushSubmodules {
            options.submodules = SubmodulePushMode(rawValue: pushSubmoduleMode) ?? .onDemand
        }

        return options
    }

    /// 默认值取自 HEAD 的跟踪关系；没有远端或远端分支时在表单里说明。
    func prepare() {
        repository = session.repository
        let head = session.headBranch
        let tracked = remoteBranches.first { $0.id == head?.upstream }

        switch kind {
        case .sync:
            source = tracked?.id ?? remoteBranches.first?.id ?? ""

        case .rebase:
            source = branches.first { $0.id == head?.upstream }?.id
                ?? branches.first { $0.id != head?.id }?.id
                ?? ""

        case .forcePush:
            source = head?.id ?? branches.first(where: \.isLocal)?.id ?? ""
            selectDestination()

        case .pushRevision:
            source = session.status?.branch.head ?? session.status?.branch.oid ?? ""
            remote = head?.upstreamRemote.flatMap { $0 == "." ? nil : $0 }
                ?? session.history.snapshot?.remotes.first?.name
                ?? ""
            destination = head?.upstreamBranch.map { String($0.dropFirst("refs/heads/".count)) } ?? source
        }

        if kind != .rebase, session.history.snapshot?.remotes.isEmpty != false {
            error = AppLocalization.text("sync.noRemotes")
        } else if [.sync, .forcePush].contains(kind), remoteBranches.isEmpty {
            error = AppLocalization.text("sync.noRemoteBranches")
        }
    }

    /// 强推的目标默认是所选本地分支的跟踪分支，没有时取第一个远端分支。
    func selectDestination() {
        let local = branches.first { $0.id == source }

        destination = remoteBranches.first { $0.id == local?.upstream }?.id
            ?? remoteBranches.first?.id
            ?? ""
    }

    /// 计算强推的提交数与状态；所选分支一变就取消上一次计算。
    func loadLease() async {
        guard kind == .forcePush else {
            return
        }

        lease = nil

        guard
            source.hasPrefix("refs/heads/"),
            destination.hasPrefix("refs/remotes/"),
            let runner = session.runner
        else {
            checkingLease = false
            return
        }

        checkingLease = true

        do {
            try await Task.sleep(for: .milliseconds(150))
            let result = try await RepositorySync(runner: runner)
                .forcePushPreview(branch: source, destination: destination)

            try Task.checkCancellation()
            lease = result
        } catch {
            if !Task.isCancelled {
                self.error = AppFailure(error: error, opening: false, location: session.repository).details
            }
        }

        if !Task.isCancelled {
            checkingLease = false
        }
    }

    /// 捕获表单值后开始执行并关闭 sheet；仓库暂不可写时表单保持打开，已填写的参数原样保留。
    func perform() {
        // 仓库已经切换时不把参数用到另一个仓库上
        guard session.repository == repository else {
            close()
            return
        }

        let started =
            switch kind {
            case .sync: startSync()
            case .rebase: startRebase()
            case .forcePush: startForcePush()
            case .pushRevision: startPushRevision()
            }

        if started {
            close()
        }
    }

    /// 同步当前分支与所选远端分支。
    private func startSync() -> Bool {
        guard
            let reference = remoteBranches.first(where: { $0.id == source }),
            let owner = session.history.snapshot?.remote(for: reference)
        else {
            return false
        }

        var options = SyncOptions()
        options.rebase = rebase
        options.verifySignatures = verify
        options.push = pushOptions

        let branch = "refs/heads/" + reference.id.dropFirst(("refs/remotes/" + owner.name + "/").count)
        return session.sync(remote: owner.name, branch: branch, options: options)
    }

    /// 把当前分支变基到所选分支上；被本地改动挡住时按设置询问先储藏。
    private func startRebase() -> Bool {
        let target = source
        let skipHooks = skipHooks

        return session.performGit(
            { runner, output in
                try await RepositorySync(runner: runner)
                    .rebase(onto: target, skipHooks: skipHooks, onOutput: output)
            },
            title: AppLocalization.text("sync.rebaseHead"),
            offersAutoStash: true
        )
    }

    /// 以对话框里核对过的远端版本为期望值强推。
    private func startForcePush() -> Bool {
        guard
            let lease,
            let local = branches.first(where: { $0.id == source }),
            let target = remoteBranches.first(where: { $0.id == destination }),
            let owner = session.history.snapshot?.remote(for: target)
        else {
            return false
        }

        let remote = owner.name
        let name = String(target.id.dropFirst(("refs/remotes/" + remote + "/").count))
        let expected = lease.destination
        var settings = PushOptions()
        settings.skipHooks = skipHooks
        let options = settings

        return session.performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .push(
                        branch: local.name,
                        remote: remote,
                        destination: name,
                        setUpstream: false,
                        options: options,
                        lease: expected,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.forcePush")
        )
    }

    /// 把所填版本推到所选远端的目标引用。
    private func startPushRevision() -> Bool {
        let revision = source.trimmingCharacters(in: .whitespaces)
        let target = destination.trimmingCharacters(in: .whitespaces)
        let remote = remote
        let skipHooks = skipHooks

        return session.performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .push(
                        revision: revision,
                        remote: remote,
                        to: target,
                        skipHooks: skipHooks,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("sync.pushRevision")
        )
    }
}
