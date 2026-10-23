import AppKit
import CryptoKit
import Security
import SpookyKit

/// 在 A 上串行呈现远端凭据与编辑器请求，取消或超时立即结束输入。
@MainActor
final class RemoteCallbackPresenter {
    /// 多窗口共用一个输入队列。
    static let shared = RemoteCallbackPresenter()

    /// 等待呈现的请求与一次性应答。
    private var pending: [(RemoteCallbackRequest, CheckedContinuation<String?, Never>)] = []

    /// 当前正在显示的请求。
    private var current: (RemoteCallbackRequest, CheckedContinuation<String?, Never>, NSAlert)? = nil

    /// 当前输入的超时任务，与 B 侧的 120 秒上限一致。
    private var timeout: Task<Void, Never>? = nil

    /// 已存凭据直接从 A 的钥匙串取出，其余请求排队呈现。
    func respond(to request: RemoteCallbackRequest) async -> String? {
        guard !Task.isCancelled else { return nil }

        if request.kind != .editor, let saved = credential(for: request) { return saved }

        return await withTaskCancellationHandler {
            await withCheckedContinuation {
                pending.append((request, $0))
                presentNext()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(request.id) }
        }
    }

    /// 使用安全输入框或可滚动文本编辑器；Git 原始提示保持原文。
    private func presentNext() {
        guard current == nil, !pending.isEmpty else { return }
        let (request, continuation) = pending.removeFirst()
        let alert = NSAlert()
        let privateKey = request.kind == .sshAskpass && request.prompt.lowercased().contains("passphrase")

        // 签名口令单独命名：解锁的签名私钥不会加入 SSH agent，不能沿用网络私钥的说明。
        let title: String =
            switch request.kind {
            case .editor: "callback.editor"
            case .signing: "signing.unlock"
            case .askpass, .sshAskpass: privateKey ? "callback.privateKey" : "callback.credentials"
            }
        alert.messageText = AppLocalization.text(title)
        alert.informativeText = request.host + "\n" + request.prompt
            + (
                privateKey && request.host.hasPrefix("/")
                    ? "\n\n" + AppLocalization.text("callback.privateKey.help")
                    : ""
            )
        alert.addButton(withTitle: AppLocalization.text("action.continue"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))
        let input: NSView
        let value: () -> String
        let save = NSButton(checkboxWithTitle: AppLocalization.text("callback.saveKeychain"), target: nil, action: nil)

        if request.kind == .editor {
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
            scroll.hasVerticalScroller = true
            let editor = NSTextView(frame: scroll.bounds)
            editor.isRichText = false
            editor.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            editor.string = request.content ?? ""
            editor.setAccessibilityLabel(AppLocalization.text("callback.editor"))
            scroll.documentView = editor
            input = scroll
            value = { editor.string }
        } else {
            let field: NSTextField = request.kind == .askpass && request.prompt.lowercased().hasPrefix("username")
                ? NSTextField()
                : NSSecureTextField()
            field.setAccessibilityLabel(AppLocalization.text("callback.value"))
            field.frame = NSRect(x: 0, y: 36, width: 400, height: 24)
            save.frame = NSRect(x: 0, y: 0, width: 400, height: 24)
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 64))
            container.addSubview(field)
            container.addSubview(save)
            input = container
            value = { field.stringValue }
        }

        alert.accessoryView = input
        current = (request, continuation, alert)
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(120)) }
            catch { return }
            self?.cancel(request.id)
        }

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            finish(request.id, value: nil)
            return
        }

        alert.beginSheetModal(for: window.attachedSheet ?? window) { [weak self] response in
            guard let self, current?.0.id == request.id else { return }
            let answer = response == .alertFirstButtonReturn ? value() : nil

            if let answer, request.kind != .editor, save.state == .on {
                store(answer, for: request)
            }

            finish(request.id, value: answer)
        }
    }

    /// 取消正在显示或排队的输入，只有持有应答的一方可以恢复 continuation。
    private func cancel(_ id: String) {
        if let current, current.0.id == id {
            current.2.window.sheetParent?.endSheet(current.2.window, returnCode: .cancel)
            finish(id, value: nil)
        } else if let index = pending.firstIndex(where: { $0.0.id == id }) {
            pending.remove(at: index).1.resume(returning: nil)
        }
    }

    /// 结束一次请求后再呈现下一项，避免同时叠加认证 sheet。
    private func finish(_ id: String, value: String?) {
        guard let active = current, active.0.id == id else { return }
        current = nil
        timeout?.cancel()
        timeout = nil
        active.1.resume(returning: value)
        presentNext()
    }

    /// 钥匙串条目按服务器和提示隔离，账户键使用摘要而非原始提示。
    private func keychainQuery(_ request: RemoteCallbackRequest) -> [String: Any] {
        let identity = Data((request.kind.rawValue + "\n" + request.prompt).utf8)
        let account = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rakuyo.spooky.remote." + request.host,
            kSecAttrAccount as String: account,
        ]
    }

    /// 只从当前用户的 A 侧钥匙串读取，不接触 B 的图形钥匙串。
    private func credential(for request: RemoteCallbackRequest) -> String? {
        var query = keychainQuery(request)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef? = nil
        guard
            SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
            let data = value as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 仅在用户明确勾选保存时写钥匙串，不写 UserDefaults 或仓库记录。
    private func store(_ value: String, for request: RemoteCallbackRequest) {
        let query = keychainQuery(request)
        let attributes = [kSecValueData as String: Data(value.utf8)]
        let result = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if result == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
    }
}
