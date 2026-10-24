import Foundation
import SpookyKit

// MARK: - Reflog

extension RepositorySession {
    /// Reflog 里所看的本地分支，且它不是当前分支；看 HEAD 或当前分支时恢复记录就是重置 HEAD。
    var reflogRestorableBranch: RepositoryReference? {
        let reference = reflog.reference

        guard
            reference != "HEAD",
            reference != status?.branch.head.map({ "refs/heads/" + $0 })
        else { return nil }

        return history.snapshot?.references.first { $0.id == reference && $0.isLocal }
    }

    /// 能否把所看的分支恢复到这条记录：分支现在不在这条记录的提交上，且仓库可写。
    func canRestoreReflogBranch(to entry: ReflogEntry) -> Bool {
        guard let branch = reflogRestorableBranch else { return false }

        return canWrite && branch.objectID != entry.commit.id
    }

    /// 把所看的分支恢复到某条记录：确认写明影响范围后经写队列移动分支，不动工作区与暂存区；可以撤销。
    ///
    /// 分支在确认之后又被移动时，Git 按读取列表时的位置核对并拒绝。
    func requestRestore(_ entry: ReflogEntry) {
        guard canRestoreReflogBranch(to: entry), let branch = reflogRestorableBranch, let repository else {
            return
        }

        let request = generation
        let title = AppLocalization.text("reflog.restore.title")
        let message = AppLocalization.text(
            "reflog.restore.message",
            branch.name,
            entry.commit.shortID,
            repository.displayPath
        )

        onConfirm?(
            title,
            message,
            { [weak self] in
                guard let self, generation == request else { return }

                performGit(
                    { runner, _ in
                        try await RepositoryReflog(runner: runner)
                            .restore(branch.id, to: entry.commit.id, expected: branch.objectID)
                    },
                    title: title,
                    undo: .reversible
                )
            },
            nil
        )
    }
}
