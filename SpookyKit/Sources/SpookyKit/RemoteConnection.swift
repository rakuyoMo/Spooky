import CryptoKit
import Foundation
import Subprocess
import Synchronization
import System

// MARK: - RemoteConnectionState

/// 仓库的 SSH 连接状态，断线不清空上次成功的工作区快照。
public enum RemoteConnectionState: String, Sendable, CaseIterable {
    /// 正在完成首次体检与部署。
    case connecting

    /// 主连接和回调通道可用。
    case connected

    /// 正在重新建立主连接。
    case reconnecting

    /// 当前不可用，保留诊断供重试。
    case unavailable
}

// MARK: - RemoteRecoverySnapshot

/// 写操作中断后重新读取的仓库事实，不推测原命令是否成功。
public struct RemoteRecoverySnapshot: Sendable {
    /// 当前分支及工作区的完整状态。
    public let status: WorkingCopyStatus

    /// 外部进程是否仍持有暂存区锁。
    public let indexLocked: Bool

    /// 是否有合并尚未结束。
    public let merging: Bool

    /// 是否有变基尚未结束。
    public let rebasing: Bool

    /// 完成核对的时间，界面只采用晚于写入中断的核对结果。
    public let checkedAt: Date
}

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

    /// SSH 配置中的主机别名。
    public nonisolated let host: String

    /// 用户指定的绝对路径，体检成功后使用规范根路径。
    public nonisolated let requestedPath: String

    /// 当前连接状态。
    public private(set) var state = RemoteConnectionState.unavailable

    /// 上次连接错误。
    public private(set) var failure: RemoteConnectionError? = nil

    /// 最近一次体检确认的仓库身份。
    public private(set) var repository: RemoteRepository? = nil

    /// 写操作断线后取得的核对结果。
    public private(set) var recovery: RemoteRecoverySnapshot? = nil

    /// 同一主机的每条连接使用独立控制目录。
    private var localDirectory: URL? = nil

    /// B 上的 0700 会话目录。
    private var remoteDirectory: String? = nil

    /// 已原子部署的版本化包装器。
    private var wrapper: String? = nil

    /// 从子目录打开时复用已登记的工作区根会话。
    private var canonical: RemoteConnection? = nil

    /// 本机回调服务，凭据只通过此对象在内存中流转。
    private var relay: CallbackRelay? = nil

    /// 主连接检查任务。
    private var monitor: Task<Void, Never>? = nil

    /// 合并同时发起的连接请求。
    private var connecting: Task<RemoteRepository, Error>? = nil

    /// 关闭流程合并执行，重新打开必须等待旧会话清理完毕。
    private var closing: Task<Void, Never>? = nil

    /// 状态的多订阅者事件流。
    private var observers: [UUID: AsyncStream<RemoteConnectionState>.Continuation] = [:]

    /// 写操作断线或取消未确认时阻止继续写入。
    private var requiresReconciliation = false

    /// 最近一条命令结束的单调时间，心跳不延长空闲期限。
    private var lastCommand = ContinuousClock.now

    /// 尚未结束的命令不能被空闲清理打断。
    private var activeChannels = 0

    /// 系统 SSH 参数与隔离测试选项。
    private let configuration: SSHConfiguration

    /// 应用提供的凭据及编辑器交互入口。
    private var callbackHandler: RemoteCallbackHandler? = nil

    /// 创建会话不产生网络访问，首次 open 或 execute 才建立连接。
    init(host: String, path: String, configuration: SSHConfiguration = SSHConfiguration()) {
        self.host = host
        requestedPath = path
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
        try Task.checkCancellation()
        if let canonical { return try await canonical.open() }
        if let closing { await closing.value }
        if state == .connected, let repository { return repository }
        if let connecting { return try await connecting.value }
        try validateLocation()
        updateState(repository == nil ? .connecting : .reconnecting)

        let task = Task { try await self.establish() }
        connecting = task

        return try await withTaskCancellationHandler {
            do {
                let repository = try await task.value
                connecting = nil
                return repository
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

    /// 只检查主连接，不允许 SSH 因复用失败悄悄新建连接。
    public func check() async throws {
        if let canonical {
            try await canonical.check()
            return
        }

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

    /// 一次往返检查多个远端路径是否存在，状态文件读取据此跳过不存在的文件。
    func inspect(_ paths: [String]) async throws -> [Bool] {
        try Task.checkCancellation()

        if repository == nil {
            _ = try await open()
        }

        if let canonical {
            return try await canonical.inspect(paths)
        }

        let location = RepositoryLocation.remote(host: host, path: repository?.path ?? requestedPath)
        return try await RepositoryOperationQueue.shared.perform(at: location, writing: false) {
            try await self.inspectConnected(paths)
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

        try await check()
        event(.started)
        return try await runWrapped(
            arguments,
            input: input,
            acceptedExitCodes: acceptedExitCodes,
            writing: writing,
            onOutput: { event(.output($0)) }
        )
    }

    /// 获得主机槽后再确认连接；主连接失效时与命令通道一样转为不可用状态。
    private func inspectConnected(_ paths: [String]) async throws -> [Bool] {
        guard state == .connected else { throw failure ?? RemoteConnectionError(.unavailable) }
        try await check()

        do {
            return try await inspectFlags(paths)
        } catch let error as RemoteConnectionError where error.kind == .unavailable {
            failure = error
            updateState(.unavailable)
            throw error
        }
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
                environment: .inherit.updating(["LC_ALL": "en_US.UTF-8"]),
                input: input
            )
        } catch {
            let original = error
            let result = (error as? GitError)?.result

            if Task.isCancelled {
                if writing { requiresReconciliation = true }
                throw original
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

        guard requestedPath.hasPrefix("/"), !requestedPath.utf8.contains(0) else {
            throw RemoteConnectionError(.absolutePathRequired)
        }
    }

    /// 建立无命令主连接，体检成功后才部署包装器并允许仓库进入列表。
    private func establish() async throws -> RemoteRepository {
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
            return repository
        }

        try await deployRelay(in: directory)
        try Task.checkCancellation()
        self.repository = repository
        failure = nil

        if requiresReconciliation { recovery = try await reconcile() }
        updateState(.connected)
        startMonitoring()
        return repository
    }

    /// 包装器按内容哈希版本化，安装与回调状态均位于仓库之外。
    private func deployRelay(in directory: URL) async throws {
        guard let resource = Bundle.module.url(forResource: "spooky-remote", withExtension: "pl") else {
            throw RemoteConnectionError(.deployment)
        }

        let source = try Data(contentsOf: resource)
        let version = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        let filename = "spooky-remote-v1-" + String(version.prefix(16))
        let install = """
            set -eu
            umask 077
            /usr/bin/perl -MIO::Socket::UNIX -MJSON::PP -MPOSIX -e 'exit 0'
            test ! -L "$HOME/.spooky"
            test ! -L "$HOME/.spooky/bin"
            mkdir -p "$HOME/.spooky/bin"
            chmod 700 "$HOME/.spooky" "$HOME/.spooky/bin"
            spooky_install_file=$(mktemp "$HOME/.spooky/bin/.install-XXXXXXXX")
            trap 'rm -f "$spooky_install_file" "$spooky_install_file-askpass" "$spooky_install_file-git-askpass"' EXIT HUP INT TERM
            cat > "$spooky_install_file"
            chmod 700 "$spooky_install_file"
            ln "$spooky_install_file" "$spooky_install_file-askpass"
            ln "$spooky_install_file" "$spooky_install_file-git-askpass"
            mv -f "$spooky_install_file" "$HOME/.spooky/bin/\(filename)"
            mv -f "$spooky_install_file-askpass" "$HOME/.spooky/bin/\(filename)-askpass"
            mv -f "$spooky_install_file-git-askpass" "$HOME/.spooky/bin/\(filename)-git-askpass"
            printf '%s\\n' "$HOME/.spooky/bin/\(filename)"
            """
        let installed = try await probe(["/bin/sh", "-c", install], input: source, kind: .deployment)
        guard
            let path = String(data: installed.standardOutput, encoding: .utf8),
            path.hasPrefix("/"), path.hasSuffix("\n")
        else { throw RemoteConnectionError(.deployment, result: installed) }

        let wrapper = String(path.dropLast())
        self.wrapper = wrapper
        let relay = try CallbackRelay(
            path: directory.appending(path: "relay.sock").path,
            host: host,
            handler: callbackHandler ?? { _ in nil }
        )
        try relay.start()
        self.relay = relay
        let input = try JSONSerialization.data(withJSONObject: ["token": relay.token]) + Data([10])
        let created = try await probe([wrapper, "create-session"], input: input, kind: .deployment)
        guard
            let path = String(data: created.standardOutput, encoding: .utf8),
            path.hasPrefix("/tmp/spooky-"), path.hasSuffix("\n"),
            !path.dropLast().contains("\n")
        else { throw RemoteConnectionError(.deployment, result: created) }

        let remoteDirectory = String(path.dropLast())
        self.remoteDirectory = remoteDirectory
        let forward = try await ssh([
            "-O", "forward",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "StreamLocalBindUnlink=yes",
            "-R", remoteDirectory + "/relay.sock:" + relay.path,
        ], arguments: ["relay-forward"])
        guard forward.exitCode == 0 else { throw RemoteConnectionError(.deployment, result: forward) }
        _ = try await probe([wrapper, "watch", remoteDirectory], kind: .deployment)
    }

    /// 远端输出携带操作专属的结束标记，Git 返回 255 时仍保留 Git 错误身份。
    private func runWrapped(
        _ arguments: [String],
        input: Data?,
        acceptedExitCodes: Set<Int32>,
        writing: Bool,
        onOutput: @escaping @Sendable (GitOutputEvent) -> Void
    ) async throws -> GitCommandResult {
        guard let wrapper, let remoteDirectory, let relay else {
            throw RemoteConnectionError(.unavailable)
        }

        let operation = UUID().uuidString.lowercased()
        relay.register(operation)
        defer { relay.unregister(operation) }
        let callback = GitRunner.shellQuoted(wrapper)
        let command = [
            wrapper, "run", remoteDirectory, operation, String(configuration.cancellationGrace),
            "git", "-C", repository?.path ?? requestedPath,
        ] + GitRunner.globalOptions + [
            "-c", "credential.helper=",
            "-c", "core.askPass=\(wrapper)-git-askpass",
            "-c", "core.editor=\(callback) editor",
            "-c", "sequence.editor=\(callback) editor",
            "-c", "core.sshCommand=\(callback) ssh",
        ] + arguments
        let redactor = RemoteOutputRedactor(
            values: { relay.sensitiveValues(for: operation) },
            output: onOutput
        )
        let output = RemoteOutputFilter(operation: operation, onOutput: { redactor.receive($0) })
        defer { redactor.finish() }

        do {
            let raw = try await commandChannel(command, input: input, arguments: arguments) {
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
                // 命令通道已由进程执行器关闭，取消确认使用不继承取消状态的控制任务。
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
        let result = try? await commandChannel([
            wrapper, "cancel", directory, operation, String(configuration.cancellationGrace),
        ], arguments: ["cancel"])
        return result?.exitCode == 0
    }

    /// 重连后的核对由 Git 定位元数据，只检查锁与进行中操作的存在性。
    private func reconcile() async throws -> RemoteRecoverySnapshot {
        let rawStatus = try await runWrapped(
            ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all"],
            input: nil,
            acceptedExitCodes: [0],
            writing: false,
            onOutput: { _ in }
        )
        let names = ["index.lock", "MERGE_HEAD", "rebase-merge", "rebase-apply"]
        var paths: [String] = []

        for name in names {
            let result = try await runWrapped(
                ["rev-parse", "--path-format=absolute", "--git-path", name],
                input: nil,
                acceptedExitCodes: [0],
                writing: false,
                onOutput: { _ in }
            )
            paths.append(String(decoding: result.standardOutput.dropLast(), as: UTF8.self))
        }

        let flags = try await inspectFlags(paths)
        let snapshot = RemoteRecoverySnapshot(
            status: try WorkingCopyStatus(porcelainV2: rawStatus.standardOutput),
            indexLocked: flags[0],
            merging: flags[1],
            rebasing: flags[2] || flags[3],
            checkedAt: Date()
        )
        requiresReconciliation = false
        return snapshot
    }

    /// 包装器逐行返回存在标记，行数必须与输入路径一一对应，只检查存在性、不读内容。
    private func inspectFlags(_ paths: [String]) async throws -> [Bool] {
        guard let wrapper else {
            throw RemoteConnectionError(.unavailable)
        }

        let inspected = try await probe([wrapper, "inspect"] + paths, kind: .protocolFailure)
        let flags = String(decoding: inspected.standardOutput, as: UTF8.self).split(separator: "\n")

        guard flags.count == paths.count, flags.allSatisfy({ $0 == "0" || $0 == "1" }) else {
            throw RemoteConnectionError(.protocolFailure, result: inspected)
        }

        return flags.map { $0 == "1" }
    }

    /// 每个远端参数独立转义，主连接失效时禁止回退到新连接执行写操作。
    private func commandChannel(
        _ command: [String],
        input: Data? = nil,
        arguments: [String],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        activeChannels += 1
        defer {
            activeChannels -= 1
            lastCommand = .now
        }

        let shell = (configuration.environmentPrefix + command).map(GitRunner.shellQuoted).joined(separator: " ")
        return try await ssh(
            ["-o", "ControlMaster=no", "-o", "ProxyCommand=/usr/bin/false"],
            command: shell,
            input: input,
            arguments: arguments,
            onOutput: onOutput
        )
    }

    /// 本机 SSH 进程固定 locale，原始输出与业务参数分开收集。
    private func ssh(
        _ options: [String],
        command: String? = nil,
        input: Data? = nil,
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
                environment: .inherit.updating(["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]),
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
            environment: .inherit.updating(["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]),
            input: input,
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

    /// 清理顺序保证远端进程仍可通过主连接收到取消，然后才移除本机中继。
    private func tearDown() async {
        monitor?.cancel()
        monitor = nil

        if let wrapper, let remoteDirectory {
            _ = try? await commandChannel([wrapper, "close", remoteDirectory], arguments: ["session-close"])
        }

        if localDirectory != nil {
            _ = try? await ssh(["-O", "exit"], arguments: ["connection-close"])
        }

        relay?.stop()
        relay = nil

        if let localDirectory { try? FileManager.default.removeItem(at: localDirectory) }
        localDirectory = nil
        remoteDirectory = nil
        wrapper = nil
    }

    /// 广播连接状态供工具栏、横幅和测试观察。
    private func updateState(_ state: RemoteConnectionState) {
        self.state = state
        for observer in observers.values { observer.yield(state) }
    }

    /// 订阅释放时移除其写入端。
    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
