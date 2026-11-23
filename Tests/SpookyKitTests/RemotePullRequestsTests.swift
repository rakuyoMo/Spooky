import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemotePullRequestsTests

/// 服务器仓库里请求的 Git 动作：取回源分支提交、求比较基准与检出都在 B 上执行；远端是 B 上的裸仓库，
/// 里面写着托管服务为请求保留的 `refs/pull/1/head` 与 `refs/merge-requests/2/head`。
///
/// 仅在显式启用时访问测试专用仓库。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemotePullRequestsTests {
    /// 仓库里原本没有请求的提交：GitLab 的 Merge Request 经 `refs/merge-requests` 取回后才有，比较基准在 B 上算出；
    /// 远端没有引用的请求报出提交取不回来；
    /// 来自 Fork 的 GitHub Pull Request 检出成不跟踪的新分支，同名分支指向别处时拒绝；同项目的请求在远端跟踪分支一致时跟踪它。
    @Test("服务器上取回与检出 Pull Request 和 Merge Request")
    func fetchAndCheckout() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let runner = GitRunner(location: try await remote.open().location, remote: remote)
            let (base, feature) = try await Self.makeOrigin(in: fixture, runner: runner)
            let pulls = RepositoryPullRequests(runner: runner)
            let text = { (arguments: [String]) in
                String(decoding: try await runner.run(arguments), as: UTF8.self)
                    .trimmingCharacters(in: .newlines)
            }

            let merge = Self.request(on: .gitlabCom, number: 2, fork: true, base: base, feature: feature)
            let pull = Self.request(on: .github, number: 1, fork: true, base: base, feature: feature)

            #expect(try await !pulls.hasCommit(feature))
            #expect(try await pulls.comparisonBase(for: merge, remote: "origin") == nil)

            // 远端没有请求 3 的引用
            let gone = Self.request(on: .gitlabCom, number: 3, fork: true, base: base, feature: feature)

            await #expect(throws: PullRequestFetchError.headUnavailable("refs/merge-requests/3/head")) {
                try await pulls.fetchHead(of: gone.id, from: "origin")
            }

            try await pulls.fetchHead(of: merge.id, from: "origin")

            #expect(try await pulls.hasCommit(feature))
            #expect(try await pulls.comparisonBase(for: merge, remote: "origin") == base)

            // 检出时同样先经 refs/pull 取回
            try await pulls.checkout(pull, remote: "origin", as: "pr-1")

            #expect(try await text(["rev-parse", "HEAD"]) == feature)
            #expect(try await text(["symbolic-ref", "--short", "HEAD"]) == "pr-1")

            await #expect(throws: PullRequestCheckoutError.branchMismatch("main")) {
                try await pulls.checkout(pull, remote: "origin", as: "main")
            }

            // 获取远端后 origin/feature 正是源分支提交
            _ = try await runner.run(["fetch", "-q", "origin"])

            let same = Self.request(on: .gitlabCom, number: 2, fork: false, base: base, feature: feature)
            try await pulls.checkout(same, remote: "origin", as: "功能")

            #expect(try await text(["rev-parse", "--abbrev-ref", "功能@{upstream}"]) == "origin/feature")

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}

// MARK: - Steps

extension RemotePullRequestsTests {
    /// 测试仓库里 main 一个提交、feature 再一个提交，推到 B 上新建的裸仓库并写好两个请求的引用；
    /// 之后测试仓库只留 main，feature 的提交只能经请求的引用取回。返回 main 与 feature 的提交。
    private static func makeOrigin(in fixture: RemoteFixture, runner: GitRunner) async throws -> (String, String) {
        let origin = fixture.root + "/远 端.git"
        let head = { (reference: String) in
            String(decoding: try await runner.run(["rev-parse", reference]), as: UTF8.self)
                .trimmingCharacters(in: .newlines)
        }

        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "基准"])
        _ = try await runner.run(["switch", "-q", "-c", "feature"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "功能"])

        let base = try await head("main")
        let feature = try await head("feature")

        _ = try await RemoteFixture.raw([
            "git", "-c", "init.templateDir=", "init", "-q", "--bare", "-b", "main", origin,
        ])

        _ = try await runner.run(["remote", "add", "origin", origin])
        _ = try await runner.run(["push", "-q", "origin", "main", "feature"])

        for reference in ["refs/pull/1/head", "refs/merge-requests/2/head"] {
            _ = try await RemoteFixture.raw(["git", "--git-dir", origin, "update-ref", reference, feature])
        }

        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["branch", "-q", "-D", "feature"])
        _ = try await runner.run(["update-ref", "-d", "refs/remotes/origin/feature"])
        _ = try await runner.run(["reflog", "expire", "--expire=now", "--all"])
        _ = try await runner.run(["gc", "-q", "--prune=now"])

        return (base, feature)
    }

    /// 一个请求：来自 Fork 时源项目不同；目标分支是带提交的 main。
    private static func request(
        on instance: HostingInstance,
        number: Int,
        fork: Bool,
        base: String,
        feature: String
    ) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: instance, project: "o/r", number: number),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "alice", name: nil),
            createdAt: Date(),
            updatedAt: Date(),
            source: PullRequestBranch(project: fork ? "alice/r" : "o/r", branch: "feature", sha: feature),
            target: PullRequestBranch(project: "o/r", branch: "main", sha: base)
        )
    }
}
