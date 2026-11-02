import Foundation
import Security
import SpookyKit
import Synchronization
import Testing

@testable import Spooky

// MARK: - HostingAccountsTests

/// 托管账号：列表存在偏好里、令牌只交给令牌存放处；同一实例同名的账号换令牌而不重复，同一服务可以有多个账号。
@MainActor
struct HostingAccountsTests {
    /// 新账号写进偏好，重新读取后仍在；令牌不在偏好里。
    @Test("保存与读回")
    func saveAndReload() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let credentials = MemoryCredentials()
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials)

        let account = try accounts.save(
            HostingUser(username: "rakuyo", name: "鸡翅"),
            on: .github,
            authentication: .oauth,
            token: "gho_secret"
        )

        #expect(accounts.items == [account])
        #expect(credentials.token(for: account) == "gho_secret")
        #expect(accounts.client(for: account)?.instance == .github)

        let stored = try #require(defaults.data(forKey: HostingAccounts.key))
        #expect(!String(decoding: stored, as: UTF8.self).contains("gho_secret"))

        let reloaded = HostingAccounts(defaults: defaults, credentials: credentials)
        #expect(reloaded.items == [account])
    }

    /// 同一实例同名的账号换上新令牌并清除重新认证的标记；不同用户名或不同实例另加一个账号。
    @Test("重新认证与多个账号")
    func reauthenticateAndMultiple() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let credentials = MemoryCredentials()
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials)
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))

        let first = try accounts.save(
            HostingUser(username: "me", name: nil),
            on: instance,
            authentication: .personalAccessToken,
            token: "a"
        )
        accounts.markNeedsReauthentication(first)
        #expect(accounts.items.first?.needsReauthentication ?? false)

        let renewed = try accounts.save(
            HostingUser(username: "me", name: "Me"),
            on: instance,
            authentication: .personalAccessToken,
            token: "b"
        )
        #expect(renewed.id == first.id)
        #expect(accounts.items.count == 1 && !accounts.items[0].needsReauthentication)
        #expect(credentials.token(for: renewed) == "b")

        try accounts.save(HostingUser(username: "bot", name: nil), on: instance, authentication: .personalAccessToken, token: "c")
        try accounts.save(
            HostingUser(username: "me", name: nil),
            on: .gitlabCom,
            authentication: .personalAccessToken,
            token: "d"
        )
        #expect(accounts.items.count == 3)
        #expect(accounts.accounts(on: instance).map(\.username) == ["me", "bot"])
    }

    /// 移除账号同时删除令牌；令牌写不进去时账号列表不变。
    @Test("移除与写入失败")
    func removeAndFailure() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let credentials = MemoryCredentials()
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials)
        let account = try accounts.save(
            HostingUser(username: "rakuyo", name: nil),
            on: .github,
            authentication: .oauth,
            token: "t"
        )

        accounts.remove(account)
        #expect(accounts.items.isEmpty)
        #expect(credentials.token(for: account) == nil)

        credentials.failure.withLock { $0 = errSecInteractionNotAllowed }
        #expect(throws: HostingAccountError.keychain(errSecInteractionNotAllowed)) {
            try accounts.save(HostingUser(username: "rakuyo", name: nil), on: .github, authentication: .oauth, token: "t")
        }
        #expect(accounts.items.isEmpty)
    }

    /// 用户名与密码登录的账号：钥匙串存令牌的 JSON；离到期还远时直接用访问令牌，没有到期时间时从不续期。
    @Test("用户名与密码登录的令牌")
    func passwordToken() async throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let credentials = MemoryCredentials()
        let renewals = Mutex<[String]>([])
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials) { _, refreshToken in
            renewals.withLock { $0.append(refreshToken) }
            throw HostingError.unreachable("offline")
        }
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let user = HostingUser(username: "me", name: nil)

        let account = try accounts.save(
            user,
            on: instance,
            token: GitLabOAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: Date().addingTimeInterval(3600))
        )
        #expect(account.authentication == .password)
        #expect(try await accounts.token(for: account) == "at")
        #expect(accounts.client(for: account) != nil)

        let stored = try #require(credentials.token(for: account))
        let decoded = try JSONDecoder().decode(GitLabOAuthToken.self, from: Data(stored.utf8))
        #expect(decoded.accessToken == "at" && decoded.refreshToken == "rt")

        try accounts.save(user, on: instance, token: GitLabOAuthToken(accessToken: "forever", refreshToken: "rt", expiresAt: nil))
        #expect(try await accounts.token(for: account) == "forever")
        #expect(renewals.withLock { $0 }.isEmpty)
    }

    /// 距到期不到 60 秒先续期并写回；同时取两次令牌只续期一次。
    @Test("到期前串行续期")
    func renewBeforeExpiry() async throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let credentials = MemoryCredentials()
        let renewals = Mutex<[String]>([])
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials) { _, refreshToken in
            renewals.withLock { $0.append(refreshToken) }

            // 续期还没回来时，另一次取令牌已经开始等待
            try await Task.sleep(for: .milliseconds(100))
            return GitLabOAuthToken(accessToken: "at2", refreshToken: "rt2", expiresAt: Date().addingTimeInterval(7200))
        }
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))

        let account = try accounts.save(
            HostingUser(username: "me", name: nil),
            on: instance,
            token: GitLabOAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: Date().addingTimeInterval(30))
        )

        async let first = accounts.token(for: account)
        async let second = accounts.token(for: account)
        let tokens = try await [first, second]

        #expect(tokens == ["at2", "at2"])
        #expect(renewals.withLock { $0 } == ["rt"])

        let stored = try #require(credentials.token(for: account))
        let renewed = try JSONDecoder().decode(GitLabOAuthToken.self, from: Data(stored.utf8))
        #expect(renewed.accessToken == "at2" && renewed.refreshToken == "rt2")
    }

    /// 刷新令牌被拒时账号标为需要重新认证；网络失败只报错不标记；重新认证换到新令牌后标记清除。
    @Test("刷新令牌被拒")
    func renewRejected() async throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let failure = Mutex<HostingError>(.unreachable("offline"))
        let accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials()) { _, _ in
            throw failure.withLock { $0 }
        }
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let user = HostingUser(username: "me", name: nil)
        let expiring = GitLabOAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: Date())

        let account = try accounts.save(user, on: instance, token: expiring)

        await #expect(throws: HostingError.unreachable("offline")) { try await accounts.token(for: account) }
        #expect(!(accounts.items.first?.needsReauthentication ?? true))

        failure.withLock { $0 = .unauthorized("invalid_grant") }
        await #expect(throws: HostingError.unauthorized("invalid_grant")) { try await accounts.token(for: account) }
        #expect(accounts.items.first?.needsReauthentication ?? false)

        let fresh = GitLabOAuthToken(accessToken: "new", refreshToken: "rt2", expiresAt: Date().addingTimeInterval(7200))
        try accounts.save(user, on: instance, token: fresh)
        #expect(!(accounts.items.first?.needsReauthentication ?? true))
        #expect(try await accounts.token(for: account) == "new")
    }
}

// MARK: - Helpers

extension HostingAccountsTests {
    /// 独立的偏好域。
    private static func defaults() throws -> (UserDefaults, String) {
        let suite = "spooky-hosting-accounts-" + UUID().uuidString
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }
}

// MARK: - MemoryCredentials

/// 只存在内存里的令牌，可以模拟钥匙串拒绝写入。
private final class MemoryCredentials: HostingCredentialStore {
    /// 按账号标识存放的令牌。
    private let tokens = Mutex<[UUID: String]>([:])

    /// 不为 nil 时写入失败并抛出这个状态码。
    let failure = Mutex<OSStatus?>(nil)

    /// 读出令牌。
    func token(for account: HostingAccount) -> String? {
        tokens.withLock { $0[account.id] }
    }

    /// 写入令牌，或按设置失败。
    func setToken(_ token: String, for account: HostingAccount) throws {
        if let failure = failure.withLock({ $0 }) {
            throw HostingAccountError.keychain(failure)
        }

        tokens.withLock { $0[account.id] = token }
    }

    /// 删除令牌。
    func removeToken(for account: HostingAccount) {
        tokens.withLock { $0[account.id] = nil }
    }
}
