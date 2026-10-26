import SpookyKit
import SwiftUI

// MARK: - WorktreeDetailView

/// 工作树视图：头部是图标、工作树名与只有 General 一段的分段，下面是名称、当前版本、分支与路径；
/// 工作树失效时整页换成空状态，写出失效的原因。
struct WorktreeDetailView: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 头部固定 52 pt，内容区可滚动。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let worktree = session.worktrees.selected {
                if worktree.isValid {
                    settings(of: worktree)
                } else {
                    EmptyStateView(
                        title: AppLocalization.text("worktree.invalid"),
                        message: invalidMessage(worktree),
                        symbol: "exclamationmark.triangle"
                    )
                    .frame(maxHeight: .infinity)
                }
            } else if session.worktrees.isLoaded {
                EmptyStateView(
                    title: AppLocalization.text("worktree.missing"),
                    message: AppLocalization.text("worktree.missing.message", session.worktrees.selectedPath ?? ""),
                    symbol: "rectangle.on.rectangle"
                )
                .frame(maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 300)
    }
}

// MARK: - Layout

extension WorktreeDetailView {
    /// 32 pt 图标、工作树名与右侧只有一段的分段。
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(session.worktrees.selected?.name ?? "")
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()

            Picker("", selection: .constant(0)) {
                Text(AppLocalization.text("worktree.page.general")).tag(0)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel(AppLocalization.text("worktree.page"))
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// General 分段：名称、当前版本、分支与路径；服务器上的路径带主机前缀。
    private func settings(of worktree: Worktree) -> some View {
        let path = session.location(of: worktree)?.displayPath ?? worktree.path

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RemoteSettingsGroup(title: AppLocalization.text("worktree.page.general"))
                RemoteSettingRow(label: AppLocalization.text("worktree.field.name"), value: worktree.name)

                RemoteSettingRow(
                    label: AppLocalization.text("worktree.field.revision"),
                    value: worktree.head ?? AppLocalization.text("submodule.notAvailable"),
                    small: worktree.head != nil,
                    secondary: worktree.head == nil
                )

                RemoteSettingRow(
                    label: AppLocalization.text("worktree.field.branch"),
                    value: worktree.branchName ?? AppLocalization.text("branch.detachedShort"),
                    secondary: worktree.branch == nil
                )

                RemoteSettingRow(label: AppLocalization.text("worktree.field.path"), value: path, small: true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 失效的说明：Git 给出原因时写在后面。
    private func invalidMessage(_ worktree: Worktree) -> String {
        guard let reason = worktree.prunableReason, !reason.isEmpty else {
            return AppLocalization.text("worktree.invalid.message")
        }

        return AppLocalization.text("worktree.invalid.reason", reason)
    }
}
