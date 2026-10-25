import SwiftUI

// MARK: - EditDescriptionDialog

/// 编辑仓库描述：一个输入框，提交后对话框立即关闭，写入随后进行。
struct EditDescriptionDialog: View {
    /// 关闭对话框。
    let close: () -> Void

    /// 提交新的描述。
    let submit: (String) -> Void

    /// 输入框里的描述。
    @State
    private var text: String

    /// “Description:” 一行表单。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("bookmarks.description.edit"),
            message: AppLocalization.text("bookmarks.description.message"),
            submitTitle: AppLocalization.text("action.ok"),
            error: nil,
            canSubmit: true,
            cancel: close,
            submit: {
                close()
                submit(text)
            }
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("bookmarks.description.label")) {
                    TextField("", text: $text)
                        .accessibilityIdentifier("repository-description")
                }
            }
        }
    }

    /// 预填当前描述。
    ///
    /// - Parameters:
    ///   - text: 当前描述。
    ///   - close: 关闭对话框。
    ///   - submit: 提交新的描述。
    init(text: String, close: @escaping () -> Void, submit: @escaping (String) -> Void) {
        _text = State(initialValue: text)
        self.close = close
        self.submit = submit
    }
}
