import Foundation

// MARK: - GitCommandResult

/// 一次 Git 调用的输出与结束状态，不包含进程环境或标准输入。
public struct GitCommandResult: Sendable, Equatable {
    /// 调用方传入的子命令及参数。
    public let arguments: [String]

    /// 标准输出的原始字节。
    public let standardOutput: Data

    /// 标准错误的原始字节。
    public let standardError: Data

    /// 已取得的进程结束状态；启动或管道失败时可能无法取得。
    public let terminationStatus: GitTerminationStatus?

    /// 调用是否因 Swift 任务取消而结束。
    public let isCancelled: Bool

    /// 正常退出时的退出码；信号终止或状态不可得时为 nil。
    public var exitCode: Int32? {
        guard case .exited(let code) = terminationStatus else {
            return nil
        }

        return code
    }
}

// MARK: - GitTerminationStatus

/// 与进程库解耦的 Git 结束状态。
public enum GitTerminationStatus: Sendable, Equatable {
    /// 进程自行退出，并提供退出码。
    case exited(Int32)

    /// 进程被指定信号终止。
    case signaled(Int32)
}

// MARK: - GitOutputEvent

/// 流式输出的数据块；块边界不代表文本行或 UTF-8 字符边界。
public enum GitOutputEvent: Sendable {
    /// 来自标准输出的数据。
    case standardOutput(Data)

    /// 来自标准错误的数据。
    case standardError(Data)
}

// MARK: - GitError

/// Git 调用失败；保留原始输出，并将启动、取消与命令失败分开。
public struct GitError: Error, Sendable {
    /// 可供界面选择本地化说明的错误类别。
    public enum Category: Sendable {
        /// 可执行文件无法启动。
        case launchFailed

        /// 目录不是 Git 仓库。
        case notRepository

        /// 仓库没有可供操作的工作区。
        case notWorkingTree

        /// Git 无法进入所选目录。
        case pathUnavailable

        /// Git 拒绝访问所有权不可信的仓库。
        case unsafeRepository

        /// 另一个 Git 进程持有暂存区锁，不能自动删除锁文件。
        case indexLocked

        /// 推送被远端拒绝，包括非快进与服务端钩子拒绝。
        case pushRejected

        /// Git 远端认证失败。
        case authenticationFailed

        /// Git 远端仓库或已配置的远端不存在。
        case remoteNotFound

        /// 网络连接超时。
        case connectionTimedOut

        /// Git 访问远端时连接中断或不可达。
        case connectionUnavailable

        /// 当前分支未设置上游。
        case noUpstream

        /// 普通删除因分支尚未合并而被拒绝。
        case branchNotMerged

        /// 检出或合并会覆盖未提交改动。
        case localChanges

        /// 命令因 Swift 任务取消而结束。
        case cancelled

        /// 输出超过收集上限。
        case outputLimitExceeded

        /// 进程管道读写或退出状态监测失败。
        case processIOFailed

        /// Git 或 SSH 返回了调用方未接受的状态。
        case commandFailed
    }

    /// 本次调用已取得的结果，包括失败前收到的输出。
    public let result: GitCommandResult

    /// 错误类别。
    public let category: Category

    /// 进程基础设施的错误原文；Git 错误仍从结果中的 stderr 读取。
    public let diagnostic: String?

    /// 出错的子命令及其参数，保持原有 API 语义。
    public var arguments: [String] { result.arguments }

    /// 正常退出时的退出码，保持原有 API 语义。
    public var exitCode: Int32? { result.exitCode }

    /// Git 或 SSH 的标准错误原文。
    public var message: String { String(decoding: result.standardError, as: UTF8.self) }

    /// 是否被取消，便于调用方忽略已经失效的读取请求。
    public var isCancelled: Bool { result.isCancelled }
}
