import SpookyKit
import SwiftUI

// MARK: - CommitActionRow

/// 提交详情的操作条：在 HEAD 分支上是 ROLLBACK（把 HEAD 重置到这个提交）、REVERT 与 DIFFTOOL（用外部比较工具看这个提交的全部改动）三段连成一组，
/// 其它情况只有 DIFFTOOL 一段；文字大写，由详情居中压在头部与提交说明之间的分隔线上。
///
/// 操作条平时隐藏，鼠标移进详情或键盘焦点移到某一段上时淡入；隐藏时仍保留位置与键盘焦点。
struct CommitActionRow: View {
    /// 操作条的一段，也是键盘焦点的标识。
    private enum Segment {
        case rollback
        case revert
        case diffTool
    }

    /// 发起操作的窗口会话。
    let session: RepositorySession

    /// 详情显示的提交。
    let commit: HistoryCommit

    /// 是否有 Rollback 与 Revert 两段：历史正在显示 HEAD 所在的分支时才有。
    let rewrites: Bool

    /// 鼠标是否在详情上。
    let hovering: Bool

    /// 获得键盘焦点的一段。
    @FocusState
    private var focused: Segment?

    /// 各段之间露出 1 pt 的边框色作竖线，整组共用一个圆角底与描边。
    var body: some View {
        let border = AppPalette.color("general_border_color")
        let shape = RoundedRectangle(cornerRadius: 5)

        HStack(spacing: 1) {
            if rewrites {
                segment(.rollback, title: AppLocalization.text("history.rollback"), enabled: session.canRewrite) {
                    session.requestReset(to: commit.id)
                }

                segment(.revert, title: AppLocalization.text("rewrite.revert.button"), enabled: session.canRewrite) {
                    session.requestRevert([commit.id])
                }
            }

            // 变更集读出之前没有可比较的文件
            segment(
                .diffTool,
                title: AppLocalization.text("history.diffTool"),
                enabled: !session.history.changes.isEmpty
            ) {
                session.openDiffTool(
                    for: commit,
                    files: RepositorySession.comparedFiles(session.history.changes)
                )
            }
        }
        .background(border)
        .clipShape(shape)
        .overlay(shape.strokeBorder(border))
        .opacity(hovering || focused != nil ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: hovering)
    }

    /// 操作条的一段；读屏读出原本大小写的标题。
    ///
    /// - Parameters:
    ///   - id: 这一段的焦点标识。
    ///   - title: 本地化的标题，显示时改成大写。
    ///   - enabled: 这一段是否可用。
    ///   - action: 点按时执行的动作。
    private func segment(
        _ id: Segment,
        title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(CommitActionSegmentStyle())
            .disabled(!enabled)
            .focused($focused, equals: id)
            .accessibilityLabel(title)
    }
}

// MARK: - CommitActionSegmentStyle

/// 操作条的一段：11 pt 中等字重的二级文字、大写，上下内边距 4、左右 8；按下时文字白、底换成边框色，不可用时整体变淡。
private struct CommitActionSegmentStyle: ButtonStyle {
    /// 是否可用。
    @Environment(\.isEnabled)
    private var isEnabled

    /// 按下与常态两种外观。
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .textCase(.uppercase)
            .foregroundStyle(configuration.isPressed ? Color.white : Color.secondary)
            .opacity(isEnabled ? 1 : 0.5)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                configuration.isPressed
                    ? AppPalette.color("general_border_color")
                    : Color(nsColor: .controlBackgroundColor)
            )
            .contentShape(Rectangle())
    }
}
