import Foundation

// MARK: - CloneOptions

/// 克隆的选项。
public struct CloneOptions: Sendable, Hashable {
    /// 同时克隆并检出全部子模块（`--recurse-submodules`）。
    public var recurseSubmodules: Bool

    /// 要求目标机器上的 Git LFS 已安装并启用：LFS 文件由 Git 的 LFS 过滤器在检出时下载，不可用时在克隆前失败。
    public var lfs: Bool

    /// 创建克隆选项，默认两项都不选。
    public init(recurseSubmodules: Bool = false, lfs: Bool = false) {
        self.recurseSubmodules = recurseSubmodules
        self.lfs = lfs
    }
}

// MARK: - RepositoryClone

/// 一次克隆：远端地址、目标位置与选项；重试就是对同一个值再调用一次 ``start(credentialHandler:onProgress:)``。
///
/// 本机目标在 A 上克隆，服务器目标在 B 上克隆，A 只接收进度。
public struct RepositoryClone: Sendable, Hashable {
    /// 远端仓库地址，原样交给 Git。
    public let url: String

    /// 克隆到的位置：本机或服务器上的绝对路径，目录不存在或为空。
    public let destination: RepositoryLocation

    /// 克隆选项。
    public let options: CloneOptions

    /// 创建克隆请求，不访问磁盘或网络。
    public init(url: String, destination: RepositoryLocation, options: CloneOptions = CloneOptions()) {
        self.url = url
        self.destination = destination
        self.options = options
    }

    /// 地址里的仓库名，克隆的目标目录默认以它命名：去掉协议、结尾的 `/` 与 `.git`，取最后一个 `/` 或 `:` 之后的部分。
    ///
    /// 与 Git 在没有给出目标目录时的取名一致，如 `git@host:team/app.git` 与 `https://host/team/app/` 都取 `app`；取不出时为 nil。
    public static func directoryName(for url: String) -> String? {
        var text = Substring(url.trimmingCharacters(in: .whitespaces))

        if let scheme = text.range(of: "://") {
            text = text[scheme.upperBound...]
        }

        // 先去掉结尾的斜杠，再去掉 .git 与它前面的斜杠
        while text.hasSuffix("/") {
            text.removeLast()
        }

        if text.hasSuffix(".git") {
            text.removeLast(4)
        }

        while text.hasSuffix("/") {
            text.removeLast()
        }

        let name = text.split { $0 == "/" || $0 == ":" }.last.map(String.init) ?? ""
        return name.isEmpty || name == "." || name == ".." ? nil : name
    }

    /// 发起克隆，返回可取消、可观察的操作；取消不算失败，也不会自动重试。
    ///
    /// 执行 `git clone --progress [--recurse-submodules] -- <地址> <目标>`。失败时 ``GitError`` 保留 Git 的原始输出与错误类别；
    /// 取消时本机终止进程组，服务器经包装器按操作标识终止 B 上的进程组。
    ///
    /// - Parameters:
    ///   - credentialHandler: 用户名、密码与 SSH 私钥口令的询问入口；服务器目标装到主机连接上，之后的主机操作共用。
    ///   - onProgress: 从 stderr 解析出的进度，每个数据块最多回调一次。
    public func start(
        credentialHandler: RemoteCallbackHandler? = nil,
        onProgress: (@Sendable (CloneProgress) -> Void)? = nil
    ) -> GitOperation {
        start(credentialHandler: credentialHandler, onProgress: onProgress) { GitRunner(location: $0) }
    }

    /// 与公开的 ``start(credentialHandler:onProgress:)`` 相同，本机克隆经指定方式创建执行器，测试据此隔离用户的 Git 配置。
    func start(
        credentialHandler: RemoteCallbackHandler?,
        onProgress: (@Sendable (CloneProgress) -> Void)?,
        localRunner: @escaping @Sendable (RepositoryLocation) -> GitRunner
    ) -> GitOperation {
        GitOperation { event in
            let path = try HostOperationError.normalized(destination.path)
            let parser = CloneProgress.Parser()

            // 事件原样交给操作的订阅者，stderr 另外解析成进度
            let forward: @Sendable (GitOperationEvent) -> Void = { operationEvent in
                event(operationEvent)

                guard
                    let onProgress,
                    case .output(.standardError(let data)) = operationEvent,
                    let progress = parser.receive(data)
                else { return }

                onProgress(progress)
            }

            guard let host = destination.host else {
                var runner = localRunner(.local(path: path))
                runner.credentialHandler = credentialHandler

                return try await cloneLocally(at: path, runner: runner, event: forward)
            }

            return try await cloneRemotely(
                on: host,
                at: path,
                credentialHandler: credentialHandler,
                event: forward
            )
        }
    }

    /// `git clone` 的参数：地址放在 `--` 之后，以 “-” 开头的地址不会被当成选项。
    func arguments(path: String) -> [String] {
        ["clone", "--progress"]
            + (options.recurseSubmodules ? ["--recurse-submodules"] : [])
            + ["--", url, path]
    }
}

// MARK: - Private

extension RepositoryClone {
    /// 本机克隆在目标目录里执行，目录要先存在；失败或取消时删掉本次新建的目录。
    private func cloneLocally(
        at path: String,
        runner: GitRunner,
        event: @escaping @Sendable (GitOperationEvent) -> Void
    ) async throws -> GitCommandResult {
        let created = try LocalDirectory.prepare(path)

        do {
            if options.lfs {
                try await requireLFS { try await runner.execute($0, acceptedExitCodes: $1) }
            }

            event(.started)

            return try await runner.execute(arguments(path: path)) { event(.output($0)) }
        } catch {
            // 新建的目录里只有这次克隆的内容；Git 失败或收到 TERM 时会清理内容，被 KILL 时由这里清理
            if created { try? FileManager.default.removeItem(atPath: path) }
            throw error
        }
    }

    /// 服务器克隆在 B 上执行，目标作为参数交给 B 上的 Git；凭据与口令经主机连接的中继回到 A。
    private func cloneRemotely(
        on host: String,
        at path: String,
        credentialHandler: RemoteCallbackHandler?,
        event: @escaping @Sendable (GitOperationEvent) -> Void
    ) async throws -> GitCommandResult {
        let connection = RemoteConnection.host(host)

        if let credentialHandler {
            await connection.setCallbackHandler(credentialHandler)
        }

        if options.lfs {
            try await requireLFS { arguments, acceptedExitCodes in
                try await connection.runOnHost(
                    .git(arguments),
                    at: path,
                    writing: false,
                    acceptedExitCodes: acceptedExitCodes
                ) { _ in }
            }
        }

        return try await connection.runOnHost(
            .git(arguments(path: path)),
            at: path,
            writing: true,
            acceptedExitCodes: [0],
            event: event
        )
    }

    /// 确认目标机器上的 Git LFS 已安装，且 Git 配置里登记了 LFS 过滤器（`git lfs install`）。
    ///
    /// - Parameter run: 在目标机器上执行一条 Git 子命令，第二个参数是视为成功的退出码。
    private func requireLFS(
        _ run: (_ arguments: [String], _ acceptedExitCodes: Set<Int32>) async throws -> GitCommandResult
    ) async throws {
        do {
            _ = try await run(["lfs", "version"], [0])
        } catch let error as GitError where !error.isCancelled {
            throw HostOperationError.lfsUnavailable(error.result)
        }

        // 没有登记过滤器时检出只得到指针文件
        let filters = try await run(["config", "-z", "--get-regexp", "^filter\\.lfs\\."], [0, 1])

        guard filters.exitCode == 0 else {
            throw HostOperationError.lfsUnavailable(filters)
        }
    }
}
