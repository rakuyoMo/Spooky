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

        // 撤销放弃的正是仓库停着的那个操作时，进行中的操作不挡住它
        let aborted: RepositoryOperationState? =
            if !redo, case .inverse(_, _, _, let inverse) = entry.change {
                inverse.abortedOperation
            } else {
                nil
            }

        // 用户发起的写操作（执行中或排队）与合并、变基等进行中的操作都要等它结束；只有自动获取在执行时它让路
        let operation = context?.operation

        let busy = hasUserWrite
            || (operation != nil && operation != aborted)

        if busy {
            return .blocked(entry.title, reason: "undo.reason.busy")
        }

        // 服务器断线时结果未知，重连后的完整刷新核对过才允许
        if repository.host != nil, connectionState != .connected || interruptedWrite != nil {
            return .blocked(entry.title, reason: "undo.reason.disconnected")
        }

        // 反向操作的前提在执行时核对
        guard case .snapshot(let before, let after, _) = entry.change else {
            return .available(entry.title)
        }

        // 仓库应处的状态：撤销时是操作后，重做时是操作前
        let expected = redo ? before : after
        let references = undoComparedReferences
        let stashIDs = stashes.isLoaded ? stashes.entries.map(\.id) : nil

        // 正在刷新时读到的可能还是写入前的状态，对不上时先当作忙碌
        guard let status, expected.resembles(status: status, references: references, stashes: stashIDs) else {
            return .blocked(entry.title, reason: isRefreshing ? "undo.reason.busy" : "undo.reason.changed")
        }

        return .available(entry.title)
    }

    /// 撤销最近一次操作：快照记录核对仓库仍是操作后的状态，再恢复成操作前，移进废纸篓的项移回原处；反向操作记录执行反向操作。
    ///
    /// 经写队列执行并记进 Activity；要连接远端的反向操作记在 Remote 页。
    func undoLastOperation() {
        guard
            case .available = undoMenuState(redo: false),
            let history = undoHistory,
            let entry = history.undoEntries.last
        else { return }

        // 撤销重置时工作区有改动，先询问是否储藏
        if askToStashBeforeUndo(entry, in: history) {
            return
        }

        // 只有反向操作会连接远端
        let target: ActivityTarget? =
            switch entry.change {
            case .snapshot: nil
            case .inverse(_, _, _, let inverse): inverse.target
            }

        performGit(
            { runner, output in
                switch entry.change {
                case .snapshot(let before, let after, let trashed):
                    try await RepositoryUndo(runner: runner)
                        .restore(before, expecting: after, message: "undo", puttingBack: trashed)

                case .inverse(_, _, _, let inverse):
                    try await inverse.undo(runner, output)
                }
            },
            title: UndoManager().undoMenuTitle(forUndoActionName: entry.title),
            target: target,
            undo: .unrecorded
        ) { [weak self] in
            history.finishUndo(entry)

            // 反向操作按撤销后的仓库调整选中
            if let self, case .inverse(_, _, _, let inverse) = entry.change {
                inverse.afterUndo?(self)
            }
        }
    }

    /// 重做最近撤销的操作：快照记录核对仓库仍是操作前的状态，再恢复成操作后，操作移进废纸篓的项重新移进废纸篓；
    /// 反向操作记录再执行一次准备与原操作，反向操作带着专门的重做时用它代替原操作。
    func redoLastOperation() {
        guard
            case .available = undoMenuState(redo: true),
            let history = undoHistory,
            let entry = history.redoEntries.last
        else { return }

        let title = UndoManager().redoMenuTitle(forUndoActionName: entry.title)

        switch entry.change {
        case .snapshot(let before, let after, let trashed):
            // 重新移进废纸篓的新位置经记录收集，下次撤销据此移回
            let log = TrashLog()

            performGit(
                { runner, _ in
                    try await TrashLog.$current.withValue(log) {
                        try await RepositoryUndo(runner: runner)
                            .restore(after, expecting: before, message: "redo", trashing: trashed)
                    }
                },
                title: title,
                undo: .unrecorded
            ) {
                history.finishRedo(entry, change: .snapshot(before: before, after: after, trashed: log.items))
            }

        case .inverse(let prepare, let action, let target, let inverse):
            // 反向操作带着专门的重做时用它代替原操作
            let redo = inverse.redo ?? action

            // 新的反向操作在原操作之前读出，原操作成功后按推送结果核对再换上；重做与原操作记在 Activity 的同一页
            performGit(
                { runner, output in
                    let prepared = await PreparedInverse(prepare, runner: runner)
                    let log = PushLog()
                    try await prepared.perform(redo, runner: runner, output: output, pushes: log)

                    switch prepared.confirmed(by: log) {
                    case .inverse(let inverse):
                        await history.finishRedo(
                            entry,
                            change: .inverse(prepare: prepare, action: action, target: target, inverse: inverse)
                        )

                    case .unchanged:
                        await history.finishRedo(entry, change: nil)

                    case .unavailable:
                        await history.recordIrreversible(entry.title)
                    }
                },
                title: title,
                target: target,
                undo: .unrecorded
            ) { [weak self] in
                if let self {
                    inverse.afterRedo?(self)
                }
            }
        }
    }

    /// 按声明包装写操作：可撤销的操作前后各记一次状态，连同移进废纸篓的项成功改动仓库后登记；
    /// 给出反向操作的在操作之前准备，成功后按推送结果核对再登记；不能撤销的操作成功后清空撤销栈。
    ///
    /// 操作前有进行中的操作或冲突、操作后停在进行中的状态、删掉的未跟踪文件找不回内容，
    /// 或移进废纸篓的项不知道位置时，都按不能撤销处理。
    ///
    /// - Parameter target: 操作记在 Activity 的 Remote 页的对象，随反向操作记录保存，重做时记在同一页。
    func recordingUndo(
        _ action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        target: ActivityTarget?,
        recording: UndoRecording
    ) -> @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void {
        guard let history = undoHistory else {
            return action
        }

        switch recording {
        case .unrecorded:
            return action

        case .irreversible:
            return { runner, output in
                try await action(runner, output)
                await history.recordIrreversible(title)
            }

        case .inverse(let prepare):
            // 准备在操作之前读出撤销要用的内容，操作成功后按准备与推送的结果登记
            return { runner, output in
                let prepared = await PreparedInverse(prepare, runner: runner)
                let log = PushLog()
                try await prepared.perform(action, runner: runner, output: output, pushes: log)

                switch prepared.confirmed(by: log) {
                case .inverse(let inverse):
                    await history.record(
                        RepositoryUndoEntry(
                            title: title,
                            change: .inverse(prepare: prepare, action: action, target: target, inverse: inverse)
                        )
                    )

                case .unchanged:
                    break

                case .unavailable:
                    await history.recordIrreversible(title)
                }
            }

        case .reversible:
            return recordingSnapshots(action, title: title, target: target, asksToStash: false, history: history)

        case .reversibleAskingToStash:
            return recordingSnapshots(action, title: title, target: target, asksToStash: true, history: history)
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

    /// 撤销重置前工作区有已跟踪文件的改动、且设置开启时，询问是否储藏：储藏时先储藏再回到重置前，不储藏时直接回到重置前；
    /// Abort 不撤销，记录留在栈里。撤销成功后才把记录移到重做栈。
    ///
    /// - Returns: 是否已转为询问。
    private func askToStashBeforeUndo(_ entry: RepositoryUndoEntry, in history: RepositoryUndoHistory) -> Bool {
        let modified = status?.entries.contains { $0.kind == .tracked } ?? false

        guard
            entry.asksToStash,
            modified,
            Self.offersAutoStash,
            let onStashRequest,
            case .snapshot(let before, let after, _) = entry.change
        else { return false }

        let title = UndoManager().undoMenuTitle(forUndoActionName: entry.title)

        // 给出储藏说明时先储藏再恢复，新储藏保留在储藏列表里
        let restore = { @Sendable (runner: GitRunner, stash: String?) in
            let undo = RepositoryUndo(runner: runner)

            if let stash {
                try await undo.restore(before, expecting: after, message: "undo", stashing: stash)
            } else {
                try await undo.restore(before, expecting: after, message: "undo")
            }

            await history.finishUndo(entry)
        }

        let request = AutoStashRequest(
            title: title,
            error: nil,
            action: { runner, _ in try await restore(runner, nil) },
            undo: .unrecorded,
            keepsStash: true,
            stashing: { [weak self] message in
                self?.performGit({ runner, _ in try await restore(runner, message) }, title: title, undo: .unrecorded)
                    ?? false
            }
        )

        onStashRequest(.autoStash(request))
        return true
    }

    /// 可撤销的操作前后各记一次状态，连同移进废纸篓的项成功改动仓库后登记；操作单独记下的部分各记一步，
    /// 改写了名称时按改写后的名称登记。合并与反转停在冲突上时记成放弃它的反向操作。
    ///
    /// - Parameter asksToStash: 撤销时工作区有已跟踪文件的改动，先询问是否储藏；记在最后一步上。
    private func recordingSnapshots(
        _ action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        target: ActivityTarget?,
        asksToStash: Bool,
        history: RepositoryUndoHistory
    ) -> @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void {
        { runner, output in
            let undo = RepositoryUndo(runner: runner)
            let before = try? await undo.capture()
            let log = TrashLog()

            let recording = SnapshotRecording(
                action: action,
                title: title,
                target: target,
                asksToStash: asksToStash,
                steps: UndoSteps(),
                undo: undo
            )

            do {
                try await UndoSteps.$current.withValue(recording.steps) {
                    try await TrashLog.$current.withValue(log) { try await action(runner, output) }
                }
            } catch {
                // 停在冲突上的反转以失败结束，同样记成放弃它的反向操作，失败照常报告
                if before != nil, let entry = await recording.stopped() {
                    await history.record(entry)
                }

                throw error
            }

            guard let entries = await recording.entries(before: before, trashed: log.items) else {
                await history.recordIrreversible(recording.name)
                return
            }

            for entry in entries {
                await history.record(entry)
            }
        }
    }
}

// MARK: - SnapshotRecording

/// 一次按快照记录撤销的写操作：结束后把前后状态与中间单独记下的状态切成各步撤销记录。
private struct SnapshotRecording {
    /// 写操作本身，停在冲突上的合并与反转重做时再执行它。
    let action: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void

    /// 写操作的名称。
    let title: String

    /// 写操作记在 Activity 的 Remote 页的对象，重做时记在同一页。
    let target: ActivityTarget?

    /// 撤销最后一步时工作区有已跟踪文件的改动，先询问是否储藏。
    let asksToStash: Bool

    /// 操作执行中对撤销记录的说明。
    let steps: UndoSteps

    /// 读取与核对仓库状态。
    let undo: RepositoryUndo

    /// 最后一步的名称：操作改写过时用改写后的。
    var name: String {
        steps.title ?? title
    }

    /// 操作成功结束后的撤销记录，按先后排列：没有改动仓库时为空，撤销不了时为 nil。
    ///
    /// 操作前有进行中的操作、操作后停在进行中的状态（停在冲突上的合并与反转除外）、
    /// 或移进废纸篓的项不知道位置时，都撤销不了。
    ///
    /// - Parameters:
    ///   - before: 操作前的状态；读不到时为 nil。
    ///   - trashed: 整个操作移进废纸篓的项。
    func entries(before: RepositoryState?, trashed: [TrashedItem]) async -> [RepositoryUndoEntry]? {
        guard let before else {
            return nil
        }

        // 停在进行中的状态时，只有停在冲突上的合并与反转能撤销
        guard let after = try? await undo.capture() else {
            guard steps.marks.isEmpty else {
                return nil
            }

            return await stopped().map { [$0] }
        }

        // 废纸篓命令没有报告位置的项移不回来
        guard trashed.allSatisfy({ $0.location != nil }) else {
            return nil
        }

        return await split(from: before, to: after, trashed: trashed)
    }

    /// 合并或反转停在冲突上时的撤销记录：撤销是放弃它；重做时再执行一次原操作，再次停在冲突上不算失败。
    /// 没有停在冲突上时为 nil。
    func stopped() async -> RepositoryUndoEntry? {
        guard let operation = try? await undo.stoppedOperation() else {
            return nil
        }

        let action = action

        let inverse = UndoInverse(
            abortedOperation: operation,
            undo: { runner, _ in try await RepositoryUndo(runner: runner).abort(operation) },
            redo: { runner, output in
                do {
                    try await action(runner, output)
                } catch {
                    guard (try? await RepositoryUndo(runner: runner).stoppedOperation()) == operation else {
                        throw error
                    }
                }
            }
        )

        return RepositoryUndoEntry(
            title: name,
            change: .inverse(prepare: { _ in inverse }, action: action, target: target, inverse: inverse)
        )
    }

    /// 把前后状态按中间单独记下的状态切成各步，按先后排列；没有改动仓库的步不记，有一步撤销不了时为 nil。
    ///
    /// - Parameter trashed: 整个操作移进废纸篓的项，按单独记下时的项数分给各步。
    private func split(
        from before: RepositoryState,
        to after: RepositoryState,
        trashed: [TrashedItem]
    ) async -> [RepositoryUndoEntry]? {
        let marks = steps.marks
        let middle = marks.compactMap(\.state)

        // 中间有读不到的状态时撤销不了
        guard middle.count == marks.count else {
            return nil
        }

        let states = [before] + middle + [after]
        let titles = marks.map(\.title) + [name]
        let bounds = [0] + marks.map(\.trashed) + [trashed.count]
        var entries: [RepositoryUndoEntry] = []

        for index in titles.indices where states[index] != states[index + 1] {
            let items = Array(trashed[bounds[index] ..< bounds[index + 1]])

            let restorable =
                (try? await undo.canRestore(states[index], from: states[index + 1], trashed: items)) ?? false

            guard restorable else {
                return nil
            }

            entries.append(
                RepositoryUndoEntry(
                    title: titles[index],
                    change: .snapshot(before: states[index], after: states[index + 1], trashed: items),
                    asksToStash: asksToStash && index == titles.count - 1
                )
            )
        }

        return entries
    }
}

// MARK: - PreparedInverse

/// 在原操作之前执行准备闭包的结果，原操作成功后据此登记。
private enum PreparedInverse {
    /// 读出了反向操作。
    case inverse(UndoInverse)

    /// 这次操作不改动要撤销的内容。
    case unchanged

    /// 准备失败，这次操作撤销不了。
    case unavailable

    /// 执行准备闭包；失败不抛出，原操作照常执行。
    init(_ prepare: @Sendable (GitRunner) async throws -> UndoInverse?, runner: GitRunner) async {
        do {
            self = try await prepare(runner).map(Self.inverse) ?? .unchanged
        } catch {
            self = .unavailable
        }
    }

    /// 执行原操作：推送的逐条结果记进 `log`；反向操作带着废纸篓记录时，原操作移进废纸篓的项记进它。
    func perform(
        _ action: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        runner: GitRunner,
        output: @escaping @Sendable (GitOutputEvent) -> Void,
        pushes log: PushLog
    ) async throws {
        let trashLog: TrashLog? =
            if case .inverse(let inverse) = self {
                inverse.trashLog
            } else {
                nil
            }

        try await TrashLog.$current.withValue(trashLog) {
            try await PushLog.$current.withValue(log) { try await action(runner, output) }
        }
    }

    /// 原操作结束后核对：移进废纸篓的项有的不知道位置时撤销不了；反向操作要撤销的是推送新建的引用时，
    /// 推送确实新建了它才保留，已是最新算作没有改动，更新了远端已有的引用或没有推送它都撤销不了。
    func confirmed(by log: PushLog) -> Self {
        guard case .inverse(let inverse) = self else {
            return self
        }

        // 废纸篓命令没有报告位置的项移不回来
        if let trashed = inverse.trashLog?.items, trashed.contains(where: { $0.location == nil }) {
            return .unavailable
        }

        guard let pushed = inverse.pushedReference else {
            return self
        }

        switch log.result(of: pushed.reference, on: pushed.remote) {
        case .created: return self
        case .upToDate: return .unchanged
        case .updated, nil: return .unavailable
        }
    }
}
