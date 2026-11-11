import SwiftUI

// MARK: - CommitEditorSettings

/// 提交信息编辑器的偏好；Editor 设置页、提交区与提交流程读写同一组键。
enum CommitEditorSettings {
    /// 正文的折行方式。
    enum Wrapping: String, CaseIterable {
        /// 按视图宽度显示折行，提交原文不变。
        case soft

        /// 只改显示：等宽、不折行，参考线右侧变浅，超过字数上限的行整行标出；提交原文不变。
        case hard
    }

    /// 标题字数上限的偏好键。
    static let subjectLimitKey = "commitSubjectLimit"

    /// 是否显示标题剩余字数的偏好键。
    static let showsSubjectCounterKey = "commitShowsSubjectCounter"

    /// 正文折行方式的偏好键。
    static let wrappingKey = "commitBodyWrapping"

    /// 正文每行字数上限的偏好键。
    static let bodyLineLimitKey = "commitBodyLineLimit"

    /// 硬折行时是否显示参考线的偏好键。
    static let showsGuideKey = "commitShowsBodyGuide"

    /// 信息含注释行时是否提示的偏好键。
    static let warnsCommentsKey = "commitWarnsComments"

    /// 是否总是删除注释行的偏好键；提示打开时不生效。
    static let stripsCommentsKey = "commitStripsComments"

    /// Sign Off 勾选状态的偏好键，所有仓库共用。
    static let signOffKey = "commitSignOff"

    /// 是否在提交信息里补全托管服务上的 Issue 编号的偏好键。
    static let completesIssuesKey = "commitCompletesIssues"

    /// 正文区是否钉住保持展开的偏好键。
    static let pinnedKey = "commitBodyPinned"

    /// 正文区高度的偏好键。
    static let bodyHeightKey = "commitBodyHeight"

    /// 标题字数上限的默认值。
    static let defaultSubjectLimit = 50

    /// 正文每行字数上限的默认值。
    static let defaultBodyLineLimit = 72

    /// 正文区的最小与默认高度。
    static let minimumBodyHeight = 192.0

    /// 标题字数上限组合框里的候选值。
    static let subjectLimitChoices = [50, 60, 70, 72, 80, 100]

    /// 正文每行字数上限组合框里的候选值。
    static let bodyLineLimitChoices = [70, 72, 80, 90, 100]

    /// 提交时是否提示注释行。
    static var warnsComments: Bool {
        UserDefaults.standard.object(forKey: warnsCommentsKey) as? Bool ?? true
    }

    /// 提交时是否直接删除注释行。
    static var stripsComments: Bool {
        UserDefaults.standard.bool(forKey: stripsCommentsKey)
    }

    /// 提交时是否追加 Signed-off-by。
    static var signOff: Bool {
        UserDefaults.standard.bool(forKey: signOffKey)
    }

    /// 是否补全 `#` 之后的 Issue 编号。
    static var completesIssues: Bool {
        UserDefaults.standard.object(forKey: completesIssuesKey) as? Bool ?? true
    }
}

// MARK: - EditorSettingsView

/// Editor 设置页：标题字数、正文折行、注释行处理与 Issue 编号补全，修改立即生效。
struct EditorSettingsView: View {
    /// 是否显示标题剩余字数。
    @AppStorage(CommitEditorSettings.showsSubjectCounterKey)
    private var showsCounter = true

    /// 标题字数上限。
    @AppStorage(CommitEditorSettings.subjectLimitKey)
    private var subjectLimit = CommitEditorSettings.defaultSubjectLimit

    /// 正文折行方式。
    @AppStorage(CommitEditorSettings.wrappingKey)
    private var wrapping = CommitEditorSettings.Wrapping.soft.rawValue

    /// 正文每行字数上限。
    @AppStorage(CommitEditorSettings.bodyLineLimitKey)
    private var bodyLineLimit = CommitEditorSettings.defaultBodyLineLimit

    /// 硬折行时显示参考线。
    @AppStorage(CommitEditorSettings.showsGuideKey)
    private var showsGuide = true

    /// 信息含注释行时提示。
    @AppStorage(CommitEditorSettings.warnsCommentsKey)
    private var warnsComments = true

    /// 总是删除注释行。
    @AppStorage(CommitEditorSettings.stripsCommentsKey)
    private var stripsComments = false

    /// 补全 `#` 之后的 Issue 编号。
    @AppStorage(CommitEditorSettings.completesIssuesKey)
    private var completesIssues = true

    /// 标签列右对齐，控件列从 517 pt 起左对齐。
    var body: some View {
        SettingsForm(layout: .editor) {
            SettingsRow {
                Toggle(AppLocalization.text("editor.showsCounter"), isOn: $showsCounter)
            }

            // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐。
            SettingsRow(AppLocalization.text("editor.subjectLimit"), alignment: .center) {
                limitBox($subjectLimit, label: "editor.subjectLimit", choices: CommitEditorSettings.subjectLimitChoices)
            }
            .padding(.top, SettingsFormLayout.rowSpacing)

            SettingsRow(AppLocalization.text("editor.wrapping")) {
                Picker(AppLocalization.text("editor.wrapping"), selection: $wrapping) {
                    Text(AppLocalization.text("editor.softWrap")).tag(CommitEditorSettings.Wrapping.soft.rawValue)
                    Text(AppLocalization.text("editor.hardWrap")).tag(CommitEditorSettings.Wrapping.hard.rawValue)
                }
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(width: 120)
            }
            .padding(.top, SettingsFormLayout.rowSpacing)

            // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐；字数上限只在硬折行时生效。
            SettingsRow(AppLocalization.text("editor.bodyLimit"), alignment: .center) {
                limitBox($bodyLineLimit, label: "editor.bodyLimit", choices: CommitEditorSettings.bodyLineLimitChoices)
                    .disabled(!hardWraps)
            }
            .padding(.top, SettingsFormLayout.rowSpacing)

            commentRows

            SettingsSeparator(next: .checkbox)

            issueRow
        }
        .frame(height: 360, alignment: .top)
    }
}

// MARK: - Private

extension EditorSettingsView {
    /// 参考线与注释行的三个勾选框；参考线只在硬折行时可用，“总是删除” 只在提示关闭时可用。
    @ViewBuilder
    private var commentRows: some View {
        // 附在正文字数组合框下面的单个勾选框，只在硬折行时生效
        SettingsRow {
            Toggle(AppLocalization.text("editor.showsGuide"), isOn: $showsGuide)
                .disabled(!hardWraps)
        }
        .padding(.top, SettingsFormLayout.rowSpacing)

        // 注释行的两项自成一组，与上面多隔 12
        SettingsRow {
            Toggle(AppLocalization.text("editor.warnsComments"), isOn: $warnsComments)
        }
        .padding(.top, SettingsFormLayout.rowSpacing + 12)

        SettingsRow {
            Toggle(AppLocalization.text("editor.stripsComments"), isOn: $stripsComments)
                .disabled(warnsComments)
        }
        .padding(.top, SettingsFormLayout.checkboxSpacing)
    }

    /// Issue 编号补全的勾选框与 11 pt 说明。
    private var issueRow: some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(AppLocalization.text("editor.completesIssues"), isOn: $completesIssues)

                Text(AppLocalization.text("editor.completesIssues.help"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 正文按硬折行显示；正文的字数上限与参考线只在这时生效。
    private var hardWraps: Bool {
        wrapping == CommitEditorSettings.Wrapping.hard.rawValue
    }

    /// 60 pt 宽的字数上限组合框，可以输入 1–1000。
    private func limitBox(_ value: Binding<Int>, label: String, choices: [Int]) -> some View {
        LimitComboBox(value: value, choices: choices, range: 1 ... 1000, label: AppLocalization.text(label))
            .frame(width: 60)
    }
}
