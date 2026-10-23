import Foundation
import Testing

@testable import SpookyKit

/// 服务器储藏验收：储藏、恢复与部分储藏都在 B 上执行；仅在显式启用时访问测试专用仓库。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteStashTests {
    /// 部分储藏、快照、带暂存区状态的 Pop 与删除全部经同一主连接在服务器上完成。
    @Test("服务器储藏、部分储藏、Snapshot 与恢复", .timeLimit(.minutes(2)))
    func stashFlow() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let stashes = RepositoryStashes(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let tracked = fixture.repository + "/文件 [*].txt"
            let other = fixture.repository + "/other.txt"

            try await files.write(Data("base\n".utf8), to: tracked)
            try await files.write(Data("base\n".utf8), to: other)
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", "root"])

            // 部分储藏只收走所选文件与所选的未跟踪文件
            try await files.write(Data("changed\n".utf8), to: tracked)
            try await files.write(Data("changed\n".utf8), to: other)
            try await files.write(Data("new\n".utf8), to: fixture.repository + "/新 [*].txt")
            let selected = try await runner.status().entries.filter { $0.path != "other.txt" }
            try await stashes.save(message: "远端 部分", includeUntracked: true, entries: selected)
            #expect(try await runner.status().entries.map(\.path) == ["other.txt"])

            // 快照登记储藏但不改动服务器上的工作区
            let before = try await runner.status()
            try await stashes.snapshot(message: "快照", includeUntracked: false)
            #expect(try await runner.status() == before)

            let list = try await stashes.list()
            #expect(list.map(\.message) == ["快照", "远端 部分"])

            // 先删除快照，再在干净的工作区里 Pop 部分储藏
            try await stashes.drop([list[0]])
            _ = try await runner.run(["--literal-pathspecs", "restore", "--", "other.txt"])
            try await stashes.apply(try #require(try await stashes.list().first), restoreIndex: true, drop: true)
            #expect(Set(try await runner.status().entries.map(\.path)) == ["文件 [*].txt", "新 [*].txt"])
            #expect(try await stashes.list().isEmpty)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 自动储藏后原操作遇到断线：断线错误原样抛出不重试，储藏留在服务器上，原操作没有执行。
    @Test("服务器 Auto Stash 断线不重试写操作", .timeLimit(.minutes(2)))
    func autoStashInterrupted() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let stashes = RepositoryStashes(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = fixture.repository + "/file.txt"

            try await files.write(Data("base\n".utf8), to: path)
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", "root"])
            _ = try await runner.run(["branch", "feature"])
            try await files.write(Data("local\n".utf8), to: path)

            await #expect(throws: RemoteConnectionError.self) {
                try await stashes.stashingLocalChanges(message: "auto", reapply: true) {
                    try await remote.interruptMaster()
                    try await RepositorySync(runner: runner).merge("refs/heads/feature")
                }
            }

            _ = try await remote.reconnect()
            #expect(try await stashes.list().map(\.message) == ["auto"])
            #expect(try await runner.status().entries.isEmpty)

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
