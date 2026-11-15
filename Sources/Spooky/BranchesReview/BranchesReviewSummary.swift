import AppKit
import SpookyKit
import SwiftUI

// MARK: - BranchesReviewSummary

/// 分支整理详情的摘要，Commits 与 Changeset 两页共用：标签与值两列是贡献者、最后更新、跟踪与合并状态，右侧是 80 pt 头像；
/// Commits 页下面另有一行靠右的提交数，Changeset 页的改动统计由变更集自己的摘要行写出。
struct BranchesReviewSummary: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 详情里的分支。
    let branch: RepositoryReference

    /// 上 8、下 4、左右 20 pt，与提交详情的头部相同。
    var body: some View {
        let comparison = session.branchesReview.comparison

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
                    rows
                }

                Spacer(minLength: 4)

                // 头像取分支顶端提交的作者
                if let tip = comparison.commits.first {
                    InitialsAvatar(name: tip.author, email: tip.authorEmail, size: 80)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .padding(.horizontal, 20)
            .font(.system(size: 12))

            if !comparison.showsChangeset, let ahead = divergence?.ahead {
                Text(
                    ahead == 1
                        ? AppLocalization.text("review.showing.one")
                        : AppLocalization.text("review.showing", ahead)
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .frame(height: 32)
            }
        }
    }

    /// 贡献者（没有自己的提交时不列）、最后更新、跟踪与合并状态。
    @ViewBuilder
    private var rows: some View {
        let contributors = Self.contributors(session.branchesReview.comparison.commits)

        if !contributors.isEmpty {
            row("review.summary.contributors", value: contributors)
        }

        if let date = branch.date {
            row(
                "review.summary.updated",
                value: CommitMetadataView.headerDate(date, locale: .current, timeZone: .current)
            )
        }

        GridRow(alignment: .firstTextBaseline) {
            label("review.summary.tracking")
            tracking
        }

        if let divergence, let base = session.branchesReview.base {
            GridRow(alignment: .firstTextBaseline) {
                label("review.summary.mergeStatus")

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        AppLocalization.text(
                            "review.summary.divergence",
                            BranchesReviewRow.countsLabel(divergence),
                            base.name
                        )
                    )
                    .foregroundStyle(.secondary)

                    mergeResult(base.name)
                }
            }
        }
    }

    /// 跟踪的远端分支；上游已不存在时名字是红色，没有上游时写 No tracking branch。
    @ViewBuilder
    private var tracking: some View {
        if let missing = session.history.conditions[branch.id]?.missingUpstream {
            Text(BranchesReviewRow.shortName(missing))
                .foregroundStyle(Color(nsColor: .systemRed))
        } else if let upstream = branch.upstream {
            Text(BranchesReviewRow.shortName(upstream))
                .foregroundStyle(.secondary)
        } else {
            Text(AppLocalization.text("review.noTracking"))
                .foregroundStyle(.secondary)
        }
    }

    /// 与基准的比较结果；还在比较时为 nil。
    private var divergence: ReferenceDivergence? {
        session.branchesReview.comparisons[branch.id]?.divergence
    }

    /// 提交里的作者，按出现的先后去重，用逗号连起来。
    static func contributors(_ commits: [HistoryCommit]) -> String {
        var seen = Set<String>()

        return commits
            .map(\.author)
            .filter { seen.insert($0).inserted }
            .joined(separator: ", ")
    }

    /// 并入基准的结果：能干净合并是绿色的勾，会冲突是黄色的三角；其它情况没有这一行。
    @ViewBuilder
    private func mergeResult(_ base: String) -> some View {
        switch session.branchesReview.comparisons[branch.id]?.merge {
        case .clean:
            result("review.summary.canMerge", base: base, symbol: "checkmark.circle.fill", color: .systemGreen)

        case .conflicts:
            result("review.summary.conflicts", base: base, symbol: "exclamationmark.triangle.fill", color: .systemYellow)

        default:
            EmptyView()
        }
    }

    /// 带彩色图标的一行结果。
    private func result(_ key: String, base: String, symbol: String, color: NSColor) -> some View {
        Label {
            Text(AppLocalization.text(key, base))
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Color(nsColor: color))
        }
    }

    /// 一行文字值：值用二级文字色，单行、可选中、尾部截断。
    private func row(_ key: String, value: String) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            label(key)

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)
        }
    }

    /// 行首的标签，三级文字色。
    private func label(_ key: String) -> some View {
        Text(AppLocalization.text(key))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}
