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

    /// 标签列右对齐，控件列从 367 pt 起左对齐。
    var body: some View {
        SettingsForm(layout: .text) {
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
        .frame(height: 260, alignment: .top)
    }

    /// 30 pt 宽的数字框、1–100 的步进器与单位。
    private var tabWidthControl: some View {
        HStack(spacing: 8) {
            TextField("", value: $tabWidth, format: .number.grouping(.never))
                .frame(width: 30)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(AppLocalization.text("text.tabWidth"))
                .onChange(of: tabWidth) {
                    let range = TextPreferences.tabWidths
                    tabWidth = min(max(tabWidth, range.lowerBound), range.upperBound)
                }

            Stepper("", value: $tabWidth, in: TextPreferences.tabWidths)
                .labelsHidden()
                .accessibilityLabel(AppLocalization.text("text.tabWidth"))

            Text(AppLocalization.text("text.spaces"))
        }
    }
}
