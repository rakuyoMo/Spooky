import Foundation
import Observation
import SpookyKit

// MARK: - UndoRecording

/// 写操作与撤销记录的关系，由发起写操作的地方声明。
enum UndoRecording {
    /// 记下操作前后的仓库状态；操作改动了仓库、又能安全恢复时可以撤销与重做。
    case reversible

    /// 不能撤销，如改动服务器、远端设置或提交身份的操作：成功后清空本仓库的撤销记录，菜单说明上一个操作不能撤销。
    case irreversible

    /// 不碰撤销记录：自动获取这类不由用户直接发起、也不改动记录所含状态的操作，以及撤销与重做本身。
    case unrecorded
}

// MARK: - RepositoryUndoEntry

/// 一次可撤销的写操作：名称与操作前后的仓库状态。
struct RepositoryUndoEntry: Identifiable, Sendable {
    /// 在撤销栈与重做栈之间移动时用来找回同一项。
    let id = UUID()

    /// 已本地化的操作名称，菜单显示为 “Undo <名称>”。
    let title: String

    /// 操作前的状态，撤销回到这里。
    let before: RepositoryState

    /// 操作后的状态，重做回到这里。
    let after: RepositoryState
}

// MARK: - RepositoryUndoHistory

/// 一个仓库的撤销与重做栈；同一仓库开在几个窗口里时共用一份。
@MainActor
@Observable
final class RepositoryUndoHistory {
    /// 应用内按仓库位置登记的撤销栈。
    private static var histories: [RepositoryLocation: RepositoryUndoHistory] = [:]

    /// 可以撤销的操作，最近的在最后。
    private(set) var undoEntries: [RepositoryUndoEntry] = []

    /// 撤销过、可以重做的操作，最近撤销的在最后。
    private(set) var redoEntries: [RepositoryUndoEntry] = []

    /// 上一个写操作不能撤销时它的名称；记下新的可撤销操作后清除。
    private(set) var irreversibleTitle: String? = nil

    /// 取得仓库的撤销栈，第一次用到时创建。
    static func shared(for location: RepositoryLocation) -> RepositoryUndoHistory {
        if let history = histories[location] {
            return history
        }

        let history = RepositoryUndoHistory()
        histories[location] = history
        return history
    }

    /// 记下一次可撤销的操作；新的操作让之前撤销过的操作不能再重做。
    func record(_ entry: RepositoryUndoEntry) {
        undoEntries.append(entry)
        redoEntries = []
        irreversibleTitle = nil
    }

    /// 记下一次不能撤销的操作：之前的记录不再能按顺序回退，全部清空。
    func recordIrreversible(_ title: String) {
        undoEntries = []
        redoEntries = []
        irreversibleTitle = title
    }

    /// 撤销完成：这一项移到重做栈。
    func finishUndo(_ entry: RepositoryUndoEntry) {
        guard let index = undoEntries.lastIndex(where: { $0.id == entry.id }) else { return }
        redoEntries.append(undoEntries.remove(at: index))
    }

    /// 重做完成：这一项回到撤销栈。
    func finishRedo(_ entry: RepositoryUndoEntry) {
        guard let index = redoEntries.lastIndex(where: { $0.id == entry.id }) else { return }
        undoEntries.append(redoEntries.remove(at: index))
    }
}
