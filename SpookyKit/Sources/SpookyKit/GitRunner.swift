import Foundation
import Subprocess

/// 在仓库所在的位置执行 git：本机直接调用 git，远端经系统 ssh 在对方机器上调用
public struct GitRunner: Sendable {
    /// 每条 git 调用都带上的全局选项
    ///
    /// - `--no-pager`、`color.ui=never`：输出交给程序解析，不要分页，也不要颜色
    /// - `--no-optional-locks`：读状态时不顺手回写 index，免得和终端里、对方机器上 agent 的 git 操作抢锁
    /// - `core.quotepath=off`：中文等非 ASCII 路径原样输出，不转成八进制转义
    static let globalOptions = [
        "--no-pager",
        "--no-optional-locks",
        "-c", "color.ui=never",
        "-c", "core.quotepath=off",
    ]

    /// 固定错误输出语言，并清除会让 Git 越过 `-C` 访问其它仓库的环境变量。
    private static let environmentOverrides: [Environment.Key: String?] = [
        "LANG": "en_US.UTF-8",
        "LC_ALL": "en_US.UTF-8",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_EDITOR": nil,
        "GIT_SEQUENCE_EDITOR": nil,
        "GIT_DIR": nil,
        "GIT_WORK_TREE": nil,
        "GIT_COMMON_DIR": nil,
        "GIT_INDEX_FILE": nil,
        "GIT_OBJECT_DIRECTORY": nil,
        "GIT_ALTERNATE_OBJECT_DIRECTORIES": nil,
        "GIT_NAMESPACE": nil,
        "GIT_PREFIX": nil,
    ]

    /// 目标仓库
    public let location: RepositoryLocation

    /// 远端会话由执行器持有，多条命令共享同一主连接。
    public let remote: RemoteConnection?

    /// 本机网络操作的口令输入入口；服务器沿用连接上的回调处理器。
    public var credentialHandler: RemoteCallbackHandler?

    /// 本机 Git 程序路径；测试可使用临时程序验证启动和取消边界。
    private let executablePath: String

    /// 子进程的环境覆盖项，不写入结果或错误。
    private let environment: Environment

    /// 创建在指定仓库上执行 git 的实例
    ///
    /// - Parameter location: 目标仓库
    public init(location: RepositoryLocation) {
        self.location = location
        remote = RemoteConnection.forLocation(location)
        executablePath = "/usr/bin/git"
        environment = .inherit.updating(Self.environmentOverrides)
    }

    /// 用隔离环境执行测试，避免读取用户全局 Git 配置。
    init(
        location: RepositoryLocation,
        executablePath: String = "/usr/bin/git",
        environment: Environment
    ) {
        self.location = location
        remote = RemoteConnection.forLocation(location)
        self.executablePath = executablePath
        self.environment = environment.updating(Self.environmentOverrides)
    }

    /// 在集成测试中沿用专用认证配置对应的已建立连接。
    init(location: RepositoryLocation, remote: RemoteConnection) {
        self.location = location
        self.remote = remote
        executablePath = "/usr/bin/git"
        environment = .inherit.updating(Self.environmentOverrides)
    }

    /// 按 POSIX shell 的规则给参数加单引号，参数里的单引号写成 `'\''`
    static func shellQuoted(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// 固定 locale 下区分仓库、分支与网络失败，原始输出仍保留在结果中。
    static func category(for result: GitCommandResult) -> GitError.Category {
        let stderr = String(decoding: result.standardError, as: UTF8.self).lowercased()
        let stdout = String(decoding: result.standardOutput, as: UTF8.self).lowercased()
        let command = RepositoryOperationQueue.command(in: result.arguments)

        // 网络错误按具体诊断分类；凭据与仓库权限错误不使用宽泛的 “not found” 匹配。
        if
            stderr.contains("has no upstream branch") || stderr.contains("no upstream configured")
            || stderr.contains("no tracking information")
        {
            return .noUpstream
        }
        if stderr.contains("is not fully merged") { return .branchNotMerged }
        if stderr.contains("would be overwritten by") { return .localChanges }
        if
            command == "push",
            stderr.contains("[rejected]") || stderr.contains("[remote rejected]")
            || stdout.split(separator: "\n").contains(where: { $0.hasPrefix("!\t") })
        {
            return .pushRejected
        }
        if stderr.contains("connection timed out") || stderr.contains("operation timed out") {
            return .connectionTimedOut
        }
        if
            stderr.contains("authentication failed") || stderr.contains("permission denied (publickey")
            || stderr.contains("too many authentication failures")
            || stderr.contains("could not read username")
            || stderr.contains("could not read password")
        {
            return .authenticationFailed
        }
        if
            stderr.contains("does not appear to be a git repository")
            || stderr.contains("repository not found")
            || (stderr.contains("repository '") && stderr.contains("' not found"))
        {
            return .remoteNotFound
        }
        if
            [
                "connection refused", "could not resolve hostname", "could not resolve host:",
                "connection reset", "connection closed", "network is unreachable", "broken pipe",
            ]
                .contains(where: stderr.contains)
        {
            return .connectionUnavailable
        }

        if stderr.contains("index.lock"), stderr.contains("file exists") {
            return .indexLocked
        }

        guard result.exitCode == 128 else {
            return .commandFailed
        }

        if stderr.hasPrefix("fatal: not a git repository") {
            return .notRepository
        }

        if stderr.hasPrefix("fatal: this operation must be run in a work tree") {
            return .notWorkingTree
        }

        if stderr.hasPrefix("fatal: cannot change to") {
            return .pathUnavailable
        }

        if stderr.hasPrefix("fatal: detected dubious ownership") {
            return .unsafeRepository
        }

        return .commandFailed
    }

    /// 执行一条 git 子命令，成功时返回标准输出
    ///
    /// - Parameters:
    ///   - arguments: 子命令及其参数，如 `["status", "--porcelain=v2", "-z"]`
    ///   - input: 写入 git 标准输入的内容，供 `commit -F -` 这类命令使用
    /// - Throws: git 或 ssh 以非零状态退出时抛出 ``GitError``
    public func run(
        _ arguments: [String],
        input: Data? = nil
    ) async throws -> Data {
        // 兼容原有只读取 stdout 的入口；退出码、stderr 与取消由统一执行层处理。
        try await execute(arguments, input: input).standardOutput
    }

    /// 执行 Git 并返回完整结果；取消持有本次调用的 Task 即可终止本机子进程。
    ///
    /// 输出回调接收原始数据块，调用方自行处理跨块文本；可接受退出码由具体命令声明。
    public func execute(
        _ arguments: [String],
        input: Data? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        do {
            return try await operation(
                arguments,
                input: input,
                acceptedExitCodes: acceptedExitCodes,
                onOutput: onOutput
            ).value
        } catch is CancellationError {
            // 保留 M1 的取消错误语义，排队取消同样携带原始业务参数。
            throw GitError(
                result: GitCommandResult(
                    arguments: arguments,
                    standardOutput: Data(),
                    standardError: Data(),
                    terminationStatus: nil,
                    isCancelled: true
                ),
                category: .cancelled,
                diagnostic: nil
            )
        }
    }

    /// 每条命令使用相同的操作模型，本机与服务器都能观察开始、输出及结束。
    public func operation(
        _ arguments: [String],
        input: Data? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) -> GitOperation {
        if let remote {
            return remote.operation(arguments, input: input, acceptedExitCodes: acceptedExitCodes, onOutput: onOutput)
        }

        return GitOperation { event in
            try await RepositoryOperationQueue.shared.perform(
                at: location,
                writing: !RepositoryOperationQueue.isReadOnly(arguments)
            ) {
                event(.started)

                // 只有网络命令需要 askpass；本机 SSH 解锁后由系统 agent 保留密钥。
                if
                    let credentialHandler,
                    ["fetch", "push", "ls-remote"]
                        .contains(RepositoryOperationQueue.command(in: arguments) ?? "")
                {
                    return try await LocalGitAuthentication.execute(
                        executable: executablePath,
                        location: location,
                        arguments: arguments,
                        environment: environment,
                        input: input,
                        acceptedExitCodes: acceptedExitCodes,
                        handler: credentialHandler
                    ) {
                        event(.output($0))
                        onOutput?($0)
                    }
                }

                return try await CommandExecutor.execute(
                    executable: executablePath,
                    processArguments: ["-C", location.path] + Self.globalOptions + arguments,
                    arguments: arguments,
                    environment: environment,
                    input: input,
                    acceptedExitCodes: acceptedExitCodes
                ) {
                    event(.output($0))
                    onOutput?($0)
                }
            }
        }
    }

    /// 将校验与多条写命令作为一个仓库操作，避免其它窗口在中间插入写入。
    func writeTransaction<T: Sendable>(
        _ action: @Sendable () async throws -> T
    ) async throws -> T {
        let target = try await remote?.open().location ?? location

        if RepositoryOperationQueue.transaction == target {
            return try await action()
        }

        let pool = await RepositoryOperationQueue.shared.permits(for: target).write
        try await pool.acquire()

        do {
            let result = try await RepositoryOperationQueue.$transaction.withValue(target) {
                try Task.checkCancellation()
                return try await action()
            }
            await pool.release()
            return result
        } catch {
            await pool.release()
            throw error
        }
    }

    /// 版本检查在文件系统根目录进行，避免失效的仓库路径掩盖 Git 版本问题。
    func versionResult() async throws -> GitCommandResult {
        let runner = Self(
            location: .local(path: "/"),
            executablePath: executablePath,
            environment: environment
        )

        return try await runner.execute(["--version"])
    }

}
