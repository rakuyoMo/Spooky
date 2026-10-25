import AppKit
import SwiftUI

// MARK: - DialogLayout

/// 不随仓库可写状态变化的对话框骨架：64 pt 应用图标与标题、说明，内容区，错误区与底栏，宽 480。
///
/// 头部文字与错误文字对齐 `DialogMetrics.alignment`，应用图标挂在左侧；内容区的边距由内容自己决定，
/// 表单可以用 `DialogForm` 与 `DialogFormRow` 让输入列也从对齐线开始。
/// 用于身份档案、Issue 追踪设置与仓库管理这类不随仓库可写状态变化的对话框。
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
    /// 64 pt 应用图标与右侧的标题、说明，文字列宽 340 pt。
    private var header: some View {
        HStack(alignment: .top, spacing: DialogMetrics.alignment - 32 - 64) {
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
        .padding(.leading, DialogMetrics.alignment - 4 - 18)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - DialogMetrics

/// 对话框骨架的度量：头部文字、表单输入列与错误文字共用一条左对齐线。
enum DialogMetrics {
    /// 距对话框左缘 120 pt 的对齐线。
    static let alignment: CGFloat = 120

    /// 表单标签列的最小宽度：表单左边距 20 pt，标签右缘与输入列相隔 8 pt，输入列正好从对齐线开始。
    static let labelWidth: CGFloat = alignment - 20 - 8
}

// MARK: - DialogForm

/// 对话框的表单区：一组 `DialogFormRow`，左右各留 20 pt、上下各留 12 pt。
struct DialogForm<Rows: View>: View {
    /// 表单的行。
    @ViewBuilder
    let rows: () -> Rows

    /// 标签列右对齐、输入列左对齐的网格。
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
            rows()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - DialogFormRow

/// 表单的一行：右对齐的标签与它右侧的输入控件；VoiceOver 以去掉冒号的标签读出控件。
struct DialogFormRow<Field: View>: View {
    /// 标签，带冒号。
    let label: String

    /// 输入控件。
    @ViewBuilder
    let field: () -> Field

    /// 标签列至少宽到让输入列从对齐线开始。
    var body: some View {
        GridRow {
            Text(label)
                .frame(minWidth: DialogMetrics.labelWidth, alignment: .trailing)
                .gridColumnAlignment(.trailing)

            field()
                .accessibilityLabel(label.trimmingCharacters(in: CharacterSet(charactersIn: ":：")))
        }
    }
}
