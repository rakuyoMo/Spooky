import Foundation
import os

// MARK: - HostingResponse

/// 一次 API 请求解码后的结果，以及分页时的下一页页码。
struct HostingResponse<Value: Sendable>: Sendable {
    /// 解码后的结果。
    let value: Value

    /// 下一页的页码；没有下一页时为 nil。
    let nextPage: Int?
}

// MARK: - HostingClient

/// 一个账号对托管服务 REST API 的访问，从本机发起。
///
/// 令牌只放在请求头里，不进 URL、日志与错误；失败按 ``HostingError`` 分类，保留服务端返回的原文。
public struct HostingClient: Sendable {
    /// 支持的最低 GitLab 版本：合并请求的 `diffs` 接口与 `detailed_merge_status` 字段从 15.7 起都有。
    public static let minimumGitLabVersion = [15, 7]

    /// API 请求失败的日志；只记类别与状态码，不记地址、令牌与原文。
    private static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "HostingClient")

    /// 账号所在的实例。
    public let instance: HostingInstance

    /// 账号的令牌。
    private let token: String

    /// 发请求用的会话；测试换成返回固定响应的会话。
    private let session: URLSession

    /// 创建客户端，不立即发请求。
    ///
    /// - Parameters:
    ///   - instance: 账号所在的实例。
    ///   - token: OAuth 令牌或个人访问令牌。
    ///   - session: 发请求用的会话。
    public init(instance: HostingInstance, token: String, session: URLSession = .shared) {
        self.instance = instance
        self.token = token
        self.session = session
    }

    /// 令牌对应的用户；添加账号与重新认证时用它校验令牌，GitLab 同时检查版本。
    public func currentUser() async throws -> HostingUser {
        switch instance.service {
        case .github:
            let user: GitHubUser = try await send("GET", "user").value
            return HostingUser(username: user.login, name: user.name)

        case .gitlab:
            try await checkGitLabVersion()

            let user: GitLabUser = try await send("GET", "user").value
            return HostingUser(username: user.username, name: user.name)
        }
    }

    /// 发出请求并解码 JSON 结果。
    ///
    /// - Parameters:
    ///   - method: HTTP 方法。
    ///   - path: API 根地址之后的路径，已按需转义，如 `projects/group%2Fproject/merge_requests`。
    ///   - query: 查询参数。
    ///   - body: JSON 请求体。
    func send<Value: Decodable & Sendable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> HostingResponse<Value> {
        let (data, response) = try await perform(method, path, query: query, body: body)

        do {
            return HostingResponse(value: try Self.decoder.decode(Value.self, from: data), nextPage: Self.nextPage(response))
        } catch {
            Self.logger.error("托管服务 API 的响应无法解析：\(method, privacy: .public)")
            throw HostingError.incompatible(Self.describe(error))
        }
    }

    /// 发出不需要解码结果的请求，如删除与没有响应体的操作。
    func perform(_ method: String, _ path: String, body: Data? = nil) async throws {
        _ = try await perform(method, path, query: [], body: body)
    }
}

// MARK: - Request

extension HostingClient {
    /// JSON 结果的解码器：字段名从蛇形转成驼峰，时间兼容带与不带小数秒的 ISO 8601。
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)

            guard let date = Self.date(from: text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: text))
            }

            return date
        }
        return decoder
    }()

    /// 不需要转义的字符。
    private static let unreserved =
        CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    /// GitLab 的项目路径作为 API 路径的一段：除字母、数字与 `-._~` 外都转义，“/” 写成 `%2F`。
    static func encodedSegment(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }

    /// 解析 ISO 8601 时间，带不带小数秒都可以。
    static func date(from text: String) -> Date? {
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

        return (try? Date(text, strategy: fractional)) ?? (try? Date(text, strategy: .iso8601))
    }

    /// 发出请求，返回 2xx 的响应体；其余状态与网络失败按类别抛出。
    private func perform(
        _ method: String,
        _ path: String,
        query: [URLQueryItem],
        body: Data?
    ) async throws -> (Data, HTTPURLResponse) {
        let request = try makeRequest(method, path, query: query, body: body)
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw Self.classify(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HostingError.incompatible(String(describing: type(of: response)))
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let error = Self.classify(status: http.statusCode, data: data, response: http)
            Self.logger.error("托管服务 API 请求失败：\(method, privacy: .public) \(http.statusCode, privacy: .public)")
            throw error
        }

        return (data, http)
    }

    /// 组装请求：认证头按服务取，GitHub 固定 API 版本。
    private func makeRequest(_ method: String, _ path: String, query: [URLQueryItem], body: Data?) throws -> URLRequest {
        guard var components = URLComponents(url: instance.apiURL, resolvingAgainstBaseURL: false) else {
            throw HostingError.incompatible(instance.displayName)
        }

        components.percentEncodedPath += "/" + path

        // 查询值里的 “+” 等字符也转义，服务端不会把它们读成空格
        if !query.isEmpty {
            components.percentEncodedQuery = query
                .map { Self.encodedSegment($0.name) + "=" + Self.encodedSegment($0.value ?? "") }
                .joined(separator: "&")
        }

        guard let url = components.url else {
            throw HostingError.incompatible(instance.displayName)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Spooky", forHTTPHeaderField: "User-Agent")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        switch instance.service {
        case .github:
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        case .gitlab:
            request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        }

        return request
    }

    /// 确认 GitLab 不低于 ``minimumGitLabVersion``。
    private func checkGitLabVersion() async throws {
        let version: GitLabVersion = try await send("GET", "version").value
        let components = version.version.split(separator: ".").prefix(2).map { Int($0.prefix { $0.isNumber }) ?? 0 }

        guard components.count == 2, !components.lexicographicallyPrecedes(Self.minimumGitLabVersion) else {
            throw HostingError.incompatible("GitLab " + version.version)
        }
    }
}

// MARK: - Classification

extension HostingClient {
    /// 按状态码与响应头分类失败；403 与 429 里的速率限制单独分出。
    static func classify(status: Int, data: Data, response: HTTPURLResponse) -> HostingError {
        let message = message(in: data)
        let remaining = response.value(forHTTPHeaderField: "x-ratelimit-remaining")
        let rateLimited = status == 429 || (status == 403 && (remaining == "0" || message.lowercased().contains("rate limit")))

        if rateLimited {
            return .rateLimited(reset: resetDate(response), message: message)
        }

        switch status {
        case 401: return .unauthorized(message)
        case 403: return .forbidden(message)
        case 404: return .notFound(message)
        case 500...: return .server(status: status, message: message)
        default: return .rejected(status: status, message: message)
        }
    }

    /// 网络失败分成证书问题与连不上两类；取消照常按取消传出。
    ///
    /// 只有明确是证书的错误码算证书问题：TLS 握手失败也可能来自代理或网络，归入连不上。
    static func classify(_ error: URLError) -> any Error {
        switch error.code {
        case .cancelled:
            CancellationError()

        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired:
            HostingError.untrustedCertificate(error.localizedDescription)

        default:
            HostingError.unreachable(error.localizedDescription)
        }
    }

    /// 响应体里的错误原文：GitHub 的 `message` 与 `errors`，GitLab 的 `message`、`error` 与 `error_description`；不是 JSON 时取开头的文本。
    static func message(in data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(decoding: data.prefix(4096), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var parts: [String] = []

        for key in ["message", "error", "error_description"] {
            if let text = object[key] as? String {
                parts.append(text)
            } else if
                let value = object[key], let json = try? JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys]
                )
            {
                parts.append(String(decoding: json, as: UTF8.self))
            }
        }

        // GitHub 的校验失败把每项原因放在 errors 里
        if let errors = object["errors"] as? [Any] {
            parts += errors.compactMap { ($0 as? [String: Any])?["message"] as? String ?? $0 as? String }
        }

        return parts.joined(separator: "\n")
    }

    /// 速率限制解除的时间：GitHub 的 `x-ratelimit-reset` 与 GitLab 的 `RateLimit-Reset` 是秒级时间戳，`Retry-After` 是秒数。
    static func resetDate(_ response: HTTPURLResponse, now: Date = Date()) -> Date? {
        for header in ["x-ratelimit-reset", "RateLimit-Reset"] {
            if let seconds = response.value(forHTTPHeaderField: header).flatMap(TimeInterval.init) {
                return Date(timeIntervalSince1970: seconds)
            }
        }

        return response.value(forHTTPHeaderField: "Retry-After")
            .flatMap(TimeInterval.init)
            .map { now.addingTimeInterval($0) }
    }

    /// `Link` 头里 `rel="next"` 的页码；GitHub 与 GitLab 都用这种写法分页。
    static func nextPage(_ response: HTTPURLResponse) -> Int? {
        guard let link = response.value(forHTTPHeaderField: "Link") else {
            return nil
        }

        for part in link.split(separator: ",") where part.contains(#"rel="next""#) {
            guard
                let start = part.firstIndex(of: "<"),
                let end = part.firstIndex(of: ">"),
                start < end,
                let components = URLComponents(string: String(part[part.index(after: start) ..< end]))
            else {
                continue
            }

            return components.queryItems?.first { $0.name == "page" }?.value.flatMap(Int.init)
        }

        return nil
    }

    /// 解码失败的简短说明。
    private static func describe(_ error: any Error) -> String {
        guard let decoding = error as? DecodingError else {
            return String(describing: error)
        }

        switch decoding {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context),
             .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : path + ": " + context.debugDescription

        @unknown default:
            return String(describing: error)
        }
    }
}

// MARK: - GitHubUser

/// GitHub `GET /user` 里用到的字段。
private struct GitHubUser: Decodable, Sendable {
    /// 用户名。
    let login: String

    /// 显示名。
    let name: String?
}

// MARK: - GitLabUser

/// GitLab `GET /user` 里用到的字段。
private struct GitLabUser: Decodable, Sendable {
    /// 用户名。
    let username: String

    /// 显示名。
    let name: String?
}

// MARK: - GitLabVersion

/// GitLab `GET /version` 的结果。
private struct GitLabVersion: Decodable, Sendable {
    /// 版本号，如 `17.2.1-ee`。
    let version: String
}
