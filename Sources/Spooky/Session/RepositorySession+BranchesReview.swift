import Foundation
import SpookyKit

// MARK: - Branches Review

extension RepositorySession {
    /// 陈旧阈值的月数，与侧边栏视图设置共用。
    var staleMonths: Int {
        SidebarPreferences.integer(SidebarPreferences.staleIntervalKey)
    }

    /// 建议归档的分支；自动归档时还要跳过勾了 “自动归档时跳过” 的分支。
    ///
    /// - Parameter staleMonths: 陈旧阈值的月数；省略时读偏好。
    func archiveCandidates(automatic: Bool, staleMonths months: Int? = nil) -> [RepositoryReference] {
        guard let snapshot = history.snapshot else {
            return []
        }

        return BranchArchiving.candidates(
            in: snapshot,
            conditions: history.conditions,
            head: status?.branch.head,
            staleMonths: months ?? staleMonths,
            automatic: automatic
        )
    }

    /// 本地分支设置的父分支；父分支已删除或没有设置时为 nil。
    func parentBranch(of reference: RepositoryReference) -> RepositoryReference? {
        guard let parent = history.snapshot?.metadata(for: reference.id).parent else {
            return nil
        }

        return history.branches.first { $0.id == parent }
    }

    /// Update Branch 需要有父分支的本地分支，且没有进行中的操作。
    func canUpdateBranch(_ reference: RepositoryReference) -> Bool {
        canWrite && context?.operation == nil && reference.isLocal && parentBranch(of: reference) != nil
    }

    /// 归档若干分支；完成后在侧边栏说明归档了几个分支，并可以撤销。
    ///
    /// - Parameters:
    ///   - branches: 要归档的本地分支。
    ///   - automatic: 自动归档：分支记上待审阅标记，Activity 用自动归档的名称。
    func archive(_ branches: [RepositoryReference], automatic: Bool) {
        guard canSetArchived(branches) else {
            return
        }

        let ids = branches.map(\.id)
        let review = branchesReview

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner)
                    .setArchived(true, branches: ids, review: automatic)
            },
            title: AppLocalization.text(automatic ? "review.autoArchive" : "branch.archive"),
            success: { review.archivedBranches = ids }
        )
    }

    /// 撤销刚才的归档：把这批分支恢复到 Branches 分组。
    func undoArchive() {
        guard let ids = branchesReview.archivedBranches, canWrite else {
            return
        }

        branchesReview.archivedBranches = nil

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setArchived(false, branches: ids)
            },
            title: AppLocalization.text("branch.unarchive")
        )
    }

    /// 设置或取消 “自动归档时跳过”。
    func setSkipsAutoArchive(_ skips: Bool, branches: [RepositoryReference]) {
        guard canSetArchived(branches) else {
            return
        }

        let ids = branches.map(\.id)

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setSkipsAutoArchive(skips, branches: ids)
            },
            title: AppLocalization.text("review.skipAutoArchive")
        )
    }

    /// 设置或取消 “隐藏完全合并提示”。
    func setHidesMergedHint(_ hides: Bool, branches: [RepositoryReference]) {
        guard canSetArchived(branches) else {
            return
        }

        let ids = branches.map(\.id)

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).setHidesMergedHint(hides, branches: ids)
            },
            title: AppLocalization.text("review.hideMergedHint")
        )
    }

    /// 清除自动归档分支的待审阅标记；不记入 Activity。
    func markArchiveReviewed(_ branches: [RepositoryReference]) {
        let ids = branches.map(\.id)

        guard !ids.isEmpty, canWrite else {
            return
        }

        performGit(
            { runner, _ in
                try await RepositoryReferences(runner: runner).markArchiveReviewed(branches: ids)
            },
            title: AppLocalization.text("review.markReviewed"),
            recordsActivity: false
        )
    }

    /// 用父分支更新一个本地分支：合并父分支或变基到父分支上；被本地改动挡住时询问是否先储藏。
    func updateBranch(_ reference: RepositoryReference, rebase: Bool) {
        guard canUpdateBranch(reference), let parent = parentBranch(of: reference) else {
            return
        }

        let options = SyncPreferences.merge

        performGit(
            { runner, output in
                try await RepositorySync(runner: runner)
                    .updateBranch(
                        reference.id,
                        from: parent.id,
                        rebase: rebase,
                        options: options,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("review.updateBranch"),
            offersAutoStash: true
        )
    }

    /// 把基准分支并入所选分支，解决分支整理里看到的冲突；冲突留给进行中操作的横幅与冲突向导。
    func mergeBase(_ base: RepositoryReference, into reference: RepositoryReference) {
        guard canWrite, context?.operation == nil, reference.isLocal, base.id != reference.id else {
            return
        }

        let options = SyncPreferences.merge

        performGit(
            { runner, output in
                try await RepositorySync(runner: runner)
                    .updateBranch(
                        reference.id,
                        from: base.id,
                        rebase: false,
                        options: options,
                        onOutput: output
                    )
            },
            title: AppLocalization.text("review.resolveConflicts"),
            offersAutoStash: true
        )
    }
}
