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
            let sheet = NSWindow()
            sheet.styleMask = [.titled]
            sheet.tabbingMode = .disallowed

            let dialog = ConfigureExternalToolDialog(merge: merge) { [weak window, weak sheet] tool in
                if let window, let sheet {
                    window.endSheet(sheet)
                }

                continuation.resume(returning: tool)
            }

            sheet.contentViewController = NSHostingController(rootView: dialog)
            window.beginSheet(sheet)
        }
    }
}

// MARK: - ConfigureExternalToolDialog

/// 选择外部工具的对话框：头部的标题与说明、一行工具弹出菜单、取消与 Select。
struct ConfigureExternalToolDialog: View {
    /// 选合并工具；否则选比较工具。
    let merge: Bool

    /// 结束对话框：选中的工具，取消时为 nil。
    let finish: (ExternalTool?) -> Void

    /// 弹出菜单里选中的标识；空字符串表示还没有选。
    @State
    private var selection = ""

    /// 头部、内容与底栏依次排列，宽 540。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 10) {
                GridRow {
                    Text(AppLocalization.text(merge ? "externalTool.mergeTool" : "externalTool.diffTool"))
                        .gridColumnAlignment(.trailing)

                    ExternalToolPopUp(selection: $selection, merge: merge)
                        .frame(width: 278)
                        .accessibilityLabel(
                            AppLocalization.text(merge ? "externalTool.mergeTool" : "externalTool.diffTool")
                        )
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            footer
        }
        .frame(width: 540)
    }
}

// MARK: - Layout

extension ConfigureExternalToolDialog {
    /// 头部：图标、标题与一句说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text(merge ? "externalTool.configureMerge" : "externalTool.configureDiff"))
                    .font(.system(size: 14, weight: .bold))

                Text(AppLocalization.text(
                    merge ? "externalTool.configureMerge.message" : "externalTool.configureDiff.message"
                ))
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 底栏：取消与 Select；还没有选工具时 Select 不可用。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel")) { finish(nil) }
                .keyboardShortcut(.cancelAction)

            Button(AppLocalization.text("externalTool.select")) {
                finish(ExternalTool(rawValue: selection))
            }
            .keyboardShortcut(.defaultAction)
            .disabled(ExternalTool(rawValue: selection) == nil)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }
}
