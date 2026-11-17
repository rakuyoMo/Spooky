import Foundation
import Subprocess

// MARK: - LocalCallbackSession

/// 本机进程经回调中继询问口令的一次会话：私有临时目录、中继 socket、项目自带的包装器与它的几个入口。
///
/// 临时目录只存随机令牌；口令通过 socket 返回，不写文件、参数或日志。用完调用 ``close()``。
final class LocalCallbackSession {
    /// 私有临时目录，权限 `0700`。
    let directory: URL

    /// 接收包装器请求的中继。
    let relay: CallbackRelay

    /// 这次会话登记的操作标识，包装器经 `SPOOKY_OPERATION` 带回。
    let operation = UUID().uuidString.lowercased()

    /// 包装器脚本；凭据入口直接调用它。
    let wrapper: URL

    /// 包装器的 askpass 入口，交给 `SSH_ASKPASS`。
    var askpass: String {
        wrapper.path + "-askpass"
    }

    /// 包装器的 Git 凭据入口，交给 `GIT_ASKPASS` 与 `core.askPass`。
    var gitAskpass: String {
        wrapper.path + "-git-askpass"
    }

    /// 包装器的 ssh-keygen 入口，签名私钥的口令请求经它标成签名口令。
    var sshKeygen: String {
        wrapper.path + "-ssh-keygen"
    }

    /// 本机 ssh 经包装器询问私钥口令所需的环境变量。
    var sshOverrides: [Environment.Key: String?] {
        [
            "SPOOKY_SESSION": directory.path,
            "SPOOKY_OPERATION": operation,
            "SSH_ASKPASS": askpass,
            "SSH_ASKPASS_REQUIRE": "force",
            "DISPLAY": "spooky:0",
        ]
    }

    /// 建好临时目录、启动中继并放好包装器。
    ///
    /// - Parameters:
    ///   - host: 询问界面里显示的位置，如仓库的显示路径。
    ///   - handler: 处理口令与凭据请求。
    init(host: String, handler: @escaping RemoteCallbackHandler) throws {
        directory = URL(fileURLWithPath: "/tmp/spooky-local-" + UUID().uuidString.lowercased())

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        wrapper = directory.appendingPathComponent("callback")

        do {
            relay = try CallbackRelay(
                path: directory.appendingPathComponent("relay.sock").path,
                host: host,
                handler: handler
            )
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        // 中途失败时同样撤销登记、停止中继并删掉临时目录
        do {
            try relay.start()
            relay.register(operation)
            try installWrapper()
        } catch {
            close()
            throw error
        }
    }

    /// 撤销登记、停止中继并删掉临时目录。
    func close() {
        relay.unregister(operation)
        relay.stop()
        try? FileManager.default.removeItem(at: directory)
    }
}

// MARK: - Private

extension LocalCallbackSession {
    /// 放好包装器、它的几个入口与只含令牌的会话文件。
    private func installWrapper() throws {
        // 与远端使用相同的一次性协议，脚本内容来自项目自身资源。
        guard let source = Bundle.module.url(forResource: "spooky-remote", withExtension: "pl") else {
            throw RemoteConnectionError(.deployment)
        }

        try FileManager.default.copyItem(at: source, to: wrapper)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: wrapper.path)

        // 包装器按调用名区分模式：ssh-keygen 入口把签名私钥的口令请求标成签名口令，再交给本机的 ssh-keygen。
        for link in [askpass, gitAskpass, sshKeygen] {
            try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: wrapper.path)
        }

        let info = try JSONSerialization.data(withJSONObject: ["token": relay.token])
        let sessionFile = directory.appendingPathComponent("session.json")

        try info.write(to: sessionFile)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sessionFile.path)
    }
}
