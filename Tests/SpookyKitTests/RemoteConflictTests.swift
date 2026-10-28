import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteConflictTests

/// 服务器上的冲突向导仅在显式启用时访问测试专用仓库：三方内容、恢复与采用一侧都在 B 上完成。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteConflictTests {
    /// 冲突文件的读取、恢复祖先与采用一侧都经主连接在 B 上完成；断线后的写入不会被当作已执行。
    @Test("服务器冲突向导：三方内容、恢复、采用一侧与断线", .timeLimit(.minutes(3)))
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

            #expect(String(decoding: try #require(contents.worktree), as: UTF8.self).contains("<<<<<<<"))
            #expect(contents.ours == Data("ours\n".utf8) && contents.theirs == Data("theirs\n".utf8))
            #expect(try await service.context(head: status.branch.oid).progress?.state == .merge)

            // 恢复祖先版本只改 B 上的工作区，文件仍是冲突，内容不同于两侧即算手动改过
            try await service.restoreConflicts([entry], to: .base)
            #expect(try await files.read([absolute])[absolute] == Data("base\n".utf8))
            #expect(try await service.conflictContents(of: entry).isManuallyEdited)

            // 重新生成冲突后标记回来，不再算手动改过
            try await service.restoreConflicts([entry], to: .unmerged)
            #expect(try await !service.conflictContents(of: entry).isManuallyEdited)

            // 断线中的采用一侧不会执行；重连后文件仍是冲突
            try await remote.interruptMaster()

            await #expect(throws: RemoteConnectionError.self) {
                try await service.resolve([entry], theirs: true)
            }

            _ = try await remote.reconnect()
            #expect(try await runner.status().entries.first { $0.path == path }?.kind == .conflicted)
            #expect(try await service.context(head: status.branch.oid).progress?.state == .merge)

            // 重连后采用对方版本，在 B 上写入并标记解决
            try await service.resolve([entry], theirs: true)
            #expect(try await files.read([absolute])[absolute] == Data("theirs\n".utf8))
            #expect(try await runner.status().entries.allSatisfy { $0.kind != .conflicted })

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
