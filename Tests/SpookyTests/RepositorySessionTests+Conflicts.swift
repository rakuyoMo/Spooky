import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 以真实的合并冲突验证横幅与状态头的文字、已解决计数，以及冲突向导的备份记录与清理。
extension RepositorySessionTests {
    /// 两侧要用引用名说明；解决一个冲突后计数与备份都要能追溯，撤回解决与清理备份都由会话完成。
    @Test("合并冲突的标题、已解决计数、恢复冲突与备份清理")
    func conflictSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "spooky-conflict-" + UUID().uuidString
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        UserDefaults.standard.set(true, forKey: RepositorySession.keepsConflictBackupsKey)
        defer { UserDefaults.standard.removeObject(forKey: RepositorySession.keepsConflictBackupsKey) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)
        try await makeConflict(in: directory, runner: runner)

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        // 确认直接执行，模拟用户在确认框里点了主按钮
        session.onConfirm = { _, _, action, _ in action() }
        session.display(location)
        session.refresh()

        try await waitUntil { session.context?.progress != nil && session.history.snapshot != nil }

        #expect(session.operationHeaderTitle == AppLocalization.text("conflict.header.merge", "side", "main"))
        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.merge", "side", "main"))
        #expect(session.conflictCount == 2)

        // 采用对方之前留下备份，横幅能数出已解决的冲突
        let first = try #require(session.status?.entries.first { $0.path == "a.txt" })
        session.resolve([first], theirs: true)
        await session.writeTask?.value

        try await waitUntil { session.resolvedConflictCount == 1 }

        #expect(session.conflictCount == 1)
        #expect(session.currentConflictBackups == ["a.txt.orig"])

        // 已经解决的文件仍可重新生成冲突，但没有我方版本可恢复
        let resolved = try #require(session.status?.entries.first { $0.path == "a.txt" })
        #expect(session.canRestoreConflicts([resolved], to: .unmerged))
        #expect(!session.canRestoreConflicts([resolved], to: .ours))

        session.restoreConflicts([resolved], to: .unmerged, title: "restore")
        await session.writeTask?.value

        try await waitUntil { session.conflictCount == 2 }

        // 清理只删除记录在案的备份文件
        session.removeConflictBackups()
        await session.writeTask?.value

        #expect(session.currentConflictBackups.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "a.txt.orig").path))
    }
}

// MARK: - Helpers

extension RepositorySessionTests {
    /// 在 main 与 side 上分别修改两个文件后合并，留下两个双方修改的冲突。
    private func makeConflict(in directory: URL, runner: GitRunner) async throws {
        /// 写入两个文件并提交。
        func commit(_ content: String, message: String) async throws {
            for name in ["a.txt", "b.txt"] {
                try Data((content + "\n").utf8).write(to: directory.appending(path: name))
            }

            _ = try await runner.run(["add", "-A"])
            _ = try await runner.run(["commit", "-q", "-m", message])
        }

        try await commit("base", message: "base")
        _ = try await runner.run(["checkout", "-q", "-b", "side"])
        try await commit("side", message: "side")
        _ = try await runner.run(["checkout", "-q", "main"])
        try await commit("main", message: "main")
        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [1])
    }

    /// 等到会话的异步读取满足条件；超时时让测试失败，而不是一直等待。
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))

        while !condition() {
            guard .now < deadline else {
                Issue.record("等待会话状态超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
