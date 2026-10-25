import AppKit
import SwiftUI

// MARK: - DialogLayout

/// 不随仓库可写状态变化的对话框骨架：64 pt 应用图标与标题、说明，内容区，错误区与底栏，宽 480。
///
/// 头部文字与错误文字对齐距左 120 pt 的对齐线，应用图标挂在左侧；内容区的边距由内容自己决定。
/// 用于身份档案与 Issue 追踪设置这类在设置里打开的对话框。
struct DialogLayout<Content: View>: View {
    /// 对话框标题，也是 VoiceOver 读出的名称。
    let title: String

    /// 标题下方的说明。
    let message: String

    /// 主按钮的标题。
    let submitTitle: String

    /// 内容不合法的原因；为 nil 时不显示错误区。
    let error: String?

    /// 主按钮是否可用。
    let canSubmit: Bool

    /// 取消只关闭对话框。
    let cancel: () -> Void

    /// 主按钮的动作。
    let submit: () -> Void

    /// 内容区。
    @ViewBuilder
    let content: () -> Content

    /// 头部、内容、错误区与底栏依次排列。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            content()
                .font(.system(size: 13))

            if let error {
                errorRow(error)
            }

            footer
        }
        .frame(width: 480)
    }
}

// MARK: - Private

extension DialogLayout {
    /// 头部文字与错误文字共用的左对齐线。
    private var alignment: CGFloat { 120 }

    /// 64 pt 应用图标与右侧的标题、说明，文字列宽 340 pt。
    private var header: some View {
        HStack(alignment: .top, spacing: alignment - 32 - 64) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))

                Text(message)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(idealWidth: 340, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 32)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 取消与主按钮；内容不合法时主按钮不可用。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            Button(action: cancel) {
                Text(AppLocalization.text("action.cancel"))
                    .frame(minWidth: 56)
            }
            .keyboardShortcut(.cancelAction)

            Button(action: submit) {
                Text(submitTitle)
                    .frame(minWidth: 56)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(height: 53, alignment: .top)
    }

    /// 黄色警告图标挂在对齐线左侧，原因文字从对齐线开始。
    private func errorRow(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, alignment - 4 - 18)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }
}
