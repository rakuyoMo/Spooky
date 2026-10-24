import Foundation

// MARK: - ForcePushPreview

/// 安全强推前的核对结果：会推上去与会被覆盖的提交数，以及远端分支相对改写前版本的状态。
public struct ForcePushPreview: Sendable, Equatable {
    /// 远端分支当前版本与改写历史前最后一次见到的版本的关系。
    public enum Status: Sendable, Equatable {
        /// 远端分支只落后于本地分支，推送是快进，不会覆盖任何提交。
        case fastForward

        /// 远端分支正是本地分支改写历史前的版本，可以放心覆盖。
        case matchesLastKnown

        /// 两侧是同一个版本，不需要推送。
        case sameRevision

        /// 远端分支既不是改写前的版本，也没有本地从未见过的提交，覆盖前需要核对。
        case differsFromLastKnown

        /// 远端分支有本地从未见过的提交，个数为关联值。
        case newerOnRemote(Int)
    }

    /// 本地分支的提交。
    public let source: String

    /// 远端跟踪分支的提交，也是强推租约的期望值。
    public let destination: String

    /// 推送后远端分支新增的提交数。
    public let introduced: Int

    /// 推送后远端分支上被覆盖的提交数。
    public let overwritten: Int

    /// 远端分支相对改写前版本的状态。
    public let status: Status
}

// MARK: - Push

extension RepositorySync {
    /// 从本地分支的 reflog 里找改写历史前的版本时，最多检查的不同提交个数。
    static let reflogCandidateLimit = 20

    /// 显式 refspec 防止 push.default、followTags 或 mirror 改变推送范围。
    ///
    /// - Parameters:
    ///   - branch: 本地分支的短名。
    ///   - destination: 远端分支的短名。
    ///   - setUpstream: 推送成功后把本地分支的跟踪分支设为这个远端分支。
    ///   - options: 全部标签、子模块与钩子选项。
    ///   - lease: 强推的期望值：远端分支推送前必须仍指向这个提交，空字符串表示远端分支必须不存在；nil 是普通推送。
    public func push(
        branch: String,
        remote: String,
        destination: String,
        setUpstream: Bool,
        options: PushOptions = PushOptions(),
        lease: String? = nil,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> [RemoteReferenceUpdate] {
        guard lease.map({ $0.isEmpty || GitObjectID.isValid($0) }) ?? true else {
            throw RepositoryReadError.invalidQuery
        }

        return try await runner.writeTransaction {
            let references = RepositoryReferences(runner: runner)
            try await references.validate(name: branch)
            try await references.validate(name: destination)
            let snapshot = try await references.snapshot()

            guard snapshot.remotes.contains(where: { $0.name == remote }) else {
                throw RepositorySyncError.missingRemote
            }

            guard snapshot.references.contains(where: { $0.id == "refs/heads/" + branch }) else {
                throw RepositorySyncError.requiresBranch
            }

            // 强推只用写明期望值的租约，不依赖可能已被自动获取改动的跟踪引用
            let force = lease.map { expected in
                "--force-with-lease=refs/heads/" + destination + ":" + expected
            }

            var arguments = pushPrefix(remote: remote) + [force ?? "--no-force"] + pushArguments(options)

            if setUpstream {
                arguments.append("--set-upstream")
            }

            arguments += ["--", remote, "refs/heads/" + branch + ":refs/heads/" + destination]

            let result = try await runner.execute(arguments, onOutput: onOutput)
            return try RemoteReferenceUpdate.parsePush(result.standardOutput)
        }
    }

    /// 计算安全强推对话框的提交数与状态；只读取引用、reflog 与提交图，不改动仓库。
    ///
    /// 改写前的版本取本地分支 reflog 中最近一个不再是当前提交祖先的版本，即 rebase、amend 或 reset 之前的分支末端。
    ///
    /// - Parameters:
    ///   - branch: 本地分支的完整引用名。
    ///   - destination: 远端跟踪分支的完整引用名。
    public func forcePushPreview(branch: String, destination: String) async throws -> ForcePushPreview {
        guard branch.hasPrefix("refs/heads/"), destination.hasPrefix("refs/remotes/") else {
            throw RepositoryReadError.invalidQuery
        }

        let references = RepositoryReferences(runner: runner)
        let source = try await references.resolve(branch)
        let target = try await references.resolve(destination)

        guard source != target else {
            return ForcePushPreview(
                source: source,
                destination: target,
                introduced: 0,
                overwritten: 0,
                status: .sameRevision
            )
        }

        let counts = try await references.divergence(local: source, upstream: target)
        let status = try await leaseStatus(
            branch: branch,
            source: source,
            target: target,
            overwritten: counts.behind
        )

        return ForcePushPreview(
            source: source,
            destination: target,
            introduced: counts.ahead,
            overwritten: counts.behind,
            status: status
        )
    }

    /// 把任意版本推到远端的指定引用：普通推送，不强推、不推标签与子模块。
    ///
    /// - Parameters:
    ///   - revision: 要推送的分支、标签或提交，推送它指向的提交。
    ///   - remote: 远端名。
    ///   - destination: 远端引用；不以 `refs/` 开头时视为分支名，如 Gerrit 评审写 `refs/for/<分支>`。
    ///   - skipHooks: 跳过 pre-push 钩子。
    public func push(
        revision: String,
        remote: String,
        to destination: String,
        skipHooks: Bool = false,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> [RemoteReferenceUpdate] {
        let target = destination.hasPrefix("refs/") ? destination : "refs/heads/" + destination

        guard !destination.isEmpty, !destination.hasPrefix("-"), !target.contains("@{") else {
            throw RepositoryReadError.invalidQuery
        }

        return try await runner.writeTransaction {
            let references = RepositoryReferences(runner: runner)
            _ = try await runner.run(["check-ref-format", target])

            guard try await references.snapshot().remotes.contains(where: { $0.name == remote }) else {
                throw RepositorySyncError.missingRemote
            }

            // 来源先解析成提交哈希，refspec 两侧都不会被当成选项或强推标记
            let commit = try await references.resolve(revision)
            var options = PushOptions()
            options.skipHooks = skipHooks

            let arguments = pushPrefix(remote: remote) + ["--no-force"] + pushArguments(options)
                + ["--", remote, commit + ":" + target]

            let result = try await runner.execute(arguments, onOutput: onOutput)
            return try RemoteReferenceUpdate.parsePush(result.standardOutput)
        }
    }

    /// 推送命令的公共前缀：固定 porcelain 与进度，关掉会扩大推送范围的配置。
    private func pushPrefix(remote: String) -> [String] {
        [
            "-c", "push.followTags=false",
            "-c", "remote.\(remote).mirror=false",
            "push", "--porcelain", "--progress",
        ]
    }

    /// 推送选项对应的参数；子模块与钩子都显式写出，不受仓库配置影响。
    private func pushArguments(_ options: PushOptions) -> [String] {
        var arguments = [
            options.submodules.map { "--recurse-submodules=" + $0.rawValue } ?? "--no-recurse-submodules",
        ]

        if options.allTags {
            arguments.append("--tags")
        }

        if options.skipHooks {
            arguments.append("--no-verify")
        }

        return arguments
    }

    /// 按改写前的版本与远端独有的提交数判定状态；不会覆盖任何提交时不给状态。
    private func leaseStatus(
        branch: String,
        source: String,
        target: String,
        overwritten: Int
    ) async throws -> ForcePushPreview.Status {
        guard overwritten > 0 else {
            return .fastForward
        }

        let lastKnown = try await lastKnownRevision(of: branch, current: source)

        if lastKnown == target {
            return .matchesLastKnown
        }

        // 远端独有的提交：既不在本地分支上，也不在改写前的版本上
        let excluded = [source] + (lastKnown.map { [$0] } ?? [])
        let output = try await runner.run(["rev-list", "--count", target, "--not"] + excluded + ["--"])
        let text = String(decoding: output, as: UTF8.self)

        guard let newer = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw RepositoryReadError.malformedOutput("rev-list --count")
        }

        return newer > 0 ? .newerOnRemote(newer) : .differsFromLastKnown
    }

    /// reflog 中最近一个不是当前提交祖先的版本；分支没有 reflog 或从未改写过历史时为 nil。
    private func lastKnownRevision(of branch: String, current: String) async throws -> String? {
        let output = try await runner.run([
            "log", "-g", "--format=%H", "-n", String(Self.reflogCandidateLimit * 4), branch, "--",
        ])

        var seen = Set([current])
        let candidates = String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
            .filter { GitObjectID.isValid($0) && seen.insert($0).inserted }
            .prefix(Self.reflogCandidateLimit)

        for candidate in candidates {
            try Task.checkCancellation()

            // 已被回收的旧提交读不到，按不可用的候选跳过
            let ancestor = try await runner.execute(
                ["merge-base", "--is-ancestor", candidate, current],
                acceptedExitCodes: [0, 1, 128]
            )

            if ancestor.exitCode == 1 {
                return candidate
            }
        }

        return nil
    }
}
