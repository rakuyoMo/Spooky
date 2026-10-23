import Foundation
import SpookyKit

// MARK: - Conflicts

extension RepositorySession {
    /// 保留冲突备份文件的全局偏好：开启后，冲突向导覆盖冲突文件之前先把它另存为同目录的 `.orig` 文件。
    static let keepsConflictBackupsKey = "keepConflictBackups"

    /// 当前仓库在本窗口中由冲突向导生成、尚未清理的备份文件。
    var currentConflictBackups: [String] {
        repository.flatMap { conflictBackups[$0] } ?? []
    }

    /// 进行中的操作里已经解决的冲突数：有 resolve-undo 记录、当前不再是冲突的文件。
    var resolvedConflictCount: Int {
        let conflicted = Set(status?.entries.filter { $0.kind == .conflicted }.map(\.path) ?? [])
        return context?.progress?.resolvedPaths.subtracting(conflicted).count ?? 0
    }

    /// 我方的显示名：变基时是被变基到的提交，其余是当前 HEAD。
    var oursName: String {
        displayName(of: context?.progress?.ours ?? status?.branch.oid)
    }

    /// 对方的显示名；没有进行中的操作时，冲突来自应用补丁或储藏。
    var theirsName: String {
        guard let progress = context?.progress else {
            return AppLocalization.text("conflict.applied")
        }

        // 变基的对方是正在变基的分支，分支名比 orig-head 指向的提交更准确
        if let branch = progress.branch {
            return branch.hasPrefix("refs/heads/") ? String(branch.dropFirst("refs/heads/".count)) : branch
        }

        return displayName(of: progress.theirs)
    }

    /// 工作区状态头在进行中操作时的文字，如 “Merging side into main”；没有进行中的操作时为 nil。
    var operationHeaderTitle: String? {
        guard let progress = context?.progress else {
            return nil
        }

        switch progress.state {
        case .merge: return AppLocalization.text("conflict.header.merge", theirsName, oursName)
        case .squash: return AppLocalization.text("conflict.header.squash", oursName)
        case .rebase: return AppLocalization.text("conflict.header.rebase", theirsName, oursName)
        case .cherryPick: return AppLocalization.text("conflict.header.cherryPick", theirsName, oursName)
        case .revert: return AppLocalization.text("conflict.header.revert", theirsName, oursName)
        }
    }

    /// 进行中操作横幅的标题；摘取与反转按序列的提交数说明。
    var operationBannerTitle: String? {
        guard let progress = context?.progress else {
            return nil
        }

        let count = progress.stepCount ?? 1

        switch progress.state {
        case .merge: return AppLocalization.text("conflict.title.merge", theirsName, oursName)

        case .squash: return AppLocalization.text("conflict.title.squash", oursName)

        case .rebase: return AppLocalization.text("conflict.title.rebase", theirsName, oursName)

        case .cherryPick:
            return count == 1
                ? AppLocalization.text("conflict.title.cherryPick.one", oursName)
                : AppLocalization.text("conflict.title.cherryPick", count, oursName)

        case .revert:
            return count == 1
                ? AppLocalization.text("conflict.title.revert.one", oursName)
                : AppLocalization.text("conflict.title.revert", count, oursName)
        }
    }

    /// 读取冲突向导显示的三方原文与工作区文件。
    func conflictContents(of entry: StatusEntry) async throws -> ConflictContents {
        guard let runner else {
            throw CancellationError()
        }

        return try await WorkingCopyOperations(runner: runner).conflictContents(of: entry)
    }

    /// 所选文件中有可以恢复到指定版本的冲突；重新生成冲突也适用于已经标记解决的文件。
    func canRestoreConflicts(_ entries: [StatusEntry], to version: ConflictVersion) -> Bool {
        guard canWrite else {
            return false
        }

        let resolved = context?.progress?.resolvedPaths ?? []

        return entries.contains { entry in
            switch version {
            case .unmerged: entry.kind == .conflicted || resolved.contains(entry.path)
            case .ours: entry.conflict?.ours != nil
            case .theirs: entry.conflict?.theirs != nil
            case .base: entry.conflict?.base != nil
            }
        }
    }

    /// 恢复会覆盖工作区里的文件，确认时写明数量与所在机器，关闭确认后才开始写入。
    ///
    /// - Parameters:
    ///   - entries: 要恢复的文件。
    ///   - version: 恢复到的版本。
    ///   - title: 已本地化的操作名称，用作确认按钮与中断报告。
    func restoreConflicts(_ entries: [StatusEntry], to version: ConflictVersion, title: String) {
        guard canRestoreConflicts(entries, to: version) else { return }

        let request = generation
        let backup = conflictBackupRecorder()

        let message = AppLocalization.text(
            repository?.host == nil ? "conflict.restore.message" : "conflict.restore.remote",
            entries.count,
            repository?.displayPath ?? ""
        )

        onConfirm?(
            title,
            message,
            { [weak self] in
                guard let self, generation == request else { return }

                performGit(
                    { runner, _ in
                        try await WorkingCopyOperations(runner: runner)
                            .restoreConflicts(entries, to: version, backup: backup)
                    },
                    title: title,
                    recordsActivity: false
                )
            },
            nil
        )
    }

    /// 把手动编辑的结果写回冲突文件；文件在载入之后被改动时由核心库拒绝写入。
    ///
    /// - Parameters:
    ///   - text: 编辑后的完整内容，按 UTF-8 写回。
    ///   - entry: 冲突文件。
    ///   - expected: 载入时读到的工作区内容。
    ///   - saved: 写入成功后执行，向导据此重新载入。
    func saveConflictResolution(
        _ text: String,
        for entry: StatusEntry,
        replacing expected: Data?,
        saved: @escaping () -> Void
    ) {
        let backup = conflictBackupRecorder()

        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner)
                    .saveResolution(Data(text.utf8), for: entry, replacing: expected, backup: backup)
            },
            title: AppLocalization.text("conflict.save"),
            recordsActivity: false,
            success: saved
        )
    }

    /// 删除向导生成的备份文件是永久删除，确认时写明数量与所在机器。
    func removeConflictBackups() {
        let backups = currentConflictBackups

        guard canWrite, let repository, !backups.isEmpty else { return }

        let request = generation
        let title = AppLocalization.text("conflict.removeBackups")

        let message = AppLocalization.text(
            repository.host == nil ? "conflict.removeBackups.message" : "conflict.removeBackups.remote",
            backups.count,
            repository.displayPath
        )

        onConfirm?(
            title,
            message,
            { [weak self] in
                guard let self, generation == request else { return }

                performGit(
                    { runner, _ in
                        try await WorkingCopyOperations(runner: runner).removeBackups(backups)
                    },
                    title: title,
                    recordsActivity: false
                ) { [weak self] in
                    self?.conflictBackups[repository]?.removeAll { backups.contains($0) }
                }
            },
            nil
        )
    }

    /// 偏好开启时返回记录备份路径的回调；备份在写入之前生成，写入失败也会留下记录。
    func conflictBackupRecorder() -> (@Sendable ([String]) async -> Void)? {
        guard UserDefaults.standard.bool(forKey: Self.keepsConflictBackupsKey), let repository else {
            return nil
        }

        return { [weak self] paths in
            await self?.recordConflictBackups(paths, in: repository)
        }
    }
}

// MARK: - Private

extension RepositorySession {
    /// 按仓库记下新建的备份；写入期间切换了仓库也记在原仓库名下，切回来仍能看到。
    private func recordConflictBackups(_ paths: [String], in repository: RepositoryLocation) {
        guard !paths.isEmpty else { return }
        conflictBackups[repository, default: []].append(contentsOf: paths)
    }

    /// 提交的显示名：当前分支、指向它的本地分支、远端分支或标签，都没有时用短哈希。
    private func displayName(of commit: String?) -> String {
        guard let commit else {
            return AppLocalization.text("branch.noHead")
        }

        if commit == status?.branch.oid, let head = status?.branch.head {
            return head
        }

        let references = history.snapshot?.references.filter { $0.objectID == commit && $0.symbolicTarget == nil } ?? []

        let preferred = references.first(where: \.isLocal)
            ?? references.first(where: \.isRemote)
            ?? references.first { $0.id.hasPrefix("refs/tags/") }

        return preferred?.name ?? String(commit.prefix(8))
    }
}
