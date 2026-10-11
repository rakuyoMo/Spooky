/// 仓库所在的位置：本机，或某台 SSH 主机上
///
/// 远端仓库以 “主机别名 + 远端路径” 标识。别名取自 `~/.ssh/config`，
/// 择路、连接复用、密钥与主机指纹都交给系统 ssh 处理。
public enum RepositoryLocation: Hashable, Sendable {
    /// 本机仓库，`path` 为工作区的绝对路径
    case local(path: String)

    /// 远端仓库，`host` 为 `~/.ssh/config` 里的主机别名，`path` 为远端工作区的路径
    case remote(host: String, path: String)
}
