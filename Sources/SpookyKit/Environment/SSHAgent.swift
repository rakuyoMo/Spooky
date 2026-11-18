import Foundation
import Subprocess

// MARK: - SSHAgent

/// 本机发起的 SSH 连接与 SSH 签名使用的 agent。
///
/// 选中的 agent 决定 Spooky 在本机启动的 git、ssh（含连接服务器的专属主连接）与 ssh-keygen 的 `SSH_AUTH_SOCK`；
/// 连接服务器时仍不转发 agent，服务器上的 Git 用那台机器自己的 agent。
public enum SSHAgent: String, CaseIterable, Sendable {
    /// 系统的 agent：自定义变量或登录 shell 设置了 `SSH_AUTH_SOCK` 时用它，两处都有时用自定义的；否则用 Spooky 从 launchd 继承的。
    case system

    /// agent 是否在运行：`ssh-add -l` 列出密钥时以 0 退出，agent 里没有密钥时以 1 退出，连不上 agent 时以 2 退出。
    ///
    /// - Parameter socket: 要检查的 socket；nil 表示没有可用的 agent。
    public static func isRunning(socket: String?) async -> Bool {
        guard let socket, FileManager.default.fileExists(atPath: socket) else { return false }

        let result = try? await CommandExecutor.execute(
            executable: "/usr/bin/ssh-add",
            processArguments: ["-l"],
            arguments: ["ssh-add", "-l"],
            environment: .inherit.updating(["SSH_AUTH_SOCK": socket]),
            acceptedExitCodes: [0, 1]
        )

        return result != nil
    }

    /// 这个 agent 的 socket：系统 agent 依次取自定义变量、登录 shell 读到的与 Spooky 启动时继承的 `SSH_AUTH_SOCK`，
    /// 空值视为没有；都没有时为 nil。
    ///
    /// - Parameters:
    ///   - customVariables: 用户保存的自定义变量。
    ///   - loginShellVariables: 从登录 shell 读到的变量；没有开启读取时为空。
    ///   - environment: Spooky 进程启动时继承的环境。
    public func socket(
        customVariables: [String: String] = [:],
        loginShellVariables: [String: String] = [:],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        switch self {
        case .system:
            [customVariables, loginShellVariables, environment]
                .compactMap { $0["SSH_AUTH_SOCK"] }
                .first { !$0.isEmpty }
        }
    }
}
