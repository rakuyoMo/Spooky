import Foundation
import Subprocess

/// 在仓库所在的位置执行 git：本机直接调用 git，远端经系统 ssh 在对方机器上调用
public struct GitRunner: Sendable {
    /// 目标仓库
    public let location: RepositoryLocation

    /// 远端会话由执行器持有，多条命令共享同一主连接。
    public let remote: RemoteConnection?

    /// 本机 Git 程序路径；测试可使用临时程序验证启动和取消边界。
    private let executablePath: String

    /// 子进程的环境覆盖项，不写入结果或错误。
    private let environment: Environment

    /// 创建在指定仓库上执行 git 的实例
    ///
    /// - Parameter location: 目标仓库
    public init(location: RepositoryLocation) {
        self.location = location
        self.remote = RemoteConnection.forLocation(location)
        self.executablePath = "/usr/bin/git"
        self.environment = .inherit.updating(Self.environmentOverrides)
    }

    /// 用隔离环境执行测试，避免读取用户全局 Git 配置。
    init(
        location: RepositoryLocation,
        executablePath: String = "/usr/bin/git",
        environment: Environment
    ) {
        self.location = location
        self.remote = RemoteConnection.forLocation(location)
        self.executablePath = executablePath
        self.environment = environment.updating(Self.environmentOverrides)
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

    /// 版本检查在文件系统根目录进行，避免失效的仓库路径掩盖 Git 版本问题。
    func versionResult() async throws -> GitCommandResult {
        let runner = GitRunner(
            location: .local(path: "/"),
            executablePath: executablePath,
            environment: environment
        )

        return try await runner.execute(["--version"])
    }

    /// 按 POSIX shell 的规则给参数加单引号，参数里的单引号写成 `'\''`
    static func shellQuoted(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

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
        "GIT_DIR": nil,
        "GIT_WORK_TREE": nil,
        "GIT_COMMON_DIR": nil,
        "GIT_INDEX_FILE": nil,
        "GIT_OBJECT_DIRECTORY": nil,
        "GIT_ALTERNATE_OBJECT_DIRECTORIES": nil,
        "GIT_NAMESPACE": nil,
        "GIT_PREFIX": nil,
    ]

    /// 只匹配已知的本机错误前缀，避免把路径或权限错误误报为网络错误。
    static func category(for result: GitCommandResult) -> GitError.Category {
        let stderr = String(decoding: result.standardError, as: UTF8.self).lowercased()

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
}
