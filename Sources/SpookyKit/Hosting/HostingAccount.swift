import Foundation

// MARK: - HostingAuthentication

/// 账号的认证方式；令牌本身只存在系统钥匙串里。
public enum HostingAuthentication: String, Codable, Sendable {
    /// 经浏览器授权得到的 OAuth 令牌，只用于 github.com。
    case oauth

    /// 用户在托管服务上创建的个人访问令牌。
    case personalAccessToken
}

// MARK: - HostingAccount

/// 已登录的托管账号：实例、用户名与认证方式；同一实例可以有多个账号。
public struct HostingAccount: Codable, Sendable, Hashable, Identifiable {
    /// 账号的稳定标识，也是钥匙串条目的账户名。
    public let id: UUID

    /// 账号所在的实例。
    public let instance: HostingInstance

    /// 托管服务上的用户名。
    public var username: String

    /// 托管服务上的显示名；没有设置时为 nil。
    public var name: String?

    /// 认证方式。
    public var authentication: HostingAuthentication

    /// 令牌已被拒绝（无效、过期或撤销），需要重新认证。
    public var needsReauthentication: Bool

    /// 创建账号。
    ///
    /// - Parameters:
    ///   - id: 稳定标识；新账号用新值。
    ///   - instance: 账号所在的实例。
    ///   - username: 用户名。
    ///   - name: 显示名。
    ///   - authentication: 认证方式。
    ///   - needsReauthentication: 令牌是否已被拒绝。
    public init(
        id: UUID = UUID(),
        instance: HostingInstance,
        username: String,
        name: String? = nil,
        authentication: HostingAuthentication,
        needsReauthentication: Bool = false
    ) {
        self.id = id
        self.instance = instance
        self.username = username
        self.name = name
        self.authentication = authentication
        self.needsReauthentication = needsReauthentication
    }
}

// MARK: - HostingUser

/// 令牌对应的用户，添加账号与重新认证时读取。
public struct HostingUser: Sendable, Equatable {
    /// 用户名。
    public let username: String

    /// 显示名；没有设置时为 nil。
    public let name: String?

    /// 创建用户；解析与测试使用。
    public init(username: String, name: String?) {
        self.username = username
        self.name = name
    }
}
