import Foundation
import Subprocess
import Synchronization
import System

// MARK: - RemoteCommandChannel

/// 常驻在主连接上的一个 SSH 会话，运行包装器的 serve 模式；以包装器开头的命令作为请求经它执行，
/// 省掉每条命令另开会话的往返。
///
/// 已经写出的请求的执行语义与 ``CommandExecutor`` 接受全部退出码时相同：输出上限、取消与超限的错误一致。
/// 通道断开时，已经写完的请求以 255 结束，结果带上通道进程自己的诊断；还没写完的请求抛出 ``NotExecuted``，
/// 调用方改为逐条开会话执行。开始写之前任务已被取消的请求同样抛出 ``NotExecuted``，B 上不会执行它。
///
/// 由连接体检的会话转成的通道，帧之前先是体检脚本的输出，见 ``Preamble``。
///
/// 要求压缩时，B 把请求的标准输出压缩后发回，发起请求的任务各自解开，见 ``chooseOutputCompression(_:)``。
final class RemoteCommandChannel: Sendable {
    /// 请求没有交给 B 执行：通道没有就绪、已经关闭，请求编码后超出上限，或开始写之前任务已被取消。
    struct NotExecuted: Error { }

    /// 一个请求在通道里的进度。
    private enum Progress {
        /// 等着写进通道。
        case queued

        /// 正在写；写完之前通道断开时由写入方决定结果。
        case writing

        /// 已经写完，B 可能已经开始执行。
        case written
    }

    /// 交给发起请求的任务的事件。
    private enum Event: Sendable {
        /// 一段输出。
        case output(Data, isError: Bool)

        /// 压缩输出流里的一段，解开后是标准输出。
        case compressedOutput(Data)

        /// 命令结束的退出码。
        case exit(Int32)

        /// 请求写完之后通道断开，带着通道进程自己的诊断。
        case disconnected(Data)

        /// 请求没有交给 B 执行。
        case notExecuted
    }

    /// 一个还没结束的请求。
    private struct Request {
        /// 交给发起请求的任务的事件流。
        let events: AsyncStream<Event>.Continuation

        /// 写入的进度。
        var progress: Progress
    }

    /// 通道的共享状态。
    private struct State {
        /// 收到过就绪帧。
        var isReady = false

        /// B 的能力标志，来自就绪帧。
        var capabilities: UInt8 = 0

        /// 此后写出的请求是否要求 B 压缩标准输出。
        var compressesOutput = false

        /// 通道已关闭，不再接受请求。
        var isClosed = false

        /// 下一个请求的标识。
        var nextIdentifier: UInt32 = 1

        /// 还没结束的请求。
        var requests: [UInt32: Request] = [:]

        /// 等着通道就绪或关闭的任务。
        var readinessWaiters: [CheckedContinuation<Bool, Never>] = []

        /// 等着应答的探测：收到应答时得到 true，通道关闭时得到 false。
        var probes: [UInt32: CheckedContinuation<Bool, Never>] = [:]

        /// 通道进程自己的标准错误，只留开头一段。
        var diagnostic = Data()

        /// 运行通道进程的任务。
        var process: Task<Void, Never>? = nil
    }

    /// 编码后的请求帧的上限；更大的请求逐条开会话执行。
    static let requestLimit = 1024 * 1024

    /// 等待就绪帧的期限，超过就关闭通道。
    static let readinessTimeout = Duration.seconds(10)

    /// serve 模式的协议版本，写在就绪帧的标识里。
    private static let protocolVersion: UInt32 = 2

    /// 通道进程自己的标准错误保留的字节数。
    private static let diagnosticLimit = 64 * 1024

    /// 共享状态。
    private let state = Mutex(State())

    /// 通道进程标准输入的写入端；没有交给进程库的写入器，写失败时不会收到 SIGPIPE。
    private let input: Int32

    /// 按顺序写请求帧、放弃帧并在最后关掉写入端的串行队列；写入会阻塞，不放在协作线程池上。
    private let writer = DispatchQueue(label: "com.rakuyo.spooky.remote-command-channel")

    /// 通道不是由 ``close()`` 关掉时的通知。
    private let onDisconnect: @Sendable (RemoteCommandChannel) -> Void

    /// 帧之前的前导；通道进程一开始就是 serve 模式时为 nil。
    let preamble: Preamble?

    /// 通道已就绪且没有关闭。
    var isReady: Bool {
        state.withLock { $0.isReady && !$0.isClosed }
    }

    /// 创建即启动通道进程；管道建不起来时通道直接处于关闭状态。
    ///
    /// - Parameters:
    ///   - executable: 通道进程的可执行文件。
    ///   - arguments: 通道进程的参数。
    ///   - environment: 通道进程的环境变量。
    ///   - preamble: 帧之前的前导；它的输入先于任何帧写进标准输入，就绪的期限从前导结束时算起。
    ///   - onDisconnect: 通道自行断开时的通知，``close()`` 关掉时不通知。
    init(
        executable: String,
        arguments: [String],
        environment: Environment,
        preamble: Preamble? = nil,
        onDisconnect: @escaping @Sendable (RemoteCommandChannel) -> Void
    ) {
        self.onDisconnect = onDisconnect
        self.preamble = preamble

        // 两端都不让其它子进程继承；写入端关掉 SIGPIPE，进程退出后写入只会得到 EPIPE
        var descriptors: [Int32] = [-1, -1]
        let created = pipe(&descriptors) == 0
        input = descriptors[1]

        guard created else {
            state.withLock { $0.isClosed = true }

            // 进程没有启动，前导以管道的错误结束
            let failure = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            Task { await preamble?.finish(.failure(failure), cancelled: false) }
            return
        }

        _ = fcntl(descriptors[0], F_SETFD, FD_CLOEXEC)
        _ = fcntl(descriptors[1], F_SETFD, FD_CLOEXEC)
        _ = fcntl(descriptors[1], F_SETNOSIGPIPE, 1)

        // 所有请求的输出都由这个任务读，优先级固定为用户发起、不继承打开通道的任务：
        // 后台重新打开或重连时建立的通道，不会让用户发起的命令等着低优先级的读取
        let process = Task(priority: .userInitiated) { [self] in
            await run(
                executable: executable,
                arguments: arguments,
                environment: environment,
                input: FileDescriptor(rawValue: descriptors[0])
            )
        }

        state.withLock { $0.process = process }

        guard let preamble else {
            armReadinessTimeout()
            return
        }

        // 前导的输入先于任何帧写进去：脚本读完它才会转成 serve 模式
        writer.async { [self] in _ = writeAll(preamble.input) }
    }

    /// 等到通道就绪或关闭；等待期间任务被取消时关闭通道，不等满就绪期限。
    ///
    /// - Returns: 通道是否就绪。
    func waitUntilReady() async -> Bool {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let ready: Bool? = state.withLock { state in
                    if state.isClosed { return false }
                    if state.isReady { return true }

                    state.readinessWaiters.append(continuation)
                    return nil
                }

                if let ready {
                    continuation.resume(returning: ready)
                }
            }
        } onCancel: {
            close()
        }
    }

    /// 经通道执行一个包装器模式；就绪之前也可以写入，B 就绪后按顺序执行。
    ///
    /// - Parameters:
    ///   - arguments: 包装器的模式与它的参数。
    ///   - input: 请求的标准输入，空时 B 上的命令读到 `/dev/null`。
    ///   - resultArguments: 记进结果与错误的业务参数。
    ///   - onOutput: 输出片段的订阅者。
    /// - Returns: 命令的输出与退出状态；通道在请求写完之后断开时以 255 结束。
    func execute(
        _ arguments: [String],
        input: Data,
        resultArguments: [String],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        // 任务已经取消时不发请求，B 上不会开始执行
        guard !Task.isCancelled else { throw NotExecuted() }

        // 按算出的帧大小判断上限，超出时不登记也不编码
        guard Frame.requestSize(arguments: arguments, input: input) <= Self.requestLimit else { throw NotExecuted() }

        let (events, continuation) = AsyncStream<Event>.makeStream()

        let registration: (identifier: UInt32, compressesOutput: Bool)? = state.withLock { state in
            guard !state.isClosed else { return nil }

            let identifier = state.nextIdentifier
            state.nextIdentifier &+= 1
            state.requests[identifier] = Request(events: continuation, progress: .queued)
            return (identifier, state.compressesOutput)
        }

        guard let registration else { throw NotExecuted() }

        let identifier = registration.identifier
        let frame = Frame.request(
            identifier: identifier,
            arguments: arguments,
            input: input,
            compressesOutput: registration.compressesOutput
        )
        writer.async { [self] in write(frame, for: identifier) }

        let collector = GitOutputCollector(onOutput: onOutput)

        return try await withTaskCancellationHandler {
            try await receive(events, for: identifier, collector: collector, arguments: resultArguments)
        } onCancel: {
            abort(identifier)
        }
    }

    /// 由持有者关闭通道：还没写完的请求不再执行，已经写完的请求以 255 结束。
    func close() {
        shutDown(byOwner: true)
    }

    /// 开始等待就绪帧：期限内没有就绪就结束通道进程，进程结束后通道随之关闭。
    func armReadinessTimeout() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.readinessTimeout)
            self?.stopIfStarting()
        }
    }

    /// 定下此后经这条通道的请求是否要求 B 压缩标准输出，在通道就绪之后调用。
    ///
    /// 自动时先在后台发 ``probeCount`` 次探测，按最短的往返时间决定，量完之前的请求不压缩。
    ///
    /// - Parameter mode: 压缩的设置。
    func chooseOutputCompression(_ mode: SSHConfiguration.OutputCompression) {
        let capable = state.withLock { $0.capabilities & Self.compressionCapability != 0 }

        // 不用量往返时间就能定下的，直接定下
        guard mode == .automatic, capable else {
            let compresses = Self.compressesOutput(roundTrip: nil, capable: capable, mode: mode)
            state.withLock { $0.compressesOutput = compresses }
            return
        }

        Task {
            var shortest: Duration? = nil

            for _ in 0 ..< Self.probeCount {
                // 通道关闭时不再量，也不再改动
                guard let roundTrip = await probe() else { return }

                shortest = min(shortest ?? roundTrip, roundTrip)
            }

            let compresses = Self.compressesOutput(roundTrip: shortest, capable: capable, mode: mode)
            state.withLock { $0.compressesOutput = compresses }
        }
    }
}

// MARK: - Private

extension RemoteCommandChannel {
    /// 运行通道进程，边读边切开它发回的帧；进程结束后先结束还没结束的前导，再关闭通道。
    private func run(
        executable: String,
        arguments: [String],
        environment: Environment,
        input: FileDescriptor
    ) async {
        // 与逐条执行相同：通道进程独占一个进程组，结束时先 TERM、宽限期后再 KILL
        var platform = PlatformOptions()
        platform.createSession = true
        platform.teardownSequence = [
            .gracefulShutDown(toProcessGroup: true, allowedDurationToNextStep: CommandExecutor.cancellationGrace),
        ]

        let outcome: Result<GitTerminationStatus, any Error>

        do {
            let execution = try await Subprocess.run(
                .path(FilePath(executable)),
                arguments: Arguments(arguments),
                environment: environment,
                platformOptions: platform,
                input: .fileDescriptor(input, closeAfterSpawningProcess: true),
                output: .sequence,
                error: .sequence
            ) { execution in
                async let diagnostic: Void = collectDiagnostic(execution.standardError)
                try await readFrames(execution.standardOutput)
                try await diagnostic
            }

            switch execution.terminationStatus {
            case .exited(let code):
                outcome = .success(.exited(code))

            case .signaled(let signal):
                outcome = .success(.signaled(signal))
            }
        } catch {
            outcome = .failure(error)
        }

        // 没写完前导就结束时，体检的结果按进程的结果建立；前导已经结束时不再改动
        await preamble?.finish(outcome, cancelled: Task.isCancelled)
        shutDown(byOwner: false)
    }

    /// 读通道进程的标准输出，前导之后切出的事件立即交给对应的请求；分发不等待请求的消费者。
    private func readFrames(_ output: SubprocessOutputSequence) async throws {
        var reader = FrameReader()
        var stream = PreambleStream()

        for try await buffer in output {
            let data = try await passPreamble(Data(buffer: buffer), isError: false, stream: &stream)

            for event in try reader.receive(data) {
                try deliver(event)
            }
        }

        try await endPreamble(stream, isError: false)
    }

    /// 把一个事件交给对应的请求；就绪帧的协议版本不对时结束通道。
    private func deliver(_ event: FrameReader.Event) throws {
        switch event {
        case .ready(let version, let capabilities):
            guard version == Self.protocolVersion else { throw FrameReader.InvalidFrame() }

            let waiters = state.withLock { state in
                state.isReady = !state.isClosed
                state.capabilities = capabilities
                defer { state.readinessWaiters = [] }
                return state.readinessWaiters
            }

            for waiter in waiters {
                waiter.resume(returning: true)
            }

        case .output(let identifier, let isError, let data):
            state.withLock { _ = $0.requests[identifier]?.events.yield(.output(data, isError: isError)) }

        case .compressedOutput(let identifier, let data):
            state.withLock { _ = $0.requests[identifier]?.events.yield(.compressedOutput(data)) }

        case .probeReply(let identifier):
            state.withLock { $0.probes.removeValue(forKey: identifier) }?.resume(returning: true)

        case .exit(let identifier, let code):
            let request = state.withLock { $0.requests.removeValue(forKey: identifier) }
            request?.events.yield(.exit(Int32(code)))
            request?.events.finish()
        }
    }

    /// 收下通道进程前导之后的标准错误，只留开头一段作诊断。
    private func collectDiagnostic(_ errors: SubprocessOutputSequence) async throws {
        var stream = PreambleStream()

        for try await buffer in errors {
            let data = try await passPreamble(Data(buffer: buffer), isError: true, stream: &stream)

            state.withLock { state in
                state.diagnostic.append(data.prefix(max(0, Self.diagnosticLimit - state.diagnostic.count)))
            }
        }

        try await endPreamble(stream, isError: true)
    }

    /// 消费一个请求的事件，结束时按逐条执行的规则建立结果；压缩的输出在这里解开，输出上限按解开后的字节数算。
    private func receive(
        _ events: AsyncStream<Event>,
        for identifier: UInt32,
        collector: GitOutputCollector,
        arguments: [String]
    ) async throws -> GitCommandResult {
        var termination: GitTerminationStatus? = nil

        // 这个请求的解压器，收到第一段压缩输出时建立
        var inflater: Inflater? = nil

        receiving: for await event in events {
            let output: (data: Data, isError: Bool)

            switch event {
            case .output(let data, let isError):
                output = (data, isError)

            case .compressedOutput(let data):
                let current = inflater ?? Inflater()
                inflater = current

                guard let plain = try? current.inflate(data) else {
                    // 解不开说明通道的字节流已经错乱：与收到格式不对的帧一样关掉通道，这个请求按通道断开处理
                    try? await collector.receive(breakChannel(dropping: identifier), isError: true)
                    termination = .exited(255)
                    break receiving
                }

                output = (plain, false)

            case .exit(let code):
                termination = .exited(code)
                continue

            case .disconnected(let diagnostic):
                // 与逐条执行时 SSH 的 255 相同：通道进程自己的诊断接在命令的标准错误之后
                try? await collector.receive(diagnostic, isError: true)
                termination = .exited(255)
                continue

            case .notExecuted:
                throw NotExecuted()
            }

            do {
                try await collector.receive(output.data, isError: output.isError)
            } catch {
                throw await overflow(identifier, collector: collector, arguments: arguments)
            }
        }

        // 事件流没有结束事件就关闭，说明任务被取消、请求已被放弃
        let result = await collector.result(
            arguments: arguments,
            termination: termination,
            cancelled: Task.isCancelled || termination == nil
        )

        guard !result.isCancelled else {
            throw GitError(result: result, category: .cancelled, diagnostic: nil)
        }

        return result
    }

    /// 在写入队列上写一个请求帧；写完之前通道断开或写失败时，按 B 能否已经执行决定请求的结果。
    private func write(_ frame: Data, for identifier: UInt32) {
        let proceeds = state.withLock { state in
            guard !state.isClosed, state.requests[identifier]?.progress == .queued else { return false }

            state.requests[identifier]?.progress = .writing
            return true
        }

        guard proceeds else { return }

        let written = writeAll(frame)

        let (request, event): (Request?, Event?) = state.withLock { state in
            guard let request = state.requests[identifier] else { return (nil, nil) }

            // 没写完的帧 B 不会执行；写完时通道已经断开，B 可能已经执行
            if !written {
                state.requests[identifier] = nil
                return (request, .notExecuted)
            }

            if state.isClosed {
                state.requests[identifier] = nil
                return (request, state.isReady ? .disconnected(state.diagnostic) : .notExecuted)
            }

            state.requests[identifier]?.progress = .written
            return (nil, nil)
        }

        if let request, let event {
            request.events.yield(event)
            request.events.finish()
        }

        // 写不进去说明通道进程已经不读标准输入，结束它，通道随之关闭
        if !written {
            state.withLock { $0.process }?.cancel()
        }
    }

    /// 一个请求的输出超出上限：不再要这个请求的输出，结果只带上限内的字节；任务已被取消时按取消处理。
    ///
    /// - Returns: 交给调用方的错误。
    private func overflow(
        _ identifier: UInt32,
        collector: GitOutputCollector,
        arguments: [String]
    ) async -> GitError {
        abort(identifier)

        let cancelled = Task.isCancelled
        let result = await collector.result(arguments: arguments, termination: nil, cancelled: cancelled)

        return GitError(
            result: result,
            category: cancelled ? .cancelled : .outputLimitExceeded,
            diagnostic: nil
        )
    }

    /// 一个请求的压缩输出解不开：不再为它收事件，与收到格式不对的帧一样结束通道进程，通道随之关闭。
    ///
    /// - Returns: 通道进程到此为止的诊断。
    private func breakChannel(dropping identifier: UInt32) -> Data {
        let (request, process, diagnostic) = state.withLock { state in
            (state.requests.removeValue(forKey: identifier), state.process, state.diagnostic)
        }

        request?.events.finish()
        process?.cancel()
        return diagnostic
    }

    /// 发一次探测并等它的应答。
    ///
    /// - Returns: 从发出到收到应答的时间；通道已经关闭或在等待期间关闭时为 nil。
    private func probe() async -> Duration? {
        let start = ContinuousClock.now

        let answered = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let identifier: UInt32? = state.withLock { state in
                guard !state.isClosed else { return nil }

                let identifier = state.nextIdentifier
                state.nextIdentifier &+= 1
                state.probes[identifier] = continuation
                return identifier
            }

            guard let identifier else {
                continuation.resume(returning: false)
                return
            }

            // 关闭通道之后不再写：写入端可能已经关掉
            writer.async { [self] in
                guard !state.withLock({ $0.isClosed }) else { return }

                if !writeAll(Frame.probe(identifier: identifier)) {
                    state.withLock { $0.process }?.cancel()
                }
            }
        }

        return answered ? start.duration(to: .now) : nil
    }

    /// 放弃一个请求：不再等它的事件；还没开始写的请求以 ``NotExecuted`` 结束，已经开始写的请求另发放弃帧，B 不再为它发帧。
    private func abort(_ identifier: UInt32) {
        guard let request = state.withLock({ $0.requests.removeValue(forKey: identifier) }) else { return }

        // 还没开始写的请求从此不会写出，B 上不会执行它
        guard request.progress != .queued else {
            request.events.yield(.notExecuted)
            request.events.finish()
            return
        }

        request.events.finish()

        writer.async { [self] in
            guard !state.withLock({ $0.isClosed }) else { return }

            if !writeAll(Frame.abort(identifier: identifier)) {
                state.withLock { $0.process }?.cancel()
            }
        }
    }

    /// 期限到了仍没有就绪时结束通道进程。
    private func stopIfStarting() {
        let process = state.withLock { state in
            state.isReady || state.isClosed ? nil : state.process
        }

        process?.cancel()
    }

    /// 关闭通道：交出还没结束的请求的结果，叫醒等待就绪的任务与探测，最后关掉写入端并结束通道进程。
    ///
    /// 正在写的请求由写入方在写完后决定结果。
    private func shutDown(byOwner: Bool) {
        var finished: [(Request, Event)] = []
        var waiters: [CheckedContinuation<Bool, Never>] = []
        var probes: [CheckedContinuation<Bool, Never>] = []
        var process: Task<Void, Never>? = nil

        let closes = state.withLock { state in
            guard !state.isClosed else { return false }

            state.isClosed = true

            for (identifier, request) in state.requests where request.progress != .writing {
                let event: Event = request.progress == .written && state.isReady
                    ? .disconnected(state.diagnostic)
                    : .notExecuted

                finished.append((request, event))
                state.requests[identifier] = nil
            }

            waiters = state.readinessWaiters
            state.readinessWaiters = []
            probes = Array(state.probes.values)
            state.probes = [:]
            process = state.process
            return true
        }

        guard closes else { return }

        for (request, event) in finished {
            request.events.yield(event)
            request.events.finish()
        }

        for waiter in waiters + probes {
            waiter.resume(returning: false)
        }

        // 写入队列按顺序执行，正在写的帧写完或失败之后才关掉写入端
        let input = input
        writer.async { _ = Darwin.close(input) }
        process?.cancel()

        if !byOwner {
            onDisconnect(self)
        }
    }

    /// 把一整帧写进通道进程的标准输入。
    ///
    /// - Returns: 是否全部写完；对端已关闭时返回 false。
    private func writeAll(_ data: Data) -> Bool {
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return true }

            var offset = 0

            while offset < buffer.count {
                let count = Darwin.write(input, base + offset, buffer.count - offset)

                if count < 0 {
                    if errno == EINTR { continue }
                    return false
                }

                offset += count
            }

            return true
        }
    }
}
