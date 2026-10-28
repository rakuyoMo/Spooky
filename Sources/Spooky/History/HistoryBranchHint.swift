import SpookyKit
import SwiftUI

// MARK: - HistoryBranchHint

/// 选中陈旧的分支时，历史列表顶部的提示条。
///
/// 选中自动归档后还没看过的分支停留片刻后，清除它的待审阅标记。
struct HistoryBranchHint: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 陈旧阈值，与侧边栏视图设置共用。
    @AppStorage(SidebarPreferences.staleIntervalKey)
    private var staleInterval = SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

    /// 提示条，或什么都不显示。
    var body: some View {
        let branch = session.history.selectedLocalBranch

        Group {
            if let branch, let months = staleMonths(of: branch) {
                hint(months)
                Divider()
            }
        }
        .task(id: branch?.id) {
            await markReviewed(branch)
        }
    }

    /// 分支陈旧时返回陈旧阈值的月数；基准分支与普通分支没有提示条。
    private func staleMonths(of branch: RepositoryReference) -> Int? {
        guard let condition = session.history.conditions[branch.id] else {
            return nil
        }

        let months =
            SidebarPreferences.isValid(staleInterval, for: SidebarPreferences.staleIntervalKey)
                ? staleInterval
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

        return condition.isStale(months: months) ? months : nil
    }

    /// 黄色底的图标、标题与说明。
    private func hint(_ months: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 16))
                .foregroundStyle(Color(nsColor: .systemYellow))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.text("history.hint.stale"))
                    .font(.system(size: 13, weight: .semibold))

                Text(AppLocalization.text("history.hint.staleMessage", months))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))

            // 撑满整行，底色铺到右边缘
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .systemYellow).opacity(0.15))
    }

    /// 选中自动归档后还没看过的分支 1.5 秒后清除它的待审阅标记；期间换了选择则不清除。
    private func markReviewed(_ branch: RepositoryReference?) async {
        guard
            let branch,
            session.history.snapshot?.metadata(for: branch.id).needsArchiveReview ?? false
        else {
            return
        }

        try? await Task.sleep(for: .milliseconds(1500))

        guard !Task.isCancelled, session.history.selectedLocalBranch?.id == branch.id else {
            return
        }

        session.markArchiveReviewed([branch])
    }
}
