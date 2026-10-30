import Foundation

// MARK: - Undo

extension RepositoryReferences {
    /// 解析 `ls-remote` 的输出：每行是对象哈希、制表符与完整引用名。
    ///
    /// 给出的模式按引用名的结尾匹配，输出里可能有名字更长的引用，由调用方按完整引用名比较。
    static func listedReferences(in output: Data) throws -> [String] {
        try String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .map { line in
                let fields = line.split(separator: "\t", omittingEmptySubsequences: false)

                guard fields.count == 2, GitObjectID.isValid(String(fields[0])), fields[1].hasPrefix("refs/") else {
                    throw RepositoryReadError.malformedOutput("ls-remote")
                }

                return String(fields[1])
            }
    }

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

    /// 远端上现在有没有这个分支或标签：连接远端列一次，按完整引用名比较。
    ///
    /// - Parameters:
    ///   - reference: 远端上的完整引用名，以 `refs/heads/` 或 `refs/tags/` 开头。
    ///   - remote: 远端名。
    func remoteContains(_ reference: String, on remote: String) async throws -> Bool {
        let scope = reference.hasPrefix("refs/tags/") ? "--tags" : "--heads"
        let output = try await runner.run(["ls-remote", scope, "--", remote, reference])

        return try Self.listedReferences(in: output).contains(reference)
    }
}
