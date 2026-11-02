import Foundation

// MARK: - GitLabOAuthToken

/// 私有部署 GitLab 用用户名与密码换来的 OAuth 令牌：接口请求用的访问令牌、续期用的刷新令牌与到期时间。
public struct GitLabOAuthToken: Codable, Sendable, Equatable {
    /// 接口请求用的访问令牌。
    public let accessToken: String

    /// 续期用的刷新令牌；服务端没有给出时为 nil。
    public let refreshToken: String?

    /// 访问令牌到期的时间；服务端没有给出有效期时为 nil，当作不过期。
    public let expiresAt: Date?

    /// 创建令牌；解析与测试使用。
    ///
    /// - Parameters:
    ///   - accessToken: 访问令牌。
    ///   - refreshToken: 刷新令牌。
    ///   - expiresAt: 到期时间。
    public init(accessToken: String, refreshToken: String?, expiresAt: Date?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// 在 `date` 时距到期已不到 60 秒，要先续期；不过期或没有刷新令牌时不续期。
    public func needsRefresh(at date: Date = Date()) -> Bool {
        guard let expiresAt, refreshToken != nil else {
            return false
        }

        return expiresAt.timeIntervalSince(date) < 60
    }
}

// MARK: - GitLabPasswordGrant

/// 私有部署 GitLab 的 OAuth 密码授权：用用户名与密码换 API 令牌，到期前用刷新令牌续期。
///
/// 不带 OAuth 应用凭据；密码只放在换令牌这一次请求的表单里，不保存，也不进日志与错误。
/// 失败一律不自动重试，以免累计的登录失败把账号锁住。
public struct GitLabPasswordGrant: Sendable {
    /// 申请的权限范围。
    public static let scope = "api"

    /// 账号所在的实例。
    public let instance: HostingInstance

    /// 发请求用的会话；测试换成返回固定响应的会话。
    private let session: URLSession

    /// 创建授权，不立即发请求。
    ///
    /// - Parameters:
    ///   - instance: 账号所在的实例。
    ///   - session: 发请求用的会话。
    public init(instance: HostingInstance, session: URLSession = .shared) {
        self.instance = instance
        self.session = session
    }

    /// 用用户名与密码换令牌。
    ///
    /// - Parameters:
    ///   - username: GitLab 或 LDAP 的用户名，也可以是邮箱。
    ///   - password: 密码。
    public func token(username: String, password: String) async throws -> GitLabOAuthToken {
        try await post([
            "grant_type": "password",
            "username": username,
            "password": password,
            "scope": Self.scope,
        ])
    }

    /// 用刷新令牌换新的令牌；刷新令牌过期或被撤销时报 ``HostingError/unauthorized(_:)``。
    ///
    /// - Parameter refreshToken: 上一次得到的刷新令牌。
    public func refresh(_ refreshToken: String) async throws -> GitLabOAuthToken {
        do {
            return try await post(["grant_type": "refresh_token", "refresh_token": refreshToken])
        } catch HostingError.passwordRejected(let message) {
            // 续期时的 invalid_grant 说明刷新令牌已经失效，与令牌被拒同类，要重新认证
            throw HostingError.unauthorized(message)
        }
    }
}

// MARK: - Private

extension GitLabPasswordGrant {
    /// `oauth/token` 成功时的结果。
    private struct TokenResponse: Decodable, Sendable {
        /// 访问令牌。
        let accessToken: String

        /// 刷新令牌。
        let refreshToken: String?

        /// 访问令牌的有效秒数。
        let expiresIn: Int?
    }

    /// `oauth/token` 失败时的结果。
    private struct ErrorResponse: Decodable, Sendable {
        /// 错误码，如 `invalid_grant`。
        let error: String?

        /// 错误说明。
        let errorDescription: String?
    }

    /// 以表单提交到 `<实例网页地址>/oauth/token`；到期时间按收到响应时的本机时间推算，不受两边时钟差的影响。
    private func post(_ fields: [String: String]) async throws -> GitLabOAuthToken {
        var request = URLRequest(
            url: instance.webURL.appending(path: "oauth/token"),
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Spooky", forHTTPHeaderField: "User-Agent")
        request.httpBody = HostingClient.formBody(fields)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw HostingClient.classify(error)
        }

        let received = Date()

        guard let http = response as? HTTPURLResponse else {
            throw HostingError.incompatible(String(describing: type(of: response)))
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.classify(status: http.statusCode, data: data, response: http)
        }

        guard let token = try? HostingClient.decoder.decode(TokenResponse.self, from: data) else {
            throw HostingError.incompatible(HostingClient.message(in: data))
        }

        return GitLabOAuthToken(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: token.expiresIn.map { received.addingTimeInterval(TimeInterval($0)) }
        )
    }
}

// MARK: - Helpers

extension GitLabPasswordGrant {
    /// 三种授权错误码各自分类，带服务端的说明；其余按状态码分类。
    private static func classify(status: Int, data: Data, response: HTTPURLResponse) -> HostingError {
        let reply = try? HostingClient.decoder.decode(ErrorResponse.self, from: data)
        let message = reply?.errorDescription ?? reply?.error ?? ""

        switch reply?.error {
        case "invalid_grant":
            return .passwordRejected(message)

        case "invalid_client":
            return .clientCredentialsRequired(message)

        case "unsupported_grant_type":
            return .passwordGrantUnsupported(message)

        default:
            return HostingClient.classify(status: status, data: data, response: response)
        }
    }
}
