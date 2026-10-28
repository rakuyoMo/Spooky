import Foundation
import SpookyKit

// MARK: - Conflicts

extension RepositorySession {
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

    /// 进行中操作横幅的标题；摘取与反转按序列里尚未完成的提交数说明。
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

    /// 恢复冲突版本直接执行，不经确认：只改工作区，索引里的冲突保持不变。
    ///
    /// - Parameters:
    ///   - entries: 要恢复的文件。
    ///   - version: 恢复到的版本。
    ///   - title: 已本地化的操作名称，用作中断报告。
    func restoreConflicts(_ entries: [StatusEntry], to version: ConflictVersion, title: String) {
        guard canRestoreConflicts(entries, to: version) else { return }

        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).restoreConflicts(entries, to: version)
            },
            title: title,
            recordsActivity: false
        )
    }
}

// MARK: - Private

extension RepositorySession {
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
