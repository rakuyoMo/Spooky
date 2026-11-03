import SpookyKit
import SwiftUI

// MARK: - RepositoryDialogLayout

/// 仓库窗口里操作对话框的骨架：在 `DialogLayout` 外按窗口会话补上仓库位置与可写状态。
///
/// 内容区与选项区都是表单行，如 `RepositoryDialogRows.row` 与 `DialogFormOption`。
/// 服务器仓库在标题下写出带主机前缀的位置；仓库不可写时错误区说明原因，主按钮不可用；提交后由各对话框决定何时关闭。
struct RepositoryDialogLayout<Content: View, Options: View>: View {
    /// 发起动作的窗口会话，决定仓库位置与是否可写。
    let session: RepositorySession

    /// 对话框标题，也是 VoiceOver 读出的名称。
    let title: String

    /// 标题下方的一句说明。
    let message: String

    /// 对话框的宽度。
    let width: CGFloat

    /// 主按钮的标题。
    let submitTitle: String

    /// 校验或加载失败的说明；为空时不显示。
    let error: String

    /// 内容是否完整合法。
    let isValid: Bool

    /// 取消只关闭表单。
    let cancel: () -> Void

    /// 主按钮的动作。
    let submit: () -> Void

    /// 内容区的表单行。
    let content: () -> Content

    /// 选项区的表单行；为 nil 时没有 “Options” 开关。
    let options: (() -> Options)?

    /// 主按钮只在内容合法且仓库可写时可用；选项区的表单上下各留 20。
    var body: some View {
        DialogLayout(
            title: title,
            message: message,
            repository: session.repository,
            width: width,
            submitTitle: submitTitle,
            error: notice,
            canSubmit: isValid && session.canWrite,
            cancel: cancel,
            submit: submit,
            content: { DialogForm(rows: content) },
            options: options.map { options in
                { DialogForm(rows: options).padding(.vertical, 8) }
            }
        )
    }

    /// 创建对话框；选项区由调用方按内容决定有无，默认收起。
    ///
    /// - Parameters:
    ///   - session: 发起动作的窗口会话。
    ///   - title: 标题。
    ///   - message: 标题下方的一句说明。
    ///   - width: 对话框的宽度。
    ///   - submitTitle: 主按钮的标题。
    ///   - error: 校验或加载失败的说明。
    ///   - isValid: 内容是否完整合法。
    ///   - cancel: 取消的动作。
    ///   - submit: 主按钮的动作。
    ///   - options: 选项区的表单行；为 nil 时没有 “Options” 开关。
    ///   - content: 内容区的表单行。
    init(
        session: RepositorySession,
        title: String,
        message: String,
        width: CGFloat = 480,
        submitTitle: String,
        error: String,
        isValid: Bool,
        cancel: @escaping () -> Void,
        submit: @escaping () -> Void,
        options: (() -> Options)?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.session = session
        self.title = title
        self.message = message
        self.width = width
        self.submitTitle = submitTitle
        self.error = error
        self.isValid = isValid
        self.cancel = cancel
        self.submit = submit
        self.content = content
        self.options = options
    }
}

// MARK: - Initializers

extension RepositoryDialogLayout {
    /// 创建带选项区的对话框；选项区默认收起。
    init(
        session: RepositorySession,
        title: String,
        message: String,
        width: CGFloat = 480,
        submitTitle: String,
        error: String,
        isValid: Bool,
        cancel: @escaping () -> Void,
        submit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder options: @escaping () -> Options
    ) {
        self.init(
            session: session,
            title: title,
            message: message,
            width: width,
            submitTitle: submitTitle,
            error: error,
            isValid: isValid,
            cancel: cancel,
            submit: submit,
            options: options,
            content: content
        )
    }
}

extension RepositoryDialogLayout where Options == EmptyView {
    /// 没有选项区的对话框。
    init(
        session: RepositorySession,
        title: String,
        message: String,
        width: CGFloat = 480,
        submitTitle: String,
        error: String,
        isValid: Bool,
        cancel: @escaping () -> Void,
        submit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            session: session,
            title: title,
            message: message,
            width: width,
            submitTitle: submitTitle,
            error: error,
            isValid: isValid,
            cancel: cancel,
            submit: submit,
            options: nil,
            content: content
        )
    }
}

// MARK: - Private

extension RepositoryDialogLayout {
    /// 错误区的文字：校验失败的说明，以及仓库暂不可写的原因；都没有时为 nil。
    private var notice: String? {
        var lines = error.isEmpty ? [] : [error]

        // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的参数
        if !session.canWrite {
            lines.append(AppLocalization.text("dialog.blocked"))
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// MARK: - RepositoryDialogRows

/// 仓库对话框里重复出现的表单行与校验说明。
@MainActor
enum RepositoryDialogRows {
    /// 标签列右对齐、输入列占满的一行，标签列的宽度与辅助功能里标签与控件的配对同 `DialogFormRow`。
    static func row(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        let content = field()

        return DialogFormRow(label: label) {
            content
        }
    }

    /// 校验失败的说明：名字、地址与 refspec 不合法时写出所填的值，其余失败给出 Git 原文。
    static func validationMessage(_ error: any Error, in session: RepositorySession) -> String {
        switch error {
        case ReferenceError.invalidName(let name):
            AppLocalization.text("reference.invalidName", name)

        case ReferenceError.invalidRefspec(let refspec):
            AppLocalization.text("reference.invalidRefspec", refspec)

        case ReferenceError.invalidURL(let url):
            AppLocalization.text("reference.invalidURL", url)

        default:
            AppFailure(error: error, opening: false, location: session.repository).details
        }
    }
}
