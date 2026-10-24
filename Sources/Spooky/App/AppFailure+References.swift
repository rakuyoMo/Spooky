import Foundation
import SpookyKit

// MARK: - References

extension AppFailure {
    /// 引用管理失败的文案键、类别、恢复说明、Git 原文与诊断：名字、地址与快进条件属于仓库状态问题，诊断写出涉及的名字。
    static func classification(
        of reference: ReferenceError
    ) -> (key: String, kind: FailureKind, recoveryKey: String, output: GitCommandResult?, diagnostic: String?) {
        switch reference {
        case .invalidName(let name):
            ("reference.error.name", .repository, "reference.error.name.help", nil, name)

        case .invalidRefspec(let refspec):
            ("reference.error.refspec", .repository, "reference.error.refspec.help", nil, refspec)

        case .invalidURL(let url):
            ("reference.error.url", .repository, "reference.error.url.help", nil, url)

        case .diverged(let branch, let upstream):
            ("branch.error.diverged", .repository, "branch.error.diverged.help", nil, branch + " → " + upstream)

        case .currentBranch(let branch):
            ("branch.error.current", .repository, "branch.error.current.help", nil, branch)

        case .remoteBranchExists(let branch, let remote):
            ("branch.error.remoteExists", .repository, "branch.error.remoteExists.help", nil, remote + "/" + branch)

        case .noWebAddress(let url):
            ("remote.error.browser", .repository, "remote.error.browser.help", nil, url)

        case .unmergedBranches(_, let error):
            ("branch.error.unmerged", .git, "branch.error.unmerged.help", error.result, error.diagnostic)
        }
    }
}
