import Foundation

// MARK: - HostExecution

/// 在目标位置所在的机器上执行 Git 以外的程序：本机直接启动进程，服务器经主机连接的包装器。
///
/// 两边执行的是同一份脚本，目录检查与扫描的规则在本机与服务器上一致。
enum HostExecution {
    /// 执行一个只读程序，取消所在的任务即终止它的进程组。
    ///
    /// - Parameters:
    ///   - program: 第一个元素是可执行文件的绝对路径，其余是参数。
    ///   - location: 程序作用的机器与路径，按它占用主机槽。
    ///   - acceptedExitCodes: 视为成功的退出码。
    ///   - onOutput: 流式输出，块边界不代表行或字符边界。
    static func run(
        _ program: [String],
        at location: RepositoryLocation,
        acceptedExitCodes: Set<Int32> = [0],
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> GitCommandResult {
        guard case .remote(let host, let path) = location else {
            return try await RepositoryOperationQueue.shared.perform(at: location, writing: false) {
                try await CommandExecutor.execute(
                    executable: program[0],
                    processArguments: Array(program.dropFirst()),
                    arguments: program,
                    environment: .inherit.updating(["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]),
                    acceptedExitCodes: acceptedExitCodes,
                    onOutput: onOutput
                )
            }
        }

        return try await RemoteConnection.host(host)
            .hostOperation(
                .program(program),
                at: path,
                writing: false,
                acceptedExitCodes: acceptedExitCodes,
                onOutput: onOutput
            )
            .value
    }
}
