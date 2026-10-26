import Foundation
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - HostingClientTests

/// 托管服务 API：请求头与地址、令牌不进 URL、失败分类与原文、分页，以及 github.com 的设备授权。
///
/// 请求经 ``HostingStub`` 返回固定响应，不离开本机；处理函数是全局的，所以这组测试依次执行。
@Suite(.serialized)
struct HostingClientTests {
    /// github.com：令牌放在 Authorization 头里，固定 API 版本，地址里没有令牌。
    @Test("GitHub 的当前用户")
    func githubUser() async throws {
        let requests = HostingStub.respond { _ in (200, [:], Data(#"{"login":"rakuyo","name":"鸡翅"}"#.utf8)) }
        let client = HostingClient(instance: .github, token: "secret-token", session: HostingStub.session())

        let user = try await client.currentUser()
        #expect(user == HostingUser(username: "rakuyo", name: "鸡翅"))

        let request = try #require(requests.withLock { $0.first })
        #expect(request.url?.absoluteString == "https://api.github.com/user")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
        #expect(!(request.url?.absoluteString.contains("secret-token") ?? true))

        // 列表与详情随时在变，不能用缓存里的旧响应
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    /// 私有部署的 GitLab：先查版本再读用户，令牌放在 PRIVATE-TOKEN 头里，地址带端口与部署路径。
    @Test("GitLab 的版本与当前用户")
    func gitlabUser() async throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com:8443/gitlab"))
        let requests = HostingStub.respond { request in
            request.url?.path().hasSuffix("/version") ?? false
                ? (200, [:], Data(#"{"version":"17.2.1-ee","revision":"abc"}"#.utf8))
                : (200, [:], Data(#"{"username":"rakuyo","name":null}"#.utf8))
        }

        let user = try await HostingClient(instance: instance, token: "glpat", session: HostingStub.session()).currentUser()
        #expect(user == HostingUser(username: "rakuyo", name: nil))

        let urls = requests.withLock { $0.map { $0.url?.absoluteString ?? "" } }
        #expect(urls == ["https://git.example.com:8443/gitlab/api/v4/version", "https://git.example.com:8443/gitlab/api/v4/user"])
        #expect(requests.withLock { $0.allSatisfy { $0.value(forHTTPHeaderField: "PRIVATE-TOKEN") == "glpat" } })
    }

    /// 低于 15.7 的 GitLab 不兼容，不再读用户。
    @Test("GitLab 版本过低")
    func gitlabTooOld() async throws {
        let requests = HostingStub.respond { _ in (200, [:], Data(#"{"version":"15.6.9","revision":"abc"}"#.utf8)) }
        let client = HostingClient(instance: .gitlabCom, token: "glpat", session: HostingStub.session())

        await #expect(throws: HostingError.incompatible("GitLab 15.6.9")) { try await client.currentUser() }
        #expect(requests.withLock { $0.count } == 1)
    }

    /// 401、403、404、422 与 5xx 各自分类并保留原文；403 与 429 里的速率限制带上解除时间。
    @Test("失败分类")
    func classification() async throws {
        let cases: [(Int, [String: String], String, HostingError)] = [
            (401, [:], #"{"message":"Bad credentials"}"#, .unauthorized("Bad credentials")),
            (
                403,
                [:],
                #"{"message":"Resource not accessible by integration"}"#,
                .forbidden("Resource not accessible by integration")
            ),
            (
                403,
                ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1700000000"],
                #"{"message":"API rate limit exceeded"}"#,
                .rateLimited(reset: Date(timeIntervalSince1970: 1_700_000_000), message: "API rate limit exceeded")
            ),
            (
                429,
                ["RateLimit-Reset": "1700000100"],
                "Retry later",
                .rateLimited(reset: Date(timeIntervalSince1970: 1_700_000_100), message: "Retry later")
            ),
            (404, [:], #"{"message":"404 Project Not Found"}"#, .notFound("404 Project Not Found")),
            (
                422,
                [:],
                #"{"message":"Validation Failed","errors":[{"message":"A pull request already exists"}]}"#,
                .rejected(status: 422, message: "Validation Failed\nA pull request already exists")
            ),
            (405, [:], #"{"message":{"base":["is protected"]}}"#, .rejected(status: 405, message: #"{"base":["is protected"]}"#)),
            (502, [:], "<html>Bad Gateway</html>", .server(status: 502, message: "<html>Bad Gateway</html>")),
        ]

        for (status, headers, body, expected) in cases {
            _ = HostingStub.respond { _ in (status, headers, Data(body.utf8)) }
            let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())

            await #expect(throws: expected) { try await client.currentUser() }
        }
    }

    /// 网络失败分成连不上与证书不受信任两类；响应不是预期的格式算不兼容。
    @Test("网络失败与不兼容的响应")
    func transport() async throws {
        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())

        _ = HostingStub.respond { _ in throw URLError(.cannotFindHost) }
        let unreachable = await #expect(throws: HostingError.self) { try await client.currentUser() }
        #expect({ if case .unreachable = unreachable { true } else { false } }())

        _ = HostingStub.respond { _ in throw URLError(.serverCertificateUntrusted) }
        let certificate = await #expect(throws: HostingError.self) { try await client.currentUser() }
        #expect({ if case .untrustedCertificate = certificate { true } else { false } }())

        // TLS 握手失败不一定是证书问题，可能是代理或网络
        _ = HostingStub.respond { _ in throw URLError(.secureConnectionFailed) }
        let handshake = await #expect(throws: HostingError.self) { try await client.currentUser() }
        #expect({ if case .unreachable = handshake { true } else { false } }())

        _ = HostingStub.respond { _ in (200, [:], Data(#"{"id":1}"#.utf8)) }
        let incompatible = await #expect(throws: HostingError.self) { try await client.currentUser() }
        #expect({ if case .incompatible(let text) = incompatible { text.contains("login") } else { false } }())
    }

    /// `Link` 头里 `rel="next"` 的页码；没有下一页时为 nil。
    @Test("分页")
    func pagination() throws {
        let url = try #require(URL(string: "https://api.github.com/x"))
        let link = #"<https://api.github.com/x?page=1>; rel="prev", <https://api.github.com/x?per_page=50&page=3>; rel="next""#
        let next = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Link": link]))
        let last = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:]))

        #expect(HostingClient.nextPage(next) == 3)
        #expect(HostingClient.nextPage(last) == nil)
        #expect(HostingClient.encodedSegment("group/子 组+x") == "group%2F%E5%AD%90%20%E7%BB%84%2Bx")
        #expect(HostingClient.date(from: "2026-10-25T12:00:00.123Z") != nil)
        #expect(HostingClient.date(from: "2026-10-25T12:00:00Z") != nil)
    }

    /// 设备授权：申请验证码后按间隔轮询，等待中与放慢时继续，拿到令牌即返回；表单里带 Client ID。
    @Test("设备授权")
    func deviceFlow() async throws {
        let replies = Mutex([
            #"{"error":"authorization_pending"}"#,
            #"{"error":"slow_down","interval":10}"#,
            #"{"access_token":"gho_token","token_type":"bearer","scope":"repo,read:org"}"#,
        ])
        let requests = HostingStub.respond { request in
            guard request.url?.path() != "/login/device/code" else {
                let code =
                    #"{"device_code":"dc","user_code":"WDJB-MJHT","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#
                return (200, [:], Data(code.utf8))
            }

            return (200, [:], Data(replies.withLock { $0.removeFirst() }.utf8))
        }

        let waits = Mutex<[Duration]>([])
        let flow = GitHubDeviceFlow(clientID: "Ov23liMkZicKtgDk5XnB", session: HostingStub.session()) { duration in
            waits.withLock { $0.append(duration) }
        }

        let authorization = try await flow.start()
        #expect(authorization.userCode == "WDJB-MJHT")
        #expect(authorization.verificationURL.absoluteString == "https://github.com/login/device")

        let token = try await flow.token(for: authorization)
        #expect(token == "gho_token")
        #expect(waits.withLock { $0 } == [.seconds(5), .seconds(5), .seconds(10)])

        let form = String(decoding: HostingStub.body(of: try #require(requests.withLock { $0.first })), as: UTF8.self)
        #expect(form == "client_id=Ov23liMkZicKtgDk5XnB&scope=repo%20read%3Aorg")
    }

    /// 用户拒绝或验证码过期时停止轮询并报出原因。
    @Test("设备授权被拒绝或过期")
    func deviceFlowEnds() async throws {
        let flow = GitHubDeviceFlow(clientID: "id", session: HostingStub.session()) { _ in }
        let authorization = GitHubDeviceFlow.Authorization(
            deviceCode: "dc",
            userCode: "CODE",
            verificationURL: HostingInstance.github.webURL.appending(path: "login/device"),
            interval: 5,
            expiresAt: Date().addingTimeInterval(900)
        )

        _ = HostingStub.respond { _ in (200, [:], Data(#"{"error":"access_denied"}"#.utf8)) }
        await #expect(throws: HostingError.authorizationDenied) { try await flow.token(for: authorization) }

        _ = HostingStub.respond { _ in (200, [:], Data(#"{"error":"expired_token"}"#.utf8)) }
        await #expect(throws: HostingError.authorizationExpired) { try await flow.token(for: authorization) }
    }
}

// MARK: - HostingStub

/// 返回固定响应的 URL 协议：请求交给测试给出的处理函数，不离开本机。
final class HostingStub: URLProtocol {
    /// 处理函数：收到请求，返回状态码、响应头与响应体，或抛出网络错误。
    typealias Handler = @Sendable (URLRequest) throws -> (Int, [String: String], Data)

    /// 读取 ``HostingStub`` 收到的请求。
    struct RequestLog: Sendable {
        /// 在锁里读取收到的请求。
        func withLock<Result>(_ body: ([URLRequest]) -> Result) -> Result {
            HostingStub.requests.withLock { body($0) }
        }
    }

    /// 当前测试的处理函数。
    private static let handler = Mutex<Handler?>(nil)

    /// 收到的请求，按顺序记录。
    private static let requests = Mutex<[URLRequest]>([])

    /// 换上处理函数并清空记录，返回之后收到的请求。
    @discardableResult
    static func respond(_ handler: @escaping Handler) -> RequestLog {
        self.handler.withLock { $0 = handler }
        requests.withLock { $0 = [] }
        return RequestLog()
    }

    /// 只经这个协议发请求的会话。
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HostingStub.self]
        return URLSession(configuration: configuration)
    }

    /// 请求体：经会话发出的请求把它放在流里。
    static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)

            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }

    /// 接管所有请求。
    override class func canInit(with _: URLRequest) -> Bool { true }

    /// 请求原样使用。
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// 交给处理函数并把结果返回给会话。
    override func startLoading() {
        Self.requests.withLock { $0.append(request) }

        do {
            guard let handler = Self.handler.withLock({ $0 }), let url = request.url else {
                throw URLError(.unknown)
            }

            let (status, headers, data) = try handler(request)

            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
            else {
                throw URLError(.badServerResponse)
            }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    /// 没有需要停止的工作。
    override func stopLoading() { }
}
