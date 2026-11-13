import Foundation
import Observation
import SpookyKit

// MARK: - UndoRecording

/// 写操作与撤销记录的关系，由发起写操作的地方声明。
enum UndoRecording {
    /// 记下操作前后的仓库状态；操作改动了仓库、又能安全恢复时可以撤销与重做。
    case reversible

    /// 由操作自己给出反向操作，用于快照记不住的内容，如远端设置、assume-unchanged 标记、Git LFS 的启用、
    /// 远端上发布与改名的引用，以及子模块的结构与本地设置。
    ///
    /// 闭包在操作之前执行，读出撤销要用的内容：返回反向操作时，操作成功后记一条；
    /// 返回 nil 表示这次操作不改动要撤销的内容，不碰撤销记录；抛出表示这次操作撤销不了，成功后按 ``irreversible`` 处理。
    case inverse(@Sendable (GitRunner) async throws -> UndoInverse?)

    /// 不能撤销，如推送或改动提交身份的操作：成功后清空本仓库的撤销记录，菜单说明上一个操作不能撤销。
    case irreversible

    /// 不碰撤销记录：自动获取这类不由用户直接发起、也不改动记录所含状态的操作，以及撤销与重做本身。
    case unrecorded
}

// MARK: - UndoInverse

/// 操作自己给出的反向操作。
struct UndoInverse: Sendable {
    /// 撤销要连接远端时记在 Activity 的 Remote 页的对象；为 nil 时记在 Repository 页。
    var target: ActivityTarget? = nil

    /// 原操作推送新建的远端引用，如发布的分支与标签：原操作结束后按 ``PushLog`` 里这个引用的结果登记，
    /// 新建了它才记一条，已是最新时不碰撤销记录，更新了远端已有的引用时按不能撤销处理。为 nil 时照常登记。
    var pushedReference: (remote: String, reference: String)? = nil

    /// 收集原操作移进废纸篓的项，撤销时据此移回：原操作在它之下执行，有的项废纸篓命令没有报告位置时按不能撤销处理。
    /// 为 nil 时不收集。
    var trashLog: TrashLog? = nil

    /// 撤销时执行，输出经第二个参数送进 Activity：先核对前提，仓库已不是操作后的样子时抛出
    /// ``RepositoryUndoError/repositoryChanged``，不做任何改动。
    let undo: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void

    /// 重做时代替原操作执行，如复用撤销时留下的子模块 Git 目录重新添加；为 nil 时再执行一次原操作。
    var redo: (@Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void)? = nil
}

// MARK: - RepositoryUndoEntry

/// 一次可撤销的写操作：名称与撤销、重做的办法。
struct RepositoryUndoEntry: Identifiable, Sendable {
    /// 撤销与重做的办法。
    enum Change: Sendable {
        /// 操作前后的仓库状态与操作移进废纸篓的项：撤销回到操作前，重做回到操作后；废纸篓里的项撤销时移回原处，重做时重新移进废纸篓。
        case snapshot(before: RepositoryState, after: RepositoryState, trashed: [TrashedItem])

        /// 操作自己给出的反向操作：撤销时执行它；重做时再执行一次准备与原操作（反向操作带着专门的重做时用它代替原操作），
        /// 换上新读出的反向操作。
        ///
        /// `target` 是原操作记在 Activity 的 Remote 页的对象，重做时同样记在那里；为 nil 时记在 Repository 页。
        case inverse(
            prepare: @Sendable (GitRunner) async throws -> UndoInverse?,
            action: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
            target: ActivityTarget?,
            inverse: UndoInverse
        )
    }

    /// 在撤销栈与重做栈之间移动时用来找回同一项。
    let id = UUID()

    /// 已本地化的操作名称，菜单显示为 “Undo <名称>”。
    let title: String

    /// 撤销与重做的办法。
    let change: Change
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

    /// 重做完成：这一项带着重做后的撤销办法回到撤销栈，如重新移进废纸篓后的位置、新读出的反向操作。
    ///
    /// - Parameter change: 重做后的撤销办法；为 nil 时这次重做没有改动要撤销的内容，这一项不再回到撤销栈。
    func finishRedo(_ entry: RepositoryUndoEntry, change: RepositoryUndoEntry.Change?) {
        guard let index = redoEntries.lastIndex(where: { $0.id == entry.id }) else { return }

        let redone = redoEntries.remove(at: index)

        if let change {
            undoEntries.append(RepositoryUndoEntry(title: redone.title, change: change))
        }
    }
}
