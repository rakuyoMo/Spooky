import Foundation

// MARK: - GitHubDeviceFlow

/// github.com 的设备授权：Spooky 取得一次性验证码，用户在浏览器里输入并授权后，轮询换到 OAuth 令牌。
///
/// 只用 OAuth App 的公开 Client ID，不需要 Client Secret；令牌只交给调用方存进钥匙串。
public struct GitHubDeviceFlow: Sendable {
    /// 一次授权：用户要输入的验证码、输入验证码的网页，以及轮询用的设备码与间隔。
    public struct Authorization: Sendable, Equatable {
        /// 轮询时交给 GitHub 的设备码。
        public let deviceCode: String

        /// 用户在网页上输入的验证码，如 `WDJB-MJHT`。
        public let userCode: String

        /// 输入验证码的网页。
        public let verificationURL: URL

        /// 两次轮询之间至少间隔的秒数。
        public let interval: Int

        /// 验证码过期的时间。
        public let expiresAt: Date
    }

    /// 申请的权限：读写私有仓库与 Pull Request，读取所属组织。
    public static let scopes = ["repo", "read:org"]

    /// OAuth App 的 Client ID。
    public let clientID: String

    /// 发请求用的会话；测试换成返回固定响应的会话。
    private let session: URLSession

    /// 两次轮询之间的等待；测试换成不等待。
    private let sleep: @Sendable (Duration) async throws -> Void

    /// 创建授权流程，不立即发请求。
    ///
    /// - Parameters:
    ///   - clientID: OAuth App 的 Client ID。
    ///   - session: 发请求用的会话。
    ///   - sleep: 两次轮询之间的等待。
    public init(
        clientID: String,
        session: URLSession = .shared,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.clientID = clientID
        self.session = session
        self.sleep = sleep
    }

    /// 申请验证码。
    public func start() async throws -> Authorization {
        let response: CodeResponse = try await post(
            "login/device/code",
            ["client_id": clientID, "scope": Self.scopes.joined(separator: " ")]
        )

        guard let url = URL(string: response.verificationUri) else {
            throw HostingError.incompatible(response.verificationUri)
        }

        return Authorization(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURL: url,
            interval: response.interval,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    /// 按间隔轮询，直到用户在浏览器里授权、拒绝或验证码过期；任务取消时停止。
    ///
    /// - Parameter authorization: ``start()`` 得到的授权。
    /// - Returns: OAuth 令牌。
    public func token(for authorization: Authorization) async throws -> String {
        var interval = authorization.interval

        while Date() < authorization.expiresAt {
            try await sleep(.seconds(interval))

            let response: TokenResponse = try await post(
                "login/oauth/access_token",
                [
                    "client_id": clientID,
                    "device_code": authorization.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                ]
            )

            if let token = response.accessToken {
                return token
            }

            switch response.error {
            case "authorization_pending":
                continue

            // 轮询太快时 GitHub 给出新的间隔
            case "slow_down":
                interval = response.interval ?? interval + 5

            case "expired_token":
                throw HostingError.authorizationExpired

            case "access_denied":
                throw HostingError.authorizationDenied

            default:
                throw HostingError.rejected(status: 400, message: response.errorDescription ?? response.error ?? "")
            }
        }

        throw HostingError.authorizationExpired
    }
}

// MARK: - Private

extension GitHubDeviceFlow {
    /// `login/device/code` 的结果。
    private struct CodeResponse: Decodable, Sendable {
        /// 设备码。
        let deviceCode: String

        /// 验证码。
        let userCode: String

        /// 输入验证码的网页。
        let verificationUri: String

        /// 验证码的有效秒数。
        let expiresIn: Int

        /// 轮询间隔的秒数。
        let interval: Int
    }

    /// `login/oauth/access_token` 的结果：成功时有令牌，否则是错误码。
    private struct TokenResponse: Decodable, Sendable {
        /// OAuth 令牌。
        let accessToken: String?

        /// 错误码，如 `authorization_pending`。
        let error: String?

        /// 错误说明。
        let errorDescription: String?

        /// `slow_down` 时的新间隔。
        let interval: Int?
    }

    /// 以表单提交到 github.com，要求 JSON 结果；网络失败与 HTTP 错误按 ``HostingError`` 分类。
    private func post<Value: Decodable & Sendable>(_ path: String, _ fields: [String: String]) async throws -> Value {
        var request = URLRequest(url: HostingInstance.github.webURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Spooky", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(
            fields
                .sorted { $0.key < $1.key }
                .map { HostingClient.encodedSegment($0.key) + "=" + HostingClient.encodedSegment($0.value) }
                .joined(separator: "&")
                .utf8
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw HostingClient.classify(error)
        }

        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw HostingClient.classify(status: http.statusCode, data: data, response: http)
        }

        do {
            return try HostingClient.decoder.decode(Value.self, from: data)
        } catch {
            throw HostingError.incompatible(HostingClient.message(in: data))
        }
    }
}
