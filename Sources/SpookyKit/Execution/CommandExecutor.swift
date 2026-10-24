import Foundation
import Subprocess
import System

// MARK: - CommandExecutor

/// Git 与 SSH 共用的异步进程边界，保留原始输出并响应任务取消。
enum CommandExecutor {
    /// 取消时 TERM 与 KILL 之间的宽限期，与服务器包装器的默认宽限期一致。
    static let cancellationGrace = Duration.seconds(2)

    /// 为 true 时标准输出只交给输出回调，不收集进结果，也不受单次输出上限约束；导出与保存补丁据此边读边写盘。
    @TaskLocal
    static var streamsStandardOutput = false

    /// 同时排空两条管道；公开结果只包含业务参数，不记录环境和输入。
    static func execute(
        executable: String,
        processArguments: [String],
        arguments: [String] = [],
        environment: Environment = .inherit,
        input: Data? = nil,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        let command = (executable: executable, arguments: processArguments)
        let collector = GitOutputCollector(onOutput: onOutput)
        let termination: GitTerminationStatus

        do {
            try Task.checkCancellation()

            // 两条管道必须同时消费，否则较大的 stderr 会堵住仍在等待 stdout 的调用。
            // 即使没有输入也显式送入 EOF，Git 不会等待交互式终端输入。
            var platform = PlatformOptions()
            platform.createSession = true

            // 取消只结束本次创建的进程组：先发 TERM，让 Git 移除自己的锁文件；
            // 宽限期后仍未退出再 KILL，SSH、askpass 和钩子不能遗留为后台写入。
            platform.teardownSequence = [
                .gracefulShutDown(toProcessGroup: true, allowedDurationToNextStep: cancellationGrace),
            ]
            let result = try await Subprocess.run(
                .path(FilePath(command.executable)),
                arguments: Arguments(command.arguments),
                environment: environment,
                platformOptions: platform,
                input: .data(input ?? Data()),
                output: .sequence,
                error: .sequence
            ) { execution in
                async let output: Void = collector.consume(execution.standardOutput, isError: false)
                async let error: Void = collector.consume(execution.standardError, isError: true)
                _ = try await (output, error)
            }

            switch result.terminationStatus {
            case .exited(let code):
                termination = .exited(code)

            case .signaled(let signal):
                termination = .signaled(signal)
            }
        } catch {
            let cancelled = Task.isCancelled || error is CancellationError
            let result = await collector.result(
                arguments: arguments,
                termination: nil,
                cancelled: cancelled
            )
            let category: GitError.Category =
                if cancelled {
                    .cancelled
                } else if error is GitOutputLimitError {
                    .outputLimitExceeded
                } else if
                    let processError = error as? SubprocessError,
                    [.spawnFailed, .executableNotFound, .failedToChangeWorkingDirectory]
                        .contains(processError.code)
                {
                    .launchFailed
                } else {
                    .processIOFailed
                }

            throw GitError(
                result: result,
                category: category,
                diagnostic: cancelled || error is GitOutputLimitError ? nil : String(describing: error)
            )
        }

        let result = await collector.result(
            arguments: arguments,
            termination: termination,
            cancelled: Task.isCancelled
        )

        // 被取消的请求即使恰好以 0 退出，也不能用来覆盖界面上的较新结果。
        guard !result.isCancelled else {
            throw GitError(result: result, category: .cancelled, diagnostic: nil)
        }

        guard let code = result.exitCode, acceptedExitCodes.contains(code) else {
            throw GitError(result: result, category: GitRunner.category(for: result), diagnostic: nil)
        }

        return result
    }
}

// MARK: - GitOutputLimitError

/// 输出超限时结束读取，由进程库负责回收子进程。
private struct GitOutputLimitError: Error { }

// MARK: - GitOutputCollector

/// 同时收集两条输出管道，失败时仍能取回此前收到的数据。
private actor GitOutputCollector {
    /// 已收集的标准输出。
    private var standardOutput = Data()

    /// 已收集的标准错误。
    private var standardError = Data()

    /// 可选的流式输出订阅者。
    private let onOutput: (@Sendable (GitOutputEvent) -> Void)?

    /// 标准输出只转交订阅者，不收集。
    private let streamsStandardOutput = CommandExecutor.streamsStandardOutput

    /// 创建一次命令专用的输出收集器。
    init(onOutput: (@Sendable (GitOutputEvent) -> Void)?) {
        self.onOutput = onOutput
    }

    /// 连续消费一条管道，输出超限时保留上限内的原始字节。
    func consume(_ sequence: SubprocessOutputSequence, isError: Bool) async throws {
        for try await buffer in sequence {
            let data = Data(buffer: buffer)

            // 写盘的输出可能远超内存上限，原样转交后不再保留
            if !isError, streamsStandardOutput {
                onOutput?(.standardOutput(data))
                continue
            }
            let limit = isError ? 1024 * 1024 : 256 * 1024 * 1024
            let count = isError ? standardError.count : standardOutput.count
            let retained = data.prefix(max(0, limit - count))

            if isError {
                standardError.append(retained)
                onOutput?(.standardError(Data(retained)))
            } else {
                standardOutput.append(retained)
                onOutput?(.standardOutput(Data(retained)))
            }

            guard data.count <= limit - count else {
                throw GitOutputLimitError()
            }
        }
    }

    /// 为成功、失败或取消建立同一种结果快照。
    func result(
        arguments: [String],
        termination: GitTerminationStatus?,
        cancelled: Bool
    ) -> GitCommandResult {
        GitCommandResult(
            arguments: arguments,
            standardOutput: standardOutput,
            standardError: standardError,
            terminationStatus: termination,
            isCancelled: cancelled
        )
    }
}
