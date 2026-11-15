import SpookyKit
import SwiftUI

// MARK: - WorktreeDetailView

/// 工作树视图：头部是图标与工作树名，下面是名称、路径、当前版本与分支；
/// 工作树失效时整页换成空状态，写出失效的原因。
struct WorktreeDetailView: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 头部固定 52 pt，内容区可滚动；列表读出之前内容区留空。
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
                }
            } else if session.worktrees.isLoaded {
                EmptyStateView(
                    title: AppLocalization.text("worktree.missing"),
                    message: AppLocalization.text("worktree.missing.message", session.worktrees.selectedPath ?? ""),
                    symbol: "rectangle.on.rectangle"
                )
            } else {
                Color.clear
            }
        }
        .frame(minWidth: 480, minHeight: 300)
    }
}

// MARK: - Layout

extension WorktreeDetailView {
    /// 32 pt 图标与工作树名。
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
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// GENERAL 组：名称、路径、当前版本与分支；本机路径带在 Finder 打开的按钮，服务器上的路径带主机前缀。
    private func settings(of worktree: Worktree) -> some View {
        ScrollView {
            SettingTable {
                RemoteSettingsGroup(title: AppLocalization.text("worktree.page.general"))

                RemoteSettingRow(label: AppLocalization.text("worktree.field.name"), value: worktree.name)

                RemoteSettingRow(
                    label: AppLocalization.text("worktree.field.path"),
                    location: session.location(of: worktree)
                )

                RemoteSettingRow(
                    label: AppLocalization.text("worktree.field.revision"),
                    value: worktree.head ?? AppLocalization.text("submodule.notAvailable"),
                    secondary: worktree.head == nil
                )

                RemoteSettingRow(
                    label: AppLocalization.text("worktree.field.branch"),
                    value: worktree.branchName ?? AppLocalization.text("branch.detachedShort"),
                    secondary: worktree.branch == nil
                )
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
