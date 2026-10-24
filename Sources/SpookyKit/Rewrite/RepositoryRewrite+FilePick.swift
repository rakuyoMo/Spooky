import Foundation

// MARK: - File Pick

extension RepositoryRewrite {
    /// 只把一个提交里一个文件的改动套用到工作区，不改暂存区；套用不上时整体失败，工作区保持不变。
    ///
    /// 改动取自这个提交与它的第一个父提交之间，根提交取整个文件；重命名的文件连同原路径一起取出。
    /// 补丁在仓库所在的机器上生成并应用，Git 的原始输出保留在错误里。
    ///
    /// - Parameters:
    ///   - path: 文件在这个提交里的路径。
    ///   - originalPath: 重命名前的路径；没有重命名时为 nil。
    ///   - commit: 提交的完整哈希。
    public func cherryPick(path: String, originalPath: String?, from commit: String) async throws {
        try Self.validate([commit])

        let paths = [path] + (originalPath.map { [$0] } ?? [])

        let arguments =
            ["--literal-pathspecs", "show", "--format=", "--diff-merges=first-parent", "-M"]
                + RepositoryStashes.patchOptions
                + [commit, "--"]
                + paths

        try await runner.writeTransaction {
            let patch = try await runner.run(arguments)

            guard !patch.isEmpty else {
                throw WorkingCopyError.invalidSelection
            }

            _ = try await runner.run(["apply", "--whitespace=nowarn", "-"], input: patch)
        }
    }
}
