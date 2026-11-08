import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestActionRulesTests

/// 请求列表的右键菜单、双击与详情底栏：检出在跟踪源分支的本地分支有未推送的提交，
/// 或它就是当前分支且已在请求的提交上时不可用，免得覆盖本地的工作。
@MainActor
struct PullRequestActionRulesTests {
    /// 没有跟踪分支、跟踪分支在别的提交上或来自 Fork 时能检出；跟踪分支有未推送的提交、
    /// 或它是当前分支且已在请求的提交上时不能；仓库不可写时都不能。
    @Test("检出请求的可用条件")
    func checkoutAvailability() async throws {
        // 远端分支 origin/feature 在第一个提交上，本地的 feature 跟踪它
        let fixture = try await HistoryListTests.makeSession(commits: ["first", "second"]) { runner, _ in
            _ = try await runner.run(["remote", "add", "origin", "http://127.0.0.1:9/group/project.git"])
            _ = try await runner.run(["update-ref", "refs/remotes/origin/feature", "HEAD~1"])
            _ = try await runner.run(["branch", "--track", "feature", "origin/feature"])
        }
        defer { fixture.close() }

        let runner = fixture.runner
        let session = fixture.session
        let second = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let first = try await RepositoryReferences(runner: runner).resolve("HEAD~1")
        #expect(session.history.branches.contains { $0.id == "refs/heads/feature" && $0.upstream != nil })

        try await Self.loadRemote(of: session, runner: runner)

        let tracked = Self.request(branch: "feature", sha: first.uppercased())
        #expect(session.canCheckOutPullRequest(tracked))
        #expect(session.canCheckOutPullRequest(Self.request(branch: "untracked", sha: first)))

        // feature 是当前分支：在请求的提交上时不能，请求在别的提交上或源分支提交未知时能
        _ = try await runner.run(["switch", "-q", "feature"])
        await Self.reload(session)
        #expect(session.status?.branch.head == "feature")

        #expect(!session.canCheckOutPullRequest(tracked))
        #expect(session.canCheckOutPullRequest(Self.request(branch: "feature", sha: second)))
        #expect(session.canCheckOutPullRequest(Self.request(branch: "feature", sha: "")))

        // feature 不是当前分支，但领先 origin/feature 一个提交时不能；来自 Fork 的请求不看本地分支
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["update-ref", "refs/heads/feature", second])
        await Self.reload(session)
        #expect(session.history.divergence["refs/heads/feature"]?.ahead == 1)

        #expect(!session.canCheckOutPullRequest(Self.request(branch: "feature", sha: second)))
        #expect(session.canCheckOutPullRequest(Self.request(branch: "feature", sha: second, fork: true)))

        // 另一个写操作进行中
        let location = try #require(session.repository)
        #expect(RepositoryWriteLocks.shared.acquire(location))
        #expect(!session.canCheckOutPullRequest(Self.request(branch: "untracked", sha: first)))
        RepositoryWriteLocks.shared.release(location)
    }
}

// MARK: - Helpers

extension PullRequestActionRulesTests {
    /// `group/project` 里 `me` 发起的请求；来自 Fork 时源分支在 `me/project`。
    private static func request(branch: String, sha: String, fork: Bool = false) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: .gitlabCom, project: "group/project", number: 4),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "me", name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: fork ? "me/project" : "group/project", branch: branch, sha: sha),
            target: PullRequestBranch(project: "group/project", branch: "main", sha: "")
        )
    }

    /// 重读工作区与引用；引用在工作区状态之后另读，等它与它带起的读取都结束。
    private static func reload(_ session: RepositorySession) async {
        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }
    }

    /// 请求视图读出远端，选中 origin；账号列表只在内存里，不碰本机的账号。
    private static func loadRemote(of session: RepositorySession, runner: GitRunner) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-action-rules-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        session.pullRequests.accounts = HostingAccounts(defaults: defaults, credentials: MemoryCredentials())
        session.pullRequests.load(runner: runner)

        // 端口不可达，列表很快失败；第一次读完时标记已读过
        await until { session.pullRequests.isLoaded }
        #expect(session.pullRequests.remote == "origin")
    }
}
