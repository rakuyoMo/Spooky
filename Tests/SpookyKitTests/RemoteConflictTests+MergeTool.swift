import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteConflictTests + MergeTool

extension RemoteConflictTests {
    /// 服务器上的冲突交给本机合并工具：三方副本与结果文件只在本机缓存里，结果核对后写回 B 再暂存；没有结果或核对失败时文件仍是冲突。
    @Test("服务器冲突交给合并工具：缓存副本、取消、核对失败与写回")
    func mergeTool() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
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

            let entry = try #require(try await runner.status().entries.first { $0.path == path })
            let cache = RepositoryFileCache(runner: runner)
            defer { cache.removeAll() }
            let merge = try await ExternalToolFiles(cache: cache).prepareMerge(entry)
            let service = WorkingCopyOperations(runner: runner)

            // 三方副本取自 B 的索引，结果文件是 B 上带冲突标记的工作区内容
            #expect(try Data(contentsOf: merge.local) == Data("ours\n".utf8))
            #expect(try Data(contentsOf: merge.remote) == Data("theirs\n".utf8))
            #expect(try String(decoding: Data(contentsOf: merge.merged), as: UTF8.self).contains("<<<<<<<"))

            // 工具没有写结果文件即为取消：没有结果，B 上仍是冲突
            #expect(try merge.result() == nil)
            #expect(try await runner.status().entries.first { $0.path == path }?.kind == .conflicted)

            // 工具运行期间 B 上的文件被改过：拒绝写回，仍是冲突
            let marked = try #require(try await files.read([absolute])[absolute])
            try await files.write(Data("edited elsewhere\n".utf8), to: absolute)

            await #expect(throws: ExternalToolError.fileChanged) {
                try await service.applyMergeResult(Data("merged\n".utf8), for: merge, keepBackup: false)
            }

            #expect(try await runner.status().entries.first { $0.path == path }?.kind == .conflicted)

            // 改回准备时的内容后写回：结果写到 B 上并暂存，冲突解决
            try await files.write(marked, to: absolute)
            try await service.applyMergeResult(Data("merged\n".utf8), for: merge, keepBackup: false)

            let resolved = try await runner.status().entries.first { $0.path == path }

            #expect(try await files.read([absolute])[absolute] == Data("merged\n".utf8))
            #expect(resolved?.kind != .conflicted && resolved?.staged == .modified)

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
