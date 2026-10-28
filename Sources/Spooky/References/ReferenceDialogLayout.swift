import SpookyKit
import SwiftUI

// MARK: - ReferenceDialogLayout

/// 引用管理对话框共用的骨架：头部、内容、错误、仓库不可写的提示、可折叠的选项与底栏，宽 540。
///
/// 主按钮只在内容合法且仓库可写时可用；提交后由各对话框决定何时关闭。
struct ReferenceDialogLayout<Content: View, Options: View>: View {
    /// 发起动作的窗口会话，决定仓库路径与是否可写。
    let session: RepositorySession

    /// 对话框标题，也是 VoiceOver 读出的名称。
    let title: String

    /// 标题下方的一句说明。
    let message: String

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

    /// 内容区的表格行。
    let content: () -> Content

    /// 选项区；为 nil 时没有 “Options” 开关。
    let options: (() -> Options)?

    /// 选项展开状态只在本次表单有效。
    @State
    private var optionsExpanded = false

    /// 头部、内容、错误、不可写提示、选项与底栏依次排列。
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 10) {
                content()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            notices

            if let options {
                DisclosureGroup(AppLocalization.text("dialog.options"), isExpanded: $optionsExpanded) {
                    options()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppPalette.color("general_secondary_background_color"))
            }

            footer
        }
        .frame(width: 540)
    }

    /// 创建带选项区的对话框；选项区默认收起。
    init(
        session: RepositorySession,
        title: String,
        message: String,
        submitTitle: String,
        error: String,
        isValid: Bool,
        cancel: @escaping () -> Void,
        submit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder options: @escaping () -> Options
    ) {
        self.session = session
        self.title = title
        self.message = message
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

extension ReferenceDialogLayout where Options == EmptyView {
    /// 没有选项区的对话框。
    init(
        session: RepositorySession,
        title: String,
        message: String,
        submitTitle: String,
        error: String,
        isValid: Bool,
        cancel: @escaping () -> Void,
        submit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.session = session
        self.title = title
        self.message = message
        self.submitTitle = submitTitle
        self.error = error
        self.isValid = isValid
        self.cancel = cancel
        self.submit = submit
        self.content = content
        options = nil
    }
}

// MARK: - Layout

extension ReferenceDialogLayout {
    /// 校验失败的说明，以及仓库暂不可写的提示。
    @ViewBuilder
    private var notices: some View {
        if !error.isEmpty {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.system(size: 12))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }

        // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的参数。
        if !session.canWrite {
            Label(AppLocalization.text("dialog.blocked"), systemImage: "exclamationmark.triangle")
                .font(.system(size: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    /// 头部：图标、标题、服务器仓库的位置与说明。
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))

                // 服务器仓库在标题下写出带主机前缀的位置，本机仓库没有这一行
                if let repository = session.repository, repository.host != nil {
                    Text(repository.displayPath)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(message)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    /// 底栏：取消与主按钮，内容不合法或仓库不可写时主按钮禁用。
    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(AppLocalization.text("action.cancel"), action: cancel)
                .keyboardShortcut(.cancelAction)

            Button(submitTitle, action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || !session.canWrite)
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
    }
}

// MARK: - ReferenceDialogRows

/// 引用管理对话框里重复出现的表格行。
@MainActor
enum ReferenceDialogRows {
    /// 标签列右对齐、输入列占满的一行。
    static func row(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        GridRow {
            Text(label)
                .gridColumnAlignment(.trailing)

            field()
                .accessibilityLabel(label.trimmingCharacters(in: CharacterSet(charactersIn: ":：")))
        }
    }

    /// 输入列下方的勾选项，说明紧跟在下面。
    static func option(_ title: String, help: String, isOn: Binding<Bool>) -> some View {
        GridRow {
            Color.clear
                .gridCellUnsizedAxes([.horizontal, .vertical])

            ReferenceOption(title: title, help: help, isOn: isOn)
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

// MARK: - ReferenceOption

/// 勾选项与它下方的说明；说明用正常文本色，只在禁用时随控件变灰。
struct ReferenceOption: View {
    /// 勾选项标题。
    let title: String

    /// 说明。
    let help: String

    /// 勾选状态。
    @Binding
    var isOn: Bool

    /// 禁用时说明变灰。
    @Environment(\.isEnabled)
    private var isEnabled

    /// 说明左缘对齐勾选框的标题文字；没有说明时只有勾选框。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)

            if !help.isEmpty {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                    .padding(.leading, 19)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
