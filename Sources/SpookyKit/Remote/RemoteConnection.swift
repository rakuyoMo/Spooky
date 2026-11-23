import CryptoKit
import Foundation
import os
import Subprocess
import Synchronization
import System

// MARK: - RemoteConnection

/// 每个服务器工作区的专属主连接、体检、回调与远端进程生命周期。
public actor RemoteConnection {
    /// 前台轮询间隔。
    public static let foregroundPollInterval = Duration.seconds(2)

    /// 后台窗口轮询间隔。
    public static let backgroundPollInterval = Duration.seconds(10)

    /// 重连失败后的重试间隔。
    public static let reconnectInterval = Duration.seconds(5)

    /// 多个执行器复用同一工作区会话。
    private static let connections = Mutex<[RepositoryLocation: RemoteConnection]>([:])

    /// 连接状态、远端会话、常驻通道与取消结果的日志；主机别名按私有记录。
    static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "RemoteConnection")

    /// SSH 配置中的主机别名。
    public nonisolated let host: String

    /// 用户指定的绝对路径，体检成功后使用规范根路径。
    public nonisolated let requestedPath: String

    /// 为 true 时连接整台主机而不是某个工作区：新建、克隆、扫描与目录浏览在仓库存在之前使用。
    public nonisolated let isHostScoped: Bool

    /// 当前连接状态。
    public private(set) var state = RemoteConnectionState.unavailable

    /// 上次连接错误。
    public internal(set) var failure: RemoteConnectionError? = nil

    /// 最近一次体检确认的仓库身份。
    public private(set) var repository: RemoteRepository? = nil

    /// 写操作断线后取得的核对结果。
    public private(set) var recovery: RemoteRecoverySnapshot? = nil

    /// 最近一次体检读到的 B 端环境，体检失败时同样保留，供界面给出修复方向。
    public internal(set) var environment: RemoteHostEnvironment? = nil

    /// 同一主机的每条连接使用独立控制目录。
    private(set) var localDirectory: URL? = nil

    /// B 上的 0700 会话目录。
    private(set) var remoteDirectory: String? = nil

    /// 没能经当时的主连接关掉的旧会话目录，其中的操作可能仍在 B 上执行；重新连接后先关掉它们。
    private var unclosedSessions: [String] = []

    /// 已原子部署的版本化包装器。
    private(set) var wrapper: String? = nil

    /// 从子目录打开时复用已登记的工作区根会话。
    private(set) var canonical: RemoteConnection? = nil

    /// 本机回调服务，凭据只通过此对象在内存中流转。
    private var relay: CallbackRelay? = nil

    /// 主连接检查任务。
    private var monitor: Task<Void, Never>? = nil

    /// 合并同时发起的连接请求。
    private var connecting: Task<Void, Error>? = nil

    /// 关闭流程合并执行，重新打开必须等待旧会话清理完毕。
    private var closing: Task<Void, Never>? = nil

    /// 状态的多订阅者事件流。
    private var observers: [UUID: AsyncStream<RemoteConnectionState>.Continuation] = [:]

    /// 写操作断线或取消未确认时阻止继续写入。
    var requiresReconciliation = false

    /// 最近一条命令结束的单调时间，心跳不延长空闲期限。
    private var lastCommand = ContinuousClock.now

    /// 尚未结束的命令不能被空闲清理打断。
    private var activeChannels = 0

    /// 系统 SSH 参数与隔离测试选项。
    let configuration: SSHConfiguration

    /// 应用提供的凭据及编辑器交互入口。
    private var callbackHandler: RemoteCallbackHandler? = nil

    /// 主连接上常驻的命令通道，就绪之后才放在这里。
    var resident: RemoteCommandChannel? = nil

    /// 正在后台重新打开常驻通道的任务。
    var reopening: Task<Void, Never>? = nil

    /// 连续打不开常驻通道的次数，到上限后等重新连接再试。
    var channelFailures = 0

    /// 经常驻通道执行完的命令数，测试据此确认命令走了通道。
    var channelCommands = 0

    /// 创建会话不产生网络访问，首次 open 或 execute 才建立连接。
    ///
    /// - Parameter hostScoped: 是否连接整台主机；主机连接不检查工作区，`path` 不使用。
    init(
        host: String,
        path: String,
        hostScoped: Bool = false,
        configuration: SSHConfiguration = SSHConfiguration()
    ) {
        self.host = host
        requestedPath = path
        isHostScoped = hostScoped
        self.configuration = configuration
    }

    /// 释放别名执行器时结束状态转发；失去本机中继后 B 的会话看守会自行清理。
    deinit {
        monitor?.cancel()
        relay?.stop()
    }

    /// App 退出时只关闭自己创建的连接。
    public static func closeAll() async {
        let existing = connections.withLock { connections in
            let values = Array(connections.values)
            connections.removeAll()
            return values
        }

        for connection in existing { await connection.close() }

        // 主机连接另行登记，同样只关闭自己创建的
        await closeHosts()
    }

    /// 为现有 GitRunner API 提供按仓库共享的远端执行服务。
    nonisolated static func forLocation(_ location: RepositoryLocation) -> RemoteConnection? {
        guard case .remote(let host, let path) = location else { return nil }

        return connections.withLock {
            if let connection = $0[location] { return connection }
            let connection = RemoteConnection(host: host, path: path)
            $0[location] = connection
            return connection
        }
    }

    /// 在连接建立前安装 UI 回调，测试可以提供受控应答。
    public func setCallbackHandler(_ handler: @escaping RemoteCallbackHandler) async {
        callbackHandler = handler
        await canonical?.setCallbackHandler(handler)
    }

    /// 每个窗口拥有独立的状态订阅，不互相抢占事件。
    public func states() -> AsyncStream<RemoteConnectionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<RemoteConnectionState>.makeStream()
        observers[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    /// 按规定顺序完成 SSH、Git、路径、工作区与状态格式检查。
    public func open() async throws -> RemoteRepository {
        try await connect()

        // 从子目录打开时，规范会话的仓库身份在共享会话时已经记下
        guard let repository else { throw RemoteConnectionError(.unavailable) }
        return repository
    }

    /// 建立或复用主连接：工作区连接按顺序体检后部署包装器，主机连接只体检 Git 与 B 端环境。
    func connect() async throws {
        try Task.checkCancellation()

        if let canonical {
            try await canonical.connect()
            return
        }

        if let closing { await closing.value }
        if state == .connected, isHostScoped || repository != nil { return }

        if let connecting {
            try await connecting.value
            return
        }

        try validateLocation()
        let established = isHostScoped ? environment != nil : repository != nil
        updateState(established ? .reconnecting : .connecting)

        let task = Task { try await self.establish() }
        connecting = task

        return try await withTaskCancellationHandler {
            do {
                try await task.value
                connecting = nil
            } catch {
                connecting = nil
                if let closing { await closing.value }
                else { await Task.detached { await self.tearDown() }.value }

                let problem = (error as? RemoteConnectionError)
                    ?? RemoteConnectionError(.deployment, diagnostic: String(describing: error))
                failure = problem
                updateState(.unavailable)
                throw error
            }
        } onCancel: {
            task.cancel()
        }
    }

    /// 换网络或重连先关闭本会话主连接，绝不触碰用户的控制 socket。
    public func reconnect() async throws -> RemoteRepository {
        if let canonical { return try await canonical.reconnect() }
        await close()
        updateState(.reconnecting)
        return try await open()
    }

    /// 仓库或应用关闭时回收远端包装器状态及本机临时目录。
    public func close() async {
        if let canonical {
            await canonical.close()
            updateState(.unavailable)
            return
        }

        if let closing {
            await closing.value
            return
        }

        let attempt = connecting
        connecting = nil
        attempt?.cancel()
        monitor?.cancel()
        updateState(.unavailable)

        // 先等待被取消的安装任务结束，避免它在清理后重新创建远端文件。
        let task = Task.detached {
            _ = try? await attempt?.value
            await self.tearDown()
        }
        closing = task
        await task.value
        closing = nil
    }

    /// 创建可取消、可观察的远端操作；未知命令按写操作处理。
    public nonisolated func operation(
        _ arguments: [String],
        input: Data? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) -> GitOperation {
        GitOperation { event in
            try await self.perform(
                arguments,
                input: input,
                acceptedExitCodes: acceptedExitCodes
            ) {
                event($0)
                if case .output(let output) = $0 { onOutput?(output) }
            }
        }
    }

    /// 与本机相同的完整命令结果接口，等待任务的取消传播至操作对象。
    public func execute(
        _ arguments: [String],
        input: Data? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        try await operation(
            arguments,
            input: input,
            acceptedExitCodes: acceptedExitCodes,
            onOutput: onOutput
        ).value
    }

    /// 只检查主连接，不允许 SSH 因复用失败悄悄新建连接；常驻通道连着时主连接一定还在，不另开控制请求。
    public func check() async throws {
        if let canonical {
            try await canonical.check()
            return
        }

        if let resident, resident.isReady { return }

        guard localDirectory != nil else { throw RemoteConnectionError(.unavailable) }
        let result = try await ssh(["-O", "check"], arguments: ["connection-check"])

        guard result.exitCode == 0 else {
            let error = RemoteConnectionError.ssh(result)
            failure = error
            updateState(.unavailable)
            throw error
        }
    }

    /// 为 SFTP 批处理提供同主连接的启动接口，复用失效时禁止新建连接。
    public func sftpCommand() async throws -> (executable: String, arguments: [String]) {
        if let canonical { return try await canonical.sftpCommand() }
        try await check()
        guard let localDirectory else { throw RemoteConnectionError(.unavailable) }

        // sftp 的 -S 指定 SSH 程序，控制 socket 必须通过 ControlPath 传递。
        let arguments = ["-b", "-"] + Array(configuration.options.dropFirst(2)) + [
            "-o", "ControlPath=" + localDirectory.appending(path: "master.sock").path,
            "-o", "ControlMaster=no",
            "-o", "ProxyCommand=/usr/bin/false",
            "--", host,
        ]
        return ("/usr/bin/sftp", arguments)
    }

    /// 文件传输共用主机队列和写入核对规则，取消只终止本次 SFTP 通道。
    func transferSFTP(_ input: Data, writing: Bool) async throws -> GitCommandResult {
        if let canonical { return try await canonical.transferSFTP(input, writing: writing) }
        guard !writing || !requiresReconciliation else {
            throw RemoteConnectionError(.interruptedWrite)
        }

        let location = repository?.location ?? .remote(host: host, path: requestedPath)
        return try await RepositoryOperationQueue.shared.perform(at: location, writing: writing) {
            try await self.runSFTP(input, writing: writing)
        }
    }

    /// 用于断线验收：仅关闭 Spooky 自己的 SSH 主连接。
    func interruptMaster() async throws {
        if let canonical {
            try await canonical.interruptMaster()
            return
        }

        _ = try await ssh(["-O", "exit"], arguments: ["connection-close"])
    }

    /// 阶段失败归入对应体检错误；SSH 255 优先按连接诊断识别。
    func probe(
        _ command: [String],
        input: Data? = nil,
        kind: RemoteConnectionError.Kind
    ) async throws -> GitCommandResult {
        let result = try await commandChannel(command, input: input, arguments: [kind.rawValue])
        if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }
        guard result.exitCode == 0 else { throw RemoteConnectionError(kind, result: result) }
        return result
    }

}

// MARK: - Private

extension RemoteConnection {
    /// 同一仓库写入串行，同一主机最多同时执行八条命令。
    private func perform(
        _ arguments: [String],
        input: Data?,
        acceptedExitCodes: Set<Int32>,
        event: @escaping @Sendable (GitOperationEvent) -> Void
    ) async throws -> GitCommandResult {
        try Task.checkCancellation()
        if repository == nil { _ = try await open() }

        if let canonical {
            return try await canonical.perform(
                arguments,
                input: input,
                acceptedExitCodes: acceptedExitCodes,
                event: event
            )
        }

        let path = repository?.path ?? requestedPath
        let location = RepositoryLocation.remote(host: host, path: path)
        let writing = !RepositoryOperationQueue.isReadOnly(arguments)

        return try await RepositoryOperationQueue.shared.perform(at: location, writing: writing) {
            try await self.runConnected(
                arguments,
                input: input,
                acceptedExitCodes: acceptedExitCodes,
                writing: writing,
                event: event
            )
        }
    }

    /// 获得执行槽后再次检查连接和核对状态，排队期间的断线不能被忽略。
    ///
    /// 读取不另外确认主连接：主连接失效时命令通道以 SSH 的 255 结束，同样记下失败、转为不可用状态。
    private func runConnected(
        _ arguments: [String],
        input: Data?,
        acceptedExitCodes: Set<Int32>,
        writing: Bool,
        event: @escaping @Sendable (GitOperationEvent) -> Void
    ) async throws -> GitCommandResult {
        guard state == .connected else { throw failure ?? RemoteConnectionError(.unavailable) }
        guard !writing || !requiresReconciliation else {
            throw RemoteConnectionError(.interruptedWrite)
        }

        // 写入之前确认主连接还在：主连接已经失效时写入不开始，重连后不必为它核对仓库
        if writing { try await check() }

        event(.started)
        return try await runWrapped(
            arguments,
            input: input,
            acceptedExitCodes: acceptedExitCodes,
            writing: writing,
            onOutput: { event(.output($0)) }
        )
    }

    /// 活跃传输阻止空闲回收，失败后检查主连接以区分文件错误与断线。
    private func runSFTP(_ input: Data, writing: Bool) async throws -> GitCommandResult {
        guard !writing || !requiresReconciliation else {
            throw RemoteConnectionError(.interruptedWrite)
        }

        let command = try await sftpCommand()
        activeChannels += 1
        defer {
            activeChannels -= 1
            lastCommand = .now
        }

        do {
            return try await CommandExecutor.execute(
                executable: command.executable,
                processArguments: command.arguments,
                arguments: ["sftp"],
                environment: .inherit
                    .updating(LocalExecutionSettings.current.sshOverrides)
                    .updating(["LC_ALL": "en_US.UTF-8"]),
                input: input
            )
        } catch {
            let original = error
            let result = (error as? GitError)?.result

            if Task.isCancelled {
                guard writing else { throw original }

                // SFTP 没有可确认退出的远端进程组：写入被取消时按取消未确认报告，会话据此重连核对，核对之前不能继续写入
                requiresReconciliation = true
                let host = host
                Self.logger.error("SFTP 写入已取消，未能确认服务器上已停止：\(host, privacy: .private)")
                throw RemoteConnectionError(.cancellationUnconfirmed, result: result)
            }

            do { try await check() }
            catch {
                requiresReconciliation = writing || requiresReconciliation
                let failure = RemoteConnectionError(writing ? .interruptedWrite : .unavailable, result: result)
                self.failure = failure
                updateState(.unavailable)
                throw failure
            }

            throw original
        }
    }

    /// 检查输入结构；单引号属于合法数据，但选项、用户和端口不在别名中拆解。
    private func validateLocation() throws {
        guard
            !host.isEmpty,
            !host.hasPrefix("-"),
            !host.contains(where: { $0.isWhitespace || $0.isNewline }),
            !host.contains("@"), !host.contains(":"), !host.contains("/"),
            !host.utf8.contains(0)
        else { throw RemoteConnectionError(.invalidHost) }

        // 主机连接没有工作区路径
        guard !isHostScoped else { return }

        guard requestedPath.hasPrefix("/"), !requestedPath.utf8.contains(0) else {
            throw RemoteConnectionError(.absolutePathRequired)
        }
    }

    /// 建立无命令主连接，体检成功后才部署包装器并允许仓库进入列表。
    private func establish() async throws {
        let directory = URL(fileURLWithPath: "/tmp/spooky-" + UUID().uuidString.lowercased())
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        localDirectory = directory
        let master = try await ssh([
            "-M", "-N", "-f",
            "-o", "ControlPersist=600",
            "-o", "ClearAllForwardings=yes",
        ], arguments: ["connection-open"])
        guard master.exitCode == 0 else { throw RemoteConnectionError.ssh(master) }
        try await check()

        // 主机连接没有工作区：体检 Git 与 B 端环境后直接部署包装器
        if isHostScoped {
            try await verifyHost()
            try await deployRelay(in: directory)

            // 先关掉上一个会话里的操作，再算连上
            try await closeUnclosedSessions()
            try Task.checkCancellation()
            failure = nil
            updateState(.connected)
            startMonitoring()
            return
        }

        let repository = try await verifyRepository()
        let existing = Self.connections.withLock { connections -> RemoteConnection? in
            if let existing = connections[repository.location], existing !== self {
                connections[.remote(host: host, path: requestedPath)] = existing
                return existing
            }

            connections[repository.location] = self
            return nil
        }

        if let existing {
            // 子目录和根目录指向同一个工作区，关闭额外的体检连接后共享规范会话。
            await tearDown()
            canonical = existing
            if let callbackHandler { await existing.setCallbackHandler(callbackHandler) }
            let repository = try await existing.open()
            self.repository = repository
            updateState(await existing.state)
            mirrorState(from: existing)
            return
        }

        try await deployRelay(in: directory)

        // 先关掉上一个会话里的操作再核对仓库，读到的才不会再被它们改动
        try await closeUnclosedSessions()
        try Task.checkCancellation()
        self.repository = repository
        failure = nil

        if requiresReconciliation { recovery = try await reconcile() }
        updateState(.connected)
        startMonitoring()
    }

    /// 包装器按内容哈希版本化，安装与回调状态均位于仓库之外；安装包装器与新建会话在一次往返里完成。
    private func deployRelay(in directory: URL) async throws {
        guard let resource = Bundle.module.url(forResource: "spooky-remote", withExtension: "pl") else {
            throw RemoteConnectionError(.deployment)
        }

        let source = try Data(contentsOf: resource)
        let version = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        let filename = "spooky-remote-v1-" + String(version.prefix(16))

        // 处理器在请求到达时才取：主机连接为多种操作共用，连接建立后才安装的处理器同样生效
        let relay = try CallbackRelay(
            path: directory.appending(path: "relay.sock").path,
            host: host,
            handler: { [weak self] request in
                let handler = await self?.callbackHandler
                return await handler?(request) ?? nil
            }
        )
        try relay.start()
        self.relay = relay

        // 包装器源码与会话令牌先后经标准输入交给 B；输出的第一行是包装器路径，最后一行是会话目录
        let token = try JSONSerialization.data(withJSONObject: ["token": relay.token]) + Data([10])
        let deployed = try await probe(
            ["/bin/sh", "-c", Self.deploymentScript(filename: filename, length: source.count)],
            input: source + token,
            kind: .deployment
        )

        guard
            let output = String(data: deployed.standardOutput, encoding: .utf8),
            output.hasSuffix("\n"),
            let separator = output.dropLast().lastIndex(of: "\n")
        else { throw RemoteConnectionError(.deployment, result: deployed) }

        let wrapper = String(output[..<separator])
        let remoteDirectory = String(output[output.index(after: separator)...].dropLast())

        guard wrapper.hasPrefix("/"), remoteDirectory.hasPrefix("/tmp/spooky-") else {
            throw RemoteConnectionError(.deployment, result: deployed)
        }

        self.wrapper = wrapper
        Self.logger.info("远端包装器已就绪：\(filename, privacy: .public)")
        self.remoteDirectory = remoteDirectory
        let forward = try await ssh([
            "-O", "forward",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "StreamLocalBindUnlink=yes",
            "-R", remoteDirectory + "/relay.sock:" + relay.path,
        ], arguments: ["relay-forward"])
        guard forward.exitCode == 0 else { throw RemoteConnectionError(.deployment, result: forward) }

        try await startWatcher(wrapper: wrapper, remoteDirectory: remoteDirectory)
    }

    /// 在本工作区执行 Git：带上全局选项与回调配置，交给包装器在独立进程组里运行。
    func runWrapped(
        _ arguments: [String],
        input: Data?,
        acceptedExitCodes: Set<Int32>,
        writing: Bool,
        onOutput: @escaping @Sendable (GitOutputEvent) -> Void
    ) async throws -> GitCommandResult {
        guard let wrapper else { throw RemoteConnectionError(.unavailable) }

        return try await runOperation(
            ["git", "-C", repository?.path ?? requestedPath]
                + GitRunner.globalOptions
                + Self.callbackOptions(wrapper: wrapper)
                + arguments,
            arguments: arguments,
            input: input,
            acceptedExitCodes: acceptedExitCodes,
            writing: writing,
            onOutput: onOutput
        )
    }

    /// 远端输出携带操作专属的结束标记，Git 返回 255 时仍保留 Git 错误身份。
    ///
    /// - Parameters:
    ///   - command: 在 B 上执行的完整命令，由包装器放进独立进程组。
    ///   - arguments: 记进结果与错误的业务参数。
    ///   - inputFile: 标准输入改从这个本机文件读取，大段内容经它传给 B。
    ///   - writing: 中断后是否要求重连核对；主机级命令没有可核对的仓库，传 false。
    func runOperation(
        _ command: [String],
        arguments: [String],
        input: Data? = nil,
        inputFile: URL? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        writing: Bool,
        onOutput: @escaping @Sendable (GitOutputEvent) -> Void
    ) async throws -> GitCommandResult {
        guard let wrapper, let remoteDirectory, let relay else {
            throw RemoteConnectionError(.unavailable)
        }

        let operation = UUID().uuidString.lowercased()
        relay.register(operation)
        defer { relay.unregister(operation) }
        let command = [
            wrapper, "run", remoteDirectory, operation, String(configuration.cancellationGrace),
        ] + command
        let redactor = RemoteOutputRedactor(
            arguments: arguments,
            values: { relay.sensitiveValues(for: operation) },
            output: onOutput
        )
        let output = RemoteOutputFilter(operation: operation, onOutput: { redactor.receive($0) })
        defer { redactor.finish() }

        do {
            let raw = try await commandChannel(command, input: input, inputFile: inputFile, arguments: arguments) {
                output.receive($0)
            }
            let result = redactor.result(try output.completed(raw))

            guard let code = result.exitCode, acceptedExitCodes.contains(code) else {
                throw GitError(result: result, category: GitRunner.category(for: result), diagnostic: nil)
            }

            return result
        } catch {
            let redacted: any Error =
                if let remote = error as? RemoteConnectionError {
                    RemoteConnectionError(
                        remote.kind,
                        result: remote.result.map { redactor.result($0) },
                        diagnostic: remote.diagnostic
                    )
                } else {
                    error
                }

            let gitFailure = redacted as? GitError
            if
                Task.isCancelled || (gitFailure?.isCancelled ?? false)
                || gitFailure?.category == .outputLimitExceeded
                || gitFailure?.category == .processIOFailed
            {
                // 本机已经不再接收这条命令的输出，B 上的进程组由取消确认结束；确认使用不继承取消状态的控制任务。
                let confirmed = await Task.detached {
                    await self.cancelRemote(operation, directory: remoteDirectory, wrapper: wrapper)
                }.value

                if !confirmed {
                    requiresReconciliation = writing || requiresReconciliation
                    throw RemoteConnectionError(
                        .cancellationUnconfirmed,
                        result: gitFailure.map { redactor.result($0.result) }
                    )
                }

                if let gitFailure, !gitFailure.isCancelled {
                    throw GitError(result: redactor.result(gitFailure.result), category: gitFailure.category, diagnostic: nil)
                }

                throw CancellationError()
            }

            if
                let connection = redacted as? RemoteConnectionError,
                [.unavailable, .protocolFailure].contains(connection.kind)
            {
                requiresReconciliation = writing || requiresReconciliation
                failure = connection
                updateState(.unavailable)
            }

            throw redacted
        }
    }

    /// 取消通道只发送随机操作标识，包装器负责 TERM、宽限期、KILL 和退出确认。
    private func cancelRemote(_ operation: String, directory: String, wrapper: String) async -> Bool {
        let host = host
        let grace = String(configuration.cancellationGrace)

        // 被取消的命令在 B 上结束之前仍占着会话，取消通道按主机限量，B 才不会拒绝开新会话
        let result = try? await RepositoryOperationQueue.shared.performCancellation(on: host) {
            try await self.commandChannel(
                [wrapper, "cancel", directory, operation, grace],
                arguments: ["cancel"]
            )
        }
        let confirmed = result?.exitCode == 0

        // 未确认的取消要等重连核对后才能继续写入，记为错误便于事后排查
        Self.logger.log(
            level: confirmed ? .info : .error,
            "远端取消\(confirmed ? "已确认，进程组已退出" : "未得到确认", privacy: .public)：\(host, privacy: .private)"
        )

        return confirmed
    }

    /// 能经常驻通道执行时经它执行，否则另开会话；每个远端参数独立转义，主连接失效时禁止回退到新连接执行写操作。
    ///
    /// - Parameter inputFile: 标准输入改从这个本机文件读取。
    func commandChannel(
        _ command: [String],
        input: Data? = nil,
        inputFile: URL? = nil,
        arguments: [String],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        activeChannels += 1
        defer {
            activeChannels -= 1
            lastCommand = .now
        }

        let channeled = try await executeThroughChannel(
            command,
            input: input,
            inputFile: inputFile,
            arguments: arguments,
            onOutput: onOutput
        )

        if let channeled { return channeled }

        let shell = (configuration.environmentPrefix + command).map(GitRunner.shellQuoted).joined(separator: " ")
        return try await ssh(
            ["-o", "ControlMaster=no", "-o", "ProxyCommand=/usr/bin/false"],
            command: shell,
            input: input,
            inputFile: inputFile,
            arguments: arguments,
            onOutput: onOutput
        )
    }

    /// 本机 SSH 进程固定 locale，原始输出与业务参数分开收集。
    ///
    /// - Parameter inputFile: 标准输入改从这个本机文件读取。
    private func ssh(
        _ options: [String],
        command: String? = nil,
        input: Data? = nil,
        inputFile: URL? = nil,
        arguments: [String],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        guard let localDirectory else { throw RemoteConnectionError(.unavailable) }
        let control = localDirectory.appending(path: "master.sock").path
        let processArguments = configuration.options + ["-S", control] + options
            + ["--", host] + (command.map { [$0] } ?? [])

        if options.contains("-f") {
            // 后台主进程会继承管道，改由专属日志接收诊断，避免等待十分钟才收到 EOF。
            let log = localDirectory.appending(path: "ssh.log")
            let result = try await Subprocess.run(
                .path(FilePath("/usr/bin/ssh")),
                arguments: Arguments(["-E", log.path] + processArguments),
                environment: Self.sshEnvironment,
                input: .none,
                output: .discarded,
                error: .discarded
            )
            let status: GitTerminationStatus =
                switch result.terminationStatus {
                case .exited(let code): .exited(code)
                case .signaled(let signal): .signaled(signal)
                }

            return GitCommandResult(
                arguments: arguments,
                standardOutput: Data(),
                standardError: (try? Data(contentsOf: log)) ?? Data(),
                terminationStatus: status,
                isCancelled: Task.isCancelled
            )
        }

        return try await CommandExecutor.execute(
            executable: "/usr/bin/ssh",
            processArguments: processArguments,
            arguments: arguments,
            environment: Self.sshEnvironment,
            input: input,
            inputFile: inputFile,
            acceptedExitCodes: Set(0 ... 255),
            onOutput: onOutput
        )
    }

    /// 已持有子目录执行器的调用者也能继续观察规范会话的断线与核对结果。
    private func mirrorState(from connection: RemoteConnection) {
        monitor?.cancel()
        monitor = Task { [weak self] in
            for await state in await connection.states() {
                guard !Task.isCancelled else { return }
                await self?.receiveCanonicalState(state, from: connection)
            }
        }
    }

    /// 转发状态时一并取得诊断，保证所有窗口呈现同一连接事实。
    private func receiveCanonicalState(_ state: RemoteConnectionState, from connection: RemoteConnection) async {
        failure = await connection.failure
        recovery = await connection.recovery
        updateState(state)
    }

    /// 连接检测不阻塞主线程，断线后由窗口的重连循环接管。
    private func startMonitoring() {
        monitor?.cancel()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.foregroundPollInterval)
                    guard let self else { return }

                    if await closeIfIdle() { return }

                    try await check()
                } catch { return }
            }
        }
    }

    /// 心跳不算仓库活动，连续十分钟无命令时结束专属主连接。
    private func closeIfIdle() async -> Bool {
        guard activeChannels == 0, lastCommand.duration(to: .now) >= .seconds(600) else { return false }
        await close()
        return true
    }

    /// 经新的主连接尽力关掉没能经旧连接关掉的会话：包装器取消其中全部操作并等待确认，会话目录已不在也算关掉。
    ///
    /// 只有连接本身失败时这次连接才失败，会话留到下次重连再关；包装器确认不了操作结束时记下错误、不再重试，
    /// 旧操作的监管进程已不在时永远等不到确认，不能因此一直连不上。
    private func closeUnclosedSessions() async throws {
        guard let wrapper else { throw RemoteConnectionError(.unavailable) }

        for session in unclosedSessions {
            let result = try await commandChannel([wrapper, "close", session], arguments: ["session-close"])
            if result.exitCode == 255 { throw RemoteConnectionError.ssh(result) }

            // 包装器已执行完关闭，确认与否都移出列表：后面的会话连接失败时，这一个不再重试
            unclosedSessions.removeAll { $0 == session }

            let host = host
            let closed = result.exitCode == 0
            Self.logger.log(
                level: closed ? .info : .error,
                "\(closed ? "已关闭上一个远端会话" : "上一个远端会话里的操作未能确认结束，不再重试", privacy: .public)：\(host, privacy: .private)"
            )
        }
    }

    /// 清理顺序保证远端进程仍可通过主连接收到取消，然后才移除本机中继。
    private func tearDown() async {
        monitor?.cancel()
        monitor = nil

        if let wrapper, let remoteDirectory {
            let closed = try? await commandChannel([wrapper, "close", remoteDirectory], arguments: ["session-close"])

            // 主连接已断或取消没能确认时，会话里的操作可能仍在 B 上执行，看守可能要过了心跳容忍期才清理；记下来，重新连接后先关掉它
            if closed?.exitCode != 0 {
                let host = host
                Self.logger.error("远端会话未能关闭，重新连接后再关闭：\(host, privacy: .private)")
                unclosedSessions.append(remoteDirectory)
            }
        }

        // 关闭会话的请求经常驻通道发出并结束之后，才关掉通道
        closeChannel()

        if localDirectory != nil {
            let host = host
            Self.logger.info("关闭专属主连接：\(host, privacy: .private)")
            _ = try? await ssh(["-O", "exit"], arguments: ["connection-close"])
        }

        relay?.stop()
        relay = nil

        if let localDirectory { try? FileManager.default.removeItem(at: localDirectory) }
        localDirectory = nil
        remoteDirectory = nil
        wrapper = nil
    }

    /// 广播连接状态供工具栏、横幅和测试观察；测试也经它切换连接状态。
    func updateState(_ state: RemoteConnectionState) {
        // 只记录真正发生的切换；进入不可用时附上失败类别，便于定位断线原因
        if state != self.state {
            let host = host
            let reason = state == .unavailable ? failure?.kind.rawValue ?? "-" : "-"
            Self.logger.info(
                "连接状态 \(self.state.rawValue, privacy: .public) → \(state.rawValue, privacy: .public)：\(host, privacy: .private)，失败类别 \(reason, privacy: .public)"
            )
        }

        self.state = state
        for observer in observers.values { observer.yield(state) }
    }

    /// 订阅释放时移除其写入端。
    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
