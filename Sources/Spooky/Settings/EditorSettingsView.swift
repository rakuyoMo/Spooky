import AppKit
import SwiftUI

// MARK: - CommitEditorSettings

/// 提交信息编辑器的偏好；Editor 设置页、提交区与提交流程读写同一组键。
enum CommitEditorSettings {
    /// 正文的折行方式。
    enum Wrapping: String, CaseIterable {
        /// 按视图宽度显示折行，提交原文不变。
        case soft

        /// 等宽显示并在字数上限处折行，提交时把这些折行写成换行。
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

    /// 提交时使用的正文折行方式。
    static var wrapping: Wrapping {
        UserDefaults.standard.string(forKey: wrappingKey).flatMap(Wrapping.init(rawValue:)) ?? .soft
    }

    /// 提交时使用的正文每行字数上限。
    static var bodyLineLimit: Int {
        limit(bodyLineLimitKey) ?? defaultBodyLineLimit
    }

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

    /// 读取正整数上限；未设置或不是正数时为 nil。
    static func limit(_ key: String) -> Int? {
        (UserDefaults.standard.object(forKey: key) as? Int).flatMap { $0 > 0 ? $0 : nil }
    }
}

// MARK: - EditorSettingsView

/// Editor 设置页：标题字数、正文折行与注释行处理，修改立即生效。
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

    /// 标签列右对齐，控件列左对齐。
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Toggle(AppLocalization.text("editor.showsCounter"), isOn: $showsCounter)
            }

            // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐。
            GridRow(alignment: .center) {
                Text(AppLocalization.text("editor.subjectLimit"))
                    .gridColumnAlignment(.trailing)
                limitBox($subjectLimit, label: "editor.subjectLimit", choices: CommitEditorSettings.subjectLimitChoices)
            }

            GridRow {
                Text(AppLocalization.text("editor.wrapping"))
                Picker(AppLocalization.text("editor.wrapping"), selection: $wrapping) {
                    Text(AppLocalization.text("editor.softWrap")).tag(CommitEditorSettings.Wrapping.soft.rawValue)
                    Text(AppLocalization.text("editor.hardWrap")).tag(CommitEditorSettings.Wrapping.hard.rawValue)
                }
                .labelsHidden()
                .frame(width: 120)
            }

            // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐。
            GridRow(alignment: .center) {
                Text(AppLocalization.text("editor.bodyLimit"))
                limitBox($bodyLineLimit, label: "editor.bodyLimit", choices: CommitEditorSettings.bodyLineLimitChoices)
            }

            commentRows
        }
        .padding(40)
        .frame(width: 900, height: 300, alignment: .top)
    }
}

// MARK: - Private

extension EditorSettingsView {
    /// 参考线与注释行的三个勾选框；“总是删除” 只在提示关闭时可用。
    @ViewBuilder
    private var commentRows: some View {
        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            Toggle(AppLocalization.text("editor.showsGuide"), isOn: $showsGuide)
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            Toggle(AppLocalization.text("editor.warnsComments"), isOn: $warnsComments)
                .padding(.top, 12)
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            Toggle(AppLocalization.text("editor.stripsComments"), isOn: $stripsComments)
                .disabled(warnsComments)
        }
    }

    /// 60 pt 宽的字数上限组合框。
    private func limitBox(_ value: Binding<Int>, label: String, choices: [Int]) -> some View {
        LimitComboBox(value: value, choices: choices, label: AppLocalization.text(label))
            .frame(width: 60)
    }
}

// MARK: - LimitComboBox

/// 字数上限的组合框：可以从候选值里选，也可以直接输入 1–1000 的整数；输入不是数字时恢复原值。
private struct LimitComboBox: NSViewRepresentable {
    /// 选中候选或结束输入时写回偏好。
    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        /// 要写回的字数上限。
        var value: Binding<Int>

        /// 创建协调器。
        init(value: Binding<Int>) {
            self.value = value
        }

        /// 选中候选值后立即生效；此时组合框的文字还没更新，取选中的候选本身。
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard
                let box = notification.object as? NSComboBox,
                let text = box.objectValueOfSelectedItem as? String
            else { return }

            commit(text, in: box)
        }

        /// 输入结束（回车或离开输入框）时生效。
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }

            commit(box.stringValue, in: box)
        }

        /// 整数限制在 1–1000 后写回；不是整数时恢复原值。
        private func commit(_ text: String, in box: NSComboBox) {
            if let number = Int(text.trimmingCharacters(in: .whitespaces)) {
                value.wrappedValue = max(1, min(number, 1000))
            }

            box.stringValue = String(value.wrappedValue)
        }
    }

    /// 字数上限。
    @Binding
    var value: Int

    /// 下拉列表里的候选值。
    let choices: [Int]

    /// 辅助功能读出的名称。
    let label: String

    /// 创建可编辑、显示 5 个候选的组合框。
    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.isEditable = true
        box.usesDataSource = false
        box.numberOfVisibleItems = 5
        box.addItems(withObjectValues: choices.map(String.init))
        box.stringValue = String(value)
        box.delegate = context.coordinator
        box.setAccessibilityLabel(label)
        return box
    }

    /// 不在编辑时跟随偏好的变化。
    func updateNSView(_ box: NSComboBox, context: Context) {
        context.coordinator.value = $value

        if box.currentEditor() == nil {
            box.stringValue = String(value)
        }
    }

    /// 创建接收选择与输入结束的协调器。
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }
}
