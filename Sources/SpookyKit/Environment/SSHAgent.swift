import Foundation
import Subprocess

// MARK: - SSHAgent

/// 本机发起的 SSH 连接与 SSH 签名使用的 agent。
///
/// 选中的 agent 决定 Spooky 在本机启动的 git、ssh（含连接服务器的专属主连接）与 ssh-keygen 的 `SSH_AUTH_SOCK`；
/// 连接服务器时仍不转发 agent，服务器上的 Git 用那台机器自己的 agent。
public enum SSHAgent: String, CaseIterable, Sendable {
    #warning(
        "TODO: 候选只有系统与 1Password 两项、1Password 未安装时同样列出、系统 agent 取 Spooky 启动时继承的 SSH_AUTH_SOCK，三点都是推断。核实方式：在装与未装 1Password 的机器上分别打开 SSH Agent 菜单比对候选，并在登录 shell 改写 SSH_AUTH_SOCK 后看系统 agent 实际连到哪个 socket；影响 SSH Agent 菜单的候选与系统 agent 的 socket。"
    )

    /// macOS 自带的 agent，即 Spooky 从 launchd 继承的 `SSH_AUTH_SOCK`。
    case system

    /// 1Password 提供的 agent，socket 在它的群组容器里。
    case onePassword

    /// 1Password agent 的 socket 相对用户主目录的位置。
    static let onePasswordSocket = "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

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

    /// 这个 agent 的 socket；系统 agent 没有设置 `SSH_AUTH_SOCK` 时为 nil。
    ///
    /// - Parameters:
    ///   - environment: Spooky 进程启动时继承的环境。
    ///   - home: 用户主目录。
    public func socket(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String? {
        switch self {
        case .system:
            environment["SSH_AUTH_SOCK"].flatMap { $0.isEmpty ? nil : $0 }

        case .onePassword:
            home.appending(path: Self.onePasswordSocket).path
        }
    }
}
