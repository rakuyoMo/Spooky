import SpookyKit
import Synchronization

// MARK: - UndoSteps

/// 按快照记录撤销的写操作在执行中对撤销记录的说明：先做完的部分单独记一步，或按实际结果改写最后一步的名称。
///
/// 经任务本地值交给操作；写操作不按快照记录撤销时为 nil。
final class UndoSteps: Sendable {
    /// 先做完、单独记一步的部分。
    struct Mark: Sendable {
        /// 这一步的名称。
        let title: String

        /// 做完这一步后的仓库状态；读不到时为 nil，整个操作按不能撤销处理。
        let state: RepositoryState?

        /// 做完这一步时移进废纸篓的项数：此前的项属于这一步与更早的步。
        let trashed: Int
    }

    /// 当前写操作的说明。
    @TaskLocal
    static var current: UndoSteps?

    /// 单独记下的部分，按先后排列。
    private let storedMarks = Mutex<[Mark]>([])

    /// 最后一步改写后的名称。
    private let storedTitle = Mutex<String?>(nil)

    /// 单独记下的部分，按先后排列。
    var marks: [Mark] {
        storedMarks.withLock { $0 }
    }

    /// 最后一步改写后的名称；没有改写时为 nil，用写操作本身的名称。
    var title: String? {
        storedTitle.withLock { $0 }
    }

    /// 把到此为止的改动单独记成名为 `title` 的一步。
    func mark(_ title: String, runner: GitRunner) async {
        let state = try? await RepositoryUndo(runner: runner).capture()
        let trashed = TrashLog.current?.items.count ?? 0

        storedMarks.withLock { $0.append(Mark(title: title, state: state, trashed: trashed)) }
    }

    /// 按实际结果改写最后一步的名称，如多选删除只删掉一部分时按删掉的个数命名。
    func rename(_ title: String) {
        storedTitle.withLock { $0 = title }
    }
}
