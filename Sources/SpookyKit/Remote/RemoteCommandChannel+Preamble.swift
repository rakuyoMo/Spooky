import Foundation
import Synchronization

// MARK: - Preamble

extension RemoteCommandChannel {
    /// 通道进程在帧之前的一段输出：连接体检的会话转成常驻通道时，体检脚本先写各步骤的结果，
    /// 两路输出各写一个转入通道的标记之后才 exec 到包装器的 serve 模式。
    ///
    /// 两路输出由 ``RemoteHealthCheck/Splitter`` 切开：转入通道的标记之前的输出组成体检的结果，上限与逐条执行相同；
    /// 之后的标准输出按帧切开，标准错误作通道自己的诊断。标准输出的第一个分隔帧在前导结束之前就交给连接。
    /// 两路都读到转入通道的标记时体检以 0 结束；进程没写完前导就结束时，体检的结果带着进程的结束状态。
    final class Preamble: Sendable {
        /// 前导的进度。
        private struct State {
            /// 还没读到转入通道的标记的输出路数。
            var remaining = 2

            /// 体检的结果，前导结束后才有。
            var outcome: Result<GitCommandResult, GitError>? = nil

            /// 等着体检结果的任务。
            var waiters: [CheckedContinuation<Result<GitCommandResult, GitError>, Never>] = []

            /// 标准输出的第一个分隔帧；前导结束时还没读到它就是 nil。
            var firstFrame: RemoteHealthCheck.Splitter.Frame? = nil

            /// 第一个分隔帧已经读到，或前导已经结束。
            var isFrameSettled = false

            /// 等着第一个分隔帧的任务。
            var frameWaiters: [CheckedContinuation<RemoteHealthCheck.Splitter.Frame?, Never>] = []
        }

        /// 记进体检结果与错误的业务参数。
        let arguments: [String]

        /// 收集分隔标记之前的输出。
        let collector = GitOutputCollector(onOutput: nil)

        /// 共享状态。
        private let state = Mutex(State())

        /// 创建一段前导。
        ///
        /// - Parameter arguments: 记进体检结果与错误的业务参数。
        init(arguments: [String]) {
            self.arguments = arguments
        }

        /// 等到前导结束，取体检的结果。
        func outcome() async -> Result<GitCommandResult, GitError> {
            await withCheckedContinuation { continuation in
                let outcome = state.withLock { state -> Result<GitCommandResult, GitError>? in
                    if let outcome = state.outcome { return outcome }

                    state.waiters.append(continuation)
                    return nil
                }

                if let outcome {
                    continuation.resume(returning: outcome)
                }
            }
        }

        /// 等到标准输出的第一个分隔帧；前导没读到它就结束时为 nil。
        func firstFrame() async -> RemoteHealthCheck.Splitter.Frame? {
            await withCheckedContinuation { continuation in
                let settled = state.withLock { state -> RemoteHealthCheck.Splitter.Frame?? in
                    if state.isFrameSettled { return .some(state.firstFrame) }

                    state.frameWaiters.append(continuation)
                    return .none
                }

                if let settled {
                    continuation.resume(returning: settled)
                }
            }
        }

        /// 通道进程结束或读取出错时结束前导：按逐条执行的规则把进程的结果或错误转成体检的结果；前导已经结束时不再改动。
        ///
        /// - Parameters:
        ///   - outcome: 进程的结束状态，或启动进程、读取输出时抛出的错误。
        ///   - cancelled: 通道进程是否已被结束。
        func finish(_ outcome: Result<GitTerminationStatus, any Error>, cancelled: Bool) async {
            guard state.withLock({ $0.outcome == nil }) else { return }

            switch outcome {
            case .success(let termination):
                let result = await collector.result(arguments: arguments, termination: termination, cancelled: cancelled)

                // 与逐条执行接受全部退出码时相同：被取消或没有退出码都算失败
                if cancelled {
                    resolve(.failure(GitError(result: result, category: .cancelled, diagnostic: nil)))
                } else if result.exitCode == nil {
                    resolve(.failure(GitError(result: result, category: GitRunner.category(for: result), diagnostic: nil)))
                } else {
                    resolve(.success(result))
                }

            case .failure(let error):
                resolve(.failure(await CommandExecutor.failure(error, collector: collector, arguments: arguments)))
            }
        }

        /// 一路输出读到了分隔标记；两路都读到时体检以 0 结束。
        ///
        /// - Returns: 前导是否就此结束。
        func pass() async -> Bool {
            let finished = state.withLock { state in
                state.remaining -= 1
                return state.remaining == 0
            }

            guard finished else { return false }

            let result = await collector.result(arguments: arguments, termination: .exited(0), cancelled: false)
            return resolve(.success(result))
        }

        /// 读到了标准输出的一个分隔帧：第一个交给等着它的任务，之后的不改动。
        func reach(_ frame: RemoteHealthCheck.Splitter.Frame) {
            settleFrame(frame)
        }

        /// 记下体检的结果并叫醒等待的任务；还没读到第一个分隔帧的等待以 nil 结束。
        ///
        /// - Returns: 是否记下；已经有结果时不改动。
        @discardableResult
        private func resolve(_ outcome: Result<GitCommandResult, GitError>) -> Bool {
            let waiters = state.withLock { state -> [CheckedContinuation<Result<GitCommandResult, GitError>, Never>]? in
                guard state.outcome == nil else { return nil }

                state.outcome = outcome
                defer { state.waiters = [] }
                return state.waiters
            }

            guard let waiters else { return false }

            settleFrame(nil)

            for waiter in waiters {
                waiter.resume(returning: outcome)
            }

            return true
        }

        /// 定下第一个分隔帧并叫醒等着它的任务；已经定下时不改动。
        private func settleFrame(_ frame: RemoteHealthCheck.Splitter.Frame?) {
            let waiters = state.withLock { state -> [CheckedContinuation<RemoteHealthCheck.Splitter.Frame?, Never>] in
                guard !state.isFrameSettled else { return [] }

                state.isFrameSettled = true
                state.firstFrame = frame
                defer { state.frameWaiters = [] }
                return state.frameWaiters
            }

            for waiter in waiters {
                waiter.resume(returning: frame)
            }
        }
    }

    /// 一路输出在转入通道的标记之前的进度。
    struct PreambleStream {
        /// 这一路已经过了转入通道的标记。
        var isPassed = false

        /// 切开这一路的前导。
        var splitter = RemoteHealthCheck.Splitter()
    }
}

// MARK: - Waiting

extension RemoteCommandChannel {
    /// 等体检脚本写完前导，取体检的结果；等待期间任务被取消时关闭通道，通道进程随之结束。
    ///
    /// 结果的规则与 ``CommandExecutor`` 接受全部退出码时相同：输出超限、取消与进程出错都抛出 ``GitError``。
    /// 进程没写完前导就结束时，结果带着它的结束状态，通道随之关闭。
    func preambleResult() async throws -> GitCommandResult {
        guard let preamble else { throw NotExecuted() }

        let outcome = await withTaskCancellationHandler {
            await preamble.outcome()
        } onCancel: {
            close()
        }

        // 与逐条执行相同：被取消的体检即使恰好已经结束，也按取消处理
        guard !Task.isCancelled else {
            let result = await preamble.collector.result(
                arguments: preamble.arguments,
                termination: nil,
                cancelled: true
            )

            throw GitError(result: result, category: .cancelled, diagnostic: nil)
        }

        return try outcome.get()
    }

    /// 收下通道进程的一块输出：这一路还没读到转入通道的标记时，标记之前的部分记进体检的结果。
    ///
    /// - Parameters:
    ///   - data: 这一块输出。
    ///   - isError: 是否来自标准错误。
    ///   - stream: 这一路的进度。
    /// - Returns: 转入通道的标记之后、交给通道的部分；没有前导时原样返回。
    func passPreamble(_ data: Data, isError: Bool, stream: inout PreambleStream) async throws -> Data {
        guard !stream.isPassed, let preamble else { return data }

        let scan = stream.splitter.receive(data)
        try await record(scan.released, isError: isError, into: preamble)

        // 会话步骤是标准输出的第一帧，读到就交给连接，不等其余步骤
        if !isError, let frame = scan.frames.first {
            preamble.reach(frame)
        }

        // 宣告或分隔帧的格式不对时等不到转入通道的标记，体检就此结束，按输出不完整处理
        if stream.splitter.isMalformed {
            await preamble.finish(.success(.exited(0)), cancelled: false)
            return Data()
        }

        guard let passed = scan.channel else { return Data() }

        stream.isPassed = true

        // 前导结束后才开始等就绪帧
        if await preamble.pass() {
            armReadinessTimeout()
        }

        return passed
    }

    /// 一路输出读完时还没读到转入通道的标记：留着待看的末尾几个字节也记进体检的结果。
    ///
    /// - Parameters:
    ///   - stream: 这一路的进度。
    ///   - isError: 是否来自标准错误。
    func endPreamble(_ stream: inout PreambleStream, isError: Bool) async throws {
        guard !stream.isPassed, let preamble else { return }

        try await record(stream.splitter.finish(), isError: isError, into: preamble)
    }

    /// 把前导的一段输出记进体检的结果；超出上限时立即以超限结束前导，不等通道进程结束。
    private func record(_ data: Data, isError: Bool, into preamble: Preamble) async throws {
        do {
            try await preamble.collector.receive(data, isError: isError)
        } catch {
            await preamble.finish(.failure(error), cancelled: false)
            throw error
        }
    }
}
