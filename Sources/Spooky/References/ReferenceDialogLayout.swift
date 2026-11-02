import SpookyKit
import SwiftUI

// MARK: - ReferenceDialogLayout

/// 引用管理对话框共用的骨架：头部、内容、错误、仓库不可写的提示、可折叠的选项与底栏，宽 540。
///
/// 主按钮只在内容合法且仓库可写时可用；提交后由各对话框决定何时关闭。
/// 头部文字与错误、不可写的提示对齐内容区的输入列，图标挂在头部文字左侧。
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

    /// 内容区输入列的左缘；内容区没有输入列时为 nil。
    @State
    private var inputColumn: CGFloat?

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
        .coordinateSpace(.named(DialogMetrics.coordinateSpace))
        .onPreferenceChange(DialogInputColumnKey.self) { inputColumn = $0 }
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
    /// 头部文字与提示文字的左缘。
    private var alignment: CGFloat {
        DialogMetrics.textLeading(for: inputColumn)
    }

    /// 校验失败的说明，以及仓库暂不可写的提示。
    @ViewBuilder
    private var notices: some View {
        if !error.isEmpty {
            notice(error)
        }

        // 断线或其它写操作进行中时主按钮禁用，说明原因并保留已填写的参数。
        if !session.canWrite {
            notice(AppLocalization.text("dialog.blocked"))
        }
    }

    /// 头部：图标、标题、服务器仓库的位置与说明；文字从对齐线开始，图标在文字左侧 16 pt。
    private var header: some View {
        HStack(alignment: .top, spacing: DialogMetrics.iconSpacing) {
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
        .padding(.leading, alignment - DialogMetrics.iconSpacing - 64)
        .padding(.trailing, 32)
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

    /// 一条提示：图标挂在对齐线左侧，文字从对齐线开始。
    private func notice(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .padding(.leading, alignment - 4 - 18)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - ReferenceDialogRows

/// 引用管理对话框里重复出现的表格行。
@MainActor
enum ReferenceDialogRows {
    /// 标签列右对齐、输入列占满的一行，标签列的宽度与辅助功能里标签与控件的配对同 `DialogFormRow`。
    static func row(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        let content = field()

        return DialogFormRow(label: label) {
            content
        }
    }

    /// 输入列下方的勾选项，说明紧跟在下面；没有带标签的行时，勾选项本身就是输入列。
    static func option(_ title: String, help: String, isOn: Binding<Bool>) -> some View {
        GridRow {
            Color.clear
                .frame(width: DialogMetrics.labelWidth, height: 0)
                .gridCellUnsizedAxes(.vertical)

            ReferenceOption(title: title, help: help, isOn: isOn)
                .dialogInputColumn()
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
