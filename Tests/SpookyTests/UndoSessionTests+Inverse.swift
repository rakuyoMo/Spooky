import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Inverse

/// 由操作自己给出反向操作的撤销：assume-unchanged 的标记与 Git LFS 的启用，以及准备结果与撤销记录的关系。
extension UndoSessionTests {
    /// 标记与取消 assume-unchanged 各自撤销后文件列表随之变化，重做后再次生效；标记本来都在时不占撤销栈。
    @Test("assume-unchanged 的撤销与重做")
    func assumeUnchangedRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let set = AppLocalization.text("files.assumeUnchanged.set")

        try fixture.write("changed\n")
        await fixture.refresh()
        let entry = try #require(session.status?.entries.first)

        // 标记后 Git 不再报告这个文件的改动
        try await fixture.perform { session.setAssumeUnchanged([entry], true) }
        #expect(session.status?.entries.isEmpty ?? false)
        #expect(try await Self.settledState(of: session, redo: false) == .available(set))

        try await fixture.perform { session.undoLastOperation() }
        #expect(session.status?.entries.map(\.path) == [entry.path])

        try await fixture.perform { session.redoLastOperation() }
        #expect(session.status?.entries.isEmpty ?? false)

        // 再标记一次不改动任何标记
        try await fixture.perform { session.setAssumeUnchanged([entry], true) }
        #expect(session.undoHistory?.undoEntries.count == 1)

        // 取消标记：撤销后文件又被标记
        try await fixture.perform { session.setAssumeUnchanged([entry], false) }
        #expect(session.status?.entries.map(\.path) == [entry.path])

        try await fixture.perform { session.undoLastOperation() }
        #expect(session.status?.entries.isEmpty ?? false)

        try await fixture.perform { session.redoLastOperation() }
        #expect(session.status?.entries.map(\.path) == [entry.path])
    }

    /// 启用 Git LFS 撤销后仓库本地没有 LFS 过滤器，重做后又有；本来就启用时再启用只是更新钩子，不占撤销栈。
    @Test("启用 Git LFS 的撤销与重做", .enabled(if: hasLFS, "测试进程的 PATH 里没有 git-lfs"))
    func enableLFSRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let lfs = RepositoryLFS(runner: fixture.runner)

        try await fixture.perform { session.enableLFS() }
        #expect(try await lfs.isInstalledLocally())
        #expect(try await Self.settledState(of: session, redo: false) == .available(AppLocalization.text("lfs.enable")))

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await !lfs.isInstalledLocally())

        try await fixture.perform { session.redoLastOperation() }
        #expect(try await lfs.isInstalledLocally())

        try await fixture.perform { session.enableLFS() }
        #expect(session.undoHistory?.undoEntries.count == 1)
    }

    /// 准备失败时操作照常执行，按不能撤销处理：清空撤销栈，菜单写明上一个操作不能撤销。
    @Test("准备反向操作失败时不能撤销")
    func failedPreparation() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session

        try await fixture.createBranch("topic")
        try await fixture.perform {
            session.performGit(
                { runner, _ in _ = try await runner.run(["config", "--local", "x.y", "z"]) },
                title: "Prepare",
                undo: .inverse { _ in throw RepositoryReadError.invalidQuery }
            )
        }

        #expect(try await Self.settledState(of: session, redo: false) == .irreversible("Prepare"))
        #expect(session.undoHistory?.undoEntries.isEmpty ?? false)
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 测试进程的 PATH 里有 git-lfs：会话的执行器继承这个 PATH。
    nonisolated static let hasLFS = (ProcessInfo.processInfo.environment["PATH"] ?? "")
        .split(separator: ":")
        .contains { FileManager.default.isExecutableFile(atPath: $0 + "/git-lfs") }
}
