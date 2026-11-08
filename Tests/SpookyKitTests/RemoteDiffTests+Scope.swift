import Foundation
import Testing

@testable import SpookyKit

extension RemoteDiffTests {
    /// 同一套精确路径、快照与写入检查在服务器执行，文件内容通过 SFTP 读取。
    @Test("服务器单文件补丁边界", arguments: [false, true])
    func remoteScope(ancestor: Bool) async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()
        var failure: (any Error)? = nil

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            try await verifyRemoteScope(fixture, runner: runner, ancestor: ancestor)
        } catch {
            failure = error
        }

        await remote.close()

        // 清理仅针对本测试目录，失败后不重复删除。
        do {
            try await fixture.remove()
        } catch {
            Issue.record("服务器测试目录未清理：\(fixture.root)")
            throw error
        }

        if let failure { throw failure }
    }

    /// 建立真实重命名后验证旁支隔离、独立旧文件保护和两类过期拒绝。
    private func verifyRemoteScope(_ fixture: RemoteFixture, runner: GitRunner, ancestor: Bool) async throws {
        let service = WorkingCopyOperations(runner: runner)
        let files = RepositoryFiles(runner: runner)
        let old = ancestor ? "node" : "old"
        let new = ancestor ? "node/sub/a.txt" : "new"
        let base = (1 ... 12).map { "line \($0)\n" }.joined()
        try await files.write(Data(base.utf8), to: fixture.repository + "/" + old)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        _ = try await runner.run(["mv", "--", old, ".moving"])

        if ancestor {
            _ = try await RemoteFixture.raw([
                "mkdir", "-p", fixture.repository + "/node/sub", fixture.repository + "/node/side",
            ])
        }

        _ = try await runner.run(["mv", "--", ".moving", new])
        let changed = base.replacingOccurrences(of: "line 2\n", with: "changed 2\n")
        try await files.write(Data(changed.utf8), to: fixture.repository + "/" + new)
        let independent = Data([0, 0xFF, 0xFE, 10])

        if !ancestor { try await files.write(independent, to: fixture.repository + "/" + old) }
        let entry = try #require(try await runner.status().entries.first { $0.path == new })
        #expect(entry.originalPath == old)
        let staged = try RepositoryDiff(patch: await service.patch(for: entry, side: .staged, options: DiffOptions()))
        #expect(staged.files.count == 1)
        #expect(staged.files.first?.metadata.rename?.oldPath == old)
        let snapshot = try await service.diff(for: entry, side: .unstaged)
        #expect(snapshot.diff?.files.count == 1)
        let sibling = ancestor ? "node/sub/branch" : "outside"
        let siblingData = Data("sibling\n".utf8)
        try await files.write(siblingData, to: fixture.repository + "/" + sibling)
        _ = try await runner.run(["add", "--", sibling])

        if ancestor {
            try await files.write(siblingData, to: fixture.repository + "/node/side/deeper")
        } else {
            try await files.write(independent + Data([1]), to: fixture.repository + "/" + old)
        }

        #expect(try await service.isCurrent(snapshot))
        await #expect(throws: WorkingCopyError.invalidSelection) {
            try await service.apply(snapshot, file: 0, hunk: 0, lines: [999])
        }
        try await service.apply(snapshot, file: 0, hunk: 0)
        #expect(try await runner.run(["show", ":" + new]) == Data(changed.utf8))
        #expect(try await runner.run(["show", ":" + sibling]) == siblingData)

        let siblingPath = fixture.repository + "/" + sibling

        #expect(try await files.read([siblingPath])[siblingPath] == siblingData)
        try await verifyRemoteStale(fixture, runner: runner, entry: entry, changed: changed)

        if !ancestor {
            let path = fixture.repository + "/" + old
            #expect(try await files.read([path])[path] == independent + Data([1]))
            #expect(try await runner.status().entries.contains { $0.path == old && $0.kind == .untracked })
        }
    }

    /// 内容变化与旧重命名配对都在生产入口拒绝，不能把条目重新绑定到另一目的路径。
    private func verifyRemoteStale(
        _ fixture: RemoteFixture,
        runner: GitRunner,
        entry: StatusEntry,
        changed: String
    ) async throws {
        let service = WorkingCopyOperations(runner: runner)
        let files = RepositoryFiles(runner: runner)
        let path = fixture.repository + "/" + entry.path
        try await files.write(Data((changed + "first\n").utf8), to: path)
        let snapshot = try await service.diff(for: entry, side: .unstaged)
        try await files.write(Data((changed + "second\n").utf8), to: path)
        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await service.apply(snapshot, file: 0, hunk: 0)
        }
        #expect(try await files.read([path])[path] == Data((changed + "second\n").utf8))
        _ = try await runner.run(["mv", "--", entry.path, "other"])
        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await service.diff(for: entry, side: .staged)
        }
    }
}
