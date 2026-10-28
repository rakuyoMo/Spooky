import Foundation
import SpookyKit

// MARK: - GerritPush

/// 推送到 Gerrit 评审：Integration 设置里打开后，分支右键菜单与工具栏才提供这个入口。
enum GerritPush {
    /// 偏好键：是否提供推送到 Gerrit 的入口。
    static let key = "enableGerritPush"

    /// 当前是否提供推送到 Gerrit 的入口；没有记录时不提供。
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    /// Gerrit 为评审分支收取变更的引用。
    ///
    /// - Parameter branch: 评审分支名。
    static func reviewReference(_ branch: String) -> String {
        "refs/for/" + branch
    }
}

// MARK: - Gerrit

extension RepositorySession {
    /// 打开了 Gerrit 推送，且仓库能推送任意版本。
    var canPushToGerrit: Bool {
        GerritPush.isEnabled && canPushRevision
    }

    /// 快速推送到 Gerrit 需要一个跟踪远端分支的本地分支。
    ///
    /// - Parameter branch: 右键的本地分支。
    func canQuickPushToGerrit(_ branch: RepositoryReference) -> Bool {
        canPushToGerrit && gerritRemote(of: branch) != nil
    }

    /// 不经对话框，把本地分支推到它跟踪的远端的 `refs/for/<分支>`。
    ///
    /// - Parameter branch: 右键的本地分支。
    func quickPushToGerrit(_ branch: RepositoryReference) {
        guard canQuickPushToGerrit(branch), let remote = gerritRemote(of: branch) else {
            return
        }

        let name = branch.name
        let target = GerritPush.reviewReference(name)

        _ = performGit(
            { runner, output in
                _ = try await RepositorySync(runner: runner)
                    .push(revision: name, remote: remote, to: target, skipHooks: false, onOutput: output)
            },
            title: AppLocalization.text("gerrit.push"),
            activityKind: .remote
        )
    }

    /// 本地分支跟踪的远端名；没有跟踪关系或跟踪的是本仓库里的分支时为 nil。
    ///
    /// - Parameter branch: 本地分支。
    func gerritRemote(of branch: RepositoryReference) -> String? {
        guard branch.isLocal, let remote = branch.upstreamRemote, remote != "." else {
            return nil
        }

        return remote
    }
}
