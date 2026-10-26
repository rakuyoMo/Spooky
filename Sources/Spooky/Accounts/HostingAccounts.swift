import Foundation
import Observation
import Security
import SpookyKit

// MARK: - HostingCredentialStore

/// 托管账号令牌的存放处：App 用系统钥匙串，测试换成内存，免得写进用户的钥匙串。
protocol HostingCredentialStore: Sendable {
    /// 账号的令牌；没有保存时为 nil。
    func token(for account: HostingAccount) -> String?

    /// 保存或替换账号的令牌。
    func setToken(_ token: String, for account: HostingAccount) throws

    /// 删除账号的令牌；没有保存时什么都不做。
    func removeToken(for account: HostingAccount)
}

// MARK: - HostingAccountError

/// 保存账号时钥匙串的失败。
enum HostingAccountError: Error, Equatable {
    /// 钥匙串拒绝写入，带上它返回的状态码。
    case keychain(OSStatus)
}

// MARK: - KeychainHostingCredentials

/// 系统钥匙串里的令牌：服务名带实例地址，账户名是账号标识，按实例与账号隔离。
struct KeychainHostingCredentials: HostingCredentialStore {
    /// 读出令牌。
    func token(for account: HostingAccount) -> String? {
        var query = Self.query(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var value: CFTypeRef?

        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// 已有条目时替换令牌，否则新建条目。
    func setToken(_ token: String, for account: HostingAccount) throws {
        let query = Self.query(for: account)
        let attributes = [kSecValueData as String: Data(token.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw HostingAccountError.keychain(status)
        }
    }

    /// 删除条目。
    func removeToken(for account: HostingAccount) {
        SecItemDelete(Self.query(for: account) as CFDictionary)
    }
}

// MARK: - Keychain Query

extension KeychainHostingCredentials {
    /// 一个账号的钥匙串条目。
    private static func query(for account: HostingAccount) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rakuyo.spooky.hosting." + account.instance.webURL.absoluteString,
            kSecAttrAccount as String: account.id.uuidString,
        ]
    }
}

// MARK: - HostingAccounts

/// 全部窗口共用的托管账号：账号列表存在偏好里，令牌只存在钥匙串里，不进仓库记录与日志。
@MainActor
@Observable
final class HostingAccounts {
    /// App 共用的账号。
    static let shared = HostingAccounts()

    /// 偏好键，值为账号数组的 JSON。
    static let key = "hostingAccounts"

    /// 已登录的账号，按添加的先后排列。
    private(set) var items: [HostingAccount]

    /// 存放账号列表的偏好。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 存放令牌的地方。
    @ObservationIgnored
    private let credentials: any HostingCredentialStore

    /// 读出偏好里的账号；内容损坏时视为没有账号。
    ///
    /// - Parameters:
    ///   - defaults: 存放账号列表的偏好。
    ///   - credentials: 存放令牌的地方。
    init(defaults: UserDefaults = .standard, credentials: any HostingCredentialStore = KeychainHostingCredentials()) {
        self.defaults = defaults
        self.credentials = credentials
        items = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([HostingAccount].self, from: $0) } ?? []
    }

    /// 实例上的账号。
    func accounts(on instance: HostingInstance) -> [HostingAccount] {
        items.filter { $0.instance == instance }
    }

    /// 账号的 API 客户端；令牌不在钥匙串里时为 nil。
    func client(for account: HostingAccount) -> HostingClient? {
        credentials.token(for: account).map { HostingClient(instance: account.instance, token: $0) }
    }

    /// 保存校验过的令牌：同一实例上已有同名账号时换上新令牌并清除重新认证的标记，否则加入新账号。
    ///
    /// - Parameters:
    ///   - user: 令牌对应的用户。
    ///   - instance: 账号所在的实例。
    ///   - authentication: 认证方式。
    ///   - token: 校验过的令牌。
    /// - Returns: 保存后的账号。
    @discardableResult
    func save(
        _ user: HostingUser,
        on instance: HostingInstance,
        authentication: HostingAuthentication,
        token: String
    ) throws -> HostingAccount {
        let existing = items.first { $0.instance == instance && $0.username == user.username }

        let account = HostingAccount(
            id: existing?.id ?? UUID(),
            instance: instance,
            username: user.username,
            name: user.name,
            authentication: authentication
        )

        // 先写钥匙串，写不进去时账号列表保持原样
        try credentials.setToken(token, for: account)

        if let index = items.firstIndex(where: { $0.id == account.id }) {
            items[index] = account
        } else {
            items.append(account)
        }

        persist()
        return account
    }

    /// 移除账号并删除它的令牌。
    func remove(_ account: HostingAccount) {
        credentials.removeToken(for: account)
        items.removeAll { $0.id == account.id }
        persist()
    }

    /// 托管服务拒绝了令牌时标记账号需要重新认证。
    func markNeedsReauthentication(_ account: HostingAccount) {
        guard let index = items.firstIndex(where: { $0.id == account.id }), !items[index].needsReauthentication else {
            return
        }

        items[index].needsReauthentication = true
        persist()
    }

    /// 把账号列表写回偏好。
    private func persist() {
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.key)
    }
}
