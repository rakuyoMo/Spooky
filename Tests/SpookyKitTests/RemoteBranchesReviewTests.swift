import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteBranchesReviewTests

/// M7 分支整理的服务器验收只在显式启用时访问 spooky-test 的独立测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteBranchesReviewTests {
    /// 与基准分支的比较、分叉点、自动归档的标记与 Update Branch 都在 B 上执行，结论与本机一致。
    @Test("服务器上的分支比较、分叉点、归档标记与 Update Branch", .timeLimit(.minutes(3)))
    func branchesReviewOnServer() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let refs = RepositoryReferences(runner: runner)

            _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
            let root = try await refs.resolve("HEAD")
            _ = try await runner.run(["branch", "merged"])
            _ = try await runner.run(["switch", "-q", "-c", "feature/合并"])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "topic"])
            _ = try await runner.run(["switch", "-q", "main"])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "main moves on"])

            // 已并入与两侧都有提交的分支一次比较，后者经批量预览得到能干净合并
            let snapshot = try await refs.snapshot()
            let tips = Dictionary(
                uniqueKeysWithValues: snapshot.references.filter(\.isLocal).map { ($0.id, $0.objectID) }
            )
            let base = try #require(tips["refs/heads/main"])
            let result = try await refs.compare(tips.filter { $0.key != "refs/heads/main" }, toBase: base)
            #expect(try #require(result["refs/heads/merged"]).isMerged)
            #expect(result["refs/heads/feature/合并"]?.merge == .clean)
            #expect(result["refs/heads/feature/合并"]?.divergence == ReferenceDivergence(ahead: 1, behind: 1))

            let topic = try #require(tips["refs/heads/feature/合并"])
            #expect(try await refs.forkPoint(of: topic, base: base) == root)

            // 自动归档的待审阅标记写进 B 上的仓库配置
            try await refs.setArchived(true, branches: ["refs/heads/merged"], review: true)
            #expect(try await refs.snapshot().metadata(for: "refs/heads/merged").needsArchiveReview)

            // Update Branch 在 B 上检出并合并父分支
            try await RepositorySync(runner: runner)
                .updateBranch("refs/heads/feature/合并", from: "refs/heads/main", rebase: false)
            #expect(try await runner.status().branch.head == "feature/合并")
            #expect(try await refs.forkPoint(of: try await refs.resolve("HEAD"), base: base) == base)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let error = error as? GitError { Issue.record(Comment(rawValue: error.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
