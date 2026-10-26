import Foundation
import Testing

@testable import SpookyKit

// MARK: - RepositoryPullRequestsTests

/// 请求在仓库里的 Git 动作：远端用本机裸仓库，在其中写入托管服务为请求保留的 `refs/pull/1/head`。
struct RepositoryPullRequestsTests {
    /// 克隆不会取回请求的引用；取回后提交可用，比较基准由本机的 merge-base 算出。
    @Test("取回源分支提交与比较基准")
    func fetchAndBase() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let fixture = try await PullRequestFixture(temporary)
        let pulls = RepositoryPullRequests(runner: fixture.clone)
        let request = fixture.request(fork: true)

        #expect(try await !pulls.hasCommit(fixture.feature))
        #expect(try await pulls.comparisonBase(for: request) == nil)

        try await pulls.fetchHead(of: request.id, from: "origin")
        #expect(try await pulls.hasCommit(fixture.feature))
        #expect(try await pulls.comparisonBase(for: request) == fixture.base)
        #expect(try await !pulls.hasCommit("not-a-hash"))
    }

    /// 来自 Fork 的请求从提交新建不跟踪的分支；同名分支指向别处时拒绝；同仓库的请求在远端跟踪分支一致时跟踪它。
    @Test("检出请求")
    func checkout() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let fixture = try await PullRequestFixture(temporary)
        let pulls = RepositoryPullRequests(runner: fixture.clone)

        try await pulls.checkout(fixture.request(fork: true), remote: "origin", as: "pr-1")
        #expect(try await fixture.text(["rev-parse", "HEAD"]) == fixture.feature)
        #expect(try await fixture.text(["symbolic-ref", "--short", "HEAD"]) == "pr-1")

        // 同名分支已指向源分支提交时直接检出
        _ = try await fixture.clone.run(["switch", "-q", "main"])
        try await pulls.checkout(fixture.request(fork: true), remote: "origin", as: "pr-1")
        #expect(try await fixture.text(["symbolic-ref", "--short", "HEAD"]) == "pr-1")

        await #expect(throws: PullRequestCheckoutError.branchMismatch("main")) {
            try await pulls.checkout(fixture.request(fork: true), remote: "origin", as: "main")
        }

        // 获取远端后 origin/feature 正是源分支提交
        _ = try await fixture.clone.run(["fetch", "-q", "origin"])
        try await pulls.checkout(fixture.request(fork: false), remote: "origin", as: "功能")
        let upstream = try await fixture.text(["rev-parse", "--abbrev-ref", "功能@{upstream}"])
        #expect(upstream == "origin/feature")
    }
}

// MARK: - PullRequestFixture

/// 裸仓库作远端，main 上一个提交、feature 上再一个提交，远端另有指向 feature 的 `refs/pull/1/head`；克隆在它旁边。
private struct PullRequestFixture {
    /// 克隆的执行器。
    let clone: GitRunner

    /// main 的提交，也是合并基准。
    let base: String

    /// feature 的提交。
    let feature: String

    /// 建出远端与克隆。
    init(_ temporary: TemporaryRepository) async throws {
        let root = temporary.directory.path
        let remote = root + "/远端.git"
        let work = root + "/工作"
        let setup = temporary.runner

        _ = try await setup.run(["-c", "init.templateDir=", "init", "-q", "--bare", "-b", "main", "--", remote])
        _ = try await setup.run(["-c", "init.templateDir=", "init", "-q", "-b", "main", "--", work])

        let source = temporary.runner(at: work)
        _ = try await source.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await source.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await source.run(["commit", "-q", "--allow-empty", "-m", "基准"])
        _ = try await source.run(["switch", "-q", "-c", "feature"])
        _ = try await source.run(["commit", "-q", "--allow-empty", "-m", "功能"])
        _ = try await source.run(["push", "-q", remote, "main", "feature"])

        base = try await Self.text(source, ["rev-parse", "main"])
        feature = try await Self.text(source, ["rev-parse", "feature"])

        // 托管服务为请求保留的引用；在克隆之后才指向一个只在这里有的提交
        _ = try await temporary.runner(at: remote).run(["update-ref", "refs/pull/1/head", feature])

        _ = try await setup.run(["clone", "-q", "--", remote, root + "/克隆"])
        clone = temporary.runner(at: root + "/克隆")
        _ = try await clone.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await clone.run(["config", "--local", "user.email", "spooky@example.invalid"])

        // 克隆里只留 main，feature 的提交只能经请求的引用取回
        _ = try await clone.run(["update-ref", "-d", "refs/remotes/origin/feature"])
        _ = try await clone.run(["reflog", "expire", "--expire=now", "--all"])
        _ = try await clone.run(["gc", "-q", "--prune=now"])
    }

    /// 请求 1：来自 Fork 时源项目不同。
    func request(fork: Bool) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: .github, project: "o/r", number: 1),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: "alice",
            createdAt: Date(),
            updatedAt: Date(),
            source: PullRequestBranch(project: fork ? "alice/r" : "o/r", branch: "feature", sha: feature),
            target: PullRequestBranch(project: "o/r", branch: "main", sha: base)
        )
    }

    /// 克隆里执行一条命令，取去掉换行的输出。
    func text(_ arguments: [String]) async throws -> String {
        try await Self.text(clone, arguments)
    }
}

// MARK: - Helpers

extension PullRequestFixture {
    /// 执行一条命令，取去掉换行的输出。
    fileprivate static func text(_ runner: GitRunner, _ arguments: [String]) async throws -> String {
        String(decoding: try await runner.run(arguments), as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
