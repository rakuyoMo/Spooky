import SwiftUI

// MARK: - ConfirmationDialog

/// 对话框骨架的确认版：只有头部与底栏，内容区最多一个勾选框。
///
/// 勾选框左缘对齐对齐线，下方留 20 pt；它的状态交给主按钮与备选按钮的动作，取消时不生效。
/// 每个按钮都先关闭对话框，再执行各自的动作。
struct ConfirmationDialog: View {
    /// 标题，是一个名词短语。
    let title: String

    /// 写明影响范围的说明。
    let message: String

    /// 主按钮的标题，写出要执行的动作。
    let submitTitle: String

    /// 取消按钮的标题。
    let cancelTitle: String

    /// 备选按钮的标题与动作；为 nil 时用普通底栏。
    let alternate: (title: String, action: (_ checked: Bool) -> Void)?

    /// 内容区勾选框的标题；为 nil 时没有勾选框。
    let checkbox: String?

    /// 关闭对话框。
    let close: () -> Void

    /// 取消后执行，此时对话框已经关闭。
    let cancel: () -> Void

    /// 选了主按钮后执行，此时对话框已经关闭；参数是勾选框是否勾上。
    let submit: (_ checked: Bool) -> Void

    /// 是否勾上了内容区的勾选框。
    @State
    private var checked = false

    /// 标题、说明与底栏，以及可选的勾选框。
    var body: some View {
        DialogLayout(
            title: title,
            message: message,
            submitTitle: submitTitle,
            cancelTitle: cancelTitle,
            alternate: alternate.map { alternate in
                (title: alternate.title, action: { choose(alternate.action) })
            },
            cancel: {
                close()
                cancel()
            },
            submit: { choose(submit) }
        ) {
            if let checkbox {
                Toggle(checkbox, isOn: $checked)
                    .padding(.leading, DialogMetrics.alignment)
                    .padding(.bottom, 20)
            }
        }
    }

    /// 创建确认对话框。
    ///
    /// - Parameters:
    ///   - title: 标题。
    ///   - message: 说明。
    ///   - submitTitle: 主按钮的标题。
    ///   - cancelTitle: 取消按钮的标题。
    ///   - alternate: 备选按钮的标题与动作，动作的参数是勾选框是否勾上。
    ///   - checkbox: 内容区勾选框的标题。
    ///   - close: 关闭对话框。
    ///   - cancel: 取消后执行。
    ///   - submit: 选了主按钮后执行。
    init(
        title: String,
        message: String,
        submitTitle: String,
        cancelTitle: String = AppLocalization.text("action.cancel"),
        alternate: (title: String, action: (_ checked: Bool) -> Void)? = nil,
        checkbox: String? = nil,
        close: @escaping () -> Void,
        cancel: @escaping () -> Void = { },
        submit: @escaping (_ checked: Bool) -> Void
    ) {
        self.title = title
        self.message = message
        self.submitTitle = submitTitle
        self.cancelTitle = cancelTitle
        self.alternate = alternate
        self.checkbox = checkbox
        self.close = close
        self.cancel = cancel
        self.submit = submit
    }

    /// 呈现会话请求的确认：请求带着可以关掉的确认项时，内容区是 “Do not ask me again”，勾上并确认后关掉这项确认。
    ///
    /// - Parameters:
    ///   - request: 会话发来的确认请求。
    ///   - close: 关闭对话框。
    init(request: ConfirmationRequest, close: @escaping () -> Void) {
        self.init(
            title: request.title,
            message: request.message,
            submitTitle: request.submitTitle,
            checkbox: request.suppression.map { _ in AppLocalization.text("dialog.doNotAskAgain") },
            close: close
        ) { checked in
            if checked {
                request.suppression?.isEnabled = false
            }

            request.action()
        }
    }
}

// MARK: - Private

extension ConfirmationDialog {
    /// 先关闭对话框，再带着勾选框的状态执行所选按钮的动作。
    private func choose(_ action: (_ checked: Bool) -> Void) {
        close()
        action(checked)
    }
}
