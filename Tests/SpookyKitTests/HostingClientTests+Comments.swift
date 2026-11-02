import Foundation
import Testing

@testable import SpookyKit

// MARK: - Comments

/// 讨论里的写操作：修改与删除评论、回复评论、只改描述；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub：评论按 issue comment 的编号修改与删除，描述只发 `body`，不带标题与目标分支。
    @Test("GitHub 修改与删除评论、修改描述")
    func githubCommentWrites() async throws {
        let requests = HostingStub.respond { request in
            request.httpMethod == "DELETE" ? (204, [:], Data()) : (200, [:], Data("{}".utf8))
        }

        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .github, project: "o/r", number: 7)

        try await client.editComment(5, body: "改过的 **内容**", on: id)
        try await client.deleteComment(5, on: id)
        try await client.updateDescription("新的描述", of: id)

        let sent = requests.withLock { $0 }
        #expect(sent.map { $0.httpMethod ?? "" } == ["PATCH", "DELETE", "PATCH"])

        #expect(
            sent.map { $0.url?.absoluteString ?? "" } == [
                "https://api.github.com/repos/o/r/issues/comments/5",
                "https://api.github.com/repos/o/r/issues/comments/5",
                "https://api.github.com/repos/o/r/pulls/7",
            ]
        )

        #expect(try Self.payload(of: sent[0]) == ["body": "改过的 **内容**"])
        #expect(HostingStub.body(of: sent[1]).isEmpty)
        #expect(try Self.payload(of: sent[2]) == ["body": "新的描述"])
    }

    /// GitLab：评论是 Merge Request 下的 note，描述只发 `description`；删除回 204 没有响应体。
    @Test("GitLab 修改与删除评论、修改描述")
    func gitlabCommentWrites() async throws {
        let requests = HostingStub.respond { request in
            request.httpMethod == "DELETE" ? (204, [:], Data()) : (200, [:], Data("{}".utf8))
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .gitlabCom, project: "group/sub/project", number: 3)

        try await client.editComment(9, body: "改过", on: id)
        try await client.deleteComment(9, on: id)
        try await client.updateDescription("", of: id)

        let sent = requests.withLock { $0 }
        #expect(sent.map { $0.httpMethod ?? "" } == ["PUT", "DELETE", "PUT"])

        let project = "https://gitlab.com/api/v4/projects/group%2Fsub%2Fproject/merge_requests/3"
        #expect(sent.map { $0.url?.absoluteString ?? "" } == [project + "/notes/9", project + "/notes/9", project])

        #expect(try Self.payload(of: sent[0]) == ["body": "改过"])

        // 清空描述同样只发描述一项
        #expect(try Self.payload(of: sent[2]) == ["description": ""])
    }

    /// GitLab 的回复：逐页读讨论，在含这条评论的讨论里加一条；找不到时报不存在，不发回复。
    @Test("GitLab 回复评论时跨页找到所在的讨论")
    func gitlabReply() async throws {
        let first = #"[{"id":"aaa111","individual_note":true,"notes":[{"id":1}]}]"#
        let second = #"[{"id":"bbb222","individual_note":false,"notes":[{"id":2},{"id":3}]}]"#
        let next = #"<https://gitlab.com/api/v4/projects/group%2Fproject/merge_requests/3/discussions?page=2>; rel="next""#

        let requests = HostingStub.respond { request in
            guard request.httpMethod == "GET" else {
                return (201, [:], Data("{}".utf8))
            }

            return request.url?.query()?.contains("page=2") ?? false
                ? (200, [:], Data(second.utf8))
                : (200, ["Link": next], Data(first.utf8))
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .gitlabCom, project: "group/project", number: 3)

        try await client.replyToComment(3, body: "回复", on: id)

        let sent = requests.withLock { $0 }
        let project = "https://gitlab.com/api/v4/projects/group%2Fproject/merge_requests/3"

        #expect(
            sent.map { $0.url?.absoluteString ?? "" } == [
                project + "/discussions?per_page=100&page=1",
                project + "/discussions?per_page=100&page=2",
                project + "/discussions/bbb222/notes",
            ]
        )
        #expect(sent.last?.httpMethod == "POST")
        #expect(try Self.payload(of: try #require(sent.last)) == ["body": "回复"])

        // 评论已被删除：读完所有讨论都没有它
        let missing = HostingStub.respond { _ in (200, [:], Data(first.utf8)) }

        await #expect(throws: HostingError.notFound("")) {
            try await client.replyToComment(42, body: "回复", on: id)
        }

        #expect(missing.withLock { $0.allSatisfy { $0.httpMethod == "GET" } })
    }

    /// GitHub 的 Pull Request 评论不能回复：不发请求就失败。
    @Test("GitHub 不支持回复评论")
    func githubReplyUnsupported() async throws {
        let requests = HostingStub.respond { _ in (200, [:], Data("{}".utf8)) }
        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .github, project: "o/r", number: 7)

        #expect(!HostingService.github.supportsCommentReplies)
        #expect(HostingService.gitlab.supportsCommentReplies)

        await #expect(throws: HostingError.self) {
            try await client.replyToComment(5, body: "回复", on: id)
        }

        #expect(requests.withLock { $0.isEmpty })
    }
}

// MARK: - Helpers

extension HostingClientTests {
    /// 请求体里的 JSON 对象，值都是文字。
    fileprivate static func payload(of request: URLRequest) throws -> [String: String]? {
        try JSONSerialization.jsonObject(with: HostingStub.body(of: request)) as? [String: String]
    }
}
