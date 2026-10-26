import Foundation
import Testing

@testable import SpookyKit

// MARK: - GitHubLiveTests

/// github.com 上的真实流程：在测试仓库里推送临时分支，新建、读取、评论、修改、检出、合并与关闭 Pull Request，结束时删掉临时分支。
///
/// 默认不跑；`SPOOKY_GITHUB_TESTS=1` 时运行，令牌取自 `SPOOKY_GITHUB_TOKEN`，测试仓库取自 `SPOOKY_GITHUB_REPOSITORY`（`owner/repo`）。
/// 本机 Git 经 `gh auth git-credential` 认证推送与获取，令牌不写进地址与配置。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_GITHUB_TESTS"] == "1"))
struct GitHubLiveTests {
    /// 测试仓库与令牌。
    private let repository = ProcessInfo.processInfo.environment["SPOOKY_GITHUB_REPOSITORY"] ?? ""

    /// 测试账号的令牌。
    private let token = ProcessInfo.processInfo.environment["SPOOKY_GITHUB_TOKEN"] ?? ""

    /// 新建、列表、详情、评论、修改、检出与压缩合并后删除源分支。
    @Test("Pull Request 的完整流程", .timeLimit(.minutes(5)))
    func lifecycle() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let client = HostingClient(instance: .github, token: token)
        let user = try await client.currentUser()
        let (runner, branch, sha) = try await pushBranch(in: temporary, name: "spooky-live-")

        let created = try await client.createPullRequest(
            PullRequestDraft(
                sourceProject: repository,
                sourceBranch: branch,
                targetProject: repository,
                targetBranch: "main",
                title: "Spooky 测试",
                body: "由测试创建"
            )
        )

        #expect(created.author == user.username && created.state == .open && created.source.sha == sha)
        #expect(try await client.pullRequests(in: repository).items.contains { $0.id == created.id })

        try await client.addComment("评论 " + branch, to: created.id)
        #expect(try await client.comments(on: created.id).contains { $0.body == "评论 " + branch })

        try await client.updatePullRequest(created.id, title: "Spooky 测试（改）", body: "改过的描述", targetBranch: "main")
        let updated = try await client.pullRequest(created.id)
        #expect(updated.title == "Spooky 测试（改）" && updated.body == "改过的描述")

        // 在本机取回源分支提交并检出成本地分支
        let pulls = RepositoryPullRequests(runner: runner)
        try await pulls.checkout(updated, remote: "origin", as: "pr-\(created.id.number)")
        #expect(String(decoding: try await runner.run(["rev-parse", "HEAD"]), as: UTF8.self).hasPrefix(sha))
        #expect(try await pulls.comparisonBase(for: updated) != nil)

        let options = try await waitForMergeOptions(client, updated)
        #expect(options.methods.contains(.squash))
        #expect(options.block == nil, "\(String(describing: options.block))")

        let result = try await client.merge(updated, method: .squash, deletesSourceBranch: true)
        #expect(result.sha != nil)
        let merged = try await client.pullRequest(created.id)
        #expect(merged.state == .merged, "\(merged.state) \(result)")

        // 合并后源分支在远端已删除
        let remaining = try await runner.run(["ls-remote", "--heads", "origin", branch])
        #expect(remaining.isEmpty)
    }

    /// 关闭不合并；结束时删掉远端的临时分支。
    @Test("关闭 Pull Request", .timeLimit(.minutes(3)))
    func close() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let client = HostingClient(instance: .github, token: token)
        let (runner, branch, _) = try await pushBranch(in: temporary, name: "spooky-close-")

        let created = try await client.createPullRequest(
            PullRequestDraft(
                sourceProject: repository,
                sourceBranch: branch,
                targetProject: repository,
                targetBranch: "main",
                title: "Spooky 关闭测试",
                body: ""
            )
        )

        try await client.closePullRequest(created.id)
        #expect(try await client.pullRequest(created.id).state == .closed)

        _ = try await runner.run(["push", "-q", "origin", "--delete", branch])
    }
}

// MARK: - Helpers

extension GitHubLiveTests {
    /// 克隆测试仓库，在新分支上提交一次并推送；返回克隆的执行器、分支名与提交。
    private func pushBranch(in temporary: TemporaryRepository, name prefix: String) async throws -> (GitRunner, String, String) {
        let path = temporary.directory.path + "/clone"
        let branch = prefix + UUID().uuidString.prefix(8).lowercased()
        let helper = ["-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential"]

        _ = try await temporary.runner.run(helper + ["clone", "-q", "--", "https://github.com/" + repository + ".git", path])

        let runner = temporary.runner(at: path)
        _ = try await runner.run(["config", "--local", "credential.helper", "!gh auth git-credential"])
        _ = try await runner.run(["config", "--local", "user.name", "Spooky Test"])
        _ = try await runner.run(["config", "--local", "user.email", "spooky@example.invalid"])
        _ = try await runner.run(["switch", "-q", "-c", branch])

        try Data((branch + "\n").utf8).write(to: URL(fileURLWithPath: path + "/" + branch + ".txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "测试 " + branch])
        _ = try await runner.run(["push", "-q", "-u", "origin", branch])

        let sha = String(decoding: try await runner.run(["rev-parse", "HEAD"]), as: UTF8.self)
            .trimmingCharacters(in: .newlines)

        return (runner, branch, sha)
    }

    /// GitHub 在后台计算能否合并，等它算完。
    private func waitForMergeOptions(_ client: HostingClient, _ request: PullRequest) async throws -> PullRequestMergeOptions {
        for _ in 0 ..< 20 {
            let options = try await client.mergeOptions(for: request)

            guard options.block == .checking else {
                return options
            }

            try await Task.sleep(for: .seconds(2))
        }

        return try await client.mergeOptions(for: request)
    }
}
