import Darwin
import Foundation
import os
import Security
import Synchronization

// MARK: - RemoteCallbackRequest

/// Git 交互请求；令牌留在传输层，不传给 UI 或日志。
public struct RemoteCallbackRequest: Sendable {
    /// 回调类别。
    public enum Kind: String, Sendable, Codable {
        /// Git 的用户名或密码提示。
        case askpass

        /// 仓库所在机器的 SSH 私钥口令。
        case sshAskpass = "ssh-askpass"

        /// 必须交互编辑的文本。
        case editor

        /// 提交签名密钥的口令，来自 gpg 的 loopback 索取或 ssh-keygen 解锁签名私钥。
        case signing
    }

    /// 服务器主机别名或本机仓库路径，用于区分凭据上下文。
    public let host: String

    /// 本次回调的随机标识。
    public let id: String

    /// 来源操作标识。
    public let operation: String

    /// 提示类型，决定使用安全输入框还是文本编辑器。
    public let kind: Kind

    /// Git 或 SSH 的原始提示。
    public let prompt: String

    /// 编辑器的初始文本，仅存在内存中。
    public let content: String?

    /// 发起回调的操作能否询问用户；不能时只用已存的凭据，取不到就按取消处理。
    public let isInteractive: Bool
}

extension RemoteCallbackRequest {
    /// 在本任务里启动的 Git 操作发起回调时能否询问用户；自动获取这类不是用户直接发起的操作置为 false。
    @TaskLocal
    public static var allowsInteraction = true
}

/// UI 返回 nil 表示取消；值只经当前会话的 socket 交回请求进程。
public typealias RemoteCallbackHandler = @Sendable (RemoteCallbackRequest) async -> String?

// MARK: - CallbackRelay

/// 单会话 Unix socket 服务；锁保护描述符、活动操作和一次性请求集合。
final class CallbackRelay: Sendable {
    /// 每次接受的连接有独立身份，防止超时任务误关被复用的描述符。
    private struct Client {
        /// 本机连接身份。
        let id: UUID

        /// 等待用户输入的任务。
        var task: Task<Void, Never>? = nil

        /// 回调所属操作，结束操作时可取消仍在等待的输入。
        var operation: String? = nil

        /// 一条连接只能进入一次应答流程。
        var finishing = false
    }

    /// 传输报文中的令牌只用于验证，不交给上层。
    private struct Message: Decodable {
        /// 随机会话令牌。
        let token: String

        /// 随机请求标识。
        let id: String

        /// 发起回调的命令标识。
        let operation: String

        /// 请求种类。
        let kind: String

        /// 原始提示文字。
        let prompt: String?

        /// 可编辑文本。
        let content: String?
    }

    /// 一次性应答，拒绝时不携带值。
    private struct Response: Encodable {
        /// 用户是否确认输入。
        let accepted: Bool

        /// 只在当前 socket 中传输的输入值。
        let value: String?
    }

    /// 描述符、连接与一次性请求等可变状态，只能在锁内读写。
    private struct State {
        /// 接受连接的文件描述符；停止后置为 -1。
        var descriptor: Int32 = -1

        /// 待处理连接及其回调任务。
        var clients: [Int32: Client] = [:]

        /// 回调交付的凭据只保留到操作结束，用来清除错误与日志中的回显。
        var secrets: [String: [Data]] = [:]

        /// 允许请求凭据的正在运行的操作。
        var operations: Set<String> = []

        /// 其中不能询问用户的操作。
        var quietOperations: Set<String> = []

        /// 每个随机请求仅允许应答一次。
        var requests: Set<String> = []
    }

    /// 回调请求的日志：只记类型与是否应答，提示文字与应答内容都不记录。
    private static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "CallbackRelay")

    /// 本机 socket 的绝对路径。
    let path: String

    /// 256 位随机会话令牌，不进入命令参数和日志。
    let token: String

    /// 当前连接的服务器别名。
    private let host: String

    /// 交互输入由应用或测试提供。
    private let handler: RemoteCallbackHandler

    /// 保护跨 Dispatch 与 Swift 并发访问的状态。
    private let state = Mutex(State())

    /// 独立队列处理有超时的 socket 读取，不占用主线程。
    private let queue = DispatchQueue(label: "com.rakuyo.spooky.relay", attributes: .concurrent)

    /// 安全创建监听端，目录必须由调用者以 0700 创建。
    init(path: String, host: String, handler: @escaping RemoteCallbackHandler) throws {
        self.path = path
        self.host = host
        self.handler = handler
        var bytes = [UInt8](repeating: 0, count: 32)

        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw RemoteConnectionError(.deployment)
        }

        token = bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// 监听仅存在于当前用户私有目录的本机 Unix socket。
    func start() throws {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { throw RemoteConnectionError(.deployment) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let utf8 = Array(path.utf8CString)

        guard utf8.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            Darwin.close(socket)
            throw RemoteConnectionError(.deployment)
        }

        withUnsafeMutableBytes(of: &address.sun_path) {
            $0.copyBytes(from: utf8.map { UInt8(bitPattern: $0) })
        }

        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bound == 0, Darwin.listen(socket, 16) == 0 else {
            Darwin.close(socket)
            throw RemoteConnectionError(.deployment)
        }

        _ = fcntl(socket, F_SETFD, FD_CLOEXEC)
        state.withLock { $0.descriptor = socket }
        queue.async { [weak self] in self?.acceptConnections(socket) }
    }

    /// 主连接关闭时立即终止所有回调并删除本机 socket。
    func stop() {
        let (descriptor, clients) = state.withLock {
            let current = ($0.descriptor, $0.clients)
            $0.descriptor = -1
            $0.operations = []
            $0.quietOperations = []
            return current
        }

        if descriptor >= 0 {
            Darwin.shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
        }

        for (client, entry) in clients {
            entry.task?.cancel()
            Darwin.shutdown(client, SHUT_RDWR)
        }

        unlink(path)
    }

    /// 接受连接后移交并发队列，慢速输入不会阻塞其它操作。
    private func acceptConnections(_ socket: Int32) {
        while state.withLock({ $0.descriptor == socket }) {
            let client = Darwin.accept(socket, nil, nil)
            guard client >= 0 else { break }
            _ = fcntl(client, F_SETFD, FD_CLOEXEC)
            var timeout = timeval(tv_sec: 120, tv_usec: 0)
            var noSignal: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
            setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))

            let id = UUID()
            let accepted = state.withLock {
                guard $0.descriptor == socket, $0.clients.count < 32 else { return false }
                $0.clients[client] = Client(id: id, task: nil)
                return true
            }

            guard accepted else {
                Darwin.close(client)
                continue
            }

            queue.async { [weak self] in self?.receive(client, id: id) }
            queue.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self else { return }
                let task = state.withLock { $0.clients[client]?.id == id ? $0.clients[client]?.task : nil }
                task?.cancel()
                finish(client, id: id, value: nil)
            }
        }
    }

    /// 一条连接承载一个有界 JSON 请求，后续输入不参与第二次应答。
    private func receive(_ client: Int32, id: UUID) {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while data.count <= 8 * 1024 * 1024 {
            let count = Darwin.read(client, &buffer, buffer.count)

            guard count > 0 else {
                finish(client, id: id, value: nil)
                return
            }

            data.append(contentsOf: buffer.prefix(count))

            if data.last == 10 { break }
        }

        guard
            data.count <= 8 * 1024 * 1024,
            let message = try? JSONDecoder().decode(Message.self, from: data),
            validToken(message.token)
        else {
            finish(client, id: id, value: nil)
            return
        }

        let accepted = state.withLock {
            guard
                $0.descriptor >= 0, $0.clients[client]?.id == id,
                !$0.requests.contains(message.id), $0.requests.count < 100_000
            else {
                return false
            }

            // 心跳不占用一次性请求集合；交互请求必须来自已登记的操作。
            if message.kind == "heartbeat" { return true }
            guard $0.operations.contains(message.operation) else { return false }
            $0.requests.insert(message.id)
            $0.clients[client]?.operation = message.operation
            return true
        }

        guard accepted else {
            Self.logger.error("拒绝回调请求：操作未登记、请求重复或会话已关闭")
            finish(client, id: id, value: nil)
            return
        }

        if message.kind == "heartbeat" {
            finish(client, id: id, value: "")
            return
        }

        guard let kind = RemoteCallbackRequest.Kind(rawValue: message.kind) else {
            Self.logger.error("拒绝回调请求：未知的请求类型")
            finish(client, id: id, value: nil)
            return
        }

        Self.logger.info("收到回调请求：\(kind.rawValue, privacy: .public)")
        answer(message, kind: kind, client: client, id: id)
    }

    /// 已接受的交互请求交给界面应答；应答时再次确认操作与连接仍然有效，口令类应答记入脱敏集合。
    private func answer(_ message: Message, kind: RemoteCallbackRequest.Kind, client: Int32, id: UUID) {
        let quiet = state.withLock { $0.quietOperations.contains(message.operation) }

        let request = RemoteCallbackRequest(
            host: host,
            id: message.id,
            operation: message.operation,
            kind: kind,
            prompt: message.prompt ?? "",
            content: message.content,
            isInteractive: !quiet
        )
        let task = Task { [self] in
            let response = await handler(request)
            let active = state.withLock {
                guard
                    $0.operations.contains(message.operation), $0.descriptor >= 0,
                    $0.clients[client]?.id == id
                else { return false }

                if
                    request.kind != .editor,
                    !request.prompt.lowercased().hasPrefix("username"),
                    let response, !response.isEmpty
                {
                    $0.secrets[message.operation, default: []].append(Data(response.utf8))
                }

                return true
            }
            let answered = !Task.isCancelled && active && response != nil
            Self.logger.info("回调请求\(answered ? "已应答" : "未应答，按取消处理", privacy: .public)：\(kind.rawValue, privacy: .public)")

            finish(client, id: id, value: answered ? response : nil)
        }

        state.withLock {
            if $0.clients[client]?.id == id {
                $0.clients[client]?.task = task
            } else {
                task.cancel()
            }
        }
    }

    /// 固定长度比较令牌，拒绝不同会话或伪造的请求。
    private func validToken(_ candidate: String) -> Bool {
        let bytes = Array(candidate.utf8)
        let expected = Array(token.utf8)
        guard bytes.count == expected.count else { return false }
        return zip(bytes, expected).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    /// 应答后总是关闭连接，口令不保存到磁盘或错误值。
    private func finish(_ client: Int32, id: UUID, value: String?) {
        let owned = state.withLock {
            guard let entry = $0.clients[client], entry.id == id, !entry.finishing else { return false }
            $0.clients[client]?.finishing = true
            return true
        }
        guard owned else { return }
        let message = Response(accepted: value != nil, value: value)
        var data = (try? JSONEncoder().encode(message)) ?? Data()
        data.append(10)

        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }

            var offset = 0

            while offset < bytes.count {
                let count = Darwin.write(client, base.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { break }
                offset += count
            }
        }

        state.withLock { _ = $0.clients.removeValue(forKey: client) }
        Darwin.close(client)
    }

}

// MARK: - Operations

extension CallbackRelay {
    /// 操作启动前允许该随机标识发起回调；当前任务不允许询问用户时，记下这个操作只能用已存的凭据。
    func register(_ operation: String) {
        let quiet = !RemoteCallbackRequest.allowsInteraction

        state.withLock {
            $0.operations.insert(operation)
            $0.secrets[operation] = []

            if quiet {
                $0.quietOperations.insert(operation)
            }
        }
    }

    /// 操作结束后拒绝迟到的回调。
    func unregister(_ operation: String) {
        let pending = state.withLock {
            $0.operations.remove(operation)
            $0.quietOperations.remove(operation)
            $0.secrets[operation] = nil
            return $0.clients.filter { $0.value.operation == operation }
        }

        for (client, entry) in pending {
            entry.task?.cancel()
            finish(client, id: entry.id, value: nil)
        }
    }

    /// 读取本操作已经交付的敏感值，供跨输出块脱敏使用。
    func sensitiveValues(for operation: String) -> [Data] {
        state.withLock { $0.secrets[operation] ?? [] }
    }
}
