import Foundation
import SpookyKit
import Testing
import TestSupport

@testable import Spooky

// MARK: - PullRequestTargetTests

/// 远端到账号与项目的对应：手动关联优先，其次是已登录账号的实例，再其次是还没有账号的已知实例，其余都不支持。
@MainActor
struct PullRequestTargetTests {
    /// github.com 上只有一个账号时直接对应；GitLab.com 的地址没有账号时说明要登录 GitLab。
    /// 同一实例上的多个账号要选一个；选定或手动关联后按关联对应，手动填的项目路径优先于地址推出的；
    /// 关联写进偏好后可以读回，删除后不再存在。
    @Test("按账号的实例对应，多个账号与手动关联")
    func resolve() throws {
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

        // 同一实例上的多个账号
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
        #expect(
            PullRequestTarget.resolve(
                remoteURL: alias,
                accounts: [bot],
                associations: [alias: association]
            ) == .unsupported
        )

        // 关联的存取
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-pr-associations-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        PullRequestAssociations.set(association, for: alias, in: defaults)
        #expect(PullRequestAssociations.load(from: defaults) == [alias: association])

        PullRequestAssociations.set(nil, for: alias, in: defaults)
        #expect(PullRequestAssociations.load(from: defaults).isEmpty)
    }

    /// 添加、移除与重新认证账号后请求视图重新找对应的账号；令牌被拒时自动加上的标记不再读一次。
    @Test("账号变化后是否重新读取请求")
    func accountsChange() {
        let me = HostingAccount(instance: .gitlabCom, username: "me", authentication: .personalAccessToken)
        let bot = HostingAccount(instance: .github, username: "bot", authentication: .oauth)

        var rejected = me
        rejected.needsReauthentication = true

        var renamed = me
        renamed.name = "Me"

        let reloads = RepositorySession.accountsChangeReloadsPullRequests

        #expect(reloads([me], [me, bot]))
        #expect(reloads([me, bot], [bot]))
        #expect(reloads([rejected], [me]))

        #expect(!reloads([me], [rejected]))
        #expect(!reloads([me], [renamed]))
        #expect(!reloads([me, bot], [me, bot]))
    }

    /// 请求视图读过之后，仓库里加了远端、刷新读到新的引用时，请求视图随即重新读出远端。
    @Test("远端变化后重新读取请求")
    func remotesChange() async throws {
        // 远端变化由窗口观察，再交给会话重读请求；第一个远端在文件监听开始之前加上
        let fixture = try await HistoryListTests.makeSession(
            commits: ["first"],
            createsWindowController: true
        ) { runner, _ in
            _ = try await runner.run(["remote", "add", "origin", "http://127.0.0.1:9/group/project.git"])
        }
        defer { fixture.close() }

        // 账号列表只在内存里，不碰本机的账号
        let session = fixture.session
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-remotes-change-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        session.pullRequests.accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())
        session.reloadPullRequests()

        // 没有账号，远端对应不到服务，列表不发请求就读完；第一次读完时标记已读过
        await until { session.pullRequests.isLoaded }
        #expect(session.pullRequests.remotes.map(\.name) == ["origin"])

        // 加了远端后刷新，窗口看到新的引用就让会话重读请求；重读可能在刷新结束前就已读完，所以在加远端之前记下读到的远端
        let before = session.pullRequests.remotes
        _ = try await fixture.runner.run(["remote", "add", "mirror", "myhost:group/project.git"])
        session.refresh(full: true)
        await session.waitForRefresh()

        await until { session.pullRequests.remotes != before && !session.pullRequests.isLoading }
        #expect(Set(session.pullRequests.remotes.map(\.name)) == ["mirror", "origin"])
    }
}
