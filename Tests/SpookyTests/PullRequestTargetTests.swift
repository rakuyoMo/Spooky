import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - PullRequestTargetTests

/// 远端到账号与项目的对应：手动关联优先，其次是已登录账号的实例，再其次是还没有账号的已知实例，其余都不支持。
@MainActor
struct PullRequestTargetTests {
    /// github.com 上只有一个账号时直接对应；GitLab.com 的地址没有账号时说明要登录 GitLab。
    @Test("按账号的实例对应")
    func resolveByInstance() {
        let github = HostingAccount(instance: .github, username: "rakuyo", authentication: .oauth)

        #expect(
            PullRequestTarget.resolve(remoteURL: "git@github.com:o/r.git", accounts: [github], associations: [:])
                == .resolved(account: github, project: "o/r")
        )
        #expect(
            PullRequestTarget.resolve(remoteURL: "https://gitlab.com/g/s/p.git", accounts: [github], associations: [:])
                == .noAccount(.gitlabCom)
        )
        #expect(
            PullRequestTarget.resolve(remoteURL: "git@example.invalid:o/r.git", accounts: [github], associations: [:])
                == .unsupported
        )
        #expect(PullRequestTarget.resolve(remoteURL: "/srv/r.git", accounts: [], associations: [:]) == .unsupported)
    }

    /// 同一实例上的多个账号要选一个；选定或手动关联后按关联对应，手动填的项目路径优先于地址推出的。
    @Test("多个账号与手动关联")
    func chooseAndAssociate() throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let me = HostingAccount(instance: instance, username: "me", authentication: .personalAccessToken)
        let bot = HostingAccount(instance: instance, username: "bot", authentication: .personalAccessToken)
        let url = "git@git.example.com:组/项目.git"

        #expect(
            PullRequestTarget.resolve(remoteURL: url, accounts: [me, bot], associations: [:])
                == .chooseAccount([me, bot], project: "组/项目")
        )
        #expect(
            PullRequestTarget.resolve(remoteURL: url, accounts: [me, bot], associations: [url: .init(account: bot.id)])
                == .resolved(account: bot, project: "组/项目")
        )

        // SSH 别名的地址只能手动关联
        let alias = "work-gitlab:组/项目.git"
        let association = PullRequestAssociation(account: me.id, project: "组/子组/项目")
        #expect(PullRequestTarget.resolve(remoteURL: alias, accounts: [me], associations: [:]) == .unsupported)
        #expect(
            PullRequestTarget.resolve(remoteURL: alias, accounts: [me], associations: [alias: association])
                == .resolved(account: me, project: "组/子组/项目")
        )

        // 关联的账号已被移除时当作没有关联
        #expect(PullRequestTarget.resolve(remoteURL: alias, accounts: [bot], associations: [alias: association]) == .unsupported)
    }

    /// 关联写进偏好后可以读回，删除后不再存在。
    @Test("关联的存取")
    func associations() throws {
        let suite = "spooky-pr-associations-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let association = PullRequestAssociation(account: UUID(), project: "o/r")
        PullRequestAssociations.set(association, for: "git@alias:o/r.git", in: defaults)
        #expect(PullRequestAssociations.load(from: defaults) == ["git@alias:o/r.git": association])

        PullRequestAssociations.set(nil, for: "git@alias:o/r.git", in: defaults)
        #expect(PullRequestAssociations.load(from: defaults).isEmpty)
    }

    /// 请求视图的文案按服务取叫法，格式参数原样代入。
    @Test("按服务的文案")
    func terminology() {
        let session = RepositorySession()

        #expect(!session.usesMergeRequests)
        #expect(session.pullRequestText("create.message", "github.com").contains("github.com"))
        #expect(session.pullRequestText("close.message", "#7", "github.com").contains("#7"))
    }
}
