import SwiftUI

// MARK: - SettingsFormLayout

/// 设置页表单的版式：标签列右对齐、控件列左对齐，两列合起来在窗口里水平居中；各页只给出自己的控件列宽。
///
/// 标签列宽到这一页最长的标签，标签的右缘在控件列左侧 8 pt，冒号排成一条竖线；
/// 冒号右侧的内容都从控件列的左缘起，单个控件充满控件列，勾选框与说明文字在列宽内折行。
///
/// 纵向间距是相邻两行布局框之间的距离：弹出菜单与输入框（``SettingsTextField``）的布局框就是可见边框，
/// 单行勾选框的布局框上下就是方块；组合框的 1 pt 描边画在布局框外，与它相邻的可见间距比给出的值小 1 pt。
struct SettingsFormLayout {
    /// 设置窗口的宽度。
    static let windowWidth: CGFloat = 900

    /// 内容距窗口上下边缘。
    static let verticalMargin: CGFloat = 20

    /// 表单距窗口左右边缘的最小距离；标签或控件过长时在这里折行。
    static let horizontalMargin: CGFloat = 20

    /// 标签右缘与控件列的间距。
    static let labelSpacing: CGFloat = 8

    /// 分组分隔线距窗口左右边缘。
    static let separatorInset: CGFloat = 40

    /// 分组分隔线与上一组最后一个控件、下一组第一行标签的距离。
    static let separatorSpacing: CGFloat = 16

    /// 弹出菜单与输入框的顶边比同一行标签的顶边高出的距离。
    static let controlLabelInset: CGFloat = 4

    /// 附在控件下面的单个勾选框、说明文字与它的距离，输入框之间的距离，以及组合框与上下相邻控件的距离。
    static let rowSpacing: CGFloat = 8

    /// 弹出菜单之间的距离。
    static let popUpSpacing: CGFloat = 10

    /// 弹出菜单与上面不是弹出菜单的一行（附在控件下的勾选框或说明文字、组合框）之间的距离。
    static let popUpAfterRowSpacing: CGFloat = 20

    /// 弹出菜单与下方勾选框组的距离。
    static let checkboxGroupSpacing: CGFloat = 12

    /// 勾选框之间的距离，两行的勾选框也一样。
    static let checkboxSpacing: CGFloat = 6

    /// 组合框与下方分隔线的距离：描边到分隔线可见 6.5 pt。
    static let comboBoxSeparatorSpacing: CGFloat = 7.5

    /// 控件列的宽度：弹出菜单、组合框与输入框充满它，勾选框与说明文字在它里面折行。
    var controlWidth: CGFloat = 278
}

// MARK: SettingsFormLayout + Pages

extension SettingsFormLayout {
    /// Git Config 页：控件列宽 310。
    static let gitConfig = Self(controlWidth: 310)

    /// Integration 页：控件列宽 254。
    static let integration = Self(controlWidth: 254)

    /// Updates 页：控件列宽 250。
    static let updates = Self(controlWidth: 250)
}

// MARK: - EnvironmentValues + SettingsFormLayout

extension EnvironmentValues {
    /// 所在设置页表单的控件列宽；不在表单里时取默认的 278 pt。
    @Entry
    var settingsFormLayout = SettingsFormLayout()
}

// MARK: - HorizontalAlignment + SettingsControlColumn

extension HorizontalAlignment {
    /// 控件列左缘的对齐线；没有标出的视图不按控件列排。
    private enum SettingsControlColumn: AlignmentID {
        /// 没有标出时取视图的左缘。
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }

    /// 表单控件列的左缘：``SettingsRow`` 在控件的左缘标出它，``SettingsForm`` 按它把各行排齐。
    fileprivate static let settingsControlColumn = HorizontalAlignment(SettingsControlColumn.self)
}

// MARK: - SettingsForm

/// 设置页的表单：各行自上而下排列，距窗口上下边缘各 20 pt，宽同窗口；控件列宽经环境交给各行。
///
/// 行距由各行用 `padding(.top:)` 按 ``SettingsFormLayout`` 的行距给出，分组之间放 ``SettingsSeparator``。
struct SettingsForm<Rows: View>: View {
    /// 这一页的控件列宽。
    let layout: SettingsFormLayout

    /// 表单的行与分隔线。
    @ViewBuilder
    let rows: () -> Rows

    /// 按控件列排齐、整体居中的各行；分隔线横贯整页。
    var body: some View {
        SettingsFormStack {
            rows()
        }
        .padding(.vertical, SettingsFormLayout.verticalMargin)
        .frame(width: SettingsFormLayout.windowWidth, alignment: .topLeading)
        .environment(\.settingsFormLayout, layout)
    }

    /// 创建表单。
    ///
    /// - Parameters:
    ///   - layout: 这一页的控件列宽，默认 278 pt。
    ///   - rows: 表单的行与分隔线。
    init(layout: SettingsFormLayout = SettingsFormLayout(), @ViewBuilder rows: @escaping () -> Rows) {
        self.layout = layout
        self.rows = rows
    }
}

// MARK: - SettingsRow

/// 表单的一行：标签紧挨在控件列左侧右对齐，控件列里的内容左对齐、宽同控件列；没有标签时内容直接从控件列开始。
struct SettingsRow<Control: View>: View {
    /// 已本地化的标签，带冒号；为 nil 时标签列留空。
    let label: String?

    /// 标签与控件的竖直对齐。
    let alignment: VerticalAlignment

    /// 控件列里的内容。
    @ViewBuilder
    let control: () -> Control

    /// 所在页的控件列宽。
    @Environment(\.settingsFormLayout)
    private var layout

    /// 标签与控件列并排，相隔 8 pt；标签过长时在左边距处折行，各行右对齐。
    var body: some View {
        HStack(alignment: alignment, spacing: SettingsFormLayout.labelSpacing) {
            if let label {
                Text(label)
                    .multilineTextAlignment(.trailing)
            }

            control()
                .frame(width: layout.controlWidth, alignment: .leading)
                .alignmentGuide(.settingsControlColumn) { $0[.leading] }
        }
    }

    /// 创建一行。
    ///
    /// - Parameters:
    ///   - label: 已本地化的标签，带冒号；为 nil 时标签列留空。
    ///   - alignment: 标签与控件的竖直对齐，默认按首行文字的基线；没有文字基线的 AppKit 控件用 `.center`。
    ///   - control: 控件列里的内容。
    init(
        _ label: String? = nil,
        alignment: VerticalAlignment = .firstTextBaseline,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.label = label
        self.alignment = alignment
        self.control = control
    }
}

// MARK: - SettingsSeparator

/// 分组之间的分隔线：横贯整页，左右各距窗口边缘 40 pt；上方距上一组最后一个控件 16 pt（组合框 7.5 pt），下方距下一组第一行的标签 16 pt。
struct SettingsSeparator: View {
    /// 上一组收尾的一行。
    enum PreviousRow {
        /// 弹出菜单、勾选框或文字。
        case control

        /// 组合框：分隔线贴近它的描边。
        case comboBox
    }

    /// 下一组打头的一行。
    enum NextRow {
        /// 弹出菜单或输入框：行的顶边是控件的顶边，比标签高出 ``SettingsFormLayout/controlLabelInset``。
        case control

        /// 勾选框：行的顶边就是文字的顶边。
        case checkbox
    }

    /// 上一组收尾的一行。
    var previous = PreviousRow.control

    /// 下一组打头的一行。
    var next = NextRow.control

    /// 1 pt 的分隔线与上下的间距。
    var body: some View {
        Divider()
            .padding(.horizontal, SettingsFormLayout.separatorInset)
            .padding(.top, topSpacing)
            .padding(.bottom, bottomSpacing)
    }

    /// 上一行底边到分隔线的距离。
    private var topSpacing: CGFloat {
        switch previous {
        case .control: SettingsFormLayout.separatorSpacing
        case .comboBox: SettingsFormLayout.comboBoxSeparatorSpacing
        }
    }

    /// 分隔线到下一行顶边的距离。
    private var bottomSpacing: CGFloat {
        switch next {
        case .control: SettingsFormLayout.separatorSpacing - SettingsFormLayout.controlLabelInset
        case .checkbox: SettingsFormLayout.separatorSpacing
        }
    }
}

// MARK: - View + SettingsColumnWidth

extension View {
    /// 控件充满控件列并左对齐：弹出菜单与组合框拉宽到列宽，勾选框与说明文字在列宽内折行。
    func settingsColumnWidth() -> some View {
        modifier(SettingsColumnWidth())
    }
}

// MARK: - SettingsColumnWidth

/// 按所在页的控件列宽排布控件；与控件并排的附加按钮排在列外。
private struct SettingsColumnWidth: ViewModifier {
    /// 所在页的控件列宽。
    @Environment(\.settingsFormLayout)
    private var layout

    /// 弹出菜单按列宽拉宽，其余控件在列宽内左对齐。
    func body(content: Content) -> some View {
        content
            .buttonSizing(.flexible)
            .frame(width: layout.controlWidth, alignment: .leading)
    }
}

// MARK: - SettingsFormStack

/// 表单各行的排布：自上而下、行间不另加距离。
///
/// 标出控件列的行按控件列排齐：标签列宽到最长的标签，两列合起来在窗口里水平居中，
/// 太宽时从左边距开始；没有标出控件列的内容（分隔线、失败说明）占满整页的宽度。
private struct SettingsFormStack: Layout {
    /// 宽度取提议的宽度，高度是各行之和。
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let width = proposal.width ?? SettingsFormLayout.windowWidth
        let height = Self.measure(subviews, width: width).reduce(0) { $0 + $1.dimensions.height }

        return CGSize(width: width, height: height)
    }

    /// 各行按控件列放好，其余内容从左缘开始。
    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let items = Self.measure(subviews, width: bounds.width)

        // 控件列左侧最宽的部分是标签列加间距，右侧是控件列
        let leading = items.compactMap(\.column).max() ?? 0

        let trailing = items
            .compactMap { item in item.column.map { item.dimensions.width - $0 } }
            .max() ?? 0

        let margin = SettingsFormLayout.horizontalMargin
        let column = (max(margin, (bounds.width - leading - trailing) / 2) + leading).rounded()

        var y = bounds.minY

        for (subview, item) in zip(subviews, items) {
            let x = item.column.map { column - $0 } ?? 0
            subview.place(at: CGPoint(x: bounds.minX + x, y: y), proposal: item.proposal)
            y += item.dimensions.height
        }
    }
}

// MARK: SettingsFormStack.Item

extension SettingsFormStack {
    /// 量好的一项。
    private struct Item {
        /// 放置时的提议尺寸。
        let proposal: ProposedViewSize

        /// 在这个提议下的尺寸。
        let dimensions: ViewDimensions

        /// 控件列在这一项里的横坐标；为 nil 时这一项不按控件列排。
        let column: CGFloat?
    }
}

// MARK: SettingsFormStack + Measure

extension SettingsFormStack {
    /// 量出每一项：行按左右边距之间的宽度量，标出的控件列位置随之取出；其余内容按整页宽度量。
    private static func measure(_ subviews: Subviews, width: CGFloat) -> [Item] {
        let rowProposal = ProposedViewSize(width: width - SettingsFormLayout.horizontalMargin * 2, height: nil)
        let fullProposal = ProposedViewSize(width: width, height: nil)

        return subviews.map { subview in
            let dimensions = subview.dimensions(in: rowProposal)

            guard let column = dimensions[explicit: .settingsControlColumn] else {
                return Item(
                    proposal: fullProposal,
                    dimensions: subview.dimensions(in: fullProposal),
                    column: nil
                )
            }

            return Item(proposal: rowProposal, dimensions: dimensions, column: column)
        }
    }
}
