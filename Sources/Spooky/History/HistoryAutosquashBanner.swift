import SpookyKit
import SwiftUI

// MARK: - HistoryAutosquashBanner

/// 历史列表头下方的横幅：在看 HEAD 分支、没有搜索条件，且最近的提交里有带 `fixup!`、`squash!` 或 `amend!` 标记、能找到目标的提交时出现。
///
/// 点按 Autosquash 把这些提交并进各自的目标，先计划再请求确认。
struct HistoryAutosquashBanner: View {
    /// 判断时与 Autosquash 一样，只看 HEAD 往回最近的这么多个提交。
    private static let window = 1000

    /// 历史与改写所在的会话。
    let session: RepositorySession

    /// 一行说明与按钮；不满足条件时不占位置。
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.merge")
                    .accessibilityHidden(true)

                Text(AppLocalization.text("history.autosquash"))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(AppLocalization.text("rewrite.autosquash.button")) {
                    session.requestRewrite(.autosquash)
                }
                .controlSize(.small)
                .disabled(!session.canRewrite)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()
        }
    }

    /// 在看 HEAD 分支、没有搜索条件，且已读取的 HEAD 历史里有可以自动压缩的提交。
    var isVisible: Bool {
        let history = session.history

        guard session.isViewingHead, history.searchConditions.isEmpty else {
            return false
        }

        // 未拉取的提交不在 HEAD 的历史里
        let local = history.commits.lazy.filter { !history.unpulled.contains($0.id) }.prefix(Self.window)
        return RepositoryRewrite.hasAutosquashCommits(in: Array(local))
    }
}
