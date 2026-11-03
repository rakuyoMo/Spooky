import SwiftUI

// MARK: - ConfirmationDialog

/// 会话请求的确认：对话框骨架的确认版，只有头部与底栏。
///
/// 请求带着可以关掉的确认项时，内容区是一个 “Do not ask me again” 勾选框，左缘对齐对齐线，下方留 20 pt；
/// 勾选只在确认时生效。
struct ConfirmationDialog: View {
    /// 会话发来的确认请求。
    let request: ConfirmationRequest

    /// 关闭对话框。
    let close: () -> Void

    /// 是否勾选了 “Do not ask me again”。
    @State
    private var suppresses = false

    /// 标题、说明与两个按钮，以及可选的勾选框。
    var body: some View {
        DialogLayout(
            title: request.title,
            message: request.message,
            submitTitle: request.submitTitle,
            cancel: close,
            submit: confirm
        ) {
            if request.suppression != nil {
                Toggle(AppLocalization.text("dialog.doNotAskAgain"), isOn: $suppresses)
                    .padding(.leading, DialogMetrics.alignment)
                    .padding(.bottom, 20)
            }
        }
    }

    /// 先关闭对话框，勾选了不再提醒时关掉这项确认，再执行操作。
    private func confirm() {
        close()

        if suppresses {
            request.suppression?.isEnabled = false
        }

        request.action()
    }
}
