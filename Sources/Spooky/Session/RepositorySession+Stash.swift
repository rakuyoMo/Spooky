import Foundation
import SpookyKit

// MARK: - StashRequest

/// 储藏入口交给窗口呈现的对话框请求。
enum StashRequest {
    /// 保存储藏或快照；文件为空表示全部本地改动。
    case save(snapshot: Bool, entries: [StatusEntry])

    /// 应用储藏，可预选其中一个。
    case apply(StashEntry?)

    /// 检出、拉取或合并被本地改动挡住后，或检出、修补旧提交开始前有本地改动时，询问是否先储藏。
    case autoStash(AutoStashRequest)
}

// MARK: - AutoStashRequest

/// 被本地改动挡住、或开始前就有本地改动的写操作；用户选择储藏后原样执行。
struct AutoStashRequest {
    /// 已本地化的操作名称。
    let title: String

    /// 原操作的整页进度标题，重新执行时沿用；不占用工作区的操作为 nil。
    var progress: String? = nil

    /// 开始前询问的检出在 Activity 里连接的对象，执行时沿用。
    var target: ActivityTarget? = nil

    /// 原操作的失败；用户选择不储藏时照常报告。开始前询问时为 nil。
    let error: (any Error)?

    /// 原操作的执行闭包。
    let action: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void

    /// 原操作失败时补在错误说明前的一段话，储藏后重新执行时沿用。
    var failureNote: (() -> String?)? = nil

    /// 原操作能否撤销；储藏、重新执行与恢复储藏合起来按同一声明记录。
    var undo = UndoRecording.irreversible

    /// 储藏一直保留，对话框不提供完成后恢复；修补旧提交与撤销重置使用。
    var keepsStash = false

    /// 选择储藏时由操作自己储藏并执行，代替先储藏、再执行 `action`；参数是储藏说明，返回是否已开始执行。撤销重置使用。
    var stashing: ((_ message: String) -> Bool)? = nil

    /// 排进队列的检出轮到时才询问，询问期间占着的轮次；答复后在它上面执行，中止时连同它一起取消。点的时候询问的为 nil。
    var turn: RepositoryWrite? = nil
}

// MARK: - Availability

extension RepositorySession {
    /// 保存储藏需要已有提交、存在本地改动且没有未解决的冲突。
    var canSaveStash: Bool {
        canStash(status?.entries ?? [])
    }

    /// 应用储藏需要至少一个储藏，且工作区没有未解决的冲突。
    var canApplyStash: Bool {
        canWrite && conflictCount == 0 && !stashes.entries.isEmpty
    }

    /// 储藏所选文件需要 HEAD 已有提交，且所选文件都不在冲突中。
    func canStash(_ entries: [StatusEntry]) -> Bool {
        canWrite && status?.branch.oid != nil && !entries.isEmpty
            && !entries.contains { $0.kind == .conflicted || $0.kind == .ignored }
    }

    /// 应用指定储藏或其中的文件。
    func canApply(_ stash: StashEntry) -> Bool {
        canWrite && conflictCount == 0 && stashes.entries.contains { $0.id == stash.id }
    }

    /// 删除所选储藏。
    func canDelete(_ stashes: [StashEntry]) -> Bool {
        canWrite && !stashes.isEmpty
    }
}

// MARK: - Stash Entries

extension RepositorySession {
    /// 菜单、工具栏、右键与拖放共用的保存入口；快速版本跳过对话框，以 Git 生成的说明直接保存。
    ///
    /// - Parameters:
    ///   - snapshot: 是否保留工作区。
    ///   - entries: 部分储藏的文件；为空表示全部本地改动。
    ///   - quick: 是否跳过对话框。
    func requestSaveStash(snapshot: Bool, entries: [StatusEntry] = [], quick: Bool = false) {
        guard entries.isEmpty ? canSaveStash : canStash(entries) else { return }

        // 快速版本沿用对话框记住的 “包含未跟踪文件” 选项；部分储藏总是带上所选的未跟踪文件
        if quick {
            let untracked = UserDefaults.standard.bool(forKey: "stashIncludeUntracked")
            saveStash(snapshot: snapshot, message: "", includeUntracked: untracked, entries: entries)
        } else {
            onStashRequest?(.save(snapshot: snapshot, entries: entries))
        }
    }

    /// 应用储藏的对话框入口，可预选一个储藏。
    func requestApplyStash(_ stash: StashEntry? = nil) {
        guard canApplyStash else { return }
        onStashRequest?(.apply(stash))
    }

    /// 删除始终确认。
    func deleteStashes(_ selected: [StashEntry]) {
        guard canDelete(selected), let first = selected.first else { return }
        let repository = repository
        let single = selected.count == 1

        // 标题与主按钮相同，也是 Activity 与撤销记录的名称
        let title = AppLocalization.text(single ? "stash.delete" : "stash.deleteStashes")
        let message = single
            ? AppLocalization.text("stash.delete.confirm", first.title)
            : AppLocalization.text("stash.deleteStashes.confirm", selected.count)

        onConfirm?(ConfirmationRequest(
            title: title,
            message: message,
            submitTitle: title
        ) { [weak self] in
            guard let self, self.repository == repository else { return }

            performGit(
                { runner, _ in try await RepositoryStashes(runner: runner).drop(selected) },
                title: title,
                touchesWorkingCopy: false,
                undo: .reversible,
                available: { $0.canDelete(selected) }
            )
        })
    }

    /// 只把储藏里的一个文件套用到工作区，补丁按储藏哈希生成。
    func applyStashFile(_ change: StashFileChange, from stash: StashEntry) {
        guard canApply(stash) else { return }

        performGit(
            { runner, _ in try await RepositoryStashes(runner: runner).apply(change, from: stash) },
            title: AppLocalization.text("stash.applyFile"),
            undo: .reversible,
            available: { $0.canApply(stash) }
        )
    }

    /// 保存储藏或快照；部分储藏总是带上所选的未跟踪文件。
    ///
    /// - Returns: 是否已开始执行；仓库不可写时不启动，对话框据此保持打开。
    @discardableResult
    func saveStash(snapshot: Bool, message: String, includeUntracked: Bool, entries: [StatusEntry]) -> Bool {
        let selection = entries.isEmpty ? nil : entries
        let untracked = selection == nil ? includeUntracked : true
        let title = AppLocalization.text(snapshot ? "stash.snapshot" : "stash.save")

        return performGit(
            { runner, _ in
                let stashes = RepositoryStashes(runner: runner)

                if snapshot {
                    try await stashes.snapshot(message: message, includeUntracked: untracked, entries: selection)
                } else {
                    try await stashes.save(message: message, includeUntracked: untracked, entries: selection)
                }
            },
            title: title,
            undo: .reversible,
            available: { session in entries.isEmpty ? session.canSaveStash : session.canStash(entries) }
        )
    }

    /// 应用或 Pop 一个储藏；冲突时储藏保留，冲突留给工作区处理。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func applyStash(_ stash: StashEntry, restoreIndex: Bool, drop: Bool) -> Bool {
        performGit(
            { runner, _ in
                try await RepositoryStashes(runner: runner).apply(stash, restoreIndex: restoreIndex, drop: drop)
            },
            title: AppLocalization.text("stash.apply"),
            undo: .reversible,
            available: { $0.canApply(stash) }
        )
    }
}

// MARK: - Auto Stash

extension RepositorySession {
    /// 检出、拉取与合并被本地改动挡住：Spooky 发起前的干净工作区检查，或 Git 拒绝覆盖未提交的改动。
    static func isBlockedByLocalChanges(_ error: any Error) -> Bool {
        if case .dirtyWorkingCopy = error as? RepositorySyncError {
            return true
        }

        return (error as? GitError)?.category == .localChanges
    }

    /// 写操作被本地改动挡住时按设置询问是否先储藏；返回是否已转为询问，未询问时调用方照常报告失败。
    ///
    /// 在失败的写操作结束之前调用，重新执行时沿用它此刻的整页进度标题。
    func offerAutoStash(
        after error: any Error,
        title: String,
        action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        failureNote: (() -> String?)? = nil,
        undo: UndoRecording = .irreversible
    ) -> Bool {
        guard Self.offersAutoStash, Self.isBlockedByLocalChanges(error), let onStashRequest else { return false }

        let request = AutoStashRequest(
            title: title,
            progress: workspaceProgress?.title,
            error: error,
            action: action,
            failureNote: failureNote,
            undo: undo
        )
        onStashRequest(.autoStash(request))
        return true
    }

    /// 检出别的分支或版本：工作区有已跟踪文件的修改时按设置先询问是否储藏，修改不妨碍检出时也问；
    /// 询问的内容与选项和 Git 拒绝检出后的相同，不储藏时照常检出。其余情况直接检出，被本地改动挡住后再询问。
    ///
    /// 询问在下一轮主线程呈现：从对话框发起时，对话框在这一轮关闭。仓库正有写操作时不在点的时候询问，
    /// 检出排进队列，轮到时按那时的状态再判断。
    ///
    /// - Parameters:
    ///   - action: 检出的执行闭包。
    ///   - title: 已本地化的操作名称。
    ///   - progress: 整页进度的标题。
    ///   - target: 要连接远端的检出传入连接的对象，记在 Activity 的 Remote 页。
    ///   - offersAutoStash: 没有先询问、执行时被本地改动挡住后是否再询问；先建分支再检出的写入重新执行会因分支已存在而失败，
    ///     不再询问。
    ///   - undo: 这次检出能否撤销。
    ///   - available: 排队后轮到时的核对，以本会话调用入口所用的同一条 `can…` 规则。
    /// - Returns: 是否已开始执行、已排进队列或已转为询问；仓库不可写时为 false。
    @discardableResult
    func performCheckout(
        _ action:
        @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        progress: String,
        target: ActivityTarget? = nil,
        offersAutoStash: Bool = true,
        undo: UndoRecording = .reversible,
        available: (@MainActor (RepositorySession) -> Bool)? = nil
    ) -> Bool {
        let modified = status?.entries.contains { $0.kind == .tracked } ?? false
        let idle = repository.map(RepositoryWriteQueue.shared.isIdle) ?? true

        guard canWrite, idle, modified, Self.offersAutoStash, onStashRequest != nil else {
            return performGit(
                action,
                title: title,
                progress: progress,
                target: target,
                offersAutoStash: offersAutoStash,
                undo: undo,
                available: available,
                asksToStash: true
            )
        }

        let request = AutoStashRequest(
            title: title,
            progress: progress,
            target: target,
            error: nil,
            action: action,
            undo: undo
        )

        let repository = repository

        Task { @MainActor [weak self] in
            guard let self, self.repository == repository else { return }

            onStashRequest?(.autoStash(request))
        }

        return true
    }

    /// 先储藏全部本地改动，再重新执行原操作，按选择恢复；任何一步失败都保留储藏并说明原因。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func performAutoStash(_ request: AutoStashRequest, message: String, reapply: Bool) -> Bool {
        if let stashing = request.stashing {
            return stashing(message)
        }

        let action = request.action

        return performGit(
            { runner, output in
                try await RepositoryStashes(runner: runner)
                    .stashingLocalChanges(message: message, reapply: reapply) {
                        try await action(runner, output)
                    }
            },
            title: request.title,
            progress: request.progress,
            target: request.target,
            undo: request.undo,
            failureNote: request.failureNote,
            turn: request.turn
        )
    }

    /// 用户选择不储藏：开始前询问的操作直接执行，Git 因本地改动拒绝时只报告这一次；其余照常报告原操作被挡住的失败。
    func declineAutoStash(_ request: AutoStashRequest) {
        guard let error = request.error else {
            performGit(
                request.action,
                title: request.title,
                progress: request.progress,
                target: request.target,
                undo: request.undo,
                failureNote: request.failureNote,
                turn: request.turn
            )
            return
        }

        onFailure?(AppFailure(error: error, opening: false, location: repository, writing: true))
    }

    /// 排进队列的检出轮到时，按刷新后的状态判断要不要先询问储藏：有已跟踪文件的修改且设置要求询问时，带着轮次呈现询问。
    ///
    /// - Parameters:
    ///   - operation: 轮到的检出。
    ///   - turn: 检出占着的轮次，答复后在它上面执行。
    /// - Returns: 是否已呈现询问；为 false 时调用方直接执行。
    func askToStash(before operation: GitWriteOperation, holding turn: RepositoryWrite) -> Bool {
        let modified = status?.entries.contains { $0.kind == .tracked } ?? false

        guard modified, Self.offersAutoStash, let onStashRequest else {
            return false
        }

        let request = AutoStashRequest(
            title: operation.title,
            progress: operation.progress,
            target: operation.target,
            error: nil,
            action: operation.action,
            failureNote: operation.failureNote,
            undo: operation.undo,
            turn: turn
        )

        onStashRequest(.autoStash(request))
        return true
    }
}

// MARK: - Helpers

extension RepositorySession {
    /// 设置 “Always offer to stash local changes”，默认开启。
    static var offersAutoStash: Bool {
        UserDefaults.standard.object(forKey: "offerAutoStash") as? Bool ?? true
    }
}
