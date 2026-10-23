import Foundation
import Testing

@testable import SpookyKit

/// M4 服务器验收只在显式启用时访问 spooky-test 的独立测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteHistorySyncTests {
    /// 两个工作区和裸仓库都在 B 上，验证操作没有落到 A 的文件系统。
    @Test("服务器历史、分支、首次发布、Fetch、Pull 与 Push", .timeLimit(.minutes(3)))
    func dailyFlow() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()
        let otherPath = fixture.root + "/other"
        let otherRemote = RemoteConnection(
            host: "spooky-test",
            path: otherPath,
            configuration: RemoteFixture.configuration
        )

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let refs = RepositoryReferences(runner: runner)
            let sync = RepositorySync(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let working = WorkingCopyOperations(runner: runner)
            let bare = fixture.root + "/remote.git"
            _ = try await runner.run(["init", "--bare", bare])
            _ = try await runner.run(["remote", "add", "origin", bare])
            try await files.write(Data("base\n".utf8), to: location.path + "/你好 [*].txt")
            try await working.stageAll(staged: true)
            try await working.commit(subject: "服务器根提交", body: "完整正文")
            try await refs.create(name: "topic/远端", startingAt: "HEAD", track: false, checkout: true)
            try await files.write(Data("base\nbranch\n".utf8), to: location.path + "/你好 [*].txt")
            try await working.stageAll(staged: true)
            try await working.commit(subject: "分支提交", body: "")
            try await refs.checkout("refs/heads/main")
            guard case .clean = try await sync.previewMerge("refs/heads/topic/远端") else {
                throw RepositoryReadError.malformedOutput("merge preview")
            }
            var options = MergeOptions()
            options.alwaysCreateCommit = true
            try await sync.merge("refs/heads/topic/远端", options: options)
            let history = RepositoryHistory(runner: runner)
            let head = try await refs.resolve("HEAD")
            let page = try await history.page(roots: [head], limit: 2)
            #expect(page.commits.count == 2 && page.hasMore)
            #expect(page.commits.first?.parents.count == 2)
            let change = try #require(try await history.changes(in: head).first)
            #expect(change.path == "你好 [*].txt")
            let commitDiff = try await history.diff(in: head, file: change)
            #expect(!(commitDiff.diff?.files.first?.hunks.isEmpty ?? true))
            _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: true)
            _ = try await runner.run(["clone", "-b", "main", bare, otherPath])
            let otherLocation = try await otherRemote.open().location
            let other = GitRunner(location: otherLocation, remote: otherRemote)
            _ = try await other.run(["config", "--local", "user.name", "Other"])
            _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
            _ = try await other.run(["config", "--local", "commit.gpgSign", "false"])
            _ = try await other.run(["commit", "--allow-empty", "-m", "another workspace"])
            _ = try await RepositorySync(runner: other)
                .push(branch: "main", remote: "origin", destination: "main", setUpstream: false)
            _ = try await sync.fetch(prune: true)
            #expect(try await runner.status().branch.behind == 1)
            try await sync.pull(rebase: false)
            #expect(try await refs.resolve("HEAD") == RepositoryReferences(runner: other).resolve("HEAD"))
            _ = try await runner.run(["commit", "--allow-empty", "-m", "local side"])
            _ = try await other.run(["commit", "--allow-empty", "-m", "other side"])
            _ = try await RepositorySync(runner: other)
                .push(branch: "main", remote: "origin", destination: "main", setUpstream: false)
            try await sync.pull(rebase: true)
            _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: false)
            #expect(try await runner.status().entries.isEmpty)
            #expect(try await runner.status().branch.ahead == 0)
            try await refs.delete(["refs/heads/topic/远端"])
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

    /// 关闭专属主连接时写入不能自动重试，重连后保留实际未推送状态。
    @Test("服务器推送取消与主连接中断", .timeLimit(.minutes(3)))
    func cancellationAndDisconnect() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let sync = RepositorySync(runner: runner)
            let bare = fixture.root + "/remote.git"
            _ = try await runner.run(["init", "--bare", bare])
            _ = try await runner.run(["remote", "add", "origin", bare])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
            _ = try await sync.push(branch: "main", remote: "origin", destination: "main", setUpstream: true)
            let hook = bare + "/hooks/pre-receive"
            try await RepositoryFiles(runner: runner)
                .write(Data("#!/bin/sh\necho SPOOKY_WAITING >&2\nsleep 30\n".utf8), to: hook)
            _ = try await RemoteFixture.raw(["chmod", "700", hook])
            _ = try await runner.run(["commit", "--allow-empty", "-m", "pending"])

            for disconnect in [false, true] {
                let (events, continuation) = AsyncStream<GitOutputEvent>.makeStream()
                let task = Task {
                    defer { continuation.finish() }
                    return try await sync.push(
                        branch: "main",
                        remote: "origin",
                        destination: "main",
                        setUpstream: false
                    ) {
                        continuation.yield($0)
                    }
                }
                var stderr = Data()
                var waiting = false

                // 直到服务端钩子已经运行才中断，确认测试命中了传输中的操作。
                for await event in events {
                    if case .standardError(let data) = event { stderr.append(data) }
                    if String(decoding: stderr, as: UTF8.self).contains("SPOOKY_WAITING") {
                        waiting = true
                        if disconnect { try await remote.interruptMaster() } else { task.cancel() }
                        break
                    }
                }
                #expect(waiting)
                do {
                    _ = try await task.value
                    Issue.record("中断的推送不能报告成功")
                } catch {
                    #expect(
                        error is CancellationError || error is RemoteConnectionError
                            || ((error as? GitError)?.isCancelled ?? false)
                    )
                }
                _ = try await remote.reconnect()
                #expect(try await runner.status().branch.ahead == 1)
            }
            await remote.close()
            try await fixture.remove()
        } catch {
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
