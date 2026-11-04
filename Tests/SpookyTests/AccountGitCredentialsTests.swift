import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - AccountGitCredentialsTests

/// HTTPS 远端属于已登录的账号时用账号令牌回答 Git：远端对应到哪个账号、令牌怎样交给 Git，以及令牌被拒后回到询问。
@MainActor
struct AccountGitCredentialsTests {
    /// 交给 Spooky 的前缀：账号实例的网页地址与关联到已登录账号的 HTTPS 远端，去掉用户名、去重；http 与 SSH 不在其中。
    @Test("凭据助手的前缀")
    func scopes() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let selfManaged = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let plain = try #require(HostingInstance.gitlab(address: "http://plain.example.com"))

        let github = try fixture.save("rakuyo", on: .github, authentication: .oauth)
        try fixture.save("me", on: selfManaged, authentication: .personalAccessToken)
        try fixture.save("bot", on: selfManaged, authentication: .personalAccessToken)
        try fixture.save("old", on: plain, authentication: .personalAccessToken)

        PullRequestAssociations.set(
            PullRequestAssociation(account: github.id),
            for: "https://me@mirror.example.com/o/r.git",
            in: fixture.defaults
        )

        PullRequestAssociations.set(
            PullRequestAssociation(account: github.id),
            for: "git@mirror.example.com:o/s.git",
            in: fixture.defaults
        )

        PullRequestAssociations.set(
            PullRequestAssociation(account: UUID()),
            for: "https://gone.example.com/o/r.git",
            in: fixture.defaults
        )

        #expect(
            fixture.credentials.scopes() == [
                "https://github.com",
                "https://git.example.com/gitlab",
                "https://mirror.example.com/o/r.git",
            ]
        )
    }

    /// 令牌按服务交给 Git：GitHub 的令牌与 GitLab 的个人访问令牌配账号的用户名，用户名与密码登录换来的令牌配 oauth2。
    @Test("回答的格式")
    func answerFormats() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let selfManaged = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let expiry = Date().addingTimeInterval(7200)

        try fixture.save("rakuyo", on: .github, authentication: .oauth, token: "gho_token")
        try fixture.save("me", on: .gitlabCom, authentication: .personalAccessToken, token: "glpat-token")
        try fixture.accounts.save(
            HostingUser(username: "dev", name: nil),
            on: selfManaged,
            token: GitLabOAuthToken(accessToken: "oauth-access", refreshToken: "rt", expiresAt: expiry)
        )

        #expect(await fixture.get("https://github.com/o/r.git") == "username=rakuyo\npassword=gho_token\n")
        #expect(await fixture.get("https://gitlab.com/g/s/p.git") == "username=me\npassword=glpat-token\n")
        #expect(await fixture.get("https://git.example.com/gitlab/g/p.git") == "username=oauth2\npassword=oauth-access\n")

        // 地址不属于任何账号，或不是 HTTPS 时不回答，Git 接着问 askpass
        #expect(await fixture.get("https://other.example.com/o/r.git") == nil)
        #expect(await fixture.get("http://github.com/o/r.git") == nil)
    }

    /// 同一实例几个账号时按手动关联选定的回答；关联地址带不带用户名、`.git` 与结尾的 “/” 都算同一个远端，没有关联时不猜。
    @Test("手动关联选定账号")
    func association() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        try fixture.save("me", on: instance, authentication: .personalAccessToken, token: "me-token")
        let bot = try fixture.save("bot", on: instance, authentication: .personalAccessToken, token: "bot-token")

        #expect(await fixture.get("https://git.example.com/gitlab/g/p.git") == nil)

        PullRequestAssociations.set(
            PullRequestAssociation(account: bot.id),
            for: "https://deploy@Git.Example.com/gitlab/g/p.git",
            in: fixture.defaults
        )

        #expect(await fixture.get("https://git.example.com/gitlab/g/p.git") == "username=bot\npassword=bot-token\n")
        #expect(await fixture.get("https://git.example.com/gitlab/g/p/") == "username=bot\npassword=bot-token\n")

        // 关联可以指到账号实例以外的地址，如镜像
        PullRequestAssociations.set(
            PullRequestAssociation(account: bot.id),
            for: "https://mirror.example.com/g/p",
            in: fixture.defaults
        )

        #expect(await fixture.get("https://mirror.example.com/g/p.git") == "username=bot\npassword=bot-token\n")
    }

    /// 需要重新认证的账号不回答，免得 Git 拿着已知失效的令牌失败。
    @Test("需要重新认证的账号")
    func needsReauthentication() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let account = try fixture.save("rakuyo", on: .github, authentication: .oauth)
        fixture.accounts.markNeedsReauthentication(account)

        #expect(await fixture.get("https://github.com/o/r.git") == nil)
    }

    /// 同一操作刚用账号令牌回答过的地址被 erase，说明 Git 拒绝了令牌：之后这个账号的地址不回答，askpass 的提示认得出这个账号；重新认证后恢复。
    @Test("令牌被拒后回到询问")
    func rejectedToken() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let user = HostingUser(username: "rakuyo", name: nil)
        try fixture.accounts.save(user, on: .github, authentication: .oauth, token: "gho_token")

        let address = "https://github.com/o/r.git"
        let prompt = "Password for 'https://rakuyo@github.com/o/r.git': "

        // 别的操作发来的 erase 对不上这次回答，不算令牌被拒
        #expect(await fixture.get(address, operation: "first") != nil)
        _ = await fixture.respond("erase", address: address, operation: "second")
        #expect(fixture.credentials.rejectedAccount(forPrompt: prompt) == nil)

        _ = await fixture.respond("erase", address: address, operation: "first")
        #expect(await fixture.get(address) == nil)
        #expect(fixture.credentials.rejectedAccount(forPrompt: prompt)?.username == "rakuyo")

        try fixture.accounts.save(user, on: .github, authentication: .oauth, token: "gho_new")
        #expect(fixture.credentials.rejectedAccount(forPrompt: prompt) == nil)
        #expect(await fixture.get(address) == "username=rakuyo\npassword=gho_new\n")
    }
}

// MARK: AccountGitCredentialsTests.Fixture

extension AccountGitCredentialsTests {
    /// 独立偏好域里的账号与回答者，令牌只存在内存里。
    @MainActor
    private struct Fixture {
        /// 偏好域所在的临时目录，测试结束时删除。
        let directory: URL

        /// 存放账号列表与手动关联的偏好。
        let defaults: UserDefaults

        /// 已登录的账号。
        let accounts: HostingAccounts

        /// 被测的回答者。
        let credentials: AccountGitCredentials

        /// 创建空的偏好域与账号。
        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appending(path: "spooky-account-git-credentials-" + UUID().uuidString)
            defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
            accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())
            credentials = AccountGitCredentials(accounts: accounts, defaults: defaults)
        }

        /// 保存一个账号。
        @discardableResult
        func save(
            _ username: String,
            on instance: HostingInstance,
            authentication: HostingAuthentication,
            token: String = "token"
        ) throws -> HostingAccount {
            try accounts.save(
                HostingUser(username: username, name: nil),
                on: instance,
                authentication: authentication,
                token: token
            )
        }

        /// 以凭据助手的 `get` 请求这个地址。
        func get(_ address: String, operation: String = UUID().uuidString) async -> String? {
            await respond("get", address: address, operation: operation)
        }

        /// 以凭据助手的请求交给回答者。
        func respond(_ action: String, address: String, operation: String) async -> String? {
            let request = RemoteCallbackRequest(
                host: "/tmp/repository",
                id: UUID().uuidString,
                operation: operation,
                kind: .credential,
                prompt: action,
                content: address,
                isInteractive: true
            )

            return await credentials.respond(to: request)
        }

        /// 删除偏好域所在的临时目录。
        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
