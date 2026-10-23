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

            GridRow {
                Text(AppLocalization.text("editor.subjectLimit"))
                    .gridColumnAlignment(.trailing)
                limitField($subjectLimit, label: "editor.subjectLimit")
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

            GridRow {
                Text(AppLocalization.text("editor.bodyLimit"))
                limitField($bodyLineLimit, label: "editor.bodyLimit")
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

    /// 60 pt 宽的字数输入框，只接受 1–1000。
    private func limitField(_ value: Binding<Int>, label: String) -> some View {
        TextField("", value: value, format: .number.grouping(.never))
            .frame(width: 60)
            .accessibilityLabel(AppLocalization.text(label))
            .onChange(of: value.wrappedValue) { value.wrappedValue = max(1, min(value.wrappedValue, 1000)) }
    }
}
