import SwiftUI

// MARK: - WorkingCopySettingsRows

/// General 页里工作区文件列表的四行设置：双击与空格的动作、字号与长文件名的截断位置。
struct WorkingCopySettingsRows: View {
    #warning("TODO: 核实字号与截断方式的默认值，目前为 Regular 与 Truncate middle；只影响还没有改过这两项设置时的列表外观")

    /// 双击文件的动作。
    @AppStorage(WorkingCopyPreferences.doubleClickAction)
    private var doubleClick = WorkingCopyPreferences.DoubleClickAction.openFile

    /// 空格键的动作。
    @AppStorage(WorkingCopyPreferences.spacebarAction)
    private var spacebar = WorkingCopyPreferences.SpacebarAction.toggleStaging

    /// 文件列表的字号。
    @AppStorage(WorkingCopyPreferences.fontSize)
    private var fontSize = WorkingCopyPreferences.FontSize.regular

    /// 长文件名的截断位置。
    @AppStorage(WorkingCopyPreferences.truncation)
    private var truncation = WorkingCopyPreferences.Truncation.middle

    /// 与 General 页其它行相同：右对齐的标签加 278 pt 宽的弹出菜单。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("files.doubleClick"))
            picker("files.doubleClick", selection: $doubleClick) { action in
                switch action {
                case .openFile: AppLocalization.text("files.doubleClick.openFile")
                case .openDiff: AppLocalization.text("files.doubleClick.openDiff")
                }
            }
        }

        GridRow {
            Text(AppLocalization.text("files.spacebar"))
            picker("files.spacebar", selection: $spacebar) { action in
                switch action {
                case .toggleStaging: AppLocalization.text("files.spacebar.toggleStaging")
                case .quickLook: AppLocalization.text("files.spacebar.quickLook")
                }
            }
        }

        GridRow {
            Text(AppLocalization.text("files.fontSize"))
            picker("files.fontSize", selection: $fontSize) { size in
                switch size {
                case .regular: AppLocalization.text("files.fontSize.regular")
                case .medium: AppLocalization.text("files.fontSize.medium")
                }
            }
        }

        GridRow {
            Text(AppLocalization.text("files.truncation"))
            picker("files.truncation", selection: $truncation) { mode in
                switch mode {
                case .beginning: AppLocalization.text("files.truncation.beginning")
                case .middle: AppLocalization.text("files.truncation.middle")
                }
            }
        }
    }

    /// 选项逐个列出的弹出菜单，标签只给辅助技术使用。
    private func picker<Option: CaseIterable & Hashable>(
        _ key: String,
        selection: Binding<Option>,
        title: @escaping (Option) -> String
    ) -> some View where Option.AllCases: RandomAccessCollection {
        Picker("", selection: selection) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                Text(title(option)).tag(option)
            }
        }
        .labelsHidden()
        .frame(width: 278)
        .accessibilityLabel(AppLocalization.text(key))
    }
}
