import Foundation

// MARK: - RemoteConnectionError

/// 连接体检的阶段与原始输出；界面据此给出具体的修复方向。
public struct RemoteConnectionError: Error, Sendable {
    /// 可恢复的连接错误与远端环境问题。
    public enum Kind: String, Sendable, CaseIterable {
        /// 输入必须是单个 SSH 配置别名。
        case invalidHost

        /// 远端工作区必须由绝对路径标识。
        case absolutePathRequired

        /// 尚未在受信任终端确认主机指纹。
        case unknownHostKey

        /// 已记录的指纹发生变化。
        case changedHostKey

        /// A 的密钥或代理未能通过认证。
        case authentication

        /// SSH 主连接不可达或已断开。
        case unavailable

        /// B 的非交互环境找不到 Git。
        case gitUnavailable

        /// Git 版本不符合最低要求。
        case gitVersion

        /// 路径不存在或不是目录。
        case pathUnavailable

        /// 当前登录用户不能读取或搜索目录。
        case pathPermission

        /// Git 未识别到工作区。
        case notWorkingTree

        /// 状态命令或其输出格式不可用。
        case statusFormat

        /// 远端包装器或回调通道部署失败。
        case deployment

        /// 包装器未提供完整的操作结果。
        case protocolFailure

        /// 已取消本机通道，但无法确认远端进程组退出。
        case cancellationUnconfirmed

        /// 写操作断线后需要核对仓库，不能重试原命令。
        case interruptedWrite
    }

    /// 错误分类不依赖界面语言。
    public let kind: Kind

    /// 失败步骤的完整输出与退出码。
    public let result: GitCommandResult?

    /// 不包含环境或中继令牌的基础设施诊断。
    public let diagnostic: String?

    /// 保存错误来源，凭据和输入不进入错误对象。
    init(_ kind: Kind, result: GitCommandResult? = nil, diagnostic: String? = nil) {
        self.kind = kind
        self.result = result
        self.diagnostic = diagnostic
    }

    /// 仅在没有包装器完成标记时按 SSH 的稳定诊断分类。
    static func ssh(_ result: GitCommandResult) -> Self {
        let message = String(decoding: result.standardError, as: UTF8.self).lowercased()

        if message.contains("remote host identification has changed") {
            return Self(.changedHostKey, result: result)
        }

        if
            message.contains("host key verification failed")
            || message.contains("no matching host key")
        {
            return Self(.unknownHostKey, result: result)
        }

        if
            message.contains("permission denied (")
            || message.contains("too many authentication failures")
            || message.contains("no supported authentication methods")
        {
            return Self(.authentication, result: result)
        }

        return Self(.unavailable, result: result)
    }
}

// MARK: - RemoteRepository

/// 已通过体检的服务器工作区，身份由别名和 Git 返回的根路径组成。
public struct RemoteRepository: Sendable, Hashable {
    /// 用户 SSH 配置中的别名。
    public let host: String

    /// Git 返回的工作区绝对路径。
    public let path: String

    /// 读取与写入使用的统一位置。
    public var location: RepositoryLocation { .remote(host: host, path: path) }

    /// 所有仓库身份展示都带主机前缀。
    public var name: String { host + ":" + URL(fileURLWithPath: path).lastPathComponent }
}
