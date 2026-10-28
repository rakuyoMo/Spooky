import Foundation
import Testing

@testable import SpookyKit

/// 服务器 M3 验收仅在显式启用时访问测试专用仓库。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteWorkingCopyTests {
    /// SFTP 与 Git 复用同一测试连接，按行提交后服务器工作区恢复干净。
    @Test("服务器 SFTP、按行暂存、提交、Amend 与永久丢弃", .timeLimit(.minutes(2)))
    func commitFlow() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = "你好 ' [*]?\\ draft.txt"
            let absolute = fixture.repository + "/" + path
            try await files.write(Data("first\nsecond\nthird".utf8), to: absolute)
            #expect(try await files.read([absolute])[absolute] == Data("first\nsecond\nthird".utf8))
            let entry = try #require(try await runner.status().entries.first { $0.path == path })
            let snapshot = try await service.diff(for: entry, side: .unstaged)
            try await service.apply(snapshot, file: 0, hunk: 0, lines: [0, 2])
            #expect(try await runner.run(["show", ":" + path]) == Data("first\nthird".utf8))
            try await service.commit(subject: "远端 cafe\u{301} ' $HOME", body: "第一行\n第二行")
            let context = try await service.context(head: try await runner.status().branch.oid)
            #expect(context.lastMessage == "远端 café ' $HOME\n\n第一行\n第二行")
            #expect(context.committer.contains("spooky@example.invalid"))
            try await service.stageAll(staged: true)
            try await service.commit(subject: "complete", body: "正文", amend: true)
            #expect(try await runner.status().entries.isEmpty)

            try await files.write(Data("discard\n".utf8), to: absolute)
            let untracked = fixture.repository + "/delete [*].txt"
            try await files.write(Data("untracked\n".utf8), to: untracked)
            try await service.discard(try await runner.status().entries, removal: .permanent)
            #expect(try await runner.status().entries.isEmpty)
            #expect(try await files.read([absolute])[absolute] == Data("first\nsecond\nthird".utf8))
            #expect(try await files.read([untracked]).isEmpty)
            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 服务器文件经 SFTP 取到本机缓存，副本路径不含远端目录；清理后副本消失。
    @Test("服务器文件进入本机缓存与清理", .timeLimit(.minutes(2)))
    func fileCache() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let path = "图 片 ' [*]?.txt"
            try await RepositoryFiles(runner: runner).write(Data("remote\n".utf8), to: fixture.repository + "/" + path)

            let cache = RepositoryFileCache(runner: runner)
            let copy = try await cache.workingTreeFile(path)
            #expect(copy.lastPathComponent == path)
            #expect(!copy.path.contains(fixture.repository))
            #expect(try Data(contentsOf: copy) == Data("remote\n".utf8))

            cache.removeAll()
            #expect(!FileManager.default.fileExists(atPath: copy.path))
            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 断线后的写入必须失败，重连核对不能制造成功提交。
    @Test("服务器旧 Diff 与断线提交拒绝", .timeLimit(.minutes(2)))
    func disconnectedWrite() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = fixture.repository + "/file"
            try await files.write(Data("one\ntwo\n".utf8), to: path)
            let entry = try #require(try await runner.status().entries.first { $0.path == "file" })
            let snapshot = try await service.diff(for: entry, side: .unstaged)
            try await files.write(Data("external\n".utf8), to: path)
            await #expect(throws: WorkingCopyError.staleSnapshot) {
                try await service.apply(snapshot, file: 0, hunk: 0)
            }
            try await service.stageAll(staged: true)
            try await remote.interruptMaster()
            await #expect(throws: RemoteConnectionError.self) {
                try await service.commit(subject: "must not succeed", body: "")
            }
            _ = try await remote.reconnect()
            #expect(try await runner.status().branch.oid == nil)
            #expect(try await runner.status().entries.contains(where: \.hasStagedChanges))
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
