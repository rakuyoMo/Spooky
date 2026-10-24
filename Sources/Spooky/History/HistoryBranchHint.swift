import SpookyKit
import SwiftUI

// MARK: - HistoryHintKind

/// 历史提示条的种类。
private enum HistoryHintKind {
    /// 已完全并入参数里的基准分支。
    case merged(String)

    /// 超过阈值没有更新。
    case stale(Int)

    /// 已完全合并时的基准分支名。
    var mergedBase: String? {
        guard case .merged(let base) = self else { return nil }
        return base
    }

    /// 完全合并是绿色，陈旧是黄色。
    var tint: Color {
        mergedBase == nil ? Color(nsColor: .systemYellow) : Color(nsColor: .systemGreen)
    }
}

// MARK: - HistoryBranchHint

/// 选中已完全合并或陈旧的分支时，历史列表顶部的提示条；单个分支可以不再显示。
///
/// 选中自动归档后还没看过的分支停留片刻后，清除它的待审阅标记。
struct HistoryBranchHint: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 完全合并提示的展开状态，所有窗口共用。
    @AppStorage("branchFullyMergedHintExpanded")
    private var expanded = true

    /// 陈旧阈值，与侧边栏视图设置共用。
    @AppStorage(SidebarPreferences.staleIntervalKey)
    private var staleInterval = SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

    /// 提示条，或什么都不显示。
    var body: some View {
        let branch = session.history.selectedLocalBranch

        Group {
            if let branch, let kind = kind(of: branch) {
                hint(kind, branch: branch)
                Divider()
            }
        }
        .task(id: branch?.id) {
            await markReviewed(branch)
        }
    }

    /// 基准分支、勾了隐藏提示的分支与普通分支没有提示条；完全合并优先于陈旧。
    private func kind(of branch: RepositoryReference) -> HistoryHintKind? {
        let metadata = session.history.snapshot?.metadata(for: branch.id) ?? BranchMetadata()

        guard
            let condition = session.history.conditions[branch.id],
            !condition.isBase,
            !metadata.hidesMergedHint
        else {
            return nil
        }

        if let base = condition.mergedInto {
            return .merged(BranchesReviewRow.shortName(base))
        }

        let months =
            SidebarPreferences.isValid(staleInterval, for: SidebarPreferences.staleIntervalKey)
                ? staleInterval
                : SidebarPreferences.defaultNumber(SidebarPreferences.staleIntervalKey)

        return condition.isStale(months: months) ? .stale(months) : nil
    }

    /// 图标、标题、说明与关闭菜单；完全合并时可以展开看合并到了哪里。
    private func hint(_ kind: HistoryHintKind, branch: RepositoryReference) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(
                systemName: kind.mergedBase == nil
                    ? "clock.badge.exclamationmark"
                    : "checkmark.circle.fill"
            )
            .font(.system(size: 16))
            .foregroundStyle(kind.tint)
            .accessibilityHidden(true)

            text(kind)

            Spacer(minLength: 4)

            dismissMenu(branch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(kind.tint.opacity(0.15))
    }

    /// 标题、说明，以及完全合并时可展开的 “合并到了哪里”。
    private func text(_ kind: HistoryHintKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppLocalization.text(kind.mergedBase == nil ? "history.hint.stale" : "history.hint.merged"))
                .font(.system(size: 13, weight: .semibold))

            Text(message(kind))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let base = kind.mergedBase {
                DisclosureGroup(isExpanded: $expanded) {
                    Text(AppLocalization.text("history.hint.mergedInto", base))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text(AppLocalization.text("history.hint.details"))
                }
            }
        }
        .font(.system(size: 12))
    }

    /// 关闭菜单：这个分支以后不再显示提示条。
    private func dismissMenu(_ branch: RepositoryReference) -> some View {
        Menu {
            Button(AppLocalization.text("history.hint.dontShow", branch.name)) {
                session.setHidesMergedHint(true, branches: [branch])
            }
            .disabled(!session.canSetArchived([branch]))
        } label: {
            Image(systemName: "xmark")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("history.hint.dismiss"))
    }

    /// 提示条的说明。
    private func message(_ kind: HistoryHintKind) -> String {
        switch kind {
        case .merged: AppLocalization.text("history.hint.mergedMessage")
        case .stale(let months): AppLocalization.text("history.hint.staleMessage", months)
        }
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
