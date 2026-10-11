import Foundation
import Subprocess
import System

/// 在仓库所在的位置执行 git：本机直接调用 git，远端经系统 ssh 在对方机器上调用
public struct GitRunner: Sendable {
    /// 目标仓库
    public let location: RepositoryLocation

    /// 创建在指定仓库上执行 git 的实例
    ///
    /// - Parameter location: 目标仓库
    public init(location: RepositoryLocation) {
        self.location = location
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
        let command = commandLine(for: arguments)

        // 没有输入时也接一个立即关闭的标准输入：git 读到 EOF 就继续，不会停下来等终端
        let result = try await Subprocess.run(
            .path(FilePath(command.executable)),
            arguments: Arguments(command.arguments),
            input: .data(input ?? Data()),
            output: .data(limit: Self.outputLimit),
            error: .string(limit: Self.errorLimit)
        )

        guard result.terminationStatus.isSuccess else {
            // 被信号杀掉的进程没有退出码
            var exitCode: Int32?

            if case .exited(let code) = result.terminationStatus {
                exitCode = code
            }

            throw GitError(
                arguments: arguments,
                exitCode: exitCode,
                message: result.standardError
            )
        }

        return result.standardOutput
    }

    /// 拼出实际要执行的程序与参数
    func commandLine(for arguments: [String]) -> (executable: String, arguments: [String]) {
        switch location {
        case .local(let path):
            return (
                "/usr/bin/git",
                ["-C", path] + Self.globalOptions + arguments
            )

        case .remote(let host, let path):

            // ssh 会把命令拼成一行交给远端的 shell 解释，所以每个参数都要先按 shell 规则转义
            let remoteCommand = (["git", "-C", path] + Self.globalOptions + arguments)
                .map(Self.shellQuoted)
                .joined(separator: " ")

            // BatchMode：不弹任何交互提示，认证不过就立刻退出，而不是卡住等输入；
            // `--` 之后才是主机别名，别名再怪也不会被当成 ssh 的选项
            return (
                "/usr/bin/ssh",
                ["-o", "BatchMode=yes", "--", host, remoteCommand]
            )
        }
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
    private static let globalOptions = [
        "--no-pager",
        "--no-optional-locks",
        "-c", "color.ui=never",
        "-c", "core.quotepath=off",
    ]

    /// 单次调用收集标准输出的上限，防止异常输出撑爆内存；正常的状态、日志远小于它
    private static let outputLimit = 256 * 1024 * 1024

    /// 标准错误只用来展示失败原因
    private static let errorLimit = 1024 * 1024
}

/// git 或 ssh 以非零状态退出
public struct GitError: Error, Sendable {
    /// 出错的子命令及其参数
    public let arguments: [String]

    /// 进程的退出码；进程被信号终止时为 nil
    public let exitCode: Int32?

    /// git 或 ssh 输出到标准错误的内容
    public let message: String
}
