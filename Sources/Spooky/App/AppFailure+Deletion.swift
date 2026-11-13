import Foundation
import SpookyKit

// MARK: - Deletion

extension AppFailure {
    /// 删除没有全部完成时的文案键、类别、恢复说明与原文：原文先列出已从磁盘移走的项，再接中断删除的错误原文。
    static func classification(
        of deletion: FileDeletionError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        let underlying = AppFailure(error: deletion.underlying, opening: false, location: nil, writing: true)
        let removed = deletion.removed.joined(separator: "\n")

        // 都已移走时只差暂存，其余情况有的项没有动
        let (key, recoveryKey) =
            deletion.removedAll
                ? ("files.error.unstagedDeletion", "files.error.unstagedDeletion.help")
                : ("files.error.partialDeletion", "files.error.partialDeletion.help")

        return (key, .repository, recoveryKey, nil, removed + "\n\n" + underlying.details)
    }
}
