import SwiftUI

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

/// 对话框的表单区：一组 `DialogFormRow`、`DialogFormOption` 与 `DialogFormField`，行距 8，左右各留 20 pt、上下各留 12 pt。
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

// MARK: - DialogFormOption

/// 表单输入列里的勾选框，说明紧跟在下面一行；没有带标签的行时，勾选框本身就是输入列。
///
/// 说明 11 pt，左缘对齐勾选框的标题文字，折行到输入列的右缘；勾选框到说明默认 8 pt，说明到下一行 8 pt。
/// 说明用正文色，只在勾选框不可用时随之变灰。
struct DialogFormOption: View {
    /// 勾选框的标题。
    let title: String

    /// 说明；为空时只有勾选框。
    var help = ""

    /// 勾选框到说明的间距；发布分支、发布标签、同步、安全强推与推送版本的 Skip Hooks 是 4。
    var spacing: CGFloat = 8

    /// 勾选状态。
    @Binding
    var isOn: Bool

    /// 不可用时说明变灰。
    @Environment(\.isEnabled)
    private var isEnabled

    /// 标签列留空，勾选框与说明在输入列。
    var body: some View {
        DialogFormField {
            VStack(alignment: .leading, spacing: spacing) {
                Toggle(title, isOn: $isOn)

                if !help.isEmpty {
                    Text(help)
                        .font(.system(size: 11))
                        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                        .padding(.leading, 19)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - DialogFormField

/// 表单里没有标签的一行：标签列留空，内容在输入列，如勾选框、说明文字与提交列表。
///
/// 内容靠左、宽度到输入列的右缘；没有带标签的行时，这一行本身就是输入列。
struct DialogFormField<Content: View>: View {
    /// 输入列里的内容。
    @ViewBuilder
    let content: () -> Content

    /// 标签列放一个只占宽度的空白，内容报为输入列。
    var body: some View {
        GridRow {
            Color.clear
                .frame(width: DialogMetrics.labelWidth, height: 0)
                .gridCellUnsizedAxes(.vertical)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .dialogInputColumn()
        }
    }
}

// MARK: - View + DialogInputColumn

extension View {
    /// 输入列里宽度有上限的控件：不超过上限，靠左；输入列比上限宽时余下的宽度留在控件右侧，标签列不随之变宽。
    ///
    /// - Parameter limit: 宽度上限；为 `.infinity` 时占满输入列。
    func dialogFieldWidth(_ limit: CGFloat) -> some View {
        frame(maxWidth: limit, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

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
