import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Trash

/// 丢弃与删除经废纸篓之后的撤销：会话记下移进废纸篓的位置，撤销时移回原处，重做时再移进去。
extension UndoSessionTests {
    /// 丢弃全部改动先确认：已跟踪的改动恢复到最后一次提交，未跟踪文件进废纸篓；撤销放回，重做再丢弃一次。
    @Test("丢弃全部改动经废纸篓的撤销与重做")
    func discardAllThroughTrash() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        defer { Self.emptyTrash(of: session) }

        let untracked = fixture.directory.appending(path: "未跟踪 ' [x].txt")
        var confirmations = 0

        session.onConfirm = { _, _, action, _ in
            confirmations += 1
            action()
        }

        try fixture.write("changed\n")
        try Data("new\n".utf8).write(to: untracked)
        await fixture.refresh()

        try await fixture.perform { session.discard(session.status?.entries ?? []) }
        #expect(confirmations == 1)
        #expect(try fixture.read() == "base\n")
        #expect(!FileManager.default.fileExists(atPath: untracked.path))

        let location = try #require(session.undoHistory?.undoEntries.last?.trashed.first?.location)
        #expect(FileManager.default.fileExists(atPath: location))
        #expect(
            try await Self.settledState(of: session, redo: false) == .available(AppLocalization.text("working.discard"))
        )

        // 撤销：未跟踪文件从废纸篓移回原处，已跟踪的改动回来
        try await fixture.perform { session.undoLastOperation() }
        #expect(try fixture.read() == "changed\n")
        #expect(try String(contentsOf: untracked, encoding: .utf8) == "new\n")
        #expect(!FileManager.default.fileExists(atPath: location))

        // 重做：再丢弃一次，新的位置留给下一次撤销
        try await fixture.perform { session.redoLastOperation() }
        #expect(try fixture.read() == "base\n")
        #expect(!FileManager.default.fileExists(atPath: untracked.path))

        let again = try #require(session.undoHistory?.undoEntries.last?.trashed.first?.location)
        #expect(FileManager.default.fileExists(atPath: again))
    }

    /// 本机删除不确认，直接移进废纸篓；撤销把文件放回原处。
    @Test("删除经废纸篓的撤销")
    func deleteThroughTrash() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        defer { Self.emptyTrash(of: session) }

        session.onConfirm = { title, _, _, _ in Issue.record("不应弹出确认：\(title)") }

        try await fixture.perform { session.delete([StatusEntry(kind: .unchanged, path: "a b.txt")]) }
        #expect(!FileManager.default.fileExists(atPath: fixture.directory.appending(path: "a b.txt").path))
        #expect(session.undoHistory?.undoEntries.last?.trashed.count == 1)

        try await fixture.perform { session.undoLastOperation() }
        #expect(try fixture.read() == "base\n")
    }
}

// MARK: - Helpers

extension UndoSessionTests {
    /// 从废纸篓删除撤销栈与重做栈里记下的项。
    static func emptyTrash(of session: RepositorySession) {
        let entries = (session.undoHistory?.undoEntries ?? []) + (session.undoHistory?.redoEntries ?? [])

        for location in entries.flatMap(\.trashed).compactMap(\.location) {
            try? FileManager.default.removeItem(atPath: location)
        }
    }
}
