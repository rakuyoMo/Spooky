import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RemoteCallbackDialogTests

/// 回调中继的询问：标题按询问的种类写，说明是主机与私钥路径或提示原文；用户名用普通输入框，密码与口令用安全输入框，
/// 输入为空时 OK 不可用；编辑器请求是等宽编辑区，按钮是 Continue。
///
/// 控件经辅助功能接口读取，进程没有辅助功能权限时跳过这几项。
@MainActor
struct RemoteCallbackDialogTests {
    /// 私钥口令、用户名、HTTPS 与 SSH 的密码、签名口令与编辑器请求各有自己的标题与输入的种类。
    @Test("各种询问的标题与输入的种类")
    func titles() {
        let privateKey = Self.prompt(.sshAskpass, "Enter passphrase for key '/tmp/id_test': ")
        let username = Self.prompt(.askpass, "Username for 'https://example.com': ")
        let password = Self.prompt(.askpass, "Password for 'https://me@example.com': ")
        let sshPassword = Self.prompt(.sshAskpass, "me@example.com's password: ")
        let signing = Self.prompt(.signing, "Enter passphrase for \"/tmp/signing\": ")
        let editor = Self.prompt(.editor, "/srv/repo/.git/COMMIT_EDITMSG", content: "Message\n")

        let cases: [(prompt: RemoteCallbackPrompt, title: String, input: RemoteCallbackPrompt.Input)] = [
            (privateKey, "callback.privateKey.title", .password),
            (username, "callback.username.title", .username),
            (password, "callback.password.title", .password),
            (sshPassword, "callback.password.title", .password),
            (signing, "signing.unlock", .password),
            (editor, "callback.editor", .text),
        ]

        for (prompt, title, input) in cases {
            #expect(prompt.title == AppLocalization.text(title), "\(title)")
            #expect(prompt.input == input, "\(title)")
        }

        #expect(username.label == AppLocalization.text("callback.username.label"))
        #expect(password.label == AppLocalization.text("callback.password.label"))
        #expect(editor.text == "Message\n")
    }

    /// 私钥口令的说明是主机一行、私钥路径一行，本机仓库另起一段说明私钥会加入 agent；
    /// 提示里取不到路径时照写提示原文；其余询问是主机与提示原文。
    @Test("说明写出主机与私钥路径或提示原文")
    func messages() {
        let path = "/tmp/key dir/it's_test"
        let passphrase = "Enter passphrase for key '\(path)': "
        let password = "Password for 'https://example.com': "
        let help = AppLocalization.text("callback.privateKey.help")
        let server = "spooky-test"

        #expect(Self.prompt(.sshAskpass, passphrase).message == "/tmp/repository\n" + path + "\n\n" + help)
        #expect(Self.prompt(.sshAskpass, passphrase, host: server).message == server + "\n" + path)
        #expect(Self.prompt(.sshAskpass, "Enter passphrase:", host: server).message == server + "\nEnter passphrase:")
        #expect(Self.prompt(.askpass, password, host: server).message == server + "\n" + password)
    }

    /// 用户名、密码与口令为空时不能提交；编辑的文本可以为空，提交空文本由 Git 自己处理。
    @Test("空输入时不能提交")
    func acceptsInput() {
        let username = Self.prompt(.askpass, "Username for 'https://example.com': ")
        let passphrase = Self.prompt(.sshAskpass, "Enter passphrase for key '/k': ")
        let editor = Self.prompt(.editor, "/srv/repo/.git/COMMIT_EDITMSG")

        #expect(!username.accepts(""))
        #expect(username.accepts("me"))
        #expect(!passphrase.accepts(""))
        #expect(passphrase.accepts(" "))
        #expect(editor.accepts(""))
    }

    /// 私钥口令：“Password:” 标签加安全输入框，从输入列伸到右边距 20；钥匙串勾选框在输入框那一列、默认不勾；
    /// 按钮是 Cancel 与 OK，空口令时 OK 不可用。点 Cancel 先关掉对话框，再交回取消。
    @Test("口令询问的输入框、勾选框与按钮", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func passwordControls() throws {
        let prompt = Self.prompt(.sshAskpass, "Enter passphrase for key '/tmp/id_test': ")
        let cancel = AppLocalization.text("action.cancel")
        var events: [String] = []

        let elements = AccessibilityProbe.elements(until: { Self.buttons(in: $0).count == 2 }) {
            RemoteCallbackDialog(prompt: prompt, close: { events.append("close") }) { value, saves in
                events.append("answer \(value ?? "nil") \(saves)")
            }
        }

        let label = AppLocalization.text("callback.password.label")
        let field = try #require(elements.first { $0.role == "AXTextField" && $0.title == label })
        let save = try #require(elements.first { $0.role == "AXCheckBox" })

        #expect(field.subrole == "AXSecureTextField")
        #expect(abs(field.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(field.frame.maxX - 460) <= 1)
        #expect(save.name == AppLocalization.text("callback.saveKeychain"))
        #expect(save.value == "0")
        #expect(abs(save.frame.minX - field.frame.minX) <= 1)
        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == prompt.title })
        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == prompt.message })

        let buttons = Self.buttons(in: elements)

        #expect(buttons.map(\.name) == [cancel, AppLocalization.text("action.ok")])
        #expect(buttons.map(\.isEnabled) == [true, false])

        _ = AccessibilityProbe.elements(pressing: [cancel], until: { _ in !events.isEmpty }) {
            RemoteCallbackDialog(prompt: prompt, close: { events.append("close") }) { value, saves in
                events.append("answer \(value ?? "nil") \(saves)")
            }
        }

        #expect(events == ["close", "answer nil false"])
    }

    /// 用户名：“Username:” 标签加普通输入框。
    @Test("用户名询问用普通输入框", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func usernameField() throws {
        let prompt = Self.prompt(.askpass, "Username for 'https://example.com': ")

        let elements = AccessibilityProbe.elements(until: { Self.buttons(in: $0).count == 2 }) {
            RemoteCallbackDialog(prompt: prompt, close: { }, answer: { _, _ in })
        }

        let label = AppLocalization.text("callback.username.label")
        let field = try #require(elements.first { $0.role == "AXTextField" && $0.title == label })

        #expect(field.subrole != "AXSecureTextField")
        #expect(Self.buttons(in: elements).map(\.isEnabled) == [true, false])
    }

    /// 编辑器请求：等宽编辑区写着要编辑的文本、占满内容区的宽度，没有钥匙串勾选框；
    /// 按钮是 Cancel 与 Continue，点 Continue 先关掉对话框，再交回编辑区的文本。
    @Test("编辑器请求的编辑区与按钮", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func editorControls() throws {
        let prompt = Self.prompt(.editor, "/srv/repo/.git/COMMIT_EDITMSG", content: "Fix the parser\n")
        let cancel = AppLocalization.text("action.cancel")
        let submit = AppLocalization.text("action.continue")
        var events: [String] = []

        let elements = AccessibilityProbe.elements(pressing: [submit], until: { _ in !events.isEmpty }) {
            RemoteCallbackDialog(prompt: prompt, close: { events.append("close") }) { value, saves in
                events.append("answer \(value ?? "nil") \(saves)")
            }
        }

        let editor = try #require(elements.first { $0.role == "AXTextArea" })

        // 宽度量外面的滚动区：系统显示常驻滚动条时，文本区让出滚动条的宽度
        let area = try #require(elements.first {
            $0.role == "AXScrollArea" && $0.frame.contains(editor.frame.origin)
        })

        #expect(editor.name == AppLocalization.text("callback.editor"))
        #expect(editor.value == "Fix the parser\n")
        #expect(abs(area.frame.minX - 21) <= 1)
        #expect(abs(area.frame.maxX - 459) <= 1)
        #expect(!elements.contains { $0.role == "AXCheckBox" })
        #expect(Self.buttons(in: elements).map(\.name) == [cancel, submit])
        #expect(events == ["close", "answer Fix the parser\n false"])
    }
}

// MARK: - Helpers

extension RemoteCallbackDialogTests {
    /// 一次可以询问用户的回调请求要显示的内容。
    ///
    /// - Parameters:
    ///   - kind: 回调类别。
    ///   - text: 提示原文。
    ///   - host: 主机别名或本机仓库路径。
    ///   - content: 编辑器的初始文本。
    private static func prompt(
        _ kind: RemoteCallbackRequest.Kind,
        _ text: String,
        host: String = "/tmp/repository",
        content: String? = nil
    ) -> RemoteCallbackPrompt {
        let request = RemoteCallbackRequest(
            host: host,
            id: UUID().uuidString,
            operation: UUID().uuidString,
            kind: kind,
            prompt: text,
            content: content,
            isInteractive: true
        )

        return RemoteCallbackPrompt(request: request)
    }

    /// 底栏的按钮，从左到右；不含窗口标题栏上的按钮。
    private static func buttons(in elements: [AccessibilityProbe.Element]) -> [AccessibilityProbe.Element] {
        elements
            .filter { $0.role == "AXButton" && $0.frame.minY > 30 && !$0.name.isEmpty }
            .sorted { $0.frame.minX < $1.frame.minX }
    }
}
