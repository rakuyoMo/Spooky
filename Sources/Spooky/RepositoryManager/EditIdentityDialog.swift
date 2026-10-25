import SwiftUI

// MARK: - EditIdentityDialog

/// 编辑只对这个仓库生效的提交人：姓名与邮箱，两项都填了才能提交。
struct EditIdentityDialog: View {
    /// 关闭对话框。
    let close: () -> Void

    /// 提交姓名与邮箱。
    let submit: (String, String) -> Void

    /// 姓名。
    @State
    private var name: String

    /// 邮箱。
    @State
    private var email: String

    /// “Name:” “Email:” 两行表单。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("bookmarks.identity.edit"),
            message: AppLocalization.text("bookmarks.identity.message"),
            submitTitle: AppLocalization.text("action.ok"),
            error: nil,
            canSubmit: !trimmed(name).isEmpty && !trimmed(email).isEmpty,
            cancel: close,
            submit: {
                close()
                submit(trimmed(name), trimmed(email))
            }
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("bookmarks.identity.name")) {
                    TextField("", text: $name, prompt: Text(AppLocalization.text("bookmarks.identity.namePrompt")))
                        .accessibilityIdentifier("identity-name")
                }

                DialogFormRow(label: AppLocalization.text("bookmarks.identity.email")) {
                    TextField("", text: $email, prompt: Text(AppLocalization.text("bookmarks.identity.emailPrompt")))
                        .accessibilityIdentifier("identity-email")
                }
            }
        }
    }

    /// 预填当前提交人。
    ///
    /// - Parameters:
    ///   - name: 当前姓名。
    ///   - email: 当前邮箱。
    ///   - close: 关闭对话框。
    ///   - submit: 提交姓名与邮箱。
    init(name: String, email: String, close: @escaping () -> Void, submit: @escaping (String, String) -> Void) {
        _name = State(initialValue: name)
        _email = State(initialValue: email)
        self.close = close
        self.submit = submit
    }

    /// 去掉首尾空白。
    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
