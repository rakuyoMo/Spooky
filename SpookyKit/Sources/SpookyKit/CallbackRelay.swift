import Darwin
import Foundation
import Security

/// 远端交互请求；令牌留在传输层，不传给 UI 或日志。
public struct RemoteCallbackRequest: Sendable {
    /// 回调类别。
    public enum Kind: String, Sendable, Codable {
        /// Git 的用户名或密码提示。
        case askpass

        /// B 侧 SSH 私钥口令。
        case sshAskpass = "ssh-askpass"

        /// 必须交互编辑的文本。
        case editor
    }

    /// 当前服务器仓库的主机别名。
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
}

/// UI 返回 nil 表示取消；值只经当前主连接交回请求进程。
public typealias RemoteCallbackHandler = @Sendable (RemoteCallbackRequest) async -> String?

/// 单会话 Unix socket 服务；锁保护描述符、活动操作和一次性请求集合。
final class CallbackRelay: @unchecked Sendable {
    /// 本机 socket 的绝对路径。
    let path: String

    /// 256 位随机会话令牌，不进入命令参数和日志。
    let token: String

    /// 当前连接的服务器别名。
    private let host: String

    /// 交互输入由应用或测试提供。
    private let handler: RemoteCallbackHandler

    /// 保护跨 Dispatch 与 Swift 并发访问的状态。
    private let lock = NSLock()

    /// 接受连接的文件描述符；停止后置为 -1。
    private var descriptor: Int32 = -1

    /// 待处理连接及其回调任务。
    private var clients: [Int32: Client] = [:]

    /// 每次接受的连接有独立身份，防止超时任务误关被复用的描述符。
    private struct Client {
        /// 本机连接身份。
        let id: UUID

        /// 等待用户输入的任务。
        var task: Task<Void, Never>?

        /// 回调所属操作，结束操作时可取消仍在等待的输入。
        var operation: String?

        /// 一条连接只能进入一次应答流程。
        var finishing = false
    }

    /// 回调交付的凭据只保留到操作结束，用来清除错误与日志中的回显。
    private var secrets: [String: [Data]] = [:]

    /// 允许请求凭据的正在运行的操作。
    private var operations: Set<String> = []

    /// 每个随机请求仅允许应答一次。
    private var requests: Set<String> = []

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
        lock.withLock { descriptor = socket }
        queue.async { [weak self] in self?.acceptConnections(socket) }
    }

    /// 操作启动前允许该随机标识发起回调。
    func register(_ operation: String) {
        lock.withLock {
            operations.insert(operation)
            secrets[operation] = []
        }
    }

    /// 操作结束后拒绝迟到的回调。
    func unregister(_ operation: String) {
        let pending = lock.withLock {
            operations.remove(operation)
            secrets[operation] = nil
            return clients.filter { $0.value.operation == operation }
        }

        for (client, entry) in pending {
            entry.task?.cancel()
            finish(client, id: entry.id, value: nil)
        }
    }

    /// 读取本操作已经交付的敏感值，供跨输出块脱敏使用。
    func sensitiveValues(for operation: String) -> [Data] {
        lock.withLock { secrets[operation] ?? [] }
    }

    /// 主连接关闭时立即终止所有回调并删除本机 socket。
    func stop() {
        let state = lock.withLock {
            let state = (descriptor, clients)
            descriptor = -1
            operations = []
            return state
        }

        if state.0 >= 0 {
            Darwin.shutdown(state.0, SHUT_RDWR)
            Darwin.close(state.0)
        }

        for (client, entry) in state.1 {
            entry.task?.cancel()
            Darwin.shutdown(client, SHUT_RDWR)
        }

        unlink(path)
    }

    /// 接受连接后移交并发队列，慢速输入不会阻塞其它操作。
    private func acceptConnections(_ socket: Int32) {
        while lock.withLock({ descriptor == socket }) {
            let client = Darwin.accept(socket, nil, nil)
            guard client >= 0 else { break }
            _ = fcntl(client, F_SETFD, FD_CLOEXEC)
            var timeout = timeval(tv_sec: 120, tv_usec: 0)
            var noSignal: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
            setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))

            let id = UUID()
            let accepted = lock.withLock {
                guard descriptor == socket, clients.count < 32 else { return false }
                clients[client] = Client(id: id, task: nil)
                return true
            }

            guard accepted else {
                Darwin.close(client)
                continue
            }

            queue.async { [weak self] in self?.receive(client, id: id) }
            queue.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self else { return }
                let task = self.lock.withLock { self.clients[client]?.id == id ? self.clients[client]?.task : nil }
                task?.cancel()
                self.finish(client, id: id, value: nil)
            }
        }
    }

    /// 一条连接承载一个有界 JSON 请求，后续输入不参与第二次应答。
    private func receive(_ client: Int32, id: UUID) {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while data.count <= 8 * 1024 * 1024 {
            let count = Darwin.read(client, &buffer, buffer.count)
            guard count > 0 else { finish(client, id: id, value: nil); return }
            data.append(contentsOf: buffer.prefix(count))

            if data.last == 10 { break }
        }

        guard data.count <= 8 * 1024 * 1024,
              let message = try? JSONDecoder().decode(Message.self, from: data),
              validToken(message.token)
        else {
            finish(client, id: id, value: nil)
            return
        }

        let accepted = lock.withLock {
            guard descriptor >= 0, clients[client]?.id == id,
                  !requests.contains(message.id), requests.count < 100_000 else {
                return false
            }

            // 心跳不占用一次性请求集合；交互请求必须来自已登记的操作。
            if message.kind == "heartbeat" { return true }
            guard operations.contains(message.operation) else { return false }
            requests.insert(message.id)
            clients[client]?.operation = message.operation
            return true
        }

        guard accepted else { finish(client, id: id, value: nil); return }

        if message.kind == "heartbeat" {
            finish(client, id: id, value: "")
            return
        }

        guard let kind = RemoteCallbackRequest.Kind(rawValue: message.kind) else {
            finish(client, id: id, value: nil)
            return
        }

        let request = RemoteCallbackRequest(
            host: host,
            id: message.id,
            operation: message.operation,
            kind: kind,
            prompt: message.prompt ?? "",
            content: message.content
        )
        let task = Task { [self] in
            let response = await handler(request)
            let active = lock.withLock {
                guard operations.contains(message.operation), descriptor >= 0,
                      clients[client]?.id == id else { return false }

                if request.kind != .editor,
                   !request.prompt.lowercased().hasPrefix("username"),
                   let response, !response.isEmpty {
                    secrets[message.operation, default: []].append(Data(response.utf8))
                }

                return true
            }
            finish(client, id: id, value: !Task.isCancelled && active ? response : nil)
        }

        lock.withLock {
            if clients[client]?.id == id {
                clients[client]?.task = task
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
        let owned = lock.withLock {
            guard clients[client]?.id == id, clients[client]?.finishing == false else { return false }
            clients[client]?.finishing = true
            return true
        }
        guard owned else { return }
        let message = Response(accepted: value != nil, value: value)
        var data = (try? JSONEncoder().encode(message)) ?? Data()
        data.append(10)

        data.withUnsafeBytes { bytes in
            var offset = 0

            while offset < bytes.count {
                let count = Darwin.write(client, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { break }
                offset += count
            }
        }

        lock.withLock { _ = clients.removeValue(forKey: client) }
        Darwin.close(client)
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
}
