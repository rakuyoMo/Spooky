import Foundation
import Observation
import SpookyKit

// MARK: - CustomEnvironmentVariable

/// Environment 页里用户保存的一个自定义变量。
struct CustomEnvironmentVariable: Identifiable, Equatable {
    /// 表格行的身份，只在内存里使用。
    let id = UUID()

    /// 变量名。
    var name: String

    /// 变量的值。
    var value: String
}

// MARK: - LocalExecutionPreferences

/// 本机执行 Git 与 SSH 的偏好：登录 shell 的环境、自定义变量、SSH agent 与 Git 程序。
///
/// 偏好变化后立即组装成 ``LocalExecutionSettings`` 交给核心库，下一条本机命令即使用新的设置；
/// 登录 shell 的变量只在内存里，每次启动 App 重新读取。
@MainActor
@Observable
final class LocalExecutionPreferences {
    /// 读取登录 shell 环境的进度。
    enum LoginShellState: Equatable {
        /// 没有开启，或还没有读过。
        case idle

        /// 正在等 shell 结束。
        case reading

        /// 已读到变量。
        case loaded

        /// shell 无法启动、超时或输出无法识别。
        case failed
    }

    /// 是否读取登录 shell 环境的偏好键。
    static let loginShellKey = "loginShellEnvironment"

    /// 自定义变量的偏好键：按表格顺序保存的 `[名称, 值]` 列表。
    static let customVariablesKey = "customEnvironmentVariables"

    /// 所选 SSH agent 的偏好键，保存 ``SSHAgent`` 的 `rawValue`。
    static let sshAgentKey = "sshAgent"

    /// 本机 Git 程序路径的偏好键。
    static let gitExecutableKey = "gitExecutable"

    /// App 使用的偏好与核心库的全局设置。
    static let shared = LocalExecutionPreferences(defaults: .standard)

    /// 是否读取登录 shell 环境。
    private(set) var usesLoginShell: Bool

    /// 最近一次从登录 shell 读到的变量。
    private(set) var loginShellVariables: [String: String] = [:]

    /// 读取登录 shell 环境的进度。
    private(set) var loginShellState = LoginShellState.idle

    /// 已保存的自定义变量，按表格顺序；同名时后面的生效。
    private(set) var customVariables: [CustomEnvironmentVariable]

    /// 所选的 SSH agent。
    private(set) var sshAgent: SSHAgent

    /// 所选的 agent 是否在运行；nil 表示正在检查。
    private(set) var sshAgentRunning: Bool? = nil

    /// 本机仓库使用的 Git 程序。
    private(set) var gitExecutable: String

    /// 交给核心库的设置：登录 shell 的变量只在开启时带上。
    var settings: LocalExecutionSettings {
        LocalExecutionSettings(
            gitExecutable: gitExecutable,
            loginShellVariables: usesLoginShell ? loginShellVariables : [:],
            customVariables: Dictionary(customVariables.map { ($0.name, $0.value) }) { $1 },
            sshAuthSocket: sshAgent.socket()
        )
    }

    /// 记录偏好的偏好域，测试使用独立的域。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 读取登录 shell 环境的方式，测试换成固定的变量。
    @ObservationIgnored
    private let readLoginShell: @Sendable () async throws -> [String: String]

    /// 把设置交给核心库；测试只记录设置，不改动全局。
    @ObservationIgnored
    private let apply: @MainActor (LocalExecutionSettings) -> Void

    /// 正在进行的登录 shell 读取。
    @ObservationIgnored
    private var loginShellTask: Task<Void, Never>?

    /// 正在进行的 agent 检查。
    @ObservationIgnored
    private var agentTask: Task<Void, Never>?

    /// 从偏好域读出保存的设置。
    ///
    /// - Parameters:
    ///   - defaults: 记录偏好的偏好域。
    ///   - readLoginShell: 读取登录 shell 环境的方式。
    ///   - apply: 把设置交给核心库的方式。
    init(
        defaults: UserDefaults,
        readLoginShell: @escaping @Sendable () async throws -> [String: String] = { try await LoginShellEnvironment.read() },
        apply: @escaping @MainActor (LocalExecutionSettings) -> Void = { LocalExecutionSettings.current = $0 }
    ) {
        #warning(
            "TODO: 读取登录 shell 环境默认关闭是推断。核实方式：在全新的偏好下打开 Environment 页看复选框是否勾选；只影响没有改过这项设置时本机 Git 是否带上登录 shell 的变量。"
        )

        self.defaults = defaults
        self.readLoginShell = readLoginShell
        self.apply = apply

        usesLoginShell = defaults.bool(forKey: Self.loginShellKey)
        sshAgent = defaults.string(forKey: Self.sshAgentKey).flatMap(SSHAgent.init(rawValue:)) ?? .system
        gitExecutable = defaults.string(forKey: Self.gitExecutableKey) ?? LocalExecutionSettings.defaultGitExecutable

        customVariables = (defaults.array(forKey: Self.customVariablesKey) as? [[String]] ?? [])
            .filter { $0.count == 2 }
            .map { CustomEnvironmentVariable(name: $0[0], value: $0[1]) }
    }

    /// App 启动时交出保存的设置，按需读取登录 shell 环境，并检查所选的 agent。
    func start() {
        apply(settings)

        if usesLoginShell {
            reloadLoginShell()
        }

        checkSSHAgent()
    }

    /// 开启或关闭读取登录 shell 环境；开启时立即读取，关闭后本机 Git 不再带上这些变量。
    func setUsesLoginShell(_ enabled: Bool) {
        usesLoginShell = enabled
        defaults.set(enabled, forKey: Self.loginShellKey)

        if enabled {
            reloadLoginShell()
        } else {
            loginShellTask?.cancel()
            loginShellState = .idle
        }

        apply(settings)
    }

    /// 保存自定义变量，下一条本机 Git 命令即使用它们；名称不合法的条目保留在表格里，但不交给 Git。
    func saveCustomVariables(_ variables: [CustomEnvironmentVariable]) {
        guard variables != customVariables else { return }

        customVariables = variables
        defaults.set(variables.map { [$0.name, $0.value] }, forKey: Self.customVariablesKey)
        apply(settings)
    }

    /// 选择 SSH agent 并检查它是否在运行。
    func selectSSHAgent(_ agent: SSHAgent) {
        sshAgent = agent
        defaults.set(agent.rawValue, forKey: Self.sshAgentKey)
        apply(settings)
        checkSSHAgent()
    }

    /// 选择本机仓库使用的 Git 程序；调用方先确认它的版本满足要求。
    func selectGitExecutable(_ path: String) {
        gitExecutable = path
        defaults.set(path, forKey: Self.gitExecutableKey)
        apply(settings)
    }

    // MARK: 读取与检查

    /// 重新读取登录 shell 环境，读完后交给核心库；仍在读的上一次读取作废。
    private func reloadLoginShell() {
        loginShellTask?.cancel()
        loginShellState = .reading

        loginShellTask = Task { [readLoginShell] in
            do {
                let variables = try await readLoginShell()

                guard !Task.isCancelled else { return }

                loginShellVariables = variables
                loginShellState = .loaded
                apply(settings)
            } catch {
                guard !Task.isCancelled else { return }

                // 失败时保留上一次读到的变量，表格下方说明这次没有读到；原因已由核心库记入日志。
                loginShellState = .failed
            }
        }
    }

    /// 检查所选的 agent 是否在运行，供 SSH Agent 一行显示警告。
    private func checkSSHAgent() {
        agentTask?.cancel()
        sshAgentRunning = nil

        let socket = sshAgent.socket()

        agentTask = Task {
            let running = await SSHAgent.isRunning(socket: socket)

            guard !Task.isCancelled else { return }

            sshAgentRunning = running
        }
    }
}
