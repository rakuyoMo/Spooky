import AppKit
import CryptoKit
import Security
import SpookyKit

// MARK: - RemoteCallbackPresenter

/// 在 A 上串行呈现远端凭据与编辑器请求，取消或超时立即结束输入。
@MainActor
final class RemoteCallbackPresenter {
    /// 多窗口共用一个输入队列。
    static let shared = RemoteCallbackPresenter()

    /// 等待呈现的请求与一次性应答。
    private var pending: [(RemoteCallbackRequest, CheckedContinuation<String?, Never>)] = []

    /// 当前正在显示的请求、它的应答与关掉对话框的动作。
    private var current: (
        request: RemoteCallbackRequest,
        continuation: CheckedContinuation<String?, Never>,
        close: () -> Void
    )? = nil

    /// 当前输入的超时任务，与 B 侧的 120 秒上限一致。
    private var timeout: Task<Void, Never>? = nil

    /// 已存凭据直接从 A 的钥匙串取出，其余请求排队呈现；凭据助手的请求交给账号令牌回答。
    func respond(to request: RemoteCallbackRequest) async -> String? {
        guard !Task.isCancelled else { return nil }

        // 账号令牌不经弹框，不能询问用户的操作同样回答；对不上账号时 Git 接着问 askpass
        if request.kind == .credential {
            return await AccountGitCredentials.shared.respond(to: request)
        }

        if request.kind != .editor, let saved = credential(for: request) { return saved }

        // 自动获取等不能询问用户的操作取不到已存凭据时按取消处理，不在后台弹出输入框
        guard request.isInteractive else {
            return nil
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation {
                pending.append((request, $0))
                presentNext()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(request.id) }
        }
    }

    /// 以对话框骨架挂在当前窗口最上层的 sheet 上；找不到窗口时按取消处理。
    private func presentNext() {
        guard current == nil, !pending.isEmpty else { return }
        let (request, continuation) = pending.removeFirst()

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            continuation.resume(returning: nil)
            presentNext()
            return
        }

        let prompt = RemoteCallbackPrompt(request: request)
        var close: () -> Void = { }

        // 挂成 sheet 时立即返回，关掉对话框的动作留给超时与取消
        DialogWindow.present(on: window.attachedSheet ?? window) { dismiss in
            close = dismiss

            return RemoteCallbackDialog(prompt: prompt, close: dismiss) { [weak self] value, saves in
                self?.answer(request, value: value, saves: saves)
            }
        }

        current = (request, continuation, close)
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(120)) }
            catch { return }
            self?.cancel(request.id)
        }
    }

    /// 对话框交回输入：勾选了保存的写进钥匙串，再结束这次请求。
    private func answer(_ request: RemoteCallbackRequest, value: String?, saves: Bool) {
        guard current?.request.id == request.id else { return }

        if let value, saves {
            store(value, for: request)
        }

        finish(request.id, value: value)
    }

    /// 取消正在显示或排队的输入，只有持有应答的一方可以恢复 continuation。
    private func cancel(_ id: String) {
        if let current, current.request.id == id {
            current.close()
            finish(id, value: nil)
        } else if let index = pending.firstIndex(where: { $0.0.id == id }) {
            pending.remove(at: index).1.resume(returning: nil)
        }
    }

    /// 结束一次请求后再呈现下一项，避免同时叠加认证 sheet。
    private func finish(_ id: String, value: String?) {
        guard let active = current, active.request.id == id else { return }
        current = nil
        timeout?.cancel()
        timeout = nil
        active.continuation.resume(returning: value)
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

// MARK: - Host Connections

extension RemoteConnection {
    /// 新建、克隆、扫描与目录浏览用的主机连接：凭据与口令经界面询问，处理器在第一次连接前装上。
    ///
    /// - Parameter alias: `~/.ssh/config` 里的主机别名。
    static func presentingHost(_ alias: String) async -> RemoteConnection {
        let connection = RemoteConnection.host(alias)
        await connection.setCallbackHandler { await RemoteCallbackPresenter.shared.respond(to: $0) }
        return connection
    }
}
