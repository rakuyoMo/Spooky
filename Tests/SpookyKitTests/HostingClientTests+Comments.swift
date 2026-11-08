import Foundation
import Testing

@testable import SpookyKit

// MARK: - Comments

/// 讨论：评论的作者、更新时间与顺序，修改与删除评论、回复评论、只改描述；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub：评论的作者带上头像地址，用户对象没有名字，评论带上更新时间；评论按 issue comment 的编号修改与删除，
    /// 描述只发 `body`，不带标题与目标分支；Pull Request 评论不能回复，不发请求就失败。
    @Test("GitHub 的评论：作者与更新时间、修改与删除、修改描述、不支持回复")
    func githubComments() async throws {
        let github = """
            [{"id":1,"body":"看过了","user":{"login":"bob","avatar_url":"https://avatars.githubusercontent.com/u/2?v=4"},
              "created_at":"2026-10-03T00:00:00Z","updated_at":"2026-10-04T00:00:00Z"},
             {"id":2,"body":null,"user":null,"created_at":"2026-10-05T00:00:00Z","updated_at":"2026-10-05T00:00:00Z"}]
            """

        HostingStub.respond { _ in (200, [:], Data(github.utf8)) }

        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .github, project: "o/r", number: 7)
        let comments = try await client.comments(on: id)

        // 用户已删除时作者是空的用户名，内容为 null 时是空字符串
        #expect(
            comments.map(\.author) == [
                HostingUser(
                    username: "bob",
                    name: nil,
                    avatarURL: URL(string: "https://avatars.githubusercontent.com/u/2?v=4")
                ),
                HostingUser(username: "", name: nil),
            ]
        )

        #expect(comments.map(\.updatedAt) == [Self.date("2026-10-04T00:00:00Z"), Self.date("2026-10-05T00:00:00Z")])
        #expect(comments.last.map(\.body.isEmpty) ?? false)

        // 修改与删除评论、修改描述
        let requests = HostingStub.respond { request in
            request.httpMethod == "DELETE" ? (204, [:], Data()) : (200, [:], Data("{}".utf8))
        }

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

        // 不支持回复
        let replies = HostingStub.respond { _ in (200, [:], Data("{}".utf8)) }

        #expect(!HostingService.github.supportsCommentReplies)
        #expect(HostingService.gitlab.supportsCommentReplies)

        await #expect(throws: HostingError.self) {
            try await client.replyToComment(5, body: "回复", on: id)
        }

        #expect(replies.withLock { $0.isEmpty })
    }

    /// GitLab：评论的作者带上名字与头像地址，旧版没有给出更新时间时为 nil，推送了新提交这类系统记录不列出；
    /// 10.3 以前不认 `sort` 与 `order_by`：读完全部页后按发表时间排，时间相同的按编号，请求里仍带着这两个参数。
    @Test("GitLab 的评论：作者与更新时间、系统记录与旧版的顺序")
    func gitlabComments() async throws {
        let gitlab = """
            [{"id":3,"body":"改过","author":{"username":"carol","name":"Carol 李","avatar_url":"https://git.example.com/uploads/c.png"},
              "created_at":"2026-10-03T00:00:00.000Z","updated_at":"2026-10-06T00:00:00.000Z","system":false},
             {"id":4,"body":"旧版","author":{"username":"dave","name":"Dave","avatar_url":null},
              "created_at":"2026-10-04T00:00:00.000Z"},
             {"id":5,"body":"added 1 commit","author":{"username":"alice"},"created_at":"2026-10-05T00:00:00.000Z","system":true}]
            """

        HostingStub.respond { _ in (200, [:], Data(gitlab.utf8)) }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: .gitlabCom, project: "group/project", number: 3)
        let notes = try await client.comments(on: id)

        #expect(
            notes.map(\.author) == [
                HostingUser(
                    username: "carol",
                    name: "Carol 李",
                    avatarURL: URL(string: "https://git.example.com/uploads/c.png")
                ),
                HostingUser(username: "dave", name: "Dave"),
            ]
        )

        #expect(notes.map(\.updatedAt) == [Self.date("2026-10-06T00:00:00Z"), nil])

        // 旧版不按发表时间排序，跨两页
        let first = #"[{"id":5,"body":"c","created_at":"2026-10-03T00:00:00Z"},"#
            + #"{"id":2,"body":"a","created_at":"2026-10-01T00:00:00Z"}]"#

        let second = #"[{"id":4,"body":"b","created_at":"2026-10-02T00:00:00Z"},"#
            + #"{"id":3,"body":"b","created_at":"2026-10-02T00:00:00Z"}]"#

        let link = #"<https://gitlab.com/api/v4/projects/1/merge_requests/3/notes?page=2>; rel="next""#

        let requests = HostingStub.respond { request in
            request.url?.query()?.contains("page=2") ?? false
                ? (200, [:], Data(second.utf8))
                : (200, ["Link": link], Data(first.utf8))
        }

        #expect(try await client.comments(on: id).map(\.id) == [2, 3, 4, 5])
        #expect(
            requests.withLock { sent in
                sent.allSatisfy { $0.url?.query()?.contains("sort=asc&order_by=created_at") ?? false }
            }
        )
    }

    /// GitLab：评论是 Merge Request 下的 note，描述只发 `description`，删除回 204 没有响应体；
    /// 回复时逐页读讨论，在含这条评论的讨论里加一条，找不到时报不存在，不发回复。
    @Test("GitLab 修改与删除评论、修改描述，跨页找到所在的讨论回复")
    func gitlabCommentWrites() async throws {
        let requests = HostingStub.respond { request in
            request.httpMethod == "DELETE" ? (204, [:], Data()) : (200, [:], Data("{}".utf8))
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let nested = PullRequestID(instance: .gitlabCom, project: "group/sub/project", number: 3)

        try await client.editComment(9, body: "改过", on: nested)
        try await client.deleteComment(9, on: nested)
        try await client.updateDescription("", of: nested)

        let sent = requests.withLock { $0 }
        let request = "https://gitlab.com/api/v4/projects/group%2Fsub%2Fproject/merge_requests/3"

        #expect(sent.map { $0.httpMethod ?? "" } == ["PUT", "DELETE", "PUT"])
        #expect(sent.map { $0.url?.absoluteString ?? "" } == [request + "/notes/9", request + "/notes/9", request])
        #expect(try Self.payload(of: sent[0]) == ["body": "改过"])

        // 清空描述同样只发描述一项
        #expect(try Self.payload(of: sent[2]) == ["description": ""])

        // 回复：所在的讨论在第二页
        let first = #"[{"id":"aaa111","individual_note":true,"notes":[{"id":1}]}]"#
        let second = #"[{"id":"bbb222","individual_note":false,"notes":[{"id":2},{"id":3}]}]"#
        let next = #"<https://gitlab.com/api/v4/projects/group%2Fproject/merge_requests/3/discussions?page=2>;"#
            + #" rel="next""#

        let replies = HostingStub.respond { request in
            guard request.httpMethod == "GET" else {
                return (201, [:], Data("{}".utf8))
            }

            return request.url?.query()?.contains("page=2") ?? false
                ? (200, [:], Data(second.utf8))
                : (200, ["Link": next], Data(first.utf8))
        }

        let id = PullRequestID(instance: .gitlabCom, project: "group/project", number: 3)

        try await client.replyToComment(3, body: "回复", on: id)

        let replied = replies.withLock { $0 }
        let project = "https://gitlab.com/api/v4/projects/group%2Fproject/merge_requests/3"

        #expect(
            replied.map { $0.url?.absoluteString ?? "" } == [
                project + "/discussions?per_page=100&page=1",
                project + "/discussions?per_page=100&page=2",
                project + "/discussions/bbb222/notes",
            ]
        )

        #expect(replied.last?.httpMethod == "POST")
        #expect(try Self.payload(of: try #require(replied.last)) == ["body": "回复"])

        // 评论已被删除：读完所有讨论都没有它
        let missing = HostingStub.respond { _ in (200, [:], Data(first.utf8)) }

        await #expect(throws: HostingError.notFound("")) {
            try await client.replyToComment(42, body: "回复", on: id)
        }

        #expect(missing.withLock { $0.allSatisfy { $0.httpMethod == "GET" } })
    }
}

// MARK: - Helpers

extension HostingClientTests {
    /// 请求体里的 JSON 对象，值都是文字。
    fileprivate static func payload(of request: URLRequest) throws -> [String: String]? {
        try JSONSerialization.jsonObject(with: HostingStub.body(of: request)) as? [String: String]
    }

    /// ISO 8601 写法的时刻。
    fileprivate static func date(_ text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
