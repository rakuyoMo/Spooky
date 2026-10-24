import Foundation

// MARK: - Branch Management

extension RepositoryReferences {
    /// 把非当前分支快进到它的上游：先给出不能快进的原因，再由 Git 自己做快进检查后更新引用，不碰工作区。
    ///
    /// 更新用 `fetch .` 完成：Git 只接受快进，并拒绝更新在任何工作树里检出的分支。已是最新时什么都不做。
    ///
    /// - Parameter branch: 本地分支的完整引用名。
    public func fastForward(
        _ branch: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        guard branch.hasPrefix("refs/heads/") else {
            throw RepositoryReadError.invalidQuery
        }

        try await runner.writeTransaction {
            let name = String(branch.dropFirst("refs/heads/".count))

            // `@{upstream}` 前只认分支短名；没有上游时 Git 报 “no upstream configured”，归为无上游的错误
            let output = try await runner.run([
                "rev-parse", "--verify", "--symbolic-full-name", "--end-of-options", name + "@{upstream}",
            ])
            let upstream = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

            let head = try await runner.execute(["symbolic-ref", "--quiet", "HEAD"], acceptedExitCodes: [0, 1])

            guard String(decoding: head.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines) != branch
            else {
                throw ReferenceError.currentBranch(name)
            }

            let counts = try await divergence(local: resolve(branch), upstream: resolve(upstream))

            guard counts.ahead == 0 else {
                throw ReferenceError.diverged(branch: name, upstream: upstream)
            }

            guard counts.behind > 0 else {
                return
            }

            _ = try await runner.execute(
                [
                    "fetch", "--no-tags", "--no-write-fetch-head", "--no-recurse-submodules",
                    "--no-auto-maintenance", "--", ".", upstream + ":" + branch,
                ],
                onOutput: onOutput
            )
        }
    }

    /// 设置本地分支的上游；上游是远端分支或另一个本地分支的完整引用名。
    public func setUpstream(_ upstream: String, for branch: String) async throws {
        guard
            branch.hasPrefix("refs/heads/"), upstream != branch,
            upstream.hasPrefix("refs/heads/") || upstream.hasPrefix("refs/remotes/")
        else {
            throw RepositoryReadError.invalidQuery
        }

        _ = try await runner.run([
            "branch", "--set-upstream-to=" + upstream, "--", String(branch.dropFirst("refs/heads/".count)),
        ])
    }

    /// 取消上游只删 `branch.<名称>.remote` 与 `merge`，分支配置段里的其它键保留。
    public func unsetUpstream(of branch: String) async throws {
        guard branch.hasPrefix("refs/heads/") else {
            throw RepositoryReadError.invalidQuery
        }

        _ = try await runner.run(["branch", "--unset-upstream", "--", String(branch.dropFirst("refs/heads/".count))])
    }

    /// 重命名本地分支；以它为父分支的分支一并改为新名字，父分支关系不会悬空。
    ///
    /// - Parameters:
    ///   - branch: 原分支的完整引用名。
    ///   - name: 新的分支短名。
    public func rename(_ branch: String, to name: String) async throws {
        guard branch.hasPrefix("refs/heads/") else {
            throw RepositoryReadError.invalidQuery
        }

        try await runner.writeTransaction {
            try await validate(name: name)
            let children = try await metadata().filter { $0.value.parent == branch }.map(\.key)

            _ = try await runner.run(["branch", "-m", "--", String(branch.dropFirst("refs/heads/".count)), name])

            for child in children {
                try await setParent("refs/heads/" + name, of: child)
            }
        }
    }

    /// 删除一个本地分支，按需再删除它跟踪的远端分支；两步在同一个仓库操作里，本地删除失败时远端不动。
    ///
    /// - Parameters:
    ///   - branch: 本地分支的完整引用名。
    ///   - force: 是否强制删除未合并的分支。
    ///   - deletingUpstream: 是否同时删除跟踪的远端分支；分支跟踪本地分支时没有可删的远端分支。
    public func delete(
        _ branch: String,
        force: Bool,
        deletingUpstream: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let upstream = deletingUpstream ? try await remoteUpstream(of: branch) : nil
            try await delete([branch], force: force)

            if let upstream {
                try await deleteRemoteBranches([upstream.branch], on: upstream.remote, onOutput: onOutput)
            }
        }
    }

    /// 在远端删除若干分支，一次推送完成；本机对应的远端跟踪分支随推送结果更新。
    ///
    /// - Parameters:
    ///   - branches: 远端上的完整引用名，如 `refs/heads/feature`。
    ///   - remote: 远端名。
    public func deleteRemoteBranches(
        _ branches: [String],
        on remote: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        guard !branches.isEmpty, branches.allSatisfy({ $0.hasPrefix("refs/heads/") }) else {
            throw RepositoryReadError.invalidQuery
        }

        try await runner.writeTransaction {
            try await validate(remote: remote)

            _ = try await runner.execute(
                Self.pushCommand(remote: remote) + ["--", remote] + branches.map { ":" + $0 },
                onOutput: onOutput
            )
        }
    }

    /// 重命名远端分支：先以原提交新建新名字，再删除原名字。
    ///
    /// 本机已知远端有新名字时直接拒绝；两次推送再各带 lease：新名字必须还不存在，原名字必须仍指向本机记录的提交。
    /// 第二步失败时两个名字都在，不会丢分支。
    ///
    /// - Parameters:
    ///   - name: 远端上的分支短名。
    ///   - remote: 远端名。
    ///   - newName: 新的分支短名。
    public func renameRemoteBranch(
        _ name: String,
        on remote: String,
        to newName: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            try await validate(remote: remote)
            try await validate(name: name)
            try await validate(name: newName)
            let object = try await resolve("refs/remotes/" + remote + "/" + name)
            let push = Self.pushCommand(remote: remote)

            // 新名字与原名字指向同一提交时推送只算 “已是最新”，lease 拦不住，先按本机记录拒绝
            let existing = try await runner.execute(
                ["rev-parse", "--verify", "--quiet", "--end-of-options", "refs/remotes/" + remote + "/" + newName],
                acceptedExitCodes: [0, 1]
            )

            guard existing.exitCode != 0 else {
                throw ReferenceError.remoteBranchExists(newName, remote: remote)
            }

            _ = try await runner.execute(
                push + ["--force-with-lease=refs/heads/" + newName + ":", "--", remote, object + ":refs/heads/" + newName],
                onOutput: onOutput
            )

            _ = try await runner.execute(
                push + ["--force-with-lease=refs/heads/" + name + ":" + object, "--", remote, ":refs/heads/" + name],
                onOutput: onOutput
            )
        }
    }

    /// 分支跟踪的远端与远端上的完整引用名；跟踪本地分支或没有上游时为 nil。
    private func remoteUpstream(of branch: String) async throws -> (remote: String, branch: String)? {
        let output = try await runner.run([
            "for-each-ref", "--format=%(upstream:remotename)%00%(upstream:remoteref)", branch,
        ])
        let fields = String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .newlines)
            .split(separator: "\u{0}", omittingEmptySubsequences: false)
            .map(String.init)

        guard fields.count == 2, !fields[0].isEmpty, fields[0] != ".", fields[1].hasPrefix("refs/heads/") else {
            return nil
        }

        return (fields[0], fields[1])
    }
}

// MARK: - Helpers

extension RepositoryReferences {
    /// 从普通删除的错误输出中取出未合并的分支短名；Git 每个未合并分支报一行。
    static func unmergedBranches(in message: String) -> [String] {
        message.split(separator: "\n").compactMap { line in
            let prefix = "error: the branch '"
            let suffix = "' is not fully merged"

            guard
                line.lowercased().hasPrefix(prefix),
                let end = line.range(of: suffix, options: [.caseInsensitive, .backwards])
            else {
                return nil
            }

            return String(line[line.index(line.startIndex, offsetBy: prefix.count) ..< end.lowerBound])
        }
    }

    /// 推送引用增删的固定参数：显式 refspec，不跟随标签、不按镜像推送、不递归子模块，进度经 stderr 流出。
    static func pushCommand(remote: String) -> [String] {
        [
            "-c", "push.followTags=false", "-c", "remote." + remote + ".mirror=false",
            "push", "--porcelain", "--progress", "--no-recurse-submodules",
        ]
    }
}
