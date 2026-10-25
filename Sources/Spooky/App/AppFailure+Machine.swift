import Foundation
import SpookyKit

// MARK: - Machine

extension AppFailure {
    /// 本机启动终端与外部工具、目标机器上新建、克隆、扫描与目录浏览的失败：文案键、类别、恢复说明与原文。
    ///
    /// 不属于这几类的错误返回 nil。
    static func machineClassification(
        of error: any Error
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?)? {
        switch error {
        case let terminal as TerminalLaunchError:
            ("error.terminal", .environment, "error.terminalHelp", nil, terminal.diagnostic)

        case let tool as ExternalToolLaunchError:
            ("externalTool.error", .environment, "externalTool.error.help", nil, tool.diagnostic)

        case let host as HostOperationError:
            classification(of: host)

        default:
            nil
        }
    }

    /// 目标机器上的路径与环境问题。
    private static func classification(
        of host: HostOperationError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        switch host {
        case .absolutePathRequired:
            ("hostError.absolutePath", .repository, "hostError.absolutePath.help", nil, nil)

        case .missingDirectory(let result):
            ("hostError.missingDirectory", .repository, "hostError.missingDirectory.help", result, nil)

        case .notDirectory(let result):
            ("hostError.notDirectory", .repository, "hostError.notDirectory.help", result, nil)

        case .permissionDenied(let result):
            ("hostError.permission", .repository, "hostError.permission.help", result, nil)

        case .diskAccessDenied(let result):
            ("remoteError.diskAccess", .repository, "remoteError.diskAccess.help", result, nil)

        case .lfsUnavailable(let result):
            ("hostError.lfsUnavailable", .environment, "hostError.lfsUnavailable.help", result, nil)
        }
    }
}
