import SwiftUI

// MARK: - SettingsFormLayout

/// 设置页表单的列位置与行距：标签列右对齐，控件列在固定位置左对齐，各页只给出自己的控件列。
///
/// 横向坐标都相对 900 pt 宽的设置窗口左缘，指控件可见边框的位置；标签的右缘在控件列左侧 8 pt。
///
/// 纵向间距是相邻两行布局框之间的距离：弹出菜单的布局框就是可见边框，单行勾选框的布局框上下就是方块；
/// 组合框的 1 pt 描边画在布局框外，与它相邻的可见间距比给出的值小 1 pt。
struct SettingsFormLayout {
    /// 设置窗口的宽度。
    static let windowWidth: CGFloat = 900

    /// 内容距窗口上下边缘。
    static let verticalMargin: CGFloat = 20

    /// 标签列距窗口左缘、控件列距窗口右缘的最小距离；标签或控件过长时在这里折行。
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

    /// 附在弹出菜单下面的勾选框与下一个弹出菜单的距离。
    static let popUpAfterCheckboxSpacing: CGFloat = 20

    /// 弹出菜单与下方勾选框组的距离。
    static let checkboxGroupSpacing: CGFloat = 12

    /// 勾选框之间的距离，两行的勾选框也一样。
    static let checkboxSpacing: CGFloat = 6

    /// 控件列的左缘。
    let controlLeading: CGFloat

    /// 弹出菜单与组合框的宽度，也是勾选框与说明文字折行的宽度。
    var controlWidth: CGFloat = 278

    /// 标签列的宽度：从左边距到标签右缘。
    var labelWidth: CGFloat {
        controlLeading - Self.labelSpacing - Self.horizontalMargin
    }
}

// MARK: SettingsFormLayout + Pages

extension SettingsFormLayout {
    /// General 页。
    static let general = Self(controlLeading: 530)

    /// Appearance 页：缩略图选择器宽 278。
    static let appearance = Self(controlLeading: 242)

    /// Git Config 页：弹出菜单宽 310。
    static let gitConfig = Self(controlLeading: 490, controlWidth: 310)

    /// Text 页：控件按内容取宽。
    static let text = Self(controlLeading: 367)

    /// Editor 页：字数组合框宽 60，折行方式的弹出菜单宽 120。
    static let editor = Self(controlLeading: 517)

    /// Integration 页：弹出菜单宽 254。
    static let integration = Self(controlLeading: 562, controlWidth: 254)

    /// Updates 页：弹出菜单宽 250。
    static let updates = Self(controlLeading: 558, controlWidth: 250)
}

// MARK: - EnvironmentValues + SettingsFormLayout

extension EnvironmentValues {
    /// 所在设置页表单的列位置；不在表单里时按 General 页。
    @Entry
    var settingsFormLayout = SettingsFormLayout.general
}

// MARK: - SettingsForm

/// 设置页的表单：各行自上而下排列，距窗口上下边缘各 20 pt，宽同窗口；列位置经环境交给各行。
///
/// 行距由各行用 `padding(.top:)` 按 ``SettingsFormLayout`` 的行距给出，分组之间放 ``SettingsSeparator``。
struct SettingsForm<Rows: View>: View {
    /// 这一页的列位置。
    let layout: SettingsFormLayout

    /// 表单的行与分隔线。
    @ViewBuilder
    let rows: () -> Rows

    /// 左对齐、不加行距的一列；分隔线把它撑到窗口宽。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rows()
        }
        .padding(.vertical, SettingsFormLayout.verticalMargin)
        .frame(width: SettingsFormLayout.windowWidth, alignment: .topLeading)
        .environment(\.settingsFormLayout, layout)
    }
}

// MARK: - SettingsRow

/// 表单的一行：标签右对齐在标签列，控件从控件列左缘开始；没有标签时标签列留空。
struct SettingsRow<Control: View>: View {
    /// 所在页的列位置。
    @Environment(\.settingsFormLayout)
    private var layout

    /// 已本地化的标签，带冒号；为 nil 时标签列留空。
    let label: String?

    /// 标签与控件的竖直对齐。
    let alignment: VerticalAlignment

    /// 控件列里的内容。
    @ViewBuilder
    let control: () -> Control

    /// 有标签时标签与控件并排，没有时控件直接从控件列左缘开始。
    var body: some View {
        Group {
            if let label {
                HStack(alignment: alignment, spacing: SettingsFormLayout.labelSpacing) {
                    Text(label)
                        .multilineTextAlignment(.trailing)
                        .frame(width: layout.labelWidth, alignment: .trailing)

                    control()
                }
                .padding(.leading, SettingsFormLayout.horizontalMargin)
            } else {
                control()
                    .padding(.leading, layout.controlLeading)
            }
        }
        .padding(.trailing, SettingsFormLayout.horizontalMargin)
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

/// 分组之间的分隔线：横贯整页，左右各距窗口边缘 40 pt；上方距上一组最后一个控件 16 pt，下方距下一组第一行的标签 16 pt。
struct SettingsSeparator: View {
    /// 下一组打头的一行。
    enum NextRow {
        /// 弹出菜单或输入框：行的顶边是控件的顶边，比标签高出 ``SettingsFormLayout/controlLabelInset``。
        case control

        /// 勾选框：行的顶边就是文字的顶边。
        case checkbox
    }

    /// 下一组打头的一行。
    var next = NextRow.control

    /// 1 pt 的分隔线与上下的间距。
    var body: some View {
        Divider()
            .padding(.horizontal, SettingsFormLayout.separatorInset)
            .padding(.top, SettingsFormLayout.separatorSpacing)
            .padding(.bottom, bottomSpacing)
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
    /// 控件占满控件列的宽度并左对齐：弹出菜单拉宽到列宽，勾选框与说明文字在列宽内折行。
    func settingsColumnWidth() -> some View {
        modifier(SettingsColumnWidth())
    }
}

// MARK: - SettingsColumnWidth

/// 按所在页的控件宽度排布控件。
private struct SettingsColumnWidth: ViewModifier {
    /// 所在页的列位置。
    @Environment(\.settingsFormLayout)
    private var layout

    /// 弹出菜单按可用宽度拉宽，其余控件在列宽内左对齐。
    func body(content: Content) -> some View {
        content
            .buttonSizing(.flexible)
            .frame(width: layout.controlWidth, alignment: .leading)
    }
}
