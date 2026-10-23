import SwiftUI

// MARK: - TextSettingsView

/// 设置 → Text：语法着色、不可见字符与 Tab 宽度三组，组间用分隔线隔开，修改立即生效。
struct TextSettingsView: View {
    /// 语法着色总开关。
    @AppStorage(TextPreferences.syntaxColoringKey)
    private var colorsSyntax = true

    /// Diff 中的语法着色。
    @AppStorage(TextPreferences.diffSyntaxColoringKey)
    private var colorsDiffSyntax = false

    /// 标出不可见字符。
    @AppStorage(TextPreferences.showsInvisiblesKey)
    private var showsInvisibles = false

    /// 一个制表符占的空格数。
    @AppStorage(TextPreferences.tabWidthKey)
    private var tabWidth = TextPreferences.defaultTabWidth

    /// 标签列右对齐，控件列左对齐。
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 16) {
            GridRow(alignment: .firstTextBaseline) {
                label("text.syntaxColoring")

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(AppLocalization.text("text.enableSyntaxColoring"), isOn: $colorsSyntax)

                    // Diff 着色是总开关下的子选项
                    Toggle(AppLocalization.text("text.syntaxColoringInDiffs"), isOn: $colorsDiffSyntax)
                        .padding(.leading, 20)
                        .disabled(!colorsSyntax)
                }
            }

            Divider()
                .gridCellColumns(2)

            GridRow(alignment: .firstTextBaseline) {
                label("text.invisibles")
                Toggle(AppLocalization.text("text.showInvisibles"), isOn: $showsInvisibles)
            }

            Divider()
                .gridCellColumns(2)

            GridRow(alignment: .firstTextBaseline) {
                label("text.tabWidth")
                tabWidthControl
            }
        }
        .padding(40)
        .frame(width: 900, height: 260, alignment: .top)
    }

    /// 30 pt 宽的数字框、1–100 的步进器与单位。
    private var tabWidthControl: some View {
        HStack(spacing: 8) {
            TextField("", value: $tabWidth, format: .number.grouping(.never))
                .frame(width: 30)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(AppLocalization.text("text.tabWidth"))
                .onChange(of: tabWidth) {
                    tabWidth = min(max(tabWidth, TextPreferences.tabWidths.lowerBound), TextPreferences.tabWidths.upperBound)
                }

            Stepper("", value: $tabWidth, in: TextPreferences.tabWidths)
                .labelsHidden()
                .accessibilityLabel(AppLocalization.text("text.tabWidth"))

            Text(AppLocalization.text("text.spaces"))
        }
    }

    /// 右对齐的行标签。
    private func label(_ key: String) -> some View {
        Text(AppLocalization.text(key))
            .gridColumnAlignment(.trailing)
    }
}
