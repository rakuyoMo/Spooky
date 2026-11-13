import SpookyKit
import SwiftUI

// MARK: - HistoryAutosquashBanner

/// 历史列表头下方的横幅：在看 HEAD 分支、没有搜索条件，且最近的提交里有带 `fixup!`、`squash!` 或 `amend!` 标记、能找到目标的提交时出现。
///
/// 标题、写出这类提交数量的说明与 Autosquash… 按钮，按钮把这些提交并进各自的目标，先计划再请求确认；
/// 右上角的关闭只在这次出现期间隐藏横幅，横幅因条件不满足消失后再出现时重新显示。
struct HistoryAutosquashBanner: View {
    /// 判断时与 Autosquash 一样，只看 HEAD 往回最近的这么多个提交。
    private static let window = 1000

    /// 历史与改写所在的会话。
    let session: RepositorySession

    /// 能找到目标的标记提交数，大于零。
    let count: Int

    /// 这次出现期间已被关闭。
    @State
    private var dismissed = false

    /// 图标、标题与说明、按钮，关闭按钮在右上角；关闭后不占位置。
    var body: some View {
        if !dismissed {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.merge")
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLocalization.text("rewrite.autosquash"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(Self.message(count))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(AppLocalization.text("rewrite.autosquash.button")) {
                    session.requestRewrite(.autosquash)
                }
                .controlSize(.small)
                .disabled(!session.canRewrite)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
            .padding(.trailing, 28)
            .padding(.vertical, 6)
            .overlay(alignment: .topTrailing) {
                closeButton
            }

            Divider()
        }
    }

    /// 右上角的关闭按钮。
    private var closeButton: some View {
        Button {
            dismissed = true
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .padding(.top, 6)
        .padding(.trailing, 10)
        .accessibilityLabel(AppLocalization.text("action.close"))
    }

    /// 在看 HEAD 分支、没有搜索条件时，已读取的 HEAD 历史里能找到目标的标记提交数；不满足条件时为零。
    static func commitCount(in session: RepositorySession) -> Int {
        let history = session.history

        guard session.isViewingHead, history.searchConditions.isEmpty else {
            return 0
        }

        // 未拉取的提交不在 HEAD 的历史里
        let local = history.commits.lazy
            .filter { !history.unpulled.contains($0.id) }
            .prefix(window)

        return RepositoryRewrite.autosquashCommitCount(in: Array(local))
    }

    /// 只有一个时选用单数，其余数量使用复数。
    private static func message(_ count: Int) -> String {
        AppLocalization.text(count == 1 ? "history.autosquash.one" : "history.autosquash", count)
    }
}
