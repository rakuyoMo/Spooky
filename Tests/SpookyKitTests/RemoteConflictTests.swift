import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteConflictTests

/// 服务器上的冲突向导仅在显式启用时访问测试专用仓库：三方内容、备份与写回都在 B 上完成。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteConflictTests {
    /// 冲突文件的读取、备份、恢复祖先与手动编辑都经主连接与 SFTP 完成；断线后的写入不会被当作已执行。
    @Test("服务器冲突向导：三方内容、备份、恢复、手动编辑与断线", .timeLimit(.minutes(3)))
    func conflictWizard() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = "冲突 ' [*]?.txt"
            let absolute = fixture.repository + "/" + path

            // 在 B 上构造合并冲突
            try await files.write(Data("base\n".utf8), to: absolute)
            _ = try await runner.run(["add", "-A"])
            _ = try await runner.run(["commit", "-q", "-m", "base"])
            _ = try await runner.run(["checkout", "-q", "-b", "side"])
            try await files.write(Data("theirs\n".utf8), to: absolute)
            _ = try await runner.run(["commit", "-q", "-a", "-m", "theirs"])
            _ = try await runner.run(["checkout", "-q", "main"])
            try await files.write(Data("ours\n".utf8), to: absolute)
            _ = try await runner.run(["commit", "-q", "-a", "-m", "ours"])
            _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])

            let status = try await runner.status()
            let entry = try #require(status.entries.first { $0.path == path })
            let contents = try await service.conflictContents(of: entry)
            let marked = try #require(contents.worktree)

            #expect(contents.ours == Data("ours\n".utf8) && contents.theirs == Data("theirs\n".utf8))
            #expect(try await service.context(head: status.branch.oid).progress?.state == .merge)

            // 恢复祖先版本前在 B 上留下备份
            let recorder = RemoteBackupRecorder()
            try await service.restoreConflicts([entry], to: .base) { await recorder.add($0) }
            let backups = await recorder.paths

            #expect(backups == [path + ".orig"])
            #expect(try await files.read([absolute + ".orig"])[absolute + ".orig"] == marked)
            #expect(try await files.read([absolute])[absolute] == Data("base\n".utf8))

            // 手动编辑经 SFTP 写回，外部改动之后拒绝覆盖
            try await service.saveResolution(Data("edited\n".utf8), for: entry, replacing: Data("base\n".utf8))
            #expect(try await files.read([absolute])[absolute] == Data("edited\n".utf8))

            await #expect(throws: ConflictResolutionError.fileChanged) {
                try await service.saveResolution(Data("again\n".utf8), for: entry, replacing: Data("base\n".utf8))
            }

            try await service.removeBackups(backups)
            #expect(try await files.read([absolute + ".orig"]).isEmpty)

            // 断线中的采用一侧不会执行；重连后文件仍是冲突
            try await remote.interruptMaster()

            await #expect(throws: RemoteConnectionError.self) {
                try await service.resolve([entry], theirs: true)
            }

            _ = try await remote.reconnect()
            #expect(try await runner.status().entries.first { $0.path == path }?.kind == .conflicted)
            #expect(try await service.context(head: status.branch.oid).progress?.state == .merge)

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

// MARK: - RemoteBackupRecorder

/// 收集备份回调交出的路径。
private actor RemoteBackupRecorder {
    /// 已经交出的备份路径。
    private(set) var paths: [String] = []

    /// 追加一批备份路径。
    func add(_ new: [String]) {
        paths += new
    }
}
