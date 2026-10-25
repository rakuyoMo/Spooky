import Foundation
import Synchronization

// MARK: - HostCommand

/// 在主机上执行的命令：仓库还不存在时没有工作区，命令不带 `-C`，路径都作为参数传入。
enum HostCommand: Sendable {
    /// Git 子命令及参数，执行时带上全局选项与回调配置。
    case git([String])

    /// 其它程序，第一个元素是可执行文件的绝对路径。
    case program([String])

    /// 记进结果与错误的业务参数。
    var arguments: [String] {
        switch self {
        case .git(let arguments), .program(let arguments): arguments
        }
    }
}

// MARK: - Host

extension RemoteConnection {
    /// App 内按主机别名登记的主机连接，与工作区连接分开登记。
    private static let hosts = Mutex<[String: RemoteConnection]>([:])

    /// 取得某台主机不绑定仓库的连接；同一别名在 App 内共用一条专属主连接，第一次执行命令时才建立。
    ///
    /// 新建、克隆、扫描与目录浏览在仓库存在之前使用它，主连接、包装器、进程组、回调中继、取消与断线规则都与工作区连接相同。
    ///
    /// - Parameter alias: `~/.ssh/config` 里的主机别名。
    public nonisolated static func host(_ alias: String) -> RemoteConnection {
        host(alias, configuration: SSHConfiguration())
    }

    /// 以指定的 SSH 配置登记主机连接，测试据此使用专用密钥；别名已登记时返回已有的连接。
    nonisolated static func host(_ alias: String, configuration: SSHConfiguration) -> RemoteConnection {
        hosts.withLock { hosts in
            if let connection = hosts[alias] { return connection }

            let connection = RemoteConnection(
                host: alias,
                path: "",
                hostScoped: true,
                configuration: configuration
            )
            hosts[alias] = connection
            return connection
        }
    }

    /// 关闭并移除全部主机连接，App 退出时由 ``closeAll()`` 调用。
    static func closeHosts() async {
        let existing = hosts.withLock { hosts in
            let values = Array(hosts.values)
            hosts.removeAll()
            return values
        }

        for connection in existing { await connection.close() }
    }

    /// 建立主机连接并返回体检读到的 B 端环境，其中有 B 上用户的主目录；已连接时直接返回。
    ///
    /// 凭据与口令请求经 ``setCallbackHandler(_:)`` 安装的处理器回到 A，处理器要在第一次连接前安装。
    public func connectHost() async throws -> RemoteHostEnvironment {
        try await connect()

        guard let environment else { throw RemoteConnectionError(.unavailable) }
        return environment
    }

    /// 建立可取消、可观察的主机操作；取消经包装器按操作标识终止 B 上的进程组。
    ///
    /// - Parameters:
    ///   - command: 要执行的命令。
    ///   - path: 命令作用的 B 上路径，按它占用写槽，同一路径上的写入串行。
    ///   - writing: 是否为写入。
    ///   - acceptedExitCodes: 视为成功的退出码。
    ///   - onOutput: 流式输出，块边界不代表行或字符边界。
    nonisolated func hostOperation(
        _ command: HostCommand,
        at path: String,
        writing: Bool,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) -> GitOperation {
        GitOperation { event in
            try await self.runOnHost(
                command,
                at: path,
                writing: writing,
                acceptedExitCodes: acceptedExitCodes
            ) {
                event($0)
                if case .output(let output) = $0 { onOutput?(output) }
            }
        }
    }

    /// 先确认主机连接，再按目标路径占用主机槽与写槽，最后交给包装器执行。
    func runOnHost(
        _ command: HostCommand,
        at path: String,
        writing: Bool,
        acceptedExitCodes: Set<Int32>,
        event: @escaping @Sendable (GitOperationEvent) -> Void
    ) async throws -> GitCommandResult {
        _ = try await connectHost()
        let location = RepositoryLocation.remote(host: host, path: path)

        return try await RepositoryOperationQueue.shared.perform(at: location, writing: writing) {
            try await self.runHostConnected(command, acceptedExitCodes: acceptedExitCodes, event: event)
        }
    }

    /// 获得执行槽后再次确认主连接，排队期间的断线不能被忽略。
    ///
    /// 主机级命令没有可核对的仓库：断线或取消未确认时只如实报告，不阻止之后的写入。
    private func runHostConnected(
        _ command: HostCommand,
        acceptedExitCodes: Set<Int32>,
        event: @escaping @Sendable (GitOperationEvent) -> Void
    ) async throws -> GitCommandResult {
        guard state == .connected, let wrapper else { throw failure ?? RemoteConnectionError(.unavailable) }

        try await check()
        event(.started)

        let full: [String] =
            switch command {
            case .git(let arguments):
                ["git"] + GitRunner.globalOptions + Self.callbackOptions(wrapper: wrapper) + arguments

            case .program(let program):
                program
            }

        return try await runOperation(
            full,
            arguments: command.arguments,
            acceptedExitCodes: acceptedExitCodes,
            writing: false,
            onOutput: { event(.output($0)) }
        )
    }
}
