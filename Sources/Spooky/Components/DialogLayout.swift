import AppKit
import SwiftUI

// MARK: - DialogLayout

/// 对话框骨架：64 pt 应用图标与标题、说明，内容区，错误区与底栏，宽 480。
///
/// 头部文字与错误文字对齐内容区的输入列，应用图标挂在头部文字左侧；内容区的边距由内容自己决定。
/// 输入列由 `DialogFormRow` 报上来，标签长时随之右移；内容区没有输入列时对齐 `DialogMetrics.alignment`。
/// 内容区里要按输入列定宽或缩进的部分，用 `DialogInputColumnReader` 读到它。
/// 要随仓库可写状态禁用的对话框，由调用方给出主按钮与错误区。
/// 等待中的步骤写在底栏左侧，前面是小号转圈。
struct DialogLayout<Content: View>: View {
    /// 对话框标题，也是 VoiceOver 读出的名称。
    let title: String

    /// 标题下方的说明。
    let message: String

    /// 主按钮的标题。
    let submitTitle: String

    /// 内容不合法的原因；为 nil 时不显示错误区。
    let error: String?

    /// 等待中的步骤，如 “Validating…”；为 nil 时底栏左侧是空的。
    var progress: String? = nil

    /// 主按钮是否可用。
    let canSubmit: Bool

    /// 取消按钮与 ⎋ 的动作：关闭对话框，等待中时也可以只停止等待。
    let cancel: () -> Void

    /// 主按钮的动作。
    let submit: () -> Void

    /// 内容区。
    @ViewBuilder
    let content: () -> Content

    /// 内容区输入列的左缘；内容区没有输入列时为 nil。
    @State
    private var inputColumn: CGFloat?

    /// 头部、内容、错误区与底栏依次排列。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            content()
                .font(.system(size: 13))
                .environment(\.dialogInputColumn, alignment)

            if let error {
                errorRow(error)
            }

            footer
        }
        .frame(width: 480)
        .coordinateSpace(.named(DialogMetrics.coordinateSpace))
        .onPreferenceChange(DialogInputColumnKey.self) { inputColumn = $0 }
    }
}

// MARK: - Private

extension DialogLayout {
    /// 头部文字与错误文字的左缘。
    private var alignment: CGFloat {
        DialogMetrics.textLeading(for: inputColumn)
    }

    /// 64 pt 应用图标与右侧的标题、说明：文字从对齐线开始，图标在文字左侧 16 pt，右边距 20。
    private var header: some View {
        HStack(alignment: .top, spacing: DialogMetrics.iconSpacing) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, alignment - DialogMetrics.iconSpacing - 64)
        .padding(.trailing, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 左侧是等待中的步骤，右侧是取消与主按钮；内容不合法时主按钮不可用。
    private var footer: some View {
        HStack(spacing: 8) {
            if let progress {
                ProgressView()
                    .controlSize(.small)

                Text(progress)
                    .font(.system(size: 13))
            }

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

// MARK: - DialogMetrics

/// 对话框骨架的度量：头部文字、表单输入列与错误文字共用一条左对齐线。
enum DialogMetrics {
    /// 距对话框左缘 120 pt 的对齐线：表单标签都不长时输入列从这里开始，内容区没有输入列时头部与错误文字对齐它。
    static let alignment: CGFloat = 120

    /// 头部图标与文字的间距。
    static let iconSpacing: CGFloat = 16

    /// 对话框骨架的坐标空间，`dialogInputColumn()` 在其中量出输入列的位置。
    static let coordinateSpace = "DialogLayout"

    /// 表单标签列的最小宽度：表单左边距 20 pt，标签右缘与输入列相隔 8 pt，输入列正好从对齐线开始。
    static let labelWidth: CGFloat = alignment - 20 - 8

    /// 头部文字与错误文字的左缘：内容区的输入列，没有输入列时是 `alignment`；不小于图标距左 32 时文字的位置。
    static func textLeading(for inputColumn: CGFloat?) -> CGFloat {
        max(inputColumn ?? alignment, 32 + 64 + iconSpacing)
    }
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

/// 表单的一行：右对齐的标签与它右侧的输入控件。
///
/// 标签列至少宽到让输入列从对齐线开始，标签长时输入列随之右移，并报给外层的对话框骨架。
/// 标签在辅助功能里是控件的标题，VoiceOver 读控件时读出标签；控件是只读的文字时，标签与文字本身都读得出，
/// 一组控件时各自保留自己的名称。
struct DialogFormRow<Field: View>: View {
    /// 标签，带冒号。
    let label: String

    /// 标签与控件的竖直对齐；为 nil 时沿用表单的首行基线对齐，多行的文字区用 `.top` 让标签与它的顶边对齐。
    var alignment: VerticalAlignment? = nil

    /// 输入控件。
    @ViewBuilder
    let field: () -> Field

    /// 把标签与控件配成一对的辅助功能命名空间。
    @Namespace
    private var accessibility

    /// 标签列至少宽到 `DialogMetrics.labelWidth`。
    var body: some View {
        GridRow(alignment: alignment) {
            Text(label)
                .frame(minWidth: DialogMetrics.labelWidth, alignment: .trailing)
                .gridColumnAlignment(.trailing)
                .accessibilityLabeledPair(role: .label, id: 0, in: accessibility)

            field()
                .accessibilityLabeledPair(role: .content, id: 0, in: accessibility)
                .dialogInputColumn()
        }
    }
}

// MARK: - View + DialogInputColumn

extension View {
    /// 把这个视图的左缘报给外层的对话框骨架，作为输入列：头部与错误文字对齐它。
    func dialogInputColumn() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DialogInputColumnKey.self,
                    value: proxy.frame(in: .named(DialogMetrics.coordinateSpace)).minX
                )
            }
        }
    }
}

// MARK: - DialogInputColumnReader

/// 按外层对话框骨架的输入列排版的内容，如固定为输入列宽度的文字、与输入列对齐的选项区。
struct DialogInputColumnReader<Content: View>: View {
    /// 由输入列的左缘生成内容。
    @ViewBuilder
    let content: (CGFloat) -> Content

    /// 外层骨架的输入列。
    @Environment(\.dialogInputColumn)
    private var inputColumn

    /// 用输入列生成的内容。
    var body: some View {
        content(inputColumn)
    }
}

// MARK: - EnvironmentValues + DialogInputColumn

extension EnvironmentValues {
    /// 外层对话框骨架里输入列的左缘，也是头部与错误文字的左缘；不在骨架里时是 `DialogMetrics.alignment`。
    @Entry
    var dialogInputColumn = DialogMetrics.alignment
}

// MARK: - DialogInputColumnKey

/// 表单输入列的左缘，由 `dialogInputColumn()` 报给外层的对话框骨架，头部与错误文字据此对齐；几行时取最靠左的。
struct DialogInputColumnKey: PreferenceKey {
    /// 没有表单行时为 nil。
    static let defaultValue: CGFloat? = nil

    /// 合并几行报上来的位置。
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        guard let next = nextValue() else {
            return
        }

        value = min(value ?? next, next)
    }
}
