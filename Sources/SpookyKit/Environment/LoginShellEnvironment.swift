import Foundation
import os

// MARK: - LoginShellEnvironmentError

/// 读取登录 shell 环境失败的原因；不携带 shell 的输出，输出里是全部环境变量。
public enum LoginShellEnvironmentError: Error, Sendable, Equatable {
    /// 找不到用户的登录 shell。
    case shellUnavailable

    /// shell 没有在时限内结束，已被结束。
    case timedOut

    /// shell 以非零状态退出，或无法启动。
    case failed

    /// 输出里没有完整的变量列表，如启动文件中途退出了 shell。
    case unreadableOutput
}

// MARK: - LoginShellEnvironment

/// 以登录、交互模式启动用户的 shell，读出它的启动文件设置好的环境变量。
///
/// 从访达启动的 App 只继承 launchd 的精简环境，`PATH` 里没有 Homebrew 等目录；
/// 开启后，这些变量交给本机执行的 Git，钩子与凭据助手才能找到用户在终端里用的程序。
public enum LoginShellEnvironment {
    /// 只描述读取时那个 shell 自身状态的变量，不属于用户的环境，不交给 Git。
    static let shellStateNames: Set<String> = ["PWD", "OLDPWD", "SHLVL", "_"]

    /// 读取失败与超时的日志；不记 shell 的输出与变量。
    private static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "LoginShellEnvironment")

    /// 当前用户的登录 shell：先取进程的 `SHELL`，没有时取账户记录里的 shell。
    public static var userShell: String? {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], shell.hasPrefix("/") {
            return shell
        }

        guard let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell else { return nil }

        let path = String(cString: shell)
        return path.hasPrefix("/") ? path : nil
    }

    /// 启动登录 shell 并读出环境变量。
    ///
    /// shell 以 `-l -i -c` 运行一段固定命令：先输出一个随机标记，再由 `/usr/bin/env -0` 以 NUL 分隔列出变量；
    /// 启动文件打印的问候语等内容都在标记之前，解析时跳过。
    ///
    /// - Parameters:
    ///   - shell: shell 程序的绝对路径；nil 时使用 ``userShell``。
    ///   - timeout: 等待 shell 结束的时限；启动文件卡住时到时结束它，不让设置页一直等待。
    /// - Returns: 变量名到值，已去掉 ``shellStateNames``。
    public static func read(
        shell: String? = nil,
        timeout: Duration = .seconds(10)
    ) async throws -> [String: String] {
        guard let shell = shell ?? userShell else {
            logger.error("读取登录 shell 环境失败：找不到登录 shell")
            throw LoginShellEnvironmentError.shellUnavailable
        }

        let marker = "spooky-environment-" + UUID().uuidString.lowercased()
        let script = "printf '%s\\0' '\(marker)'; exec /usr/bin/env -0"
        let output = try await run(shell: shell, script: script, timeout: timeout)

        guard let variables = parse(output, marker: marker) else {
            logger.error("读取登录 shell 环境失败：输出里没有完整的变量列表")
            throw LoginShellEnvironmentError.unreadableOutput
        }

        return variables
    }

    /// 解析标记之后以 NUL 分隔的 `名称=值`；值里可以有换行与 `=`，名称不合法的条目跳过。
    ///
    /// - Parameters:
    ///   - output: shell 的标准输出。
    ///   - marker: 本次读取输出的标记。
    /// - Returns: 变量名到值；输出里没有标记时为 nil。
    static func parse(_ output: Data, marker: String) -> [String: String]? {
        let bytes = [UInt8](output)
        let prefix = [UInt8](marker.utf8) + [0]

        // 标记必须出现在行首，避免启动文件恰好打印出包含它的文字时错位。
        guard
            let start = bytes.indices.first(where: { index in
                (index == 0 || bytes[index - 1] == 0x0A || bytes[index - 1] == 0)
                    && bytes[index...].starts(with: prefix)
            })
        else {
            return nil
        }

        var variables: [String: String] = [:]

        for entry in bytes[(start + prefix.count)...].split(separator: 0) {
            let text = String(decoding: entry, as: UTF8.self)

            guard let separator = text.firstIndex(of: "=") else { continue }

            let name = String(text[..<separator])

            guard LocalExecutionSettings.isValidName(name), !shellStateNames.contains(name) else { continue }

            variables[name] = String(text[text.index(after: separator)...])
        }

        return variables
    }

    // MARK: 运行 shell

    /// 在时限内运行 shell，返回标准输出；超时或失败时结束整个进程组。
    private static func run(shell: String, script: String, timeout: Duration) async throws -> Data {
        do {
            return try await withThrowingTaskGroup(of: Data?.self) { group in
                group.addTask {
                    try await CommandExecutor.execute(
                        executable: shell,
                        processArguments: ["-l", "-i", "-c", script],
                        arguments: ["login-shell"]
                    )
                    .standardOutput
                }

                group.addTask {
                    try await Task.sleep(for: timeout)
                    return nil
                }

                // 先结束的一方决定结果：时限先到就取消仍在运行的 shell。
                let first = try await group.next() ?? nil
                group.cancelAll()

                guard let first else { throw LoginShellEnvironmentError.timedOut }

                return first
            }
        } catch let error as LoginShellEnvironmentError {
            logger.error("读取登录 shell 环境超时，已结束 shell")
            throw error
        } catch let error as GitError where error.isCancelled {
            throw CancellationError()
        } catch let error as GitError {
            // GitError 的结果里有 shell 的输出，只记退出码，不向外传递。
            let exitCode = error.exitCode.map(String.init) ?? "-"
            logger.error("读取登录 shell 环境失败：退出码 \(exitCode, privacy: .public)")
            throw LoginShellEnvironmentError.failed
        }
    }
}
