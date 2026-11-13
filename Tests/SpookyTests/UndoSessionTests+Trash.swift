import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Trash

/// 丢弃与删除经废纸篓之后的撤销：会话记下移进废纸篓的位置，撤销时移回原处，重做时再移进去。
extension UndoSessionTests {
    /// 丢弃全部改动先确认：已跟踪的改动恢复到最后一次提交，未跟踪文件进废纸篓；撤销放回，重做再丢弃一次。
    /// 本机删除不确认，直接移进废纸篓并暂存删除；撤销把文件与索引项放回原处。
    @Test("丢弃全部改动与删除经废纸篓的撤销")
    func trashRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        defer { Self.emptyTrash(of: session) }

        let untracked = fixture.directory.appending(path: "未跟踪 ' [x].txt")
        let discard = AppLocalization.text("working.discard")
        var confirmations = 0

        session.onConfirm = { request in
            confirmations += 1
            request.action()
        }

        try fixture.write("changed\n")
        try Data("new\n".utf8).write(to: untracked)
        await fixture.refresh()

        // 丢弃全部改动：确认一次，未跟踪文件进废纸篓
        try await fixture.perform { session.discard(session.status?.entries ?? []) }

        #expect(confirmations == 1)
        #expect(try fixture.read() == "base\n")
        #expect(!FileManager.default.fileExists(atPath: untracked.path))

        let location = try #require(Self.trashed(in: session.undoHistory?.undoEntries.last).first?.location)

        #expect(FileManager.default.fileExists(atPath: location))
        #expect(try await Self.settledState(of: session, redo: false) == .available(discard))

        // 撤销：未跟踪文件从废纸篓移回原处，已跟踪的改动回来
        try await fixture.perform { session.undoLastOperation() }

        #expect(try fixture.read() == "changed\n")
        #expect(try String(contentsOf: untracked, encoding: .utf8) == "new\n")
        #expect(!FileManager.default.fileExists(atPath: location))

        // 重做：再丢弃一次，新的位置留给下一次撤销
        try await fixture.perform { session.redoLastOperation() }

        #expect(try fixture.read() == "base\n")
        #expect(!FileManager.default.fileExists(atPath: untracked.path))

        let again = try #require(Self.trashed(in: session.undoHistory?.undoEntries.last).first?.location)
        #expect(FileManager.default.fileExists(atPath: again))

        // 删除：不确认，直接移进废纸篓，删除同时暂存
        try await fixture.perform { session.delete([StatusEntry(kind: .unchanged, path: "a b.txt")]) }

        let deleted = fixture.directory.appending(path: "a b.txt")
        let entry = session.status?.entries.first

        #expect(confirmations == 1)
        #expect(!FileManager.default.fileExists(atPath: deleted.path))
        #expect(entry?.path == "a b.txt" && entry?.staged == .deleted && entry?.unstaged == nil)
        #expect(Self.trashed(in: session.undoHistory?.undoEntries.last).count == 1)

        // 撤销：文件回到原处，索引项随之恢复，工作区回到干净
        try await fixture.perform { session.undoLastOperation() }

        #expect(try fixture.read() == "base\n")
        #expect(try #require(session.status).entries.isEmpty)
    }

    /// 服务器没有废纸篓、确认后的永久删除：撤销按删除前的工作区快照写回已跟踪的文件，索引项、已暂存的内容与
    /// assume-unchanged 标记都回到删除前；其中有未跟踪的项时找不回内容，这次删除不能撤销。
    @Test("永久删除的撤销恢复索引与 assume-unchanged 标记")
    func permanentDeletionUndo() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let runner = fixture.runner
        let assumed = fixture.directory.appending(path: "assumed [x].txt")
        let paths = ["a b.txt", "assumed [x].txt"]

        // 标为 assume-unchanged 的文件与部分暂存的文件
        try Data("base\n".utf8).write(to: assumed)
        _ = try await runner.run(["add", "--", "assumed [x].txt"])
        _ = try await runner.run(["commit", "-q", "-m", "assumed"])
        _ = try await runner.run(["update-index", "--assume-unchanged", "--", "assumed [x].txt"])

        try fixture.write("index\n")
        _ = try await runner.run(["add", "--", "a b.txt"])
        try fixture.write("worktree\n")

        let index = try await runner.run(["ls-files", "-s", "-v", "-z"])
        let inverse = try #require(try await Self.prepareDeletion(paths, removal: .permanent, runner: runner))

        try await WorkingCopyOperations(runner: runner).delete(paths, removal: .permanent)
        #expect(!FileManager.default.fileExists(atPath: assumed.path))

        // 撤销：文件按删除前的工作区写回，索引与标记回到删除前
        try await inverse.undo(runner) { _ in }

        #expect(try await runner.run(["ls-files", "-s", "-v", "-z"]) == index)
        #expect(try fixture.read() == "worktree\n")
        #expect(try String(contentsOf: assumed, encoding: .utf8) == "base\n")

        // 有未跟踪的项时不能撤销
        try Data("new\n".utf8).write(to: fixture.directory.appending(path: "new.txt"))

        await #expect(throws: RepositoryUndoError.untrackedFiles) {
            _ = try await Self.prepareDeletion(["new.txt"], removal: .permanent, runner: runner)
        }
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 从废纸篓删除撤销栈与重做栈里记下的项。
    static func emptyTrash(of session: RepositorySession) {
        let entries = (session.undoHistory?.undoEntries ?? []) + (session.undoHistory?.redoEntries ?? [])

        for location in entries.flatMap({ trashed(in: $0) }).compactMap(\.location) {
            try? FileManager.default.removeItem(atPath: location)
        }
    }

    /// 记录里移进废纸篓的项：快照记录的，或反向操作收集的；没有记录时为空。
    static func trashed(in entry: RepositoryUndoEntry?) -> [TrashedItem] {
        switch entry?.change {
        case .snapshot(_, _, let trashed): trashed
        case .inverse(_, _, _, let inverse): inverse.trashLog?.items ?? []
        case nil: []
        }
    }

    /// 执行删除记录的准备，取出它给出的反向操作。
    static func prepareDeletion(
        _ paths: [String],
        removal: FileRemoval,
        runner: GitRunner
    ) async throws -> UndoInverse? {
        guard case .inverse(let prepare) = UndoRecording.deletingFiles(paths, removal: removal) else {
            return nil
        }

        return try await prepare(runner)
    }
}
