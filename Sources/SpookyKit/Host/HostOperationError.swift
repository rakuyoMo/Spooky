import Foundation

// MARK: - HostOperationError

/// 仓库还不存在时，目标机器上的路径或环境不能使用的原因；原始输出保留在关联的结果里。
public enum HostOperationError: Error, Sendable, Equatable {
    /// 目标路径必须是绝对路径。
    case absolutePathRequired

    /// 目录不存在。
    case missingDirectory(GitCommandResult?)

    /// 路径已存在，但不是目录。
    case notDirectory(GitCommandResult?)

    /// 登录用户没有读取或搜索这个目录的权限。
    case permissionDenied(GitCommandResult?)

    /// 系统的隐私保护拒绝读取目录（Operation not permitted），与文件权限无关。
    case diskAccessDenied(GitCommandResult?)

    /// 克隆选了 LFS，但目标机器上的 Git LFS 没有安装或没有启用。
    case lfsUnavailable(GitCommandResult)

    /// 目录检查脚本约定的退出码：2 目录不存在、3 不能读取、4 不是目录；其它错误原样返回。
    static func classify(_ error: Error) -> Error {
        guard let failure = error as? GitError, !failure.isCancelled, let code = failure.exitCode else {
            return error
        }

        switch code {
        case 2:
            return Self.missingDirectory(failure.result)

        case 3:
            return failure.message.contains("Operation not permitted")
                ? Self.diskAccessDenied(failure.result)
                : Self.permissionDenied(failure.result)

        case 4:
            return Self.notDirectory(failure.result)

        default:
            return error
        }
    }

    /// 检查并规范目标路径：必须是绝对路径、不含 NUL，去掉末尾多余的 “/”。
    static func normalized(_ path: String) throws -> String {
        guard path.hasPrefix("/"), !path.utf8.contains(0) else {
            throw Self.absolutePathRequired
        }

        var path = path

        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }

        return path
    }
}
