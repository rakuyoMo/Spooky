import Foundation
import Testing

@testable import SpookyKit

// MARK: - GitLab

/// 私有部署 GitLab 的旧版本：没有 `detailed_merge_status` 时推出不能合并的原因、9.0–12.4 各项字段缺失时的退化、
/// 反向代理解码 `%2F` 时按编号重试，以及合并接口的失败分类；与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// 草稿、正在检查与冲突按旧字段推出；没有 `has_conflicts` 时只看 `merge_status`。
    @Test("旧版 GitLab 的草稿、检查与冲突")
    func legacyBlocks() async throws {
        let cases: [([String: Any], PullRequestMergeBlock?)] = [
            ([:], nil),
            (["work_in_progress": true], .draft),
            (["merge_status": "unchecked"], .checking),
            (["merge_status": "checking"], .checking),
            (["merge_status": "cannot_be_merged_recheck"], .checking),
            (["has_conflicts": true], .conflicts),
            (["merge_status": "cannot_be_merged"], .conflicts),
        ]

        for (fields, expected) in cases {
            let options = try await Self.gitlabOptions(request: Self.legacyRequest(fields))
            #expect(options.block == expected, "\(fields)")
        }
    }

    /// 项目要求讨论解决、流水线通过时按旧字段判断；流水线先取 `head_pipeline`，没有这个键再取 `pipeline`。
    @Test("旧版 GitLab 的讨论与流水线")
    func legacyPolicies() async throws {
        let discussions: [String: Any] = ["id": 1, "only_allow_merge_if_all_discussions_are_resolved": true]
        let pipelines: [String: Any] = ["id": 1, "only_allow_merge_if_pipeline_succeeds": true]
        let success = ["status": "success"]
        let failed = ["status": "failed"]

        let cases: [([String: Any], [String: Any], PullRequestMergeBlock?)] = [
            (["blocking_discussions_resolved": false], discussions, .policy("discussions_not_resolved")),
            (["blocking_discussions_resolved": true], discussions, nil),

            // 12.5 以前没有 blocking_discussions_resolved，不判断
            ([:], discussions, nil),

            (["head_pipeline": success, "pipeline": failed], pipelines, nil),
            (["head_pipeline": NSNull(), "pipeline": success], pipelines, .policy("ci_must_pass")),
            (["pipeline": failed], pipelines, .policy("ci_must_pass")),
            (["pipeline": success], pipelines, nil),
            (["pipeline": NSNull()], pipelines, .policy("ci_must_pass")),

            // 10.6 以前两个键都没有，不判断
            ([:], pipelines, nil),

            // 项目不要求流水线通过时不看流水线
            (["pipeline": failed], ["id": 1], nil),
        ]

        for (fields, project, expected) in cases {
            let options = try await Self.gitlabOptions(request: Self.legacyRequest(fields), project: project)
            #expect(options.block == expected, "\(fields) \(project)")
        }
    }

    /// 没有 `can_merge` 时不预先挡住；EE 还差审批时挡住，CE 的 `approved` 与没有这个接口的 404 都不挡。
    @Test("旧版 GitLab 的权限与审批")
    func legacyPermissionsAndApprovals() async throws {
        let denied = Self.legacyRequest(["user": ["can_merge": false]])
        #expect(try await Self.gitlabOptions(request: denied).block == .permission)

        // 11.9 以前 user 里没有 can_merge
        #expect(try await Self.gitlabOptions(request: Self.legacyRequest(["user": [String: Any]()])).block == nil)
        #expect(try await Self.gitlabOptions(request: Self.legacyRequest(removing: ["user"])).block == nil)

        let cases: [(Int, String, PullRequestMergeBlock?)] = [
            (200, #"{"approvals_required":2,"approvals_left":1}"#, .policy("not_approved")),
            (200, #"{"approvals_required":2,"approvals_left":0}"#, nil),

            // 现在的 CE 有这个接口，但 approved 只表示有人批准过，不能拿来判断
            (200, #"{"approved":false,"approved_by":[]}"#, nil),

            (404, #"{"error":"404 Not Found"}"#, nil),
        ]

        for (status, body, expected) in cases {
            let options = try await Self.gitlabOptions(request: Self.legacyRequest(), approvals: (status, body))
            #expect(options.block == expected, "\(status) \(body)")
        }
    }

    /// 有 `detailed_merge_status` 时照它判断，`broken_status` 是冲突，不另调审批接口。
    @Test("GitLab 的 broken_status")
    func brokenStatus() async throws {
        let fields = Self.legacyRequest(["detailed_merge_status": "broken_status", "has_conflicts": false])
        let options = try await Self.gitlabOptions(request: fields)

        #expect(options.block == .conflicts)
        #expect(HostingStub.RequestLog().withLock { $0.allSatisfy { !($0.url?.path().hasSuffix("/approvals") ?? false) } })
    }

    /// 没有 `merge_method` 按 merge；没有 `remove_source_branch_after_merge` 时默认不删源分支；请求上没有 `squash` 时不能压缩。
    @Test("旧版 GitLab 的合并选项")
    func legacyOptions() async throws {
        let old = try await Self.gitlabOptions(request: Self.legacyRequest(removing: ["squash"]))
        #expect(old.projectMergeMethod == "merge" && old.methods == [.merge])
        #expect(!old.deletesSourceBranchByDefault)
        #expect(!old.allowsSquashOption && !old.squashesByDefault)

        // CE 11.0 起有 squash；项目还没有 squash_option（14.0 起）时可以选
        let squash = try await Self.gitlabOptions(
            request: Self.legacyRequest(["squash": true]),
            project: ["id": 1, "merge_method": "rebase_merge"]
        )
        #expect(squash.allowsSquashOption && squash.squashesByDefault && !squash.requiresSquash)
        #expect(squash.projectMergeMethod == "rebase_merge")
    }

    /// 单个的 `assignee` 当作指派人，带上名字与头像地址；`reopened` 当作打开，没有 `diff_refs` 时没有目标分支提交与合并基准。
    @Test("旧版 GitLab 的请求字段")
    func legacyDecoding() throws {
        let single = try Self.decodeLegacy(
            Self.legacyRequest(
                [
                    "assignee": ["username": "bob", "name": "Bob 王", "avatar_url": "https://gitlab.example.com/uploads/bob.png"],
                    "state": "reopened",
                ],
                removing: ["assignees"]
            )
        )

        #expect(
            single.assignees == [
                HostingUser(username: "bob", name: "Bob 王", avatarURL: URL(string: "https://gitlab.example.com/uploads/bob.png")),
            ]
        )

        #expect(single.state == .open)
        #expect(single.target.sha.isEmpty && single.mergeBase == nil && single.source.sha == "aaa")

        let unassigned = try Self.decodeLegacy(Self.legacyRequest(removing: ["assignees"]))
        #expect(unassigned.assignees.isEmpty)

        let both = try Self.decodeLegacy(
            Self.legacyRequest([
                "assignee": ["username": "bob"],
                "assignees": [["username": "bob"], ["username": "carol"]],
            ])
        )
        #expect(both.assignees.map(\.username) == ["bob", "carol"])
    }

    /// 10.3 以前不认 `sort` 与 `order_by`：读完全部页后按发表时间排，时间相同的按编号；请求里仍带着这两个参数。
    @Test("旧版 GitLab 的评论顺序")
    func legacyNotesOrder() async throws {
        let first =
            #"[{"id":5,"body":"c","created_at":"2026-10-03T00:00:00Z"},{"id":2,"body":"a","created_at":"2026-10-01T00:00:00Z"}]"#

        let second =
            #"[{"id":4,"body":"b","created_at":"2026-10-02T00:00:00Z"},{"id":3,"body":"b","created_at":"2026-10-02T00:00:00Z"}]"#

        let link = #"<https://gitlab.com/api/v4/projects/1/merge_requests/3/notes?page=2>; rel="next""#

        let requests = HostingStub.respond { request in
            request.url?.query()?.contains("page=2") ?? false
                ? (200, [:], Data(second.utf8))
                : (200, ["Link": link], Data(first.utf8))
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let notes = try await client.comments(on: PullRequestID(instance: .gitlabCom, project: "group/project", number: 3))

        #expect(notes.map(\.id) == [2, 3, 4, 5])
        #expect(requests.withLock { $0.allSatisfy { $0.url?.query()?.contains("sort=asc&order_by=created_at") ?? false } })
    }

    /// 反向代理解码 `%2F` 时编码的项目路径 404：按最后一段搜出完整路径相同的项目，换成编号重发并记住；搜不到时仍是 404。
    @Test("编码的项目路径被解码时按编号重试")
    func projectIDRetry() async throws {
        let instance = try #require(HostingInstance.gitlab(address: "https://proxy.example.com/gitlab"))
        let detail = try JSONSerialization.data(withJSONObject: Self.legacyRequest())
        let search = #"[{"id":7,"path_with_namespace":"other/project"},{"id":42,"path_with_namespace":"Group/Sub/Project"}]"#

        let handler: HostingStub.Handler = { request in
            let path = request.url?.path() ?? ""

            if path.contains("%2F") {
                return (404, [:], Data(#"{"error":"404 Not Found"}"#.utf8))
            }

            return path.hasSuffix("/projects") ? (200, [:], Data(search.utf8)) : (200, [:], detail)
        }

        let client = HostingClient(instance: instance, token: "t", session: HostingStub.session())
        let id = PullRequestID(instance: instance, project: "group/sub/project", number: 3)
        let api = "https://proxy.example.com/gitlab/api/v4/"

        let requests = HostingStub.respond(handler)
        _ = try await client.pullRequest(id)
        #expect(
            requests.withLock { $0.map { $0.url?.absoluteString ?? "" } } == [
                api + "projects/group%2Fsub%2Fproject/merge_requests/3",
                api + "projects?search=project&per_page=100",
                api + "projects/42/merge_requests/3",
            ]
        )

        // 同一进程里之后的请求直接用编号
        let again = HostingStub.respond(handler)
        _ = try await client.pullRequest(id)
        #expect(again.withLock { $0.map { $0.url?.absoluteString ?? "" } } == [api + "projects/42/merge_requests/3"])

        let missing = HostingStub.respond(handler)
        await #expect(throws: HostingError.notFound("404 Not Found")) {
            try await client.pullRequest(PullRequestID(instance: instance, project: "group/missing", number: 3))
        }
        #expect(missing.withLock { $0.count } == 2)
    }
}

// MARK: - Merge

extension HostingClientTests {
    /// 合并接口回 200 而请求还开着时是合并失败，带 `merge_error`，没有时为空；405、406、422 都是冲突，409 按一般的拒绝分类。
    @Test("GitLab 合并失败与冲突")
    func gitlabMergeFailures() async throws {
        let request = try Self.decodeLegacy(Self.legacyRequest())
        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let failed = try JSONSerialization.data(withJSONObject: Self.legacyRequest(["merge_error": "Something went wrong"]))
        let silent = try JSONSerialization.data(withJSONObject: Self.legacyRequest())

        HostingStub.respond { _ in (200, [:], failed) }
        await #expect(throws: HostingError.mergeFailed("Something went wrong")) {
            try await client.merge(request, method: .squash, deletesSourceBranch: false)
        }

        // 11.6 以前没有 merge_error
        HostingStub.respond { _ in (200, [:], silent) }
        await #expect(throws: HostingError.mergeFailed("")) {
            try await client.merge(request, method: .squash, deletesSourceBranch: false)
        }

        for status in [405, 406, 422] {
            HostingStub.respond { _ in (status, [:], Data(#"{"message":"Branch cannot be merged"}"#.utf8)) }
            await #expect(throws: HostingError.mergeConflict("Branch cannot be merged")) {
                try await client.merge(request, method: .squash, deletesSourceBranch: false)
            }
        }

        HostingStub.respond { _ in (409, [:], Data(#"{"message":"SHA does not match HEAD of source branch"}"#.utf8)) }
        await #expect(throws: HostingError.rejected(status: 409, message: "SHA does not match HEAD of source branch")) {
            try await client.merge(request, method: .squash, deletesSourceBranch: false)
        }
    }

    /// 合并回 401 时用同一令牌读用户：读得出是没有合并权限，读不出才是令牌失效。
    @Test("GitLab 合并回 401")
    func gitlabMergeUnauthorized() async throws {
        let request = try Self.decodeLegacy(Self.legacyRequest())
        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let denied = Data(#"{"message":"401 Unauthorized"}"#.utf8)

        let requests = HostingStub.respond { sent in
            sent.url?.path().hasSuffix("/user") ?? false
                ? (200, [:], Data(#"{"username":"rakuyo"}"#.utf8))
                : (401, [:], denied)
        }

        await #expect(throws: HostingError.forbidden("401 Unauthorized")) {
            try await client.merge(request, method: .squash, deletesSourceBranch: false)
        }
        #expect(requests.withLock { $0.map { $0.url?.path() ?? "" } } == [
            "/api/v4/projects/group%2Fproject/merge_requests/3/merge",
            "/api/v4/user",
        ])

        HostingStub.respond { _ in (401, [:], denied) }
        await #expect(throws: HostingError.unauthorized("401 Unauthorized")) {
            try await client.merge(request, method: .squash, deletesSourceBranch: false)
        }
    }

    /// 请求上已勾压缩而这次不压缩：先读详情、发更新取消压缩，再合并；没有 `squash_commit_sha` 时结果取 `merge_commit_sha`。
    @Test("GitLab 合并时取消压缩")
    func gitlabMergeWithoutSquash() async throws {
        let request = try Self.decodeLegacy(Self.legacyRequest())
        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let squashed = try JSONSerialization.data(withJSONObject: Self.legacyRequest(["squash": true]))
        let merged = try JSONSerialization.data(withJSONObject: Self.legacyRequest([
            "state": "merged",
            "merge_commit_sha": "ccc",
        ]))
        let path = "/api/v4/projects/group%2Fproject/merge_requests/3"

        let requests = HostingStub.respond { sent in
            (200, [:], sent.url?.path().hasSuffix("/merge") ?? false ? merged : squashed)
        }

        let result = try await client.merge(request, method: .merge, deletesSourceBranch: true)
        #expect(result == PullRequestMergeResult(sha: "ccc", message: "merged"))

        let sent = requests.withLock { $0 }
        #expect(sent.map { $0.httpMethod ?? "" } == ["GET", "PUT", "PUT"])
        #expect(sent.map { $0.url?.path() ?? "" } == [path, path, path + "/merge"])

        let update = try JSONSerialization.jsonObject(with: HostingStub.body(of: sent[1])) as? [String: Bool]
        #expect(update == ["squash": false])

        let merge = try JSONSerialization.jsonObject(with: HostingStub.body(of: sent[2])) as? [String: AnyHashable]
        #expect(merge == ["squash": false, "should_remove_source_branch": true, "sha": "aaa"])

        // 请求上没勾压缩时只读详情再合并；这次压缩时直接合并
        let plain = try JSONSerialization.data(withJSONObject: Self.legacyRequest())
        let unchanged = HostingStub.respond { sent in
            (200, [:], sent.url?.path().hasSuffix("/merge") ?? false ? merged : plain)
        }
        _ = try await client.merge(request, method: .merge, deletesSourceBranch: false)
        #expect(unchanged.withLock { $0.map { $0.httpMethod ?? "" } } == ["GET", "PUT"])

        let direct = HostingStub.respond { _ in (200, [:], merged) }
        _ = try await client.merge(request, method: .squash, deletesSourceBranch: false)
        #expect(direct.withLock { $0.map { $0.httpMethod ?? "" } } == ["PUT"])
    }
}

// MARK: - Legacy Fixtures

extension HostingClientTests {
    /// GitLab 12.4 的请求：没有 `detailed_merge_status`、`has_conflicts` 与 `blocking_discussions_resolved`；
    /// 编号 3，源项目与目标项目都是 1，源分支提交是 `aaa`。
    static func legacyRequest(_ overrides: [String: Any] = [:], removing: [String] = []) -> [String: Any] {
        var fields: [String: Any] = [
            "iid": 3,
            "title": "t",
            "description": "d",
            "state": "opened",
            "work_in_progress": false,
            "author": ["username": "alice"],
            "created_at": "2026-10-01T00:00:00.000Z",
            "updated_at": "2026-10-02T00:00:00.000Z",
            "source_branch": "feature",
            "target_branch": "main",
            "source_project_id": 1,
            "target_project_id": 1,
            "sha": "aaa",
            "merge_status": "can_be_merged",
            "user": ["can_merge": true],
            "squash": false,
            "assignees": [Any](),
        ]

        fields.merge(overrides) { $1 }

        for key in removing {
            fields.removeValue(forKey: key)
        }

        return fields
    }

    /// 把 GitLab 请求的字段换成通用的请求，项目是 `group/project`。
    static func decodeLegacy(_ fields: [String: Any]) throws -> PullRequest {
        let data = try JSONSerialization.data(withJSONObject: fields)

        return try HostingClient.decoder
            .decode(GitLabMergeRequest.self, from: data)
            .request(on: .gitlabCom, project: "group/project", sourceProject: "group/project")
    }

    /// 按请求字段、项目字段与审批接口的响应读出合并选项。
    ///
    /// 审批接口默认是 CE 12.x 的 404；它之后按名称搜项目时没有结果，不会记下项目编号。
    static func gitlabOptions(
        request fields: [String: Any],
        project: [String: Any] = ["id": 1],
        approvals: (status: Int, body: String) = (404, #"{"error":"404 Not Found"}"#)
    ) async throws -> PullRequestMergeOptions {
        let request = try JSONSerialization.data(withJSONObject: fields)
        let settings = try JSONSerialization.data(withJSONObject: project)
        let approvalsBody = Data(approvals.body.utf8)
        let approvalsStatus = approvals.status

        HostingStub.respond { sent in
            let path = sent.url?.path() ?? ""

            if path.hasSuffix("/approvals") {
                return (approvalsStatus, [:], approvalsBody)
            }

            if path.hasSuffix("/projects") {
                return (200, [:], Data("[]".utf8))
            }

            return (200, [:], path.hasSuffix("/merge_requests/3") ? request : settings)
        }

        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        return try await client.mergeOptions(for: decodeLegacy(fields))
    }
}
