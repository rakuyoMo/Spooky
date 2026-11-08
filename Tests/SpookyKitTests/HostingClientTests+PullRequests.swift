import Foundation
import Testing

@testable import SpookyKit

// MARK: - Pull Requests

/// Pull Request 与 Merge Request：列表与 Fork、新建、合并选项与合并的请求和解析；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub 列表：Fork 的源仓库与目标仓库不同，已合并的按 merged_at 认出，下一页取 Link 头里 `rel="next"` 的页码；
    /// 从 Fork 新建时 head 写成 `owner:branch`，请求发到目标仓库。
    @Test("GitHub 的 Pull Request 列表与从 Fork 新建")
    func githubList() async throws {
        let body = """
            [{"number":7,"title":"修复","body":null,"state":"open","draft":true,
              "user":{"login":"alice","avatar_url":"https://avatars.githubusercontent.com/u/1?v=4"},
              "created_at":"2026-10-01T00:00:00Z","updated_at":"2026-10-02T00:00:00Z","merged_at":null,
              "html_url":"https://github.com/o/r/pull/7","assignees":[{"login":"bob"}],
              "head":{"ref":"fix/登录","sha":"aaa","repo":{"full_name":"alice/r"}},
              "base":{"ref":"main","sha":"bbb","repo":{"full_name":"o/r"}}}]
            """

        let link = #"<https://api.github.com/repos/o/r/pulls?page=1>; rel="prev", "#
            + #"<https://api.github.com/repos/o/r/pulls?per_page=50&page=3>; rel="next""#

        let requests = HostingStub.respond { _ in (200, ["Link": link], Data(body.utf8)) }
        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())

        let (items, next) = try await client.pullRequests(in: "o/r")
        let request = try #require(items.first)

        #expect(next == 3)
        #expect(request.id == PullRequestID(instance: .github, project: "o/r", number: 7))
        #expect(request.id.reference == "#7")
        #expect(request.isDraft && request.isFromFork && request.state == .open)
        #expect(request.source == PullRequestBranch(project: "alice/r", branch: "fix/登录", sha: "aaa"))
        #expect(request.assignees.map(\.username) == ["bob"] && request.body.isEmpty)

        #expect(
            request.author
                == HostingUser(
                    username: "alice",
                    name: nil,
                    avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1?v=4")
                )
        )

        #expect(request.webURL?.absoluteString == "https://github.com/o/r/pull/7")

        let url = try #require(requests.withLock { $0.first?.url?.absoluteString })

        #expect(url == "https://api.github.com/repos/o/r/pulls?state=open&per_page=50&page=1")

        // 从 Fork 新建
        let created = HostingStub.respond { _ in
            (201, [:], Data(Self.githubDetail(mergeable: "null", state: "unknown").utf8))
        }

        let draft = PullRequestDraft(
            sourceProject: "alice/r",
            sourceBranch: "feature/x",
            targetProject: "o/r",
            targetBranch: "main",
            title: "标题",
            body: "描述"
        )

        _ = try await client.createPullRequest(draft)

        let sent = try #require(created.withLock { $0.first })
        let payload = try JSONSerialization.jsonObject(with: HostingStub.body(of: sent)) as? [String: String]

        #expect(sent.url?.absoluteString == "https://api.github.com/repos/o/r/pulls")
        #expect(payload == ["title": "标题", "body": "描述", "head": "alice:feature/x", "base": "main"])
    }

    /// GitHub 合并选项：按 Merge、Rebase、Squash 的顺序列出，仓库不允许的方式不列出，没有写权限或有冲突时说明原因；
    /// 合并带上源分支提交，再删除同仓库的源分支。
    @Test("GitHub 的合并选项与合并")
    func githubMerge() async throws {
        let request = Self.githubRequest(fork: false)

        HostingStub.respond { request in
            request.url?.path() == "/repos/o/r"
                ? (
                    200,
                    [:],
                    Data(
                        #"{"allow_rebase_merge":false,"delete_branch_on_merge":true,"permissions":{"push":true}}"#
                            .utf8
                    )
                )
                : (200, [:], Data(Self.githubDetail(mergeable: "false", state: "dirty").utf8))
        }

        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let options = try await client.mergeOptions(for: request)

        #expect(options.methods == [.merge, .squash])
        #expect(options.deletesSourceBranchByDefault && options.canDeleteSourceBranch)
        #expect(options.block == .conflicts)

        HostingStub.respond { request in
            request.url?.path() == "/repos/o/r"
                ? (200, [:], Data(#"{"permissions":{"push":false}}"#.utf8))
                : (200, [:], Data(Self.githubDetail(mergeable: "true", state: "clean").utf8))
        }

        // 仓库没有给出设置时三种方式都列出
        let readOnly = try await client.mergeOptions(for: request)

        #expect(readOnly.methods == [.merge, .rebase, .squash])
        #expect(readOnly.block == .permission)

        let requests = HostingStub.respond { request in
            request.httpMethod == "PUT"
                ? (200, [:], Data(#"{"sha":"ccc","merged":true,"message":"Pull Request successfully merged"}"#.utf8))
                : (204, [:], Data())
        }

        let result = try await client.merge(request, method: .squash, deletesSourceBranch: true)

        #expect(result == PullRequestMergeResult(sha: "ccc", message: "Pull Request successfully merged"))

        let sent = requests.withLock { $0 }

        #expect(sent.map { $0.httpMethod ?? "" } == ["PUT", "DELETE"])
        #expect(sent.last?.url?.absoluteString == "https://api.github.com/repos/o/r/git/refs/heads/feature/x")

        let merge = try JSONSerialization.jsonObject(with: HostingStub.body(of: try #require(sent.first)))
            as? [String: String]

        #expect(merge == ["merge_method": "squash", "sha": "aaa"])
    }

    /// GitLab 列表：多层命名空间的项目路径整体转义，同一个 Fork 的源项目路径只读一次；旧版的单个 `assignee` 当作指派人，
    /// 带上名字与头像地址，`reopened` 当作打开，没有 `diff_refs` 时没有目标分支提交与合并基准。
    @Test("GitLab 的 Merge Request 列表与旧版的请求字段")
    func gitlabList() async throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://git.example.com/gitlab"))

        let requests = HostingStub.respond { request in
            guard request.url?.path().hasSuffix("/projects/42") ?? false else {
                return (
                    200,
                    [:],
                    Data("[\(Self.gitlabRequest(iid: 3, source: 42)),\(Self.gitlabRequest(iid: 4, source: 42))]".utf8)
                )
            }

            return (200, [:], Data(#"{"id":42,"path_with_namespace":"alice/项目"}"#.utf8))
        }

        let client = HostingClient(instance: instance, token: "t", session: HostingStub.session())
        let (items, next) = try await client.pullRequests(in: "group/子组/项目")

        #expect(next == nil)
        #expect(items.map(\.id.reference) == ["!3", "!4"])
        #expect(items.first?.webURL?.absoluteString == "https://gitlab.com/group/project/-/merge_requests/3")
        #expect(items.first?.mergeBase == "mmm" && items.first?.target.sha == "bbb")

        #expect(
            items.allSatisfy {
                $0.source.project == "alice/项目" && $0.target.project == "group/子组/项目" && $0.isFromFork
            }
        )

        let urls = requests.withLock { $0.map { $0.url?.absoluteString ?? "" } }
        let encoded = "group%2F%E5%AD%90%E7%BB%84%2F%E9%A1%B9%E7%9B%AE"

        #expect(urls.count == 2)
        #expect(
            urls.first?.hasPrefix("https://git.example.com/gitlab/api/v4/projects/\(encoded)/merge_requests?")
                ?? false
        )
        #expect(urls.last == "https://git.example.com/gitlab/api/v4/projects/42")

        // 路径里的空格与 “+” 同样转义
        #expect(HostingClient.encodedSegment("group/子 组+x") == "group%2F%E5%AD%90%20%E7%BB%84%2Bx")

        // 不同项目的同号请求是不同的身份
        #expect(
            PullRequestID(instance: instance, project: "a/b", number: 3) !=
                PullRequestID(instance: instance, project: "a/c", number: 3)
        )

        try Self.expectLegacyFields()
    }
}

// MARK: - Fixtures

extension HostingClientTests {
    /// 同仓库或来自 Fork 的 GitHub 请求，源分支是 `feature/x`，提交是 `aaa`。
    static func githubRequest(fork: Bool) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: .github, project: "o/r", number: 7),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "alice", name: nil),
            createdAt: Date(),
            updatedAt: Date(),
            source: PullRequestBranch(project: fork ? "alice/r" : "o/r", branch: "feature/x", sha: "aaa"),
            target: PullRequestBranch(project: "o/r", branch: "main", sha: "bbb")
        )
    }

    /// GitHub 请求详情的 JSON。
    static func githubDetail(mergeable: String, state: String) -> String {
        """
        {"number":7,"title":"t","body":"","state":"open","draft":false,"user":{"login":"alice"},
         "created_at":"2026-10-01T00:00:00Z","updated_at":"2026-10-02T00:00:00Z","merged_at":null,
         "head":{"ref":"feature/x","sha":"aaa","repo":{"full_name":"o/r"}},
         "base":{"ref":"main","sha":"bbb","repo":{"full_name":"o/r"}},
         "mergeable":\(mergeable),"mergeable_state":"\(state)"}
        """
    }

    /// GitLab 请求的 JSON；source 是源项目编号，目标项目编号是 1。
    static func gitlabRequest(iid: Int, source: Int) -> String {
        """
        {"iid":\(iid),"title":"t","description":"d","state":"opened","draft":false,"author":{"username":"alice"},
         "created_at":"2026-10-01T00:00:00.000Z","updated_at":"2026-10-02T00:00:00.000Z",
         "source_branch":"feature","target_branch":"main","source_project_id":\(source),"target_project_id":1,
         "sha":"aaa","web_url":"https://gitlab.com/group/project/-/merge_requests/\(iid)",
         "diff_refs":{"base_sha":"mmm","head_sha":"aaa","start_sha":"bbb"},
         "detailed_merge_status":"mergeable","user":{"can_merge":false},"squash":false}
        """
    }
}

// MARK: - Legacy Fields

extension HostingClientTests {
    /// 核对旧版 GitLab 请求的指派人、状态与提交字段。
    fileprivate static func expectLegacyFields() throws {
        let single = try decodeLegacy(
            legacyRequest(
                [
                    "assignee": [
                        "username": "bob",
                        "name": "Bob 王",
                        "avatar_url": "https://gitlab.example.com/uploads/bob.png",
                    ],
                    "state": "reopened",
                ],
                removing: ["assignees"]
            )
        )

        #expect(
            single.assignees == [
                HostingUser(
                    username: "bob",
                    name: "Bob 王",
                    avatarURL: URL(string: "https://gitlab.example.com/uploads/bob.png")
                ),
            ]
        )

        #expect(single.state == .open)
        #expect(single.target.sha.isEmpty && single.mergeBase == nil && single.source.sha == "aaa")

        let unassigned = try decodeLegacy(legacyRequest(removing: ["assignees"]))

        #expect(unassigned.assignees.isEmpty)

        // 单个与多个指派人同时给出时取多个
        let both = try decodeLegacy(
            legacyRequest([
                "assignee": ["username": "bob"],
                "assignees": [["username": "bob"], ["username": "carol"]],
            ])
        )

        #expect(both.assignees.map(\.username) == ["bob", "carol"])
    }
}
