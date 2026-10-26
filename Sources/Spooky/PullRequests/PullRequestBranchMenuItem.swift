import SpookyKit
import SwiftUI

// MARK: - PullRequestBranchMenuItem

/// 分支右键菜单里的请求项：分支已有打开着的请求时显示它，否则从它新建。
///
/// 是否已有请求只看请求视图读到的列表；还没读过时总是新建，打开请求视图时再读取。
struct PullRequestBranchMenuItem: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 右键的本地或远端分支。
    let reference: RepositoryReference

    /// 显示或新建的一项。
    var body: some View {
        let branch = branchName

        if let existing = session.pullRequest(forBranch: branch) {
            Button(session.pullRequestText("forBranch.show", branch)) {
                guard let runner = session.runner else { return }

                session.showPullRequests()
                session.pullRequests.select(existing.id, runner: runner)
            }
        } else {
            Button(session.pullRequestText("forBranch.create", branch)) {
                session.showPullRequests()
                session.requestPullRequest(.create(sourceBranch: branch))
            }
            .disabled(session.repository == nil)
        }
    }

    /// 分支在远端上的名字：本地分支用自己的名字，远端分支去掉远端名。
    private var branchName: String {
        guard reference.isRemote, let remote = session.history.snapshot?.remote(for: reference) else {
            return reference.name
        }

        return String(reference.id.dropFirst(("refs/remotes/" + remote.name + "/").count))
    }
}
