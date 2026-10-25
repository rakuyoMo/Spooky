import AppKit
import SwiftUI

// MARK: - ExternalToolSettingsRows

/// Git Config 页的外部工具组：比较工具与目录对比、合并工具与保留冲突备份文件。
///
/// 与 General 页的写法相同：放在 `Grid` 里，标签右对齐，控件列 278 pt。
struct ExternalToolSettingsRows: View {
    /// 比较工具的标识；空字符串表示还没有选。
    @AppStorage(ExternalTool.diffToolKey)
    private var diffTool = ""

    /// 多个文件时比较两个目录。
    @AppStorage(ExternalTool.compareDirectoryKey)
    private var compareDirectory = true

    /// 合并工具的标识；空字符串表示还没有选。
    @AppStorage(ExternalTool.mergeToolKey)
    private var mergeTool = ""

    /// 合并工具写回结果时保留冲突文件的备份。
    @AppStorage(ExternalTool.keepBackupsKey)
    private var keepBackups = false

    /// 比较工具一行、目录对比一行、合并工具一行、保留备份一行。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("externalTool.diffTool"))
                .gridColumnAlignment(.trailing)

            ExternalToolPopUp(selection: $diffTool, merge: false)
                .frame(width: 278)
                .accessibilityLabel(AppLocalization.text("externalTool.diffTool"))
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text("externalTool.directoryDiff"), isOn: $compareDirectory)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 278, alignment: .leading)
        }

        GridRow {
            Text(AppLocalization.text("externalTool.mergeTool"))

            ExternalToolPopUp(selection: $mergeTool, merge: true)
                .frame(width: 278)
                .accessibilityLabel(AppLocalization.text("externalTool.mergeTool"))
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text("externalTool.keepBackups"), isOn: $keepBackups)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 278, alignment: .leading)
        }
    }
}

// MARK: - ExternalToolPopUp

/// 选择外部工具的弹出菜单：首项是 “None selected”，已安装的工具带应用图标，没有安装的带标记且不能选。
struct ExternalToolPopUp: View {
    /// 所选工具的标识；空字符串表示没有选。
    @Binding
    var selection: String

    /// 只列出能合并的工具。
    let merge: Bool

    /// 工具按固定顺序列出。
    var body: some View {
        Picker("", selection: $selection) {
            Text(AppLocalization.text("externalTool.noneSelected")).tag("")

            ForEach(ExternalTool.allCases.filter { !merge || $0.supportsMerge }) { tool in
                let application = tool.applicationURL

                HStack(spacing: 8) {
                    icon(application)

                    Text(tool.displayName)
                }
                .tag(tool.rawValue)
                .selectionDisabled(application == nil)
                .accessibilityLabel(
                    application == nil
                        ? AppLocalization.text("externalTool.notInstalled", tool.displayName)
                        : tool.displayName
                )
            }
        }
        .labelsHidden()
    }

    /// 已安装的工具显示应用图标；没有安装的显示提示标记。
    @ViewBuilder
    private func icon(_ application: URL?) -> some View {
        if let application {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "exclamationmark.circle")
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }
}
