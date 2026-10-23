import Foundation
import SpookyKit

// MARK: - StashRequest

/// 储藏入口交给窗口呈现的对话框请求。
enum StashRequest {
    /// 保存储藏或快照；文件为空表示全部本地改动。
    case save(snapshot: Bool, entries: [StatusEntry])

    /// 应用储藏，可预选其中一个。
    case apply(StashEntry?)

    /// 检出、拉取或合并被本地改动挡住后，询问是否先储藏。
    case autoStash(AutoStashRequest)
}

// MARK: - AutoStashRequest

/// 被本地改动挡住的写操作；用户选择储藏后原样重新执行。
struct AutoStashRequest {
    /// 已本地化的操作名称。
    let title: String

    /// 原操作的失败；用户选择不储藏时照常报告。
    let error: any Error

    /// 原操作的执行闭包。
    let action: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void
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

    /// 删除始终确认，确认说明写明改动会丢失。
    func deleteStashes(_ selected: [StashEntry]) {
        guard canDelete(selected), let first = selected.first else { return }
        let repository = repository
        let single = selected.count == 1

        onConfirm?(
            AppLocalization.text(single ? "stash.delete" : "stash.deleteStashes"),
            single
                ? AppLocalization.text("stash.delete.confirm", first.title)
                : AppLocalization.text("stash.deleteStashes.confirm", selected.count),
            { [weak self] in
                guard let self, self.repository == repository else { return }

                performGit(
                    { runner, _ in try await RepositoryStashes(runner: runner).drop(selected) },
                    title: AppLocalization.text(single ? "stash.delete" : "stash.deleteStashes")
                )
            },
            nil
        )
    }

    /// 只把储藏里的一个文件套用到工作区，补丁按储藏哈希生成。
    func applyStashFile(_ change: StashFileChange, from stash: StashEntry) {
        guard canApply(stash) else { return }

        performGit(
            { runner, _ in try await RepositoryStashes(runner: runner).apply(change, from: stash) },
            title: AppLocalization.text("stash.applyFile")
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
            title: title
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
            title: AppLocalization.text("stash.apply")
        )
    }
}

// MARK: - Auto Stash

extension RepositorySession {
    /// 检出、拉取与合并被本地改动挡住：Spooky 发起前的干净工作区检查，或 Git 拒绝覆盖未提交的改动。
    static func isBlockedByLocalChanges(_ error: any Error) -> Bool {
        if let sync = error as? RepositorySyncError {
            return sync == .dirtyWorkingCopy
        }

        return (error as? GitError)?.category == .localChanges
    }

    /// 写操作被本地改动挡住时按设置询问是否先储藏；返回是否已转为询问，未询问时调用方照常报告失败。
    func offerAutoStash(
        after error: any Error,
        title: String,
        action: @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void
    ) -> Bool {
        // 设置 “Always offer to stash local changes” 默认开启
        let enabled = UserDefaults.standard.object(forKey: "offerAutoStash") as? Bool ?? true
        guard enabled, Self.isBlockedByLocalChanges(error), let onStashRequest else { return false }

        onStashRequest(.autoStash(AutoStashRequest(title: title, error: error, action: action)))
        return true
    }

    /// 先储藏全部本地改动，再重新执行原操作，按选择恢复；任何一步失败都保留储藏并说明原因。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func performAutoStash(_ request: AutoStashRequest, message: String, reapply: Bool) -> Bool {
        let action = request.action

        return performGit(
            { runner, output in
                try await RepositoryStashes(runner: runner)
                    .stashingLocalChanges(message: message, reapply: reapply) {
                        try await action(runner, output)
                    }
            },
            title: request.title
        )
    }

    /// 用户选择不储藏：照常报告原操作被挡住的失败。
    func declineAutoStash(_ request: AutoStashRequest) {
        onFailure?(AppFailure(error: request.error, opening: false, location: repository, writing: true))
    }
}
