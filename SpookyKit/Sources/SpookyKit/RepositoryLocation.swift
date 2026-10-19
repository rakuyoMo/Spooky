import Foundation

/// 仓库所在的位置：本机，或某台 SSH 主机上
///
/// 远端仓库以 “主机别名 + 远端路径” 标识。别名取自 `~/.ssh/config`，
/// 择路、连接复用、密钥与主机指纹都交给系统 ssh 处理。
public enum RepositoryLocation: Hashable, Sendable, Codable {
    /// 本机仓库，`path` 为工作区的绝对路径
    case local(path: String)

    /// 远端仓库，`host` 为 `~/.ssh/config` 里的主机别名，`path` 为远端工作区的路径
    case remote(host: String, path: String)

    /// 工作区绝对路径；远端路径不经过本机文件系统归一化。
    public var path: String {
        switch self {
        case .local(let path), .remote(_, let path): return path
        }
    }

    /// 服务器别名，本机仓库没有主机前缀。
    public var host: String? {
        guard case .remote(let host, _) = self else { return nil }
        return host
    }

    /// 仓库名在服务器模式下始终带主机前缀。
    public var name: String {
        (host.map { $0 + ":" } ?? "") + URL(fileURLWithPath: path).lastPathComponent
    }

    /// 复制路径与标题使用同一种不会混淆机器的表示。
    public var displayPath: String { (host.map { $0 + ":" } ?? "") + path }

    /// Finder 仅接受真实存在于本机命名空间中的路径。
    public var localURL: URL? {
        guard case .local(let path) = self else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 终端中的本机 cd 或交互式 SSH 命令，每层 shell 的数据各自转义。
    public var terminalCommand: String {
        switch self {
        case .local(let path):
            return "cd -- " + GitRunner.shellQuoted(path)

        case .remote(let host, let path):
            let script = "cd -- " + GitRunner.shellQuoted(path) + " && exec \"$SHELL\" -l"
            return [
                "/usr/bin/ssh", "-t", "-a", "-o", "ForwardAgent=no",
                "-o", "StrictHostKeyChecking=yes", "--", host, script,
            ].map(GitRunner.shellQuoted).joined(separator: " ")
        }
    }
}
