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
            ("hostError.lfsUnavailable", .environment, remote ? "lfs.unavailable.remote" : "lfs.unavailable.local", result, nil)

        case .patternsRemain(let patterns):
            ("lfs.patternsRemain", .repository, "lfs.patternsRemain.help", nil, patterns.joined(separator: "\n"))
        }
    }
}
