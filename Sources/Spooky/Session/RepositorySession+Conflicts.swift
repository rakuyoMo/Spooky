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

    /// 进行中操作横幅的标题；摘取与反转按序列里尚未完成的提交数说明，停在 edit 上时写正在修改的提交与原分支。
    var operationBannerTitle: String? {
        guard let progress = context?.progress else {
            return nil
        }

        let count = progress.stepCount ?? 1

        switch progress.state {
        case .merge: return AppLocalization.text("conflict.title.merge", theirsName, oursName)

        case .squash: return AppLocalization.text("conflict.title.squash", oursName)

        case .rebase:
            // 变基的对方就是原分支
            if let edited = progress.editedCommit {
                return AppLocalization.text("conflict.title.edit", String(edited.prefix(8)), theirsName)
            }

            return AppLocalization.text("conflict.title.rebase", theirsName, oursName)

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

    /// 序列的进度行：第几步、共几步，加上当前一步的动作与提交标题；不是序列或 Git 没有记下步数时为 nil。
    var operationStepText: String? {
        guard
            let progress = context?.progress, progress.isSequence,
            let step = progress.step, let count = progress.stepCount
        else {
            return nil
        }

        guard let subject = progress.stepSubject else {
            return AppLocalization.text("conflict.step", step, count)
        }

        let key =
            switch progress.stepKind {
            case .editing: "conflict.step.editing"
            case .reverting: "conflict.step.reverting"
            case .applying, nil: "conflict.step.applying"
            }

        return AppLocalization.text(key, step, count, subject)
    }

    /// 工作区没有任何改动：暂存、未暂存、冲突与未跟踪的文件都算改动；还没读到状态时不算空。
    var isWorkingCopyClean: Bool {
        guard let entries = status?.entries else {
            return false
        }

        return !entries.contains { [.tracked, .conflicted, .untracked].contains($0.kind) }
    }

    /// 提交区的主按钮继续序列：变基与摘取、反转的序列；停在 edit 上时提交当前修订，合并与单个提交的操作用 Commit 收尾。
    var continuesSequence: Bool {
        guard let progress = context?.progress else {
            return false
        }

        return progress.isSequence && !progress.stopsForEdit
    }

    /// 显示提交区：进行中的操作还有未解决冲突或交互式变基尚未开始时隐藏。
    ///
    /// 储藏恢复这类没有进行中操作的冲突照常显示，由提交的可用性拒绝带着冲突提交。
    var showsCommitArea: Bool {
        guard let progress = context?.progress else {
            return true
        }

        return conflictCount == 0 && !progress.isPendingInteractive
    }

    /// 横幅提供 Skip：序列里这一步没有任何改动、不在 edit 步，且变基已经开始处理提交。
    var offersSkip: Bool {
        guard let progress = context?.progress else {
            return false
        }

        return progress.isSequence
            && isWorkingCopyClean
            && !progress.stopsForEdit
            && !progress.isPendingInteractive
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
