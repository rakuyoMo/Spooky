import Darwin
import Foundation
import Synchronization

// MARK: - RemoteMountMethod

/// Spooky 能把服务器仓库挂到这台 Mac 的方式。
public enum RemoteMountMethod: Sendable, Hashable {
    /// 经 NetFS 挂载 B 已有的 SMB 共享。
    case smb

    /// 用 sshfs 经 SFTP 挂载仓库目录。
    case sshfs
}

// MARK: - RemoteMountFailure

/// 挂载失败的原因；不含账号与密码。
public enum RemoteMountFailure: Error, Sendable, Equatable {
    /// NetFS 返回的状态：正数是 errno，负数是 OSStatus（`-128` 是在登录框或共享列表里取消）。
    case smb(status: Int32)

    /// sshfs 以非零状态结束，带它原样的标准错误。
    case sshfs(status: Int32, standardError: String)

    /// sshfs 没能启动，带系统给的说明。
    case launch(String)

    /// NetFS 状态的系统说明：正数按 POSIX 错误、负数按 OSStatus 取。
    ///
    /// - Parameter status: NetFS 返回的状态。
    public static func description(ofSMBStatus status: Int32) -> String {
        let domain = status > 0 ? NSPOSIXErrorDomain : NSOSStatusErrorDomain

        return NSError(domain: domain, code: Int(status)).localizedDescription
    }
}

// MARK: - RemoteMounter

/// 检测挂载方式与执行挂载的入口；测试换成不做真实挂载的实现。
///
/// 任何路径都不卸载：卷由用户在 Finder 里推出。
public struct RemoteMounter: Sendable {
    /// 真实的检测与挂载。
    public static let live = Self(
        methods: { await RemoteMountDetection.live.methods(for: $0) },
        mountSMB: { await SMBMount.mount(host: $0, share: $1, allowsInteraction: $2) },
        mountSSHFS: { host, path, folder, handler in
            await SSHFSMount.mount(host: host, path: path, at: folder, handler: handler)
        }
    )

    /// 主机别名现在可用的挂载方式。
    public var methods: @Sendable (_ host: String) async -> Set<RemoteMountMethod>

    /// 挂载 SMB 共享：给了记下的共享时挂它，否则挂主机的根地址、由用户在共享列表里选；最后一个参数为是否允许系统界面。
    public var mountSMB: @Sendable (_ host: String, _ share: URL?, _ allowsInteraction: Bool) async
        -> Result<Void, RemoteMountFailure>

    /// 用 sshfs 把 B 上的仓库目录挂到本机文件夹；给了回调时经它询问私钥口令，没有给时不询问。
    public var mountSSHFS:
        @Sendable (_ host: String, _ path: String, _ folder: URL, _ handler: RemoteCallbackHandler?) async
        -> Result<Void, RemoteMountFailure>
}

// MARK: - RemoteMountDetection

/// 挂载方式的可用条件：SMB 要在时限内连得上主机的 445 端口，sshfs 要找得到可执行文件。
struct RemoteMountDetection: Sendable {
    /// SMB 的端口。
    static let smbPort: UInt16 = 445

    /// 真实的检测：主机取 `ssh -G` 的 `hostname`，2 秒内连得上它解析出的任一地址就算 SMB 可用。
    static let live = Self(
        timeout: .seconds(2),
        connectsSMB: { host in
            guard let name = await RemoteMountLocator.serverName(of: host) else {
                return false
            }

            return await TCPPort.connects(to: name, port: smbPort)
        },
        sshfsExecutable: { SSHFSMount.executable() }
    )

    /// SMB 端口检测的时限，含解析主机的时间。
    let timeout: Duration

    /// 能否连上主机别名所指机器的 SMB 端口；自己不限时，取消时尽快结束。
    let connectsSMB: @Sendable (String) async -> Bool

    /// 找到的 sshfs 可执行文件；没有装时为 nil。
    let sshfsExecutable: @Sendable () -> String?

    /// 主机别名现在可用的挂载方式。
    ///
    /// - Parameter host: `~/.ssh/config` 里的主机别名。
    func methods(for host: String) async -> Set<RemoteMountMethod> {
        var methods: Set<RemoteMountMethod> = []

        if sshfsExecutable() != nil {
            methods.insert(.sshfs)
        }

        if await reachesSMB(host) {
            methods.insert(.smb)
        }

        return methods
    }

    /// 在时限内连得上 SMB 端口；超时算连不上，进行中的连接随之取消。
    private func reachesSMB(_ host: String) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await connectsSMB(host) }

            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }

            let first = await group.next() ?? false
            group.cancelAll()

            return first
        }
    }
}

// MARK: - TCPPort

/// 不交换数据的 TCP 端口检测。
enum TCPPort {
    /// 主机名解析出的任一地址连得上这个端口时为 true；全部连不上时为 false。不自己限时，取消时尽快结束。
    ///
    /// - Parameters:
    ///   - name: 主机名或数字地址。
    ///   - port: 端口。
    static func connects(to name: String, port: UInt16) async -> Bool {
        let cancellation = Cancellation()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    continuation.resume(returning: attempt(name, port: port, cancellation: cancellation))
                }
            }
        } onCancel: {
            cancellation.flag.withLock { $0 = true }
        }
    }
}

// MARK: - Private

extension TCPPort {
    /// 跨线程查看的取消标记。
    private final class Cancellation: Sendable {
        /// 调用方是否已取消。
        let flag = Mutex(false)
    }

    /// 对全部地址同时发起非阻塞连接，等到第一个连上、全部失败或调用方取消。
    private static func attempt(_ name: String, port: UInt16, cancellation: Cancellation) -> Bool {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM

        var list: UnsafeMutablePointer<addrinfo>? = nil

        guard getaddrinfo(name, String(port), &hints, &list) == 0, let list else {
            return false
        }

        defer { freeaddrinfo(list) }

        var pending: [Int32] = []
        defer { for item in pending { _ = close(item) } }

        for entry in sequence(first: list, next: { $0.pointee.ai_next }) {
            let descriptor = socket(entry.pointee.ai_family, entry.pointee.ai_socktype, entry.pointee.ai_protocol)

            guard descriptor >= 0 else {
                continue
            }

            _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)

            if connect(descriptor, entry.pointee.ai_addr, entry.pointee.ai_addrlen) == 0 {
                _ = close(descriptor)
                return true
            }

            if errno == EINPROGRESS {
                pending.append(descriptor)
            } else {
                _ = close(descriptor)
            }
        }

        return wait(for: &pending, cancellation: cancellation)
    }

    /// 等进行中的连接：每次最多等 100 ms 再看一次取消标记；失败的连接从列表里关掉移除。
    private static func wait(for pending: inout [Int32], cancellation: Cancellation) -> Bool {
        while !pending.isEmpty, !cancellation.flag.withLock({ $0 }) {
            var descriptors = pending.map { pollfd(fd: $0, events: Int16(POLLOUT), revents: 0) }
            let ready = poll(&descriptors, nfds_t(descriptors.count), 100)

            guard ready > 0 else {
                if ready < 0, errno != EINTR {
                    return false
                }

                continue
            }

            for descriptor in descriptors where descriptor.revents != 0 {
                var error: Int32 = 0
                var length = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(descriptor.fd, SOL_SOCKET, SO_ERROR, &error, &length)

                if error == 0, descriptor.revents & Int16(POLLOUT) != 0 {
                    return true
                }

                _ = close(descriptor.fd)
                pending.removeAll { $0 == descriptor.fd }
            }
        }

        return false
    }
}
