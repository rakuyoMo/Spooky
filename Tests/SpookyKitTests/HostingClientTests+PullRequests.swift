import Foundation
import Testing

@testable import SpookyKit

// MARK: - Pull Requests

/// Pull Request 与 Merge Request：列表与 Fork、评论、新建、合并选项与合并的请求和解析；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub 列表：Fork 的源仓库与目标仓库不同，已合并的按 merged_at 认出；下一页来自 Link 头。
    @Test("GitHub 的 Pull Request 列表")
    func githubList() async throws {
        let body = """
            [{"number":7,"title":"修复","body":null,"state":"open","draft":true,"user":{"login":"alice"},
              "created_at":"2026-10-01T00:00:00Z","updated_at":"2026-10-02T00:00:00Z","merged_at":null,
              "html_url":"https://github.com/o/r/pull/7","assignees":[{"login":"bob"}],
              "head":{"ref":"fix/登录","sha":"aaa","repo":{"full_name":"alice/r"}},
              "base":{"ref":"main","sha":"bbb","repo":{"full_name":"o/r"}}}]
            """
        let link = #"<https://api.github.com/repos/o/r/pulls?page=2>; rel="next""#
        let requests = HostingStub.respond { _ in (200, ["Link": link], Data(body.utf8)) }
        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())

        let (items, next) = try await client.pullRequests(in: "o/r")
        let request = try #require(items.first)

        #expect(next == 2)
        #expect(request.id == PullRequestID(instance: .github, project: "o/r", number: 7))
        #expect(request.id.reference == "#7")
        #expect(request.isDraft && request.isFromFork && request.state == .open)
        #expect(request.source == PullRequestBranch(project: "alice/r", branch: "fix/登录", sha: "aaa"))
        #expect(request.assignees == ["bob"] && request.body.isEmpty)
        #expect(request.webURL?.absoluteString == "https://github.com/o/r/pull/7")

        let url = try #require(requests.withLock { $0.first?.url?.absoluteString })
        #expect(url == "https://api.github.com/repos/o/r/pulls?state=open&per_page=50&page=1")
    }

    /// GitHub 合并选项：仓库不允许的方式不列出，没有写权限或有冲突时说明原因；合并带上源分支提交，再删除同仓库的源分支。
    @Test("GitHub 的合并选项与合并")
    func githubMerge() async throws {
        let request = Self.githubRequest(fork: false)

        HostingStub.respond { request in
            request.url?.path() == "/repos/o/r"
                ? (
                    200,
                    [:],
                    Data(#"{"allow_rebase_merge":false,"delete_branch_on_merge":true,"permissions":{"push":true}}"#.utf8)
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
        #expect(try await client.mergeOptions(for: request).block == .permission)

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

        let merge = try JSONSerialization.jsonObject(with: HostingStub.body(of: try #require(sent.first))) as? [String: String]
        #expect(merge == ["merge_method": "squash", "sha": "aaa"])
    }

    /// GitHub 从 Fork 新建：head 写成 `owner:branch`，请求发到目标仓库。
    @Test("GitHub 从 Fork 新建 Pull Request")
    func githubCreateFromFork() async throws {
        let requests = HostingStub.respond { _ in (201, [:], Data(Self.githubDetail(mergeable: "null", state: "unknown").utf8)) }
        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let draft = PullRequestDraft(
            sourceProject: "alice/r",
            sourceBranch: "feature/x",
            targetProject: "o/r",
            targetBranch: "main",
            title: "标题",
            body: "描述"
        )

        _ = try await client.createPullRequest(draft)

        let sent = try #require(requests.withLock { $0.first })
        let payload = try JSONSerialization.jsonObject(with: HostingStub.body(of: sent)) as? [String: String]
        #expect(sent.url?.absoluteString == "https://api.github.com/repos/o/r/pulls")
        #expect(payload == ["title": "标题", "body": "描述", "head": "alice:feature/x", "base": "main"])
    }

    /// GitLab 列表：多层命名空间的项目路径整体转义；同一个 Fork 的源项目路径只读一次。
    @Test("GitLab 的 Merge Request 列表")
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
        #expect(items.allSatisfy { $0.source.project == "alice/项目" && $0.target.project == "group/子组/项目" && $0.isFromFork })

        let urls = requests.withLock { $0.map { $0.url?.absoluteString ?? "" } }
        #expect(urls.count == 2)
        #expect(
            urls.first?
                .hasPrefix(
                    "https://git.example.com/gitlab/api/v4/projects/group%2F%E5%AD%90%E7%BB%84%2F%E9%A1%B9%E7%9B%AE/merge_requests?"
                ) ??
                false
        )
        #expect(urls.last == "https://git.example.com/gitlab/api/v4/projects/42")

        // 不同项目的同号请求是不同的身份
        #expect(
            PullRequestID(instance: instance, project: "a/b", number: 3) !=
                PullRequestID(instance: instance, project: "a/c", number: 3)
        )
    }

    /// GitLab 合并选项：项目要求压缩时只能压缩；当前账号不能合并或项目规则不满足时说明原因。
    @Test("GitLab 的合并选项与评论")
    func gitlabOptionsAndNotes() async throws {
        let request = try #require(
            try HostingStub.decodeGitLab(Self.gitlabRequest(iid: 3, source: 1), project: "group/project")
        )

        HostingStub.respond { request in
            request.url?.path().hasSuffix("/merge_requests/3") ?? false
                ? (200, [:], Data(Self.gitlabRequest(iid: 3, source: 1, canMerge: true, status: "ci_must_pass").utf8))
                : (
                    200,
                    [:],
                    Data(#"{"id":1,"merge_method":"ff","squash_option":"always","remove_source_branch_after_merge":true}"#.utf8)
                )
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let options = try await client.mergeOptions(for: request)
        #expect(options.methods == [.squash] && options.requiresSquash && options.squashesByDefault)
        #expect(options.projectMergeMethod == "ff" && options.deletesSourceBranchByDefault)
        #expect(options.block == .policy("ci_must_pass"))

        HostingStub.respond { _ in
            let notes =
                #"[{"id":1,"body":"看过了","author":{"username":"bob"},"created_at":"2026-10-03T00:00:00.000Z","system":false},"#
                    +
                    #"{"id":2,"body":"added 1 commit","author":{"username":"alice"},"created_at":"2026-10-04T00:00:00.000Z","system":true}]"#
            return (200, [:], Data(notes.utf8))
        }

        let notes = try await client.comments(on: request.id)
        #expect(notes.map(\.author) == ["bob", "alice"])
        #expect(notes.map(\.isSystem) == [false, true])
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
            author: "alice",
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
    static func gitlabRequest(iid: Int, source: Int, canMerge: Bool = false, status: String = "mergeable") -> String {
        """
        {"iid":\(iid),"title":"t","description":"d","state":"opened","draft":false,"author":{"username":"alice"},
         "created_at":"2026-10-01T00:00:00.000Z","updated_at":"2026-10-02T00:00:00.000Z",
         "source_branch":"feature","target_branch":"main","source_project_id":\(source),"target_project_id":1,
         "sha":"aaa","web_url":"https://gitlab.com/group/project/-/merge_requests/\(iid)",
         "diff_refs":{"base_sha":"mmm","head_sha":"aaa","start_sha":"bbb"},
         "detailed_merge_status":"\(status)","user":{"can_merge":\(canMerge)}}
        """
    }
}

// MARK: - Decoding

extension HostingStub {
    /// 把 GitLab 请求的 JSON 换成通用的请求，源项目与目标项目相同。
    static func decodeGitLab(_ json: String, project: String) throws -> PullRequest? {
        try HostingClient.decoder.decode(GitLabMergeRequest.self, from: Data(json.utf8))
            .request(on: .gitlabCom, project: project, sourceProject: project)
    }
}
