import Foundation
import SpookyKit

// MARK: - Rewrite

extension AppFailure {
    /// 改写操作失败的文案键、类别与恢复说明；提交序列变化时附上 Git 的原始输出。
    static func classification(
        of rewrite: RewriteError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?) {
        switch rewrite {
        case .sequenceChanged(let result):
            ("rewrite.error.changed", .repository, "rewrite.error.changed.help", result)

        case .mergeCommitsInRange:
            ("rewrite.error.merges", .repository, "rewrite.error.merges.help", nil)

        case .notInHead:
            ("rewrite.error.notInHead", .repository, "rewrite.error.notInHead.help", nil)

        case .rootCommit:
            ("rewrite.error.root", .repository, "rewrite.error.root.help", nil)

        case .noStagedChanges:
            ("rewrite.error.noStaged", .repository, "rewrite.error.noStaged.help", nil)

        case .nothingToAutosquash:
            ("rewrite.error.autosquash", .repository, "rewrite.error.autosquash.help", nil)

        case .invalidSelection:
            ("rewrite.error.selection", .repository, "rewrite.error.selection.help", nil)
        }
    }
}
