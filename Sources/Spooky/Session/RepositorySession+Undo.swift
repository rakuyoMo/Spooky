import Foundation
import SpookyKit

// MARK: - UndoMenuState

/// 撤销或重做菜单项此刻的状态。
enum UndoMenuState: Equatable {
    /// 没有可撤销或重做的操作。
    case empty

    /// 上一个写操作不能撤销，附操作名称。
    case irreversible(String)

    /// 可以执行，附操作名称。
    case available(String)

    /// 有记录但此刻不能执行，附操作名称与原因的文案键。
    case blocked(String, reason: String)
}

// MARK: - Undo

extension RepositorySession {
    /// 本窗口仓库的撤销栈；没有打开仓库时为 nil。
    var undoHistory: RepositoryUndoHistory? {
        repository.map(RepositoryUndoHistory.shared(for:))
    }

    /// 撤销或重做此刻能否执行；不能执行时给出原因，菜单据此显示。
    ///
    /// 这里只用界面已经读到的结果粗略核对，执行前核心库还会完整核对一次。
    func undoMenuState(redo: Bool) -> UndoMenuState {
        guard let repository, let history = undoHistory else {
            return .empty
        }

        guard let entry = redo ? history.redoEntries.last : history.undoEntries.last else {
            return !redo ? history.irreversibleTitle.map(UndoMenuState.irreversible) ?? .empty : .empty
        }

        // 写操作与合并、变基等进行中的操作都要等它结束
        let busy = isWriting
            || RepositoryWriteLocks.shared.contains(repository)
            || context?.operation != nil

        if busy {
            return .blocked(entry.title, reason: "undo.reason.busy")
        }

        // 服务器断线时结果未知，重连后的完整刷新核对过才允许
        if repository.host != nil, connectionState != .connected || interruptedWrite != nil {
            return .blocked(entry.title, reason: "undo.reason.disconnected")
        }

        // 仓库应处的状态：撤销时是操作后，重做时是操作前
        let expected = redo ? entry.before : entry.after
        let references = undoComparedReferences
        let stashIDs = stashes.isLoaded ? stashes.entries.map(\.id) : nil

        // 正在刷新时读到的可能还是写入前的状态，对不上时先当作忙碌
        guard let status, expected.resembles(status: status, references: references, stashes: stashIDs) else {
            return .blocked(entry.title, reason: isRefreshing ? "undo.reason.busy" : "undo.reason.changed")
        }

        return .available(entry.title)
    }

    /// 撤销最近一次操作：核对仓库仍是操作后的状态，再恢复成操作前；经写队列执行并记进 Activity。
    func undoLastOperation() {
        guard
            case .available = undoMenuState(redo: false),
            let history = undoHistory,
            let entry = history.undoEntries.last
        else { return }

        performGit(
            { runner, _ in
                try await RepositoryUndo(runner: runner).restore(entry.before, expecting: entry.after, message: "undo")
            },
            title: UndoManager().undoMenuTitle(forUndoActionName: entry.title),
            undo: .unrecorded
        ) {
            history.finishUndo(entry)
        }
    }

    /// 重做最近撤销的操作：核对仓库仍是操作前的状态，再恢复成操作后。
    func redoLastOperation() {
        guard
            case .available = undoMenuState(redo: true),
            let history = undoHistory,
            let entry = history.redoEntries.last
        else { return }

        performGit(
            { runner, _ in
                try await RepositoryUndo(runner: runner).restore(entry.after, expecting: entry.before, message: "redo")
            },
            title: UndoManager().redoMenuTitle(forUndoActionName: entry.title),
            undo: .unrecorded
        ) {
            history.finishRedo(entry)
        }
    }

    /// 按声明包装写操作：可撤销的操作前后各记一次状态，成功改动仓库后登记；不能撤销的操作成功后清空撤销栈。
    ///
    /// 操作前有进行中的操作或冲突、操作后停在进行中的状态、或删掉的未跟踪文件找不回内容时，都按不能撤销处理。
    func recordingUndo(
        _ action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        recording: UndoRecording
    ) -> @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void {
        guard let history = undoHistory, recording != .unrecorded else {
            return action
        }

        guard recording == .reversible else {
            return { runner, output in
                try await action(runner, output)
                await history.recordIrreversible(title)
            }
        }

        return { runner, output in
            let undo = RepositoryUndo(runner: runner)
            let before = try? await undo.capture()
            try await action(runner, output)

            guard let before, let after = try? await undo.capture() else {
                await history.recordIrreversible(title)
                return
            }

            // 没有改动仓库的操作不占撤销栈
            guard after != before else { return }

            let restorable = (try? await undo.canRestore(before, from: after)) ?? false

            if restorable {
                await history.record(RepositoryUndoEntry(title: title, before: before, after: after))
            } else {
                await history.recordIrreversible(title)
            }
        }
    }
}

// MARK: - Private

extension RepositorySession {
    /// 粗略核对用的分支与标签：引用快照里剥离附注标签后的目标；还没读到快照时不比较。
    private var undoComparedReferences: [String: String]? {
        history.snapshot.map { snapshot in
            Dictionary(
                snapshot.references.filter { $0.isLocal || $0.isTag }.map { ($0.id, $0.objectID) },
                uniquingKeysWith: { first, _ in first }
            )
        }
    }
}
