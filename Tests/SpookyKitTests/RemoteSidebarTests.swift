import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteSidebarTests

/// M7 侧边栏的服务器验收只在显式启用时访问 spooky-test 的独立测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteSidebarTests {
    /// 引用快照、分支状态、置顶归档与标签检出都在 B 上执行，结果与本机一致。
    @Test("服务器上的标签说明、分支状态、置顶归档与标签检出", .timeLimit(.minutes(3)))
    func referencesOnServer() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let refs = RepositoryReferences(runner: runner)
            let branch = "refs/heads/feature/合并"

            _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
            _ = try await runner.run(["branch", "feature/合并"])
            _ = try await runner.run(["tag", "-a", "v1.0", "-m", "Release “1.0”"])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "next"])

            // 置顶与归档写进 B 上的仓库配置，随快照读回
            try await refs.setPinned(true, branches: [branch])
            try await refs.setArchived(true, branches: [branch])

            let snapshot = try await refs.snapshot()
            #expect(snapshot.metadata(for: branch) == BranchMetadata(isPinned: true, isArchived: true))
            #expect(snapshot.references.first { $0.id == "refs/tags/v1.0" }?.message == "Release “1.0”")

            // 没有新提交的分支并入 main，时间来自顶端提交
            let conditions = try await refs.conditions(in: snapshot)
            let condition = try #require(conditions[branch])
            #expect(condition.mergedInto == "refs/heads/main")
            #expect(condition.lastUpdated != nil)

            // 标签检出成分离 HEAD
            try await refs.checkoutTag("refs/tags/v1.0")
            let status = try await runner.status()
            #expect(status.branch.head == nil)

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
