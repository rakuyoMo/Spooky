import SpookyKit
import SwiftUI

// MARK: - CommitActionRow

/// 提交详情里完整信息与变更集摘要之间的操作按钮行，高 22 pt：在看 HEAD 分支时有 Rollback（把 HEAD 重置到这个提交）与 Revert。
///
/// 按钮平时隐藏，鼠标移进详情或键盘焦点移到按钮上时淡入；隐藏时仍保留位置与键盘焦点。
struct CommitActionRow: View {
    /// 发起操作的窗口会话。
    let session: RepositorySession

    /// 详情显示的提交。
    let commit: HistoryCommit

    /// 鼠标是否在详情上。
    let hovering: Bool

    /// 获得键盘焦点的按钮。
    @FocusState
    private var focused: String?

    #warning(
        "TODO: 按钮行平时隐藏、鼠标移进详情时淡入是推断：显示与隐藏的方法在，触发时机没有还原。核实方式：在历史里选中 HEAD 分支上的提交，看 Rollback 与 Revert 是一直显示还是悬停才出现；只影响这一行按钮的可见时机。"
    )

    /// 按钮靠左排列，距左 20 pt。
    var body: some View {
        HStack(spacing: 8) {
            Button(AppLocalization.text("history.rollback")) {
                session.requestReset(to: commit.id)
            }
            .focused($focused, equals: "rollback")

            Button(AppLocalization.text("rewrite.revert.button")) {
                session.requestRevert([commit.id])
            }
            .focused($focused, equals: "revert")
        }
        .buttonStyle(CommitActionButtonStyle())
        .disabled(!session.canRewrite)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .opacity(hovering || focused != nil ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: hovering)
    }
}

// MARK: - CommitActionButtonStyle

/// 操作按钮：11 pt 二级文字、通用边框色描边、控件背景色底、圆角 8，内边距上下 4、左右 8；按下时文字白、底换成边框色。
private struct CommitActionButtonStyle: ButtonStyle {
    /// 是否可用，不可用时整体变淡。
    @Environment(\.isEnabled)
    private var isEnabled

    /// 按下与常态两种外观。
    func makeBody(configuration: Configuration) -> some View {
        let border = AppPalette.color("general_border_color")
        let shape = RoundedRectangle(cornerRadius: 8)

        return configuration.label
            .font(.system(size: 11))
            .foregroundStyle(configuration.isPressed ? Color.white : Color.secondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(configuration.isPressed ? border : Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay(shape.strokeBorder(border))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.5)
    }
}
