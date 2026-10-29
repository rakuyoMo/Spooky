import Foundation
import SpookyKit

// MARK: - RepositoryPublication

/// 发布仓库的设置：新建仓库用的账号与所有者、名称、描述、可见性，以及要添加的远端。
struct RepositoryPublication {
    /// 新建仓库用的账号。
    let account: HostingAccount

    /// 仓库的所有者。
    let owner: HostingOwner

    /// 仓库名。
    let name: String

    /// 描述。
    let description: String

    /// 可见性。
    let visibility: HostingVisibility

    /// 添加的远端名。
    let remote: String

    /// 远端用 SSH 地址；否则用 HTTPS 地址。
    let usesSSH: Bool
}

// MARK: - Publish Repository

extension RepositorySession {
    /// 用账号在托管服务上新建空仓库，再在仓库所在的机器上添加为远端，推送全部本地分支与标签。
    ///
    /// - Returns: 是否已开始执行。
    func publishRepository(_ publication: RepositoryPublication) -> Bool {
        let title = AppLocalization.text("publish.title")
        let client = pullRequests.accounts.client(for: publication.account)

        return performHosting(title: title, client: client) { [weak self] client in
            let repository = try await client.createRepository(
                named: publication.name,
                description: publication.description,
                visibility: publication.visibility,
                owner: publication.owner
            )
            let url = publication.usesSSH ? repository.sshURL : repository.httpsURL

            await MainActor.run {
                self?.addPublishedRemote(publication.remote, url: url)
            }

            return repository.webURL?.absoluteString ?? repository.project
        }
    }

    /// 添加刚新建的仓库为远端，再推送全部本地分支与标签，没有上游的分支跟踪新远端上的同名分支。
    ///
    /// 推送失败时，已加上的远端与托管服务上新建的仓库都保留。
    private func addPublishedRemote(_ remote: String, url: String) {
        performGit(
            { runner, output in
                try await RepositoryRemotes(runner: runner).add(name: remote, url: url, onOutput: output)

                _ = try await RepositorySync(runner: runner).pushBranchesAndTags(to: remote, onOutput: output)
            },
            title: AppLocalization.text("publish.push.title"),
            activityKind: .remote
        )
    }
}
