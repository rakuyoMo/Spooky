import Foundation
import Synchronization
import Testing

@testable import SpookyKit

// MARK: - GitLab Password

/// 私有部署 GitLab 的用户名与密码登录：换令牌与续期的请求、到期时间、三种授权错误码，以及失败不重试；
/// 与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// 换令牌发到带端口与部署路径的 `oauth/token`：表单字段齐全、不带 `client_id`，密码不在地址里；响应解析出三项。
    @Test("用密码换令牌")
    func passwordGrant() async throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com:8443/gitlab"))
        let reply =
            #"{"access_token":"at","token_type":"Bearer","expires_in":7200,"refresh_token":"rt","scope":"api","created_at":1}"#
        let requests = HostingStub.respond { _ in (200, [:], Data(reply.utf8)) }

        let before = Date()
        let token = try await GitLabPasswordGrant(instance: instance, session: HostingStub.session())
            .token(username: "rakuyo", password: "p@ss word")
        let after = Date()

        #expect(token.accessToken == "at")
        #expect(token.refreshToken == "rt")

        // 到期时间按收到响应时的本机时间推算，不用服务端的 created_at
        let expiresAt = try #require(token.expiresAt)
        #expect(expiresAt >= before.addingTimeInterval(7200) && expiresAt <= after.addingTimeInterval(7200))

        let request = try #require(requests.withLock { $0.first })
        let url = try #require(request.url?.absoluteString)
        #expect(url == "https://git.example.com:8443/gitlab/oauth/token")
        #expect(!url.contains("p%40ss") && !url.contains("p@ss"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        let form = String(decoding: HostingStub.body(of: request), as: UTF8.self)
        #expect(form == "grant_type=password&password=p%40ss%20word&scope=api&username=rakuyo")
        #expect(requests.withLock { $0.count } == 1)
    }

    /// 续期用刷新令牌；响应没有 `expires_in` 时当作不过期，不再续期。
    @Test("用刷新令牌续期")
    func refreshGrant() async throws {
        let instance = try #require(HostingInstance.gitlab(address: "http://10.0.0.5:8080"))
        let requests = HostingStub.respond { _ in (200, [:], Data(#"{"access_token":"at2","refresh_token":"rt2"}"#.utf8)) }

        let token = try await GitLabPasswordGrant(instance: instance, session: HostingStub.session()).refresh("rt")
        #expect(token == GitLabOAuthToken(accessToken: "at2", refreshToken: "rt2", expiresAt: nil))
        #expect(!token.needsRefresh())

        let request = try #require(requests.withLock { $0.first })
        #expect(request.url?.absoluteString == "http://10.0.0.5:8080/oauth/token")
        #expect(String(decoding: HostingStub.body(of: request), as: UTF8.self) == "grant_type=refresh_token&refresh_token=rt")
    }

    /// 距到期不到 60 秒才续期；没有刷新令牌或没有到期时间时不续期。
    @Test("何时续期")
    func refreshTiming() {
        let now = Date()

        #expect(
            GitLabOAuthToken(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(59))
                .needsRefresh(at: now)
        )
        #expect(
            GitLabOAuthToken(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(-1))
                .needsRefresh(at: now)
        )
        #expect(
            !GitLabOAuthToken(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(61))
                .needsRefresh(at: now)
        )
        #expect(!GitLabOAuthToken(accessToken: "a", refreshToken: nil, expiresAt: now).needsRefresh(at: now))
        #expect(!GitLabOAuthToken(accessToken: "a", refreshToken: "r", expiresAt: nil).needsRefresh(at: now))
    }

    /// 三种授权错误码各自分类并带服务端说明；续期时的 `invalid_grant` 是令牌被拒；每次都只发一次请求。
    @Test("授权错误码")
    func passwordGrantErrors() async throws {
        let grant = GitLabPasswordGrant(instance: .gitlabCom, session: HostingStub.session())

        let cases: [(Int, String, HostingError)] = [
            (400, "invalid_grant", .passwordRejected("The provided authorization grant is invalid.")),
            (401, "invalid_client", .clientCredentialsRequired("The provided authorization grant is invalid.")),
            (400, "unsupported_grant_type", .passwordGrantUnsupported("The provided authorization grant is invalid.")),
            (
                400,
                "invalid_scope",
                .rejected(status: 400, message: "invalid_scope\nThe provided authorization grant is invalid.")
            ),
        ]

        for (status, code, expected) in cases {
            let body = #"{"error":"\#(code)","error_description":"The provided authorization grant is invalid."}"#
            let requests = HostingStub.respond { _ in (status, [:], Data(body.utf8)) }

            await #expect(throws: expected) { try await grant.token(username: "u", password: "p") }
            #expect(requests.withLock { $0.count } == 1, "\(code)")
        }

        _ = HostingStub.respond { _ in (400, [:], Data(#"{"error":"invalid_grant","error_description":"expired"}"#.utf8)) }
        await #expect(throws: HostingError.unauthorized("expired")) { try await grant.refresh("rt") }
    }

    /// 网络失败与 5xx 照常分类，不自动重试，以免累计的登录失败把账号锁住。
    @Test("换令牌失败不重试")
    func passwordGrantNoRetry() async throws {
        let grant = GitLabPasswordGrant(instance: .gitlabCom, session: HostingStub.session())

        let offline = HostingStub.respond { _ in throw URLError(.timedOut) }
        let unreachable = await #expect(throws: HostingError.self) { try await grant.token(username: "u", password: "p") }
        #expect({ if case .unreachable = unreachable { true } else { false } }())
        #expect(offline.withLock { $0.count } == 1)

        let failing = HostingStub.respond { _ in (502, [:], Data("Bad Gateway".utf8)) }
        await #expect(throws: HostingError.server(status: 502, message: "Bad Gateway")) {
            try await grant.token(username: "u", password: "p")
        }
        #expect(failing.withLock { $0.count } == 1)
    }

    /// 用户名与密码登录的账号用 `Authorization: Bearer` 头，不发 `PRIVATE-TOKEN`；令牌每次请求前取一次。
    @Test("OAuth 令牌的请求头")
    func passwordBearer() async throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))
        let requests = HostingStub.respond { _ in (200, [:], Data(#"{"username":"rakuyo","name":null}"#.utf8)) }
        let calls = Mutex(0)

        let client = HostingClient(instance: instance, authentication: .password, session: HostingStub.session()) {
            calls.withLock { $0 += 1 }
            return "oauth-token"
        }

        _ = try await client.currentUser()
        _ = try await client.currentUser()

        let request = try #require(requests.withLock { $0.first })
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer oauth-token")
        #expect(request.value(forHTTPHeaderField: "PRIVATE-TOKEN") == nil)
        #expect(calls.withLock { $0 } == 2)
    }
}
