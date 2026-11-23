import Foundation
import Testing

@testable import SpookyKit

// MARK: - Checks

/// 请求的 CI/CD 状态：GitHub 的检查运行与提交状态、GitLab 的流水线与作业，以及整体状态的合成；
/// 与 ``HostingClientTests`` 同属一组依次执行。
extension HostingClientTests {
    /// GitHub：检查运行逐页读完、按创建的先后排在前面，提交状态接在后面；结束了的检查运行看结论，其余按是否已开始运行，
    /// 提交状态的 `error` 算失败；整体状态取各项里最要紧的一种。两种都从目标仓库按源分支提交读取；
    /// 一项都没有时没有整体状态，源分支提交未知时不发请求。
    @Test("GitHub 的检查运行与提交状态")
    func githubChecks() async throws {
        let first = """
            {"total_count":7,"check_runs":[
             {"id":16,"name":"deploy","status":"queued","conclusion":null,"app":{"name":"GitHub Actions"}},
             {"id":15,"name":"docs","status":"completed","conclusion":"neutral","app":null},
             {"id":14,"name":"release","status":"completed","conclusion":"skipped","app":{"name":"GitHub Actions"}},
             {"id":13,"name":"lint","status":"in_progress","conclusion":null,"app":{"name":"GitHub Actions"}}]}
            """

        let second = """
            {"total_count":7,"check_runs":[
             {"id":12,"name":"review","status":"completed","conclusion":"action_required","app":{"name":"Reviewer"}},
             {"id":11,"name":"test","status":"completed","conclusion":"timed_out","app":{"name":"GitHub Actions"}},
             {"id":10,"name":"build","status":"completed","conclusion":"success","app":{"name":"GitHub Actions"}}]}
            """

        let statuses = """
            {"state":"failure","total_count":2,"statuses":[
             {"id":1,"state":"error","context":"ci/external","description":"Build errored"},
             {"id":2,"state":"pending","context":"coverage","description":null}]}
            """

        let link = #"<https://api.github.com/repos/o/r/commits/aaa/check-runs?per_page=100&page=2>; rel="next""#

        let requests = HostingStub.respond { request in
            guard request.url?.path().hasSuffix("/check-runs") ?? false else {
                return (200, [:], Data(statuses.utf8))
            }

            return request.url?.query()?.hasSuffix("page=1") ?? false
                ? (200, ["Link": link], Data(first.utf8))
                : (200, [:], Data(second.utf8))
        }

        let client = HostingClient(instance: .github, token: "t", session: HostingStub.session())
        let request = Self.githubRequest(fork: true)
        let checks = try await client.checks(for: request)
        let actions = "GitHub Actions"

        #expect(
            checks.items == [
                PullRequestCheck(id: "run-10", name: "build", group: actions, state: .success),
                PullRequestCheck(id: "run-11", name: "test", group: actions, state: .failure),
                PullRequestCheck(id: "run-12", name: "review", group: "Reviewer", state: .manual),
                PullRequestCheck(id: "run-13", name: "lint", group: actions, state: .running),
                PullRequestCheck(id: "run-14", name: "release", group: actions, state: .skipped),
                PullRequestCheck(id: "run-15", name: "docs", group: nil, state: .neutral),
                PullRequestCheck(id: "run-16", name: "deploy", group: actions, state: .pending),
                PullRequestCheck(id: "status-1", name: "ci/external", group: nil, state: .failure),
                PullRequestCheck(id: "status-2", name: "coverage", group: nil, state: .pending),
            ]
        )

        #expect(checks.state == .failure && checks.isActive)

        // 来自 Fork 的请求同样读目标仓库 o/r
        let commit = "https://api.github.com/repos/o/r/commits/aaa"

        #expect(
            Set(requests.withLock { $0.map { $0.url?.absoluteString ?? "" } }) == [
                commit + "/check-runs?per_page=100&page=1",
                commit + "/check-runs?per_page=100&page=2",
                commit + "/status?per_page=100&page=1",
            ]
        )

        // 整体状态：取最要紧的一种，通过的盖过跳过的，一项都没有时没有
        #expect(PullRequestCheckState.overall(of: [.success, .running, .cancelled]) == .cancelled)
        #expect(PullRequestCheckState.overall(of: [.skipped, .success, .neutral]) == .success)
        #expect(PullRequestCheckState.overall(of: [.pending, .running]) == .running)
        #expect(PullRequestCheckState.overall(of: []) == nil)

        // 没有检查也没有提交状态
        HostingStub.respond { request in
            let runs = request.url?.path().hasSuffix("/check-runs") ?? false

            return (200, [:], Data((runs ? #"{"total_count":0,"check_runs":[]}"# : #"{"state":"pending","statuses":[]}"#).utf8))
        }

        #expect(try await client.checks(for: request) == PullRequestChecks(state: nil, items: []))
        #expect(try await client.checkState(for: request) == nil)

        // 源分支提交未知
        let unknown = HostingStub.respond { _ in (500, [:], Data()) }
        let detached = PullRequest(
            id: request.id,
            title: request.title,
            body: request.body,
            state: request.state,
            isDraft: request.isDraft,
            author: request.author,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt,
            source: PullRequestBranch(project: nil, branch: "feature/x", sha: ""),
            target: request.target
        )

        #expect(try await client.checkState(for: detached) == nil)
        #expect(unknown.withLock { $0.isEmpty })
    }

    /// GitLab：流水线先取 `head_pipeline`，整体状态是流水线自己的状态；作业逐页读完、按创建的先后排列，分组是所在的阶段；
    /// 流水线带项目编号时作业按编号读，旧版本没有编号时按请求的项目路径读；只读整体状态时不读作业；没有流水线时没有状态。
    @Test("GitLab 的流水线与作业")
    func gitlabChecks() async throws {
        let jobs = """
            [{"id":34,"name":"deploy","stage":"deploy","status":"manual"},
             {"id":33,"name":"rspec","stage":"test","status":"running"},
             {"id":32,"name":"lint","stage":"test","status":"failed"},
             {"id":31,"name":"compile","stage":"build","status":"success"},
             {"id":30,"name":"notify","stage":".pre","status":"waiting_for_resource"}]
            """

        let api = "https://gitlab.com/api/v4/"
        let client = HostingClient(instance: .gitlabCom, token: "t", session: HostingStub.session())
        let request = try Self.decodeLegacy(Self.legacyRequest())

        // 流水线在源项目 42 里
        let forked = try JSONSerialization.data(withJSONObject: Self.legacyRequest([
            "head_pipeline": ["id": 77, "project_id": 42, "status": "running"],
            "pipeline": ["id": 70, "status": "failed"],
        ]))

        let requests = HostingStub.respond { sent in
            (200, [:], sent.url?.path().hasSuffix("/jobs") ?? false ? Data(jobs.utf8) : forked)
        }

        let checks = try await client.checks(for: request)

        #expect(checks.state == .running && checks.isActive)
        #expect(
            checks.items == [
                PullRequestCheck(id: "job-30", name: "notify", group: ".pre", state: .pending),
                PullRequestCheck(id: "job-31", name: "compile", group: "build", state: .success),
                PullRequestCheck(id: "job-32", name: "lint", group: "test", state: .failure),
                PullRequestCheck(id: "job-33", name: "rspec", group: "test", state: .running),
                PullRequestCheck(id: "job-34", name: "deploy", group: "deploy", state: .manual),
            ]
        )

        #expect(
            requests.withLock { $0.map { $0.url?.absoluteString ?? "" } } == [
                api + "projects/group%2Fproject/merge_requests/3",
                api + "projects/42/pipelines/77/jobs?per_page=100&page=1",
            ]
        )

        // 只读整体状态
        let summary = HostingStub.respond { _ in (200, [:], forked) }

        #expect(try await client.checkState(for: request) == .running)
        #expect(summary.withLock { $0.count } == 1)

        // 10.6 起的 pipeline 没有项目编号
        let legacy = try JSONSerialization.data(withJSONObject: Self.legacyRequest([
            "pipeline": ["id": 70, "status": "canceled"],
        ]))

        let old = HostingStub.respond { sent in
            (200, [:], sent.url?.path().hasSuffix("/jobs") ?? false ? Data("[]".utf8) : legacy)
        }

        #expect(try await client.checks(for: request) == PullRequestChecks(state: .cancelled, items: []))
        #expect(
            old.withLock { $0.last?.url?.absoluteString }
                == api + "projects/group%2Fproject/pipelines/70/jobs?per_page=100&page=1"
        )

        // 没有流水线
        let none = try JSONSerialization.data(withJSONObject: Self.legacyRequest(["head_pipeline": NSNull()]))
        let empty = HostingStub.respond { _ in (200, [:], none) }

        #expect(try await client.checks(for: request) == PullRequestChecks(state: nil, items: []))
        #expect(try await client.checkState(for: request) == nil)
        #expect(empty.withLock { $0.count } == 2)
    }
}
