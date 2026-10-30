import Foundation

// MARK: - Undo

extension RepositoryTags {
    /// 发布标签之前读出撤销时的租约：本地标签指向的对象，附注标签是标签对象本身；只读本机，不连接远端。
    ///
    /// 推送是否新建了远端标签由这次推送的逐条结果判断，见 ``PushLog``。
    ///
    /// - Parameter name: 标签短名。
    public func publicationLease(of name: String) async throws -> String {
        guard !name.isEmpty else {
            throw RepositoryReadError.invalidQuery
        }

        return try await RepositoryUndo(runner: runner)
            .objectID(["rev-parse", "--verify", "--end-of-options", "refs/tags/" + name])
    }

    /// 撤销发布标签：在远端删掉它，远端标签必须仍指向发布时的对象，被别人改过时推送被拒绝，原样报错。
    ///
    /// 前提是这个远端还在；不在时抛出 ``RepositoryUndoError/repositoryChanged``，不连接远端。
    ///
    /// - Parameters:
    ///   - name: 标签短名。
    ///   - remote: 发布到的远端名。
    ///   - object: 由 ``publicationLease(of:)`` 读出的对象。
    public func undoPublish(
        _ name: String,
        on remote: String,
        object: String,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        guard !name.isEmpty, GitObjectID.isValid(object) else {
            throw RepositoryReadError.invalidQuery
        }

        try await runner.writeTransaction {
            guard try await !RepositoryRemotes(runner: runner).settings(of: remote).isEmpty else {
                throw RepositoryUndoError.repositoryChanged
            }

            let reference = "refs/tags/" + name

            _ = try await runner.execute(
                RepositoryReferences.pushCommand(remote: remote)
                    + ["--force-with-lease=" + reference + ":" + object, "--", remote, ":" + reference],
                onOutput: onOutput
            )
        }
    }
}
