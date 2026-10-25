import Foundation

// MARK: - ExternalToolLaunchError

/// 外部工具没有安装、命令行入口不存在或启动失败，保留可复制的原因。
struct ExternalToolLaunchError: Error {
    /// 工具的输出，或启动失败的系统说明。
    let diagnostic: String
}

// MARK: - ExternalToolLauncher

/// 在本机启动外部比较与合并工具，在后台等它退出；不在仓库所在的服务器上启动任何程序。
enum ExternalToolLauncher {
    /// 启动工具并等它退出。
    ///
    /// 工具的退出码不作为成败依据：比较工具常以非零退出码表示 “有差异”；合并是否产生结果由结果文件判断。
    /// 只有命令行入口不存在或无法启动时抛出 ``ExternalToolLaunchError``。
    ///
    /// - Parameter invocation: 可执行文件与参数。
    static func run(_ invocation: ExternalToolInvocation) async throws {
        guard FileManager.default.isExecutableFile(atPath: invocation.executable.path) else {
            throw ExternalToolLaunchError(diagnostic: invocation.executable.path)
        }

        try await Task.detached {
            let process = Process()
            process.executableURL = invocation.executable
            process.arguments = invocation.arguments
            process.standardInput = FileHandle.nullDevice

            // 输出只用来排空管道，避免工具写满缓冲区后阻塞
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output

            do {
                try process.run()
            } catch {
                throw ExternalToolLaunchError(diagnostic: error.localizedDescription)
            }

            _ = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
        }.value
    }
}
