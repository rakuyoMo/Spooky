import Foundation

// MARK: - BranchDeletion

/// 连同跟踪的远端分支一起删除本地分支之前记下的内容，撤销时据此重建。
public struct BranchDeletion: Sendable {
    /// 本地分支的完整引用名。
    public let branch: String

    /// 本地分支指向的提交。
    public let object: String

    /// 本地分支的配置段，含上游设置。
    public let settings: [BranchSetting]

    /// 跟踪的远端分支：远端名、远端上的完整引用名与本机记录的提交；分支跟踪本地分支或没有上游时为 nil。
    public let upstream: (remote: String, branch: String, object: String)?
}

// MARK: - Undo

extension RepositoryReferences {
    /// 撤销把远端分支 `name` 改名为 `newName`：再把它改回原名，两次推送照旧各带租约。
    ///
    /// 前提是本机还有新名字的远端跟踪分支、没有原名字的；不符时抛出 ``RepositoryUndoError/repositoryChanged``，不连接远端。
    ///
    /// - Parameters:
    ///   - name: 改名前的分支短名。
    ///   - remote: 远端名。
    ///   - newName: 改名后的分支短名。
    public func undoRenameRemoteBranch(
        _ name: String,
        on remote: String,
        to newName: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let prefix = "refs/remotes/" + remote + "/"
            let output = try await runner.run(["for-each-ref", "--format=%(refname)", prefix + newName, prefix + name])

            // 模式按路径前缀匹配，会带出名字更长的引用，按完整引用名比较
            let listed = Set(String(decoding: output, as: UTF8.self).split(separator: "\n").map(String.init))

            guard listed.contains(prefix + newName), !listed.contains(prefix + name) else {
                throw RepositoryUndoError.repositoryChanged
            }

            try await renameRemoteBranch(newName, on: remote, to: name, onOutput: onOutput)
        }
    }

    /// 删除本地分支连同它跟踪的远端分支之前，记下撤销要重建的内容。
    ///
    /// - Parameter branch: 本地分支的完整引用名。
    /// - Throws: 有远端上游、本机却没有对应的远端跟踪分支时抛出 ``RepositoryUndoError/repositoryChanged``，这次删除撤销不了。
    public func deletion(of branch: String) async throws -> BranchDeletion {
        guard branch.hasPrefix("refs/heads/") else {
            throw RepositoryReadError.invalidQuery
        }

        let object = try await resolve(branch)
        let name = String(branch.dropFirst("refs/heads/".count))
        let settings = try await RepositoryUndo(runner: runner).branchSettings().filter { $0.branch == name }

        guard let upstream = try await remoteUpstream(of: branch) else {
            return BranchDeletion(branch: branch, object: object, settings: settings, upstream: nil)
        }

        // 远端分支按本机记录的提交重建
        let tracking = "refs/remotes/" + upstream.remote + "/" + String(upstream.branch.dropFirst("refs/heads/".count))

        guard let remoteObject = try? await resolve(tracking) else {
            throw RepositoryUndoError.repositoryChanged
        }

        return BranchDeletion(
            branch: branch,
            object: object,
            settings: settings,
            upstream: (upstream.remote, upstream.branch, remoteObject)
        )
    }

    /// 撤销连同远端分支一起删除本地分支：先经推送在远端重建分支，再重建本地分支与它的配置段。
    ///
    /// 本地已有同名分支时抛出 ``RepositoryUndoError/repositoryChanged``；本机已知远端有同名分支时抛出
    /// ``ReferenceError/remoteBranchExists(_:remote:)``；推送带租约，远端已有同名分支时由 Git 拒绝。这几种情况本地都不动。
    public func undoDelete(
        _ deletion: BranchDeletion,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let local = try await runner.execute(
                ["rev-parse", "--verify", "--quiet", "--end-of-options", deletion.branch],
                acceptedExitCodes: [0, 1]
            )

            guard local.exitCode != 0 else {
                throw RepositoryUndoError.repositoryChanged
            }

            if let upstream = deletion.upstream {
                try await recreate(upstream, onOutput: onOutput)
            }

            // 空的旧值要求分支仍不存在
            _ = try await runner.run(["update-ref", "-m", "undo", deletion.branch, deletion.object, ""])
            try await RepositoryUndo(runner: runner).restoreBranchSettings(from: [], to: deletion.settings)
        }
    }

    /// 经推送在远端重建分支：本机已知远端有同名分支时拒绝，推送的租约要求远端分支仍不存在，推送没有新建它时同样拒绝。
    private func recreate(
        _ upstream: (remote: String, branch: String, object: String),
        onOutput: (@Sendable (GitOutputEvent) -> Void)?
    ) async throws {
        try await validate(remote: upstream.remote)

        let name = String(upstream.branch.dropFirst("refs/heads/".count))

        let existing = try await runner.execute(
            ["rev-parse", "--verify", "--quiet", "--end-of-options", "refs/remotes/" + upstream.remote + "/" + name],
            acceptedExitCodes: [0, 1]
        )

        guard existing.exitCode != 0 else {
            throw ReferenceError.remoteBranchExists(name, remote: upstream.remote)
        }

        let result = try await runner.execute(
            Self.pushCommand(remote: upstream.remote) + [
                "--force-with-lease=" + upstream.branch + ":",
                "--",
                upstream.remote,
                upstream.object + ":" + upstream.branch,
            ],
            onOutput: onOutput
        )

        // 远端已有同名分支、又正好指向这个提交时推送只算 “已是最新”，租约拦不住
        let update = try RemoteReferenceUpdate
            .parsePush(result.standardOutput)
            .first { $0.reference == upstream.branch }

        guard update?.flag == "*" else {
            throw ReferenceError.remoteBranchExists(name, remote: upstream.remote)
        }
    }
}
