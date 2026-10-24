import Foundation

// MARK: - Update Branch

extension RepositorySync {
    /// 把父分支的新提交并入一个本地分支：合并父分支，或把分支变基到父分支上。
    ///
    /// 检出、合并或变基持有同一个仓库写锁；工作区不干净时在检出之前就停下，交给自动储藏。
    /// 冲突时留下进行中的合并或变基，由进行中操作的横幅与冲突向导接手。
    ///
    /// - Parameters:
    ///   - branch: 要更新的本地分支的完整引用名；不是当前分支时先检出它。
    ///   - parent: 父分支的完整引用名。
    ///   - rebase: 为 true 时变基到父分支上，否则合并父分支。
    ///   - options: 合并的提交方式与签名校验；变基只使用其中的跳过钩子。
    public func updateBranch(
        _ branch: String,
        from parent: String,
        rebase: Bool,
        options: MergeOptions = MergeOptions(),
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        guard branch.hasPrefix("refs/heads/"), parent.hasPrefix("refs/"), branch != parent else {
            throw RepositoryReadError.invalidQuery
        }

        try await runner.writeTransaction {
            let status = try await runner.status()

            guard status.entries.isEmpty else {
                throw RepositorySyncError.dirtyWorkingCopy
            }

            let references = RepositoryReferences(runner: runner)
            let target = try await references.resolve(parent)

            #warning(
                "TODO: 更新非当前分支时先检出它再合并或变基，是按 “并入所选分支” 的做法推断的；核实方式：在不是 HEAD 的分支上打开集成父分支改动的弹窗，点 Merge 后看 HEAD 是否切到该分支；影响历史表头与分支整理里对非当前分支的 Update Branch"
            )
            if "refs/heads/" + (status.branch.head ?? "") != branch {
                try await references.checkout(branch)
            }

            if rebase {
                try await rebaseCurrentBranch(onto: target, skipHooks: options.skipHooks, onOutput: onOutput)
            } else {
                try await merge(target, options: options, onOutput: onOutput)
            }
        }
    }
}
