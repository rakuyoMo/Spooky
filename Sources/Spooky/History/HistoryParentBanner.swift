import SpookyKit
import SwiftUI

// MARK: - HistoryParentBanner

/// 看落后父分支的本地分支时列表顶上的横幅：标题、落后的提交数、冲突预览与 Update Branch… 按钮，右上角可以关闭。
///
/// 关闭只对这一对分支顶端与父分支顶端有效，任一边前进后再次出现。
struct HistoryParentBanner: View {
    /// 历史所在的会话。
    let session: RepositorySession

    /// 关闭过横幅的分支顶端与父分支顶端。
    @State
    private var dismissed: Set<[String]> = []

    /// 标题与说明、冲突预览，按钮在右侧；不落后或已关闭时不占位置。
    var body: some View {
        if
            let comparison = session.history.parentComparison,
            let behind = comparison.comparison?.divergence.behind,
            behind > 0,
            !dismissed.contains(Self.key(comparison))
        {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.text("history.parentBanner.title"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(Self.message(comparison, behind: behind))
                        .fixedSize(horizontal: false, vertical: true)

                    status(comparison)
                }

                Spacer(minLength: 8)

                Button(AppLocalization.text("review.updateBranch.menu")) {
                    session.requestReference(.updateBranch(comparison.branch))
                }
                .controlSize(.small)
                .disabled(!session.canUpdateBranch(comparison.branch))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
            .padding(.trailing, 28)
            .padding(.vertical, 6)
            .overlay(alignment: .topTrailing) {
                closeButton(comparison)
            }

            Divider()
        }
    }

    /// 说明分支落后父分支多少个提交，按单复数取文案。
    ///
    /// - Parameters:
    ///   - comparison: 所选分支与父分支的比较。
    ///   - behind: 落后的提交数。
    static func message(_ comparison: HistoryBaseComparison, behind: Int) -> String {
        behind == 1
            ? AppLocalization.text("history.parentBanner.message.one", comparison.branch.name, comparison.base.name)
            : AppLocalization.text(
                "history.parentBanner.message",
                comparison.branch.name,
                behind,
                comparison.base.name
            )
    }

    /// 记关闭状态用的键：分支与父分支的引用名和顶端。
    private static func key(_ comparison: HistoryBaseComparison) -> [String] {
        [
            comparison.branch.id,
            comparison.branch.objectID,
            comparison.base.id,
            comparison.base.objectID,
        ]
    }

    /// 冲突预览：能干净并入时是绿色对勾与催促更新的一句，会冲突时是黄色三角；其它情况没有这一行。
    @ViewBuilder
    private func status(_ comparison: HistoryBaseComparison) -> some View {
        if comparison.integratesCleanly {
            Label {
                Text(AppLocalization.text("history.parentBanner.clean"))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(nsColor: .systemGreen))
            }
        } else if !comparison.conflicts.isEmpty {
            Label {
                Text(AppLocalization.text("review.update.conflicts"))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(nsColor: .systemYellow))
            }
        }
    }

    /// 右上角的关闭按钮。
    private func closeButton(_ comparison: HistoryBaseComparison) -> some View {
        Button {
            dismissed.insert(Self.key(comparison))
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .padding(.top, 6)
        .padding(.trailing, 10)
        .accessibilityLabel(AppLocalization.text("action.close"))
    }
}
