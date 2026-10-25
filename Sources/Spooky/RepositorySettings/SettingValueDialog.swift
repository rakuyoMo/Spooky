import SwiftUI

// MARK: - SettingValueDialog

/// 修改仓库设置里的一项：一个输入框，值不合法或为空时主按钮禁用；提交后对话框立即关闭，写入随后进行。
struct SettingValueDialog: View {
    /// 输入框的标签，带冒号。
    let label: String

    /// 值的问题；没有问题时为 nil。
    let problem: (String) -> String?

    /// 关闭对话框。
    let close: () -> Void

    /// 提交新的值。
    let submit: (String) -> Void

    /// 输入框里的值。
    @State
    private var value: String

    /// 标签与一个输入框。
    var body: some View {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let issue = trimmed.isEmpty ? nil : problem(trimmed)

        DialogLayout(
            title: AppLocalization.text(
                "repositorySettings.edit.title",
                label.trimmingCharacters(in: CharacterSet(charactersIn: ":："))
            ),
            message: AppLocalization.text("repositorySettings.edit.message"),
            submitTitle: AppLocalization.text("action.ok"),
            error: issue,
            canSubmit: !trimmed.isEmpty && issue == nil,
            cancel: close,
            submit: {
                close()
                submit(trimmed)
            }
        ) {
            DialogForm {
                DialogFormRow(label: label) {
                    TextField("", text: $value)
                        .accessibilityIdentifier("setting-value")
                }
            }
        }
    }

    /// 预填当前值。
    ///
    /// - Parameters:
    ///   - label: 输入框的标签。
    ///   - value: 当前值。
    ///   - problem: 值的问题。
    ///   - close: 关闭对话框。
    ///   - submit: 提交新的值。
    init(
        label: String,
        value: String,
        problem: @escaping (String) -> String?,
        close: @escaping () -> Void,
        submit: @escaping (String) -> Void
    ) {
        self.label = label
        self.problem = problem
        self.close = close
        self.submit = submit
        _value = State(initialValue: value)
    }
}
