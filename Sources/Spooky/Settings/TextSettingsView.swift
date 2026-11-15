import SwiftUI

// MARK: - TextSettingsView

/// 设置 → Text：语法着色、不可见字符与 Tab 宽度三组，组间是横贯整页的分隔线，修改立即生效。
struct TextSettingsView: View {
    /// 页高：比三组合起来高，Tab 宽度一行下方留出空白。
    private static let pageHeight: CGFloat = 214

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

    /// 数字框里的文字：结束输入时才换成空格数。
    @State
    private var tabWidthText = ""

    /// 标签列右对齐，控件列左对齐。
    var body: some View {
        SettingsForm {
            SettingsRow(AppLocalization.text("text.syntaxColoring")) {
                VStack(alignment: .leading, spacing: SettingsFormLayout.checkboxSpacing) {
                    Toggle(AppLocalization.text("text.enableSyntaxColoring"), isOn: $colorsSyntax)

                    // Diff 着色是总开关下的子选项
                    Toggle(AppLocalization.text("text.syntaxColoringInDiffs"), isOn: $colorsDiffSyntax)
                        .padding(.leading, 20)
                        .disabled(!colorsSyntax)
                }
            }

            SettingsSeparator(next: .checkbox)

            SettingsRow(AppLocalization.text("text.invisibles")) {
                Toggle(AppLocalization.text("text.showInvisibles"), isOn: $showsInvisibles)
            }

            SettingsSeparator()

            SettingsRow(AppLocalization.text("text.tabWidth")) {
                tabWidthControl
            }
        }
        .frame(height: Self.pageHeight, alignment: .top)
    }

    /// 30 pt 宽的数字框、1–100 的步进器与单位。
    private var tabWidthControl: some View {
        HStack(spacing: 8) {
            SettingsTextField(
                text: $tabWidthText,
                label: AppLocalization.text("text.tabWidth"),
                alignment: .right
            ) {
                commitTabWidth($0)
            }
            .frame(width: 30)
            .onChange(of: tabWidth, initial: true) {
                tabWidthText = String(tabWidth)
            }

            Stepper("", value: $tabWidth, in: TextPreferences.tabWidths)
                .labelsHidden()
                .accessibilityLabel(AppLocalization.text("text.tabWidth"))

            Text(AppLocalization.text("text.spaces"))
        }
    }

    /// 结束输入时换成空格数：超出范围时取最近的边界，不是整数时恢复原值。
    private func commitTabWidth(_ text: String) {
        if let number = Int(text.trimmingCharacters(in: .whitespaces)) {
            let range = TextPreferences.tabWidths
            tabWidth = min(max(number, range.lowerBound), range.upperBound)
        }

        tabWidthText = String(tabWidth)
    }
}
