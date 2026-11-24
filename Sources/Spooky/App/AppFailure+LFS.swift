import Foundation
import SpookyKit

// MARK: - LFS

extension AppFailure {
    /// Git LFS 失败的文案键、类别、恢复说明与原文；找不到 Git LFS 时按仓库在本机还是服务器给出 PATH 的修复方向。
    static func classification(
        of lfs: LFSError,
        remote: Bool
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        switch lfs {
        case .unavailable(let result):
            ("hostError.lfsUnavailable", .environment, lfsUnavailableRecoveryKey(remote: remote), result, nil)

        case .patternsRemain(let patterns):
            ("lfs.patternsRemain", .repository, "lfs.patternsRemain.help", nil, patterns.joined(separator: "\n"))
        }
    }

    /// 找不到 Git LFS 时恢复说明的文案键：本机仓库指向 设置 → 环境，服务器仓库指向服务器上非交互 SSH 会话的 PATH。
    ///
    /// - Parameter remote: 出错的仓库是否在服务器上。
    static func lfsUnavailableRecoveryKey(remote: Bool) -> String {
        remote ? "lfs.unavailable.remote" : "lfs.unavailable.local"
    }
}
