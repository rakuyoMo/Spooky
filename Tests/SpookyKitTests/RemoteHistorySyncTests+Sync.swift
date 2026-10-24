import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// M7 的同步在 B 上执行：Sync 的三步、变基、带期望值的强推、Push To 与不询问用户的获取。
extension RemoteHistorySyncTests {
    /// 两个工作区与裸仓库都在 B 的测试目录里，所有命令经主连接在 B 上执行。
    @Test("服务器 Sync、Rebase、安全强推、Push To 与后台获取", .timeLimit(.minutes(3)))
    func syncOptions() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()
        let otherRemote = RemoteConnection(
            host: "spooky-test",
            path: fixture.root + "/other",
            configuration: RemoteFixture.configuration
        )

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let sync = RepositorySync(runner: runner)
            let refs = RepositoryReferences(runner: runner)
            let bare = fixture.root + "/remote.git"

            _ = try await runner.run(["init", "--bare", bare])
            _ = try await runner.run(["remote", "add", "origin", bare])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
            _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: true)
            _ = try await runner.run(["clone", "-b", "main", bare, fixture.root + "/other"])

            let other = GitRunner(location: try await otherRemote.open().location, remote: otherRemote)
            _ = try await other.run(["config", "--local", "user.name", "Other"])
            _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
            _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])

            // Sync：别人先推了一个提交，本地变基后推回
            _ = try await other.run(["commit", "--allow-empty", "-m", "other"])
            _ = try await other.run(["push", "-q", "origin", "HEAD:main"])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "local"])

            let steps = Mutex<[SyncStep]>([])
            var options = SyncOptions()
            options.rebase = true

            try await sync.sync(remote: "origin", branch: "refs/heads/main", options: options) { step in
                steps.withLock { $0.append(step) }
            }

            #expect(steps.withLock { $0 } == [.fetch, .pull, .push])
            #expect(try await runner.status().branch.ahead == 0)

            // 改写已推送的提交后，以核对过的远端版本为期望值强推
            _ = try await runner.run(["commit", "--amend", "--allow-empty", "-m", "rewritten"])
            let lease = try await sync.forcePushPreview(
                branch: "refs/heads/main",
                destination: "refs/remotes/origin/main"
            )
            #expect(lease.status == .matchesLastKnown)

            _ = try await sync.push(
                branch: "main",
                remote: "origin",
                destination: "main",
                setUpstream: false,
                lease: lease.destination
            )

            // Push To 写入 Gerrit 形式的评审引用；变基到另一个分支
            _ = try await sync.push(revision: "HEAD", remote: "origin", to: "refs/for/main")
            _ = try await runner.run(["branch", "base", "HEAD~1"])
            _ = try await runner.run(["switch", "-q", "-c", "topic", "HEAD~1"])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "topic"])
            try await sync.rebase(onto: "refs/heads/main")
            #expect(try await refs.resolve("HEAD~1") == refs.resolve("refs/heads/main"))

            // 后台获取不询问用户：B 上的 Git 经中继发起的请求都标明不能询问
            _ = try await RemoteCallbackRequest.$allowsInteraction.withValue(false) {
                try await sync.fetch(remote: "origin", prune: true)
            }

            await otherRemote.close()
            await remote.close()
            try await fixture.remove()
        } catch {
            if let error = error as? GitError { Issue.record(Comment(rawValue: error.message)) }
            await otherRemote.close()
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
