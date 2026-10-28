import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 以真实的合并冲突验证横幅的文字、已解决计数与恢复冲突版本。
extension RepositorySessionTests {
    /// 两侧要用引用名说明；解决一个冲突后计数要能追溯；恢复冲突版本只改工作区，不经确认直接执行。
    @Test("合并冲突的标题、已解决计数与恢复冲突")
    func conflictSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "spooky-conflict-" + UUID().uuidString
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await initializeRepository(at: location)
        try await makeConflict(in: directory, runner: runner)

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        // 冲突向导的操作都不需要确认，弹出确认就是错误
        session.onConfirm = { title, _, _, _ in Issue.record("不应弹出确认：\(title)") }
        session.display(location)
        session.refresh()

        try await waitUntil { session.context?.progress != nil && session.history.snapshot != nil }

        #expect(session.operationBannerTitle == AppLocalization.text("conflict.title.merge", "side", "main"))
        #expect(session.conflictCount == 2)

        // 采用对方之后，横幅能数出已解决的冲突
        let first = try #require(session.status?.entries.first { $0.path == "a.txt" })
        session.resolve([first], theirs: true)
        await session.writeTask?.value

        try await waitUntil { session.resolvedConflictCount == 1 }
        #expect(session.conflictCount == 1)

        // 已经解决的文件仍可重新生成冲突，但没有我方版本可恢复
        let resolved = try #require(session.status?.entries.first { $0.path == "a.txt" })
        #expect(session.canRestoreConflicts([resolved], to: .unmerged))
        #expect(!session.canRestoreConflicts([resolved], to: .ours))

        session.restoreConflicts([resolved], to: .unmerged, title: "restore")
        await session.writeTask?.value

        try await waitUntil { session.conflictCount == 2 }
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
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard .now < deadline else {
                Issue.record("等待会话状态超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
