import Darwin
import Foundation
import NetFS
import Synchronization

// MARK: - SMBMount

/// 经 NetFS 挂载 B 已有的 SMB 共享，挂在系统默认的位置（`/Volumes/<共享名>`）。
///
/// 账号与密码由系统的登录框与钥匙串处理，Spooky 不读取、不保存。
enum SMBMount {
    /// 挂载 SMB 共享；同一个共享已经挂着时（不论是谁挂的）算挂上，不挂第二次。
    ///
    /// 地址只有服务器、允许界面时，系统弹出共享列表让用户选；不允许界面时不弹登录框，也不弹共享列表，这时没有可挂的共享。
    ///
    /// - Parameters:
    ///   - host: 主机别名，地址的主机取 `ssh -G` 的 `hostname`。
    ///   - share: 记下的共享；nil 时挂 `smb://<主机>/`。
    ///   - allowsInteraction: 是否允许系统的登录框与共享列表。
    static func mount(host: String, share: URL?, allowsInteraction: Bool) async -> Result<Void, RemoteMountFailure> {
        let url: URL? = if let share { share } else { await serverURL(of: host) }

        guard let url else {
            return .failure(.smb(status: EHOSTUNREACH))
        }

        let options = NSMutableDictionary()
        options[kNAUIOptionKey] = allowsInteraction ? kNAUIOptionAllowUI : kNAUIOptionNoUI

        // 主机是本机地址（如 127.0.0.1）时，系统不带这个键一律拒绝挂载，返回 EHOSTUNREACH；它只影响这种情形
        options[kNetFSAllowLoopbackKey] = true

        let status = await withCheckedContinuation { continuation in
            let reported = Mutex(false)

            let finish: @Sendable (Int32) -> Void = { status in
                let first = reported.withLock { done in
                    defer { done = true }
                    return !done
                }

                guard first else {
                    return
                }

                continuation.resume(returning: status)
            }

            var request: AsyncRequestID? = nil

            let started = NetFSMountURLAsync(
                url as CFURL,
                nil,
                nil,
                nil,
                options,
                nil,
                &request,
                DispatchQueue.global()
            ) { status, _, _ in
                finish(status)
            }

            // 没能开始时完成块不会调用
            if started != 0 {
                finish(started)
            }
        }

        return outcome(of: status)
    }

    /// 主机别名所指机器的 SMB 根地址 `smb://<主机>/`；IPv6 地址加方括号。读不到主机时为 nil。
    ///
    /// - Parameter host: 主机别名。
    static func serverURL(of host: String) async -> URL? {
        guard let name = await RemoteMountLocator.serverName(of: host) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "smb"
        components.path = "/"

        if name.contains(":") {
            components.percentEncodedHost = "[" + name + "]"
        } else {
            components.host = name
        }

        return components.url
    }

    /// NetFS 的状态换成挂载结果：`0` 是挂上；`EEXIST` 是这个共享已经挂着，同样算挂上；其余都是失败。
    ///
    /// - Parameter status: NetFS 完成块或调用本身返回的状态。
    static func outcome(of status: Int32) -> Result<Void, RemoteMountFailure> {
        status == 0 || status == EEXIST ? .success(()) : .failure(.smb(status: status))
    }
}
