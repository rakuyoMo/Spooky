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
    /// 新账号写进偏好，重新读取后仍在，令牌不在偏好里；同一实例同名的账号换上新令牌并清除重新认证的标记，
    /// 不同用户名或不同实例另加一个账号；移除账号同时删除令牌，令牌写不进去时账号列表不变。
    @Test("保存、读回、重新认证、多个账号与移除")
    func saveAndRemove() throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

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

        // 同一实例同名的账号重新认证：换令牌、清除标记，不另加账号
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let first = try accounts.save(
            HostingUser(username: "me", name: nil),
            on: instance,
            authentication: .personalAccessToken,
            token: "a"
        )
        accounts.markNeedsReauthentication(first)
        #expect(accounts.items.first { $0.id == first.id }?.needsReauthentication ?? false)

        let renewed = try accounts.save(
            HostingUser(username: "me", name: "Me"),
            on: instance,
            authentication: .personalAccessToken,
            token: "b"
        )
        #expect(renewed.id == first.id)
        #expect(accounts.items.count == 2)
        #expect(!(accounts.items.first { $0.id == first.id }?.needsReauthentication ?? true))
        #expect(credentials.token(for: renewed) == "b")

        // 不同用户名或不同实例另加一个账号
        try accounts.save(
            HostingUser(username: "bot", name: nil),
            on: instance,
            authentication: .personalAccessToken,
            token: "c"
        )
        try accounts.save(
            HostingUser(username: "me", name: nil),
            on: .gitlabCom,
            authentication: .personalAccessToken,
            token: "d"
        )
        #expect(accounts.items.count == 4)
        #expect(accounts.accounts(on: instance).map(\.username) == ["me", "bot"])

        // 移除账号连令牌一起删；令牌写不进去时账号列表不变
        accounts.remove(account)
        #expect(accounts.items.count == 3 && !accounts.items.contains(account))
        #expect(credentials.token(for: account) == nil)

        credentials.failure.withLock { $0 = errSecInteractionNotAllowed }
        #expect(throws: HostingAccountError.keychain(errSecInteractionNotAllowed)) {
            try accounts.save(
                HostingUser(username: "rakuyo", name: nil),
                on: .github,
                authentication: .oauth,
                token: "t"
            )
        }
        #expect(accounts.items.count == 3)
    }

    /// 用户名与密码登录的账号：钥匙串存令牌的 JSON；离到期还远时直接用访问令牌，没有到期时间时从不续期。
    /// 刷新令牌被拒时账号标为需要重新认证；网络失败只报错不标记；重新认证换到新令牌后标记清除。
    @Test("用户名与密码登录的令牌与续期失败")
    func passwordToken() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let credentials = MemoryCredentials()
        let renewals = Mutex<[String]>([])
        let failure = Mutex<HostingError>(.unreachable("offline"))
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials) { _, refreshToken in
            renewals.withLock { $0.append(refreshToken) }
            throw failure.withLock { $0 }
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

        try accounts.save(
            user,
            on: instance,
            token: GitLabOAuthToken(accessToken: "forever", refreshToken: "rt", expiresAt: nil)
        )
        #expect(try await accounts.token(for: account) == "forever")
        #expect(renewals.withLock { $0 }.isEmpty)

        // 到期的令牌续期时网络失败：只报错，不标记
        try accounts.save(
            user,
            on: instance,
            token: GitLabOAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: Date())
        )

        await #expect(throws: HostingError.unreachable("offline")) { try await accounts.token(for: account) }
        #expect(renewals.withLock { $0 } == ["rt"])
        #expect(!(accounts.items.first?.needsReauthentication ?? true))

        // 刷新令牌被拒：标为需要重新认证
        failure.withLock { $0 = .unauthorized("invalid_grant") }
        await #expect(throws: HostingError.unauthorized("invalid_grant")) { try await accounts.token(for: account) }
        #expect(accounts.items.first?.needsReauthentication ?? false)

        // 重新认证换到新令牌后标记清除
        let fresh = GitLabOAuthToken(
            accessToken: "new",
            refreshToken: "rt2",
            expiresAt: Date().addingTimeInterval(7200)
        )
        try accounts.save(user, on: instance, token: fresh)
        #expect(!(accounts.items.first?.needsReauthentication ?? true))
        #expect(try await accounts.token(for: account) == "new")
    }

    /// 距到期不到 60 秒先续期并写回；同时取两次令牌只续期一次。
    @Test("到期前串行续期")
    func renewBeforeExpiry() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 续期开始时报到，等测试放行才返回新令牌
        let (started, arrival) = AsyncStream<Void>.makeStream()
        let (released, release) = AsyncStream<Void>.makeStream()
        let credentials = MemoryCredentials()
        let renewals = Mutex<[String]>([])
        let accounts = HostingAccounts(defaults: defaults, credentials: credentials) { _, refreshToken in
            renewals.withLock { $0.append(refreshToken) }
            arrival.yield()

            for await _ in released { }

            return GitLabOAuthToken(accessToken: "at2", refreshToken: "rt2", expiresAt: Date().addingTimeInterval(7200))
        }

        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))

        let account = try accounts.save(
            HostingUser(username: "me", name: nil),
            on: instance,
            token: GitLabOAuthToken(accessToken: "at", refreshToken: "rt", expiresAt: Date().addingTimeInterval(30))
        )

        // 第一次取令牌开始续期
        let first = Task { try await accounts.token(for: account) }
        for await _ in started { break }

        // 第二次在续期回来之前取令牌；报到与进入等待在主线程的同一步里，报到之后它已在等第一次的续期
        let (joined, join) = AsyncStream<Void>.makeStream()
        let second = Task {
            join.yield()
            return try await accounts.token(for: account)
        }

        for await _ in joined { break }

        release.finish()
        let tokens = try await [first.value, second.value]

        #expect(tokens == ["at2", "at2"])
        #expect(renewals.withLock { $0 } == ["rt"])

        let stored = try #require(credentials.token(for: account))
        let renewed = try JSONDecoder().decode(GitLabOAuthToken.self, from: Data(stored.utf8))
        #expect(renewed.accessToken == "at2" && renewed.refreshToken == "rt2")
    }
}

// MARK: - Helpers

extension HostingAccountsTests {
    /// 独立的偏好域与它所在的临时目录；用例结束时删掉目录。
    private static func defaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-hosting-accounts-" + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }
}

// MARK: - MemoryCredentials

/// 只存在内存里的令牌，可以模拟钥匙串拒绝写入。
final class MemoryCredentials: HostingCredentialStore {
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
