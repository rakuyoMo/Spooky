import Foundation
import Synchronization
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Pull Request Fixture

extension ChangesetFixture {
    /// 通过真实托管解码与详情加载入口安装请求，网络传输只接受本测试的独立域名。
    func loadRequest(needsFetch: Bool = false) async throws {
        let host = UUID().uuidString.lowercased() + ".spooky-changeset.invalid"
        let instance = try #require(HostingInstance.gitlab(address: "https://" + host))
        let source = needsFetch ? String(repeating: "e", count: 40) : commits[2].id
        ChangesetRequestProtocol.install(host: host, base: commits[0].id, source: source)
        defer { ChangesetRequestProtocol.remove(host: host) }

        let accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())
        try accounts.save(
            HostingUser(username: "test", name: nil),
            on: instance,
            authentication: .personalAccessToken,
            token: "test-token"
        )
        session.pullRequests.close()
        session.pullRequests.accounts = accounts
        _ = try await runner.run(["config", "--local", "remote.origin.url", "https://" + host + "/group/project.git"])
        session.pullRequests.load(runner: runner)
        try await FileViewsTests.wait { self.session.pullRequests.isLoaded }
        #expect(session.pullRequests.failure == nil)
        let request = try #require(session.pullRequests.items.first)
        session.pullRequests.select(request.id, runner: runner)
        try await FileViewsTests.wait { !self.session.pullRequests.isLoadingDetail }
        #expect(session.pullRequests.detailFailure == nil)
        #expect(session.pullRequests.detail != nil)
        session.pullRequests.page = .changeset
        session.pullRequests.comparison.showsChangeset = true
        try await waitForChanges()
    }
}

// MARK: - ChangesetRequestProtocol

/// 只拦截独立测试域名，模拟请求列表、详情与评论；不访问真实托管服务。
/// 父类要求重申 Sendable；共享响应由 Mutex 保护，实例没有可变字段。

// swiftlint:disable:next no_unchecked_sendable
private final class ChangesetRequestProtocol: URLProtocol, @unchecked Sendable {
    /// 每个测试域名独立保存响应，支持测试并行执行。
    private static let responses = Mutex<[String: Data]>([:])

    /// 安装固定的 GitLab 请求详情，提交哈希来自本轮临时仓库。
    static func install(host: String, base: String, source: String) {
        let json = """
            {"iid":1,"title":"Changeset","state":"opened","source_branch":"topic","target_branch":"main",
            "source_project_id":1,"target_project_id":1,"created_at":"2023-11-14T00:00:00Z",
            "updated_at":"2023-11-14T00:00:00Z","sha":"\(source)",
            "diff_refs":{"base_sha":"\(base)","start_sha":"\(base)","head_sha":"\(source)"}}
            """
        responses.withLock { $0[host] = Data(json.utf8) }
        URLProtocol.registerClass(Self.self)
    }

    /// 释放已经读完的本测试响应。
    static func remove(host: String) {
        _ = responses.withLock { $0.removeValue(forKey: host) }
    }

    /// 只认测试域名，避免干扰其它测试的 URLSession。
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".spooky-changeset.invalid") ?? false
    }

    /// 保留请求路径，按列表、详情与评论区分响应。
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// 同步送回本测试响应，释放后仍有请求视为失败而不是联网。
    override func startLoading() {
        guard
            let url = request.url,
            let host = url.host,
            let detail = Self.responses.withLock({ $0[host] }),
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        let data: Data =
            if url.path.hasSuffix("/notes") {
                Data("[]".utf8)
            } else if url.path.hasSuffix("/merge_requests") {
                Data("[".utf8) + detail + Data("]".utf8)
            } else {
                detail
            }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    /// 响应同步完成，没有挂起的网络任务。
    override func stopLoading() { }
}
