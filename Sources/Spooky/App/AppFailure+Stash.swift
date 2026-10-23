import Foundation
import SpookyKit

// MARK: - Stash

extension AppFailure {
    /// 储藏失败的文案键、类别、恢复说明与原文：说明总是写明储藏仍然保留，Git 原文来自自身结果或被包装的原始错误。
    static func classification(
        of stash: StashError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        switch stash {
        case .noLocalChanges(let result):
            return ("stash.error.noChanges", .repository, "stash.error.noChanges.help", result, nil)

        case .stashChanged:
            return ("stash.error.changed", .repository, "stash.error.changed.help", nil, nil)

        case .conflicts(let result):
            return ("stash.error.conflicts", .git, "stash.error.conflicts.help", result, nil)

        case .operationFailed(_, let underlying):
            let raw = rawOutput(of: underlying)
            return ("stash.error.operation", .git, "stash.error.operation.help", raw.output, raw.diagnostic)

        case .reapplyFailed(_, let underlying):
            let raw = rawOutput(of: underlying)
            return ("stash.error.reapply", .git, "stash.error.reapply.help", raw.output, raw.diagnostic)
        }
    }

    /// 被包装的原始错误：Git 失败带回完整输出，其余错误带回它自己的错误标题。
    private static func rawOutput(of error: any Error) -> (output: GitCommandResult?, diagnostic: String?) {
        if let git = error as? GitError {
            return (git.result, git.diagnostic)
        }

        return (nil, AppFailure(error: error, opening: false, location: nil, writing: true).title)
    }
}
