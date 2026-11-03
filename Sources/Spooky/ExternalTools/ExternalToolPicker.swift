import AppKit
import SwiftUI

// MARK: - ExternalToolPicker

/// 取得要启动的外部工具：已经选过就直接使用，还没有选时先弹出 Configure Diff Tool / Configure Merge Tool。
@MainActor
enum ExternalToolPicker {
    /// 已选的工具；还没有选时在窗口上弹出选择对话框，选中的工具写进偏好。
    ///
    /// - Parameters:
    ///   - merge: 选合并工具；否则选比较工具。
    ///   - window: 对话框所附的仓库窗口。
    /// - Returns: 要启动的工具；用户取消或没有窗口可附时为 nil。
    static func tool(merge: Bool, in window: NSWindow?) async -> ExternalTool? {
        if let tool = ExternalTool.selected(merge: merge) {
            return tool
        }

        guard let window else {
            return nil
        }

        let tool = await choose(merge: merge, in: window)

        if let tool {
            UserDefaults.standard.set(tool.rawValue, forKey: merge ? ExternalTool.mergeToolKey : ExternalTool.diffToolKey)
        }

        return tool
    }

    /// 以 sheet 显示选择对话框，等用户选择或取消。
    private static func choose(merge: Bool, in window: NSWindow) async -> ExternalTool? {
        await withCheckedContinuation { continuation in
            DialogWindow.present(on: window) { close in
                ConfigureExternalToolDialog(merge: merge) { tool in
                    close()
                    continuation.resume(returning: tool)
                }
            }
        }
    }
}

// MARK: - ConfigureExternalToolDialog

/// 选择外部工具的对话框：对话框骨架里一行填满输入列的工具弹出菜单，底栏是取消与 Select。
struct ConfigureExternalToolDialog: View {
    /// 选合并工具；否则选比较工具。
    let merge: Bool

    /// 结束对话框：选中的工具，取消时为 nil。
    let finish: (ExternalTool?) -> Void

    /// 弹出菜单里选中的标识；空字符串表示还没有选。
    @State
    private var selection = ""

    /// 还没有选工具时 Select 不可用。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text(merge ? "externalTool.configureMerge" : "externalTool.configureDiff"),
            message: AppLocalization.text(
                merge ? "externalTool.configureMerge.message" : "externalTool.configureDiff.message"
            ),
            submitTitle: AppLocalization.text("externalTool.select"),
            canSubmit: ExternalTool(rawValue: selection) != nil,
            cancel: { finish(nil) },
            submit: { finish(ExternalTool(rawValue: selection)) }
        ) {
            DialogForm {
                DialogFormRow(
                    label: AppLocalization.text(
                        merge ? "externalTool.dialog.mergeTool" : "externalTool.dialog.diffTool"
                    )
                ) {
                    ExternalToolPopUp(selection: $selection, merge: merge)
                        .buttonSizing(.flexible)
                }
            }
        }
    }
}
