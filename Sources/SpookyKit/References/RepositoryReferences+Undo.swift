import Foundation

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
}
