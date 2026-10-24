import Foundation
import SpookyKit

// MARK: - Undo

extension AppFailure {
    /// 撤销与重做被拒绝时的标题与恢复说明；拒绝都发生在改动仓库之前，说明里写明仓库没有变化。
    static func classification(of undo: RepositoryUndoError) -> (key: String, recoveryKey: String) {
        switch undo {
        case .repositoryChanged: ("undo.error.changed", "undo.error.changed.help")
        case .untrackedFiles: ("undo.error.untracked", "undo.error.untracked.help")
        case .hiddenChanges: ("undo.error.hidden", "undo.error.hidden.help")
        case .operationInProgress: ("undo.error.inProgress", "undo.error.inProgress.help")
        case .unresolvedConflicts: ("undo.error.conflicts", "undo.error.conflicts.help")
        }
    }
}
