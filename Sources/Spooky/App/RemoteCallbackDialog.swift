import AppKit
import SpookyKit
import SwiftUI

// MARK: - RemoteCallbackPrompt

/// 回调中继的一次询问要显示的内容：标题、说明与输入的种类，由请求的种类与 Git 或 SSH 的提示原文决定。
struct RemoteCallbackPrompt {
    /// 输入的种类。
    enum Input {
        /// 用户名：普通输入框。
        case username

        /// 密码与口令：安全输入框。
        case password

        /// 要编辑的文本：等宽的编辑区。
        case text
    }

    /// 对话框标题。
    let title: String

    /// 标题下方的说明：主机或本机仓库的路径，下一行是私钥路径或提示原文。
    let message: String

    /// 输入的种类。
    let input: Input

    /// 输入一开始的内容：编辑器请求是要编辑的文本，其余为空。
    let text: String

    /// 输入框的标签；编辑区没有标签。
    var label: String {
        AppLocalization.text(input == .username ? "callback.username.label" : "callback.password.label")
    }

    /// 由请求得出询问的内容。
    ///
    /// - Parameter request: 回调中继交来的请求。
    @MainActor
    init(request: RemoteCallbackRequest) {
        let prompt = request.prompt.lowercased()
        let privateKey = request.kind == .sshAskpass && prompt.contains("passphrase")

        // 签名口令单独命名：解锁的签名私钥不会加入 SSH agent，不能沿用网络私钥的标题与说明
        switch request.kind {
        case .editor:
            title = AppLocalization.text("callback.editor")
            input = .text

        case .signing:
            title = AppLocalization.text("signing.unlock")
            input = .password

        case .askpass where prompt.hasPrefix("username"):
            title = AppLocalization.text("callback.username.title")
            input = .username

        case .askpass, .sshAskpass, .credential:
            let key = privateKey ? "callback.privateKey.title" : "callback.password.title"
            title = AppLocalization.text(key)
            input = .password
        }

        message = Self.message(for: request, privateKey: privateKey)
        text = request.content ?? ""
    }

    /// 输入能否提交：编辑的文本可以为空，用户名、密码与口令不能。
    func accepts(_ value: String) -> Bool {
        input == .text || !value.isEmpty
    }
}

// MARK: - RemoteCallbackPrompt + Message

extension RemoteCallbackPrompt {
    /// 说明：主机或本机仓库的路径一行，私钥口令下一行是私钥路径，其余是提示原文；
    /// 本机的私钥口令另起一段说明私钥会加入 agent，账号令牌被拒过的地址另起一段写明原因。
    @MainActor
    private static func message(for request: RemoteCallbackRequest, privateKey: Bool) -> String {
        var text = request.host + "\n" + (privateKey ? keyPath(in: request.prompt) : request.prompt)

        if privateKey, request.host.hasPrefix("/") {
            text += "\n\n" + AppLocalization.text("callback.privateKey.help")
        }

        let rejected = request.kind == .askpass
            ? AccountGitCredentials.shared.rejectedAccount(forPrompt: request.prompt)
            : nil

        if let rejected {
            text += "\n\n" + AppLocalization.text("callback.accountTokenRejected", rejected.username)
        }

        return text
    }

    /// SSH 的口令提示 `Enter passphrase for key '<路径>': ` 里单引号之间的私钥路径；提示里没有一对单引号时是提示原文。
    private static func keyPath(in prompt: String) -> String {
        guard
            let open = prompt.firstIndex(of: "'"),
            let close = prompt.lastIndex(of: "'"),
            open < close
        else {
            return prompt
        }

        return String(prompt[prompt.index(after: open) ..< close])
    }
}

// MARK: - RemoteCallbackDialog

/// 回调中继的询问：骨架的表单版，标题按询问的种类写，说明是主机与私钥路径或提示原文。
///
/// 用户名、密码与口令的内容区是带标签的输入框与 “Save in this Mac’s Keychain” 勾选框，按钮是 Cancel 与 OK，输入为空时 OK 不可用；
/// 编辑器请求的内容区是带边框的等宽编辑区，按钮是 Cancel 与 Continue。输入框或编辑区在出现时成为焦点。
struct RemoteCallbackDialog: View {
    /// 询问的内容。
    let prompt: RemoteCallbackPrompt

    /// 关掉对话框。
    let close: () -> Void

    /// 交回输入与是否存进钥匙串，对话框已经关掉；取消时输入为 nil。
    let answer: (_ value: String?, _ saves: Bool) -> Void

    /// 输入的内容。
    @State
    private var value: String

    /// 是否把输入存进这台 Mac 的钥匙串。
    @State
    private var saves = false

    /// 输入框是否有焦点。
    @FocusState
    private var focused: Bool

    /// 头部、输入与底栏。
    var body: some View {
        DialogLayout(
            title: prompt.title,
            message: prompt.message,
            submitTitle: AppLocalization.text(prompt.input == .text ? "action.continue" : "action.ok"),
            canSubmit: prompt.accepts(value),
            cancel: {
                close()
                answer(nil, false)
            },
            submit: {
                close()
                answer(value, saves)
            },
            content: { content }
        )
    }

    /// 创建询问。
    ///
    /// - Parameters:
    ///   - prompt: 询问的内容。
    ///   - close: 关掉对话框。
    ///   - answer: 交回输入与是否存进钥匙串；取消时输入为 nil。
    init(
        prompt: RemoteCallbackPrompt,
        close: @escaping () -> Void,
        answer: @escaping (_ value: String?, _ saves: Bool) -> Void
    ) {
        self.prompt = prompt
        self.close = close
        self.answer = answer
        _value = State(initialValue: prompt.text)
    }
}

// MARK: - Sections

extension RemoteCallbackDialog {
    /// 编辑区占满内容区的宽度，高 260，四周是 1 pt 的边框；其余是一行输入框与它下方的钥匙串勾选框。
    @ViewBuilder
    private var content: some View {
        switch prompt.input {
        case .text:
            RemoteTextEditor(text: $value)
                .frame(height: 260)
                .padding(1)
                .background(AppPalette.color("general_border_color"))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

        case .username, .password:
            DialogForm {
                DialogFormRow(label: prompt.label) {
                    field
                        .focused($focused)
                        .onAppear { focused = true }
                }

                DialogFormOption(title: AppLocalization.text("callback.saveKeychain"), isOn: $saves)
            }
        }
    }

    /// 用户名用普通输入框，密码与口令用安全输入框。
    @ViewBuilder
    private var field: some View {
        if prompt.input == .username {
            TextField("", text: $value)
        } else {
            SecureField("", text: $value)
        }
    }
}

// MARK: - RemoteTextEditor

/// 编辑器请求的编辑区：可以滚动的等宽 11 pt 纯文本，出现时成为焦点；外面一圈 1 pt 的边框由调用方画。
private struct RemoteTextEditor: NSViewRepresentable {
    /// 编辑的文本。
    @Binding
    var text: String

    /// 把编辑结果写回绑定的代理。
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// 纯文本视图，宽度随滚动区，长行折行。
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .noBorder

        guard let textView = scroll.documentView as? NSTextView else {
            return scroll
        }

        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = text
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel(AppLocalization.text("callback.editor"))

        // 文本视图要等进了窗口才能成为焦点
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }

        return scroll
    }

    /// 文本只由编辑区写回，不从外面改写。
    func updateNSView(_: NSScrollView, context _: Context) { }
}

// MARK: RemoteTextEditor.Coordinator

extension RemoteTextEditor {
    /// 文本视图的代理：每次编辑后把内容写回绑定。
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        /// 编辑的文本。
        private let text: Binding<String>

        /// 创建代理。
        ///
        /// - Parameter text: 编辑的文本。
        init(text: Binding<String>) {
            self.text = text
        }

        /// 编辑后写回绑定。
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }
    }
}
