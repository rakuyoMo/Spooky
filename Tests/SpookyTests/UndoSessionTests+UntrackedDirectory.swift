import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Untracked Directory

/// 整个未跟踪的目录在工作区列表里是一个以 “/” 结尾的条目：暂存、储藏、忽略与丢弃都作用于目录本身，
/// 撤销记录仍按目录里的文件核对与恢复。
extension UndoSessionTests {
    /// 同一个带特殊字符的未跟踪目录依次暂存、储藏、忽略与丢弃，每一步都只作用于这个目录。
    @Test("未跟踪目录条目的暂存、储藏、忽略、丢弃与撤销")
    func untrackedDirectoryEntry() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        defer { Self.emptyTrash(of: session) }

        session.onConfirm = { $0.action() }

        let name = "未跟踪 \"dir\" [*]"
        let folder = fixture.directory.appending(path: name)
        let files = [folder.appending(path: "a.txt"), folder.appending(path: "sub/b.txt")]

        try FileManager.default.createDirectory(at: folder.appending(path: "sub"), withIntermediateDirectories: true)

        for file in files {
            try Data("new\n".utf8).write(to: file)
        }

        await fixture.refresh()

        // 整个目录是一行，未跟踪的文件不逐个列出
        let entry = StatusEntry(kind: .untracked, path: name + "/")

        #expect(session.status?.entries == [entry])

        // 记下的状态逐个列出目录里的文件，撤销菜单照样核对得上
        try await fixture.createBranch("topic")
        #expect(try await Self.settledState(of: session, redo: false) == .available("Branch"))

        // 暂存：目录里的文件逐个成为新增，取消暂存后回到一行
        try await fixture.perform { session.stage([entry], staged: true) }

        #expect(session.status?.entries.map(\.path).sorted() == [name + "/a.txt", name + "/sub/b.txt"])
        #expect(try #require(session.status).entries.allSatisfy { $0.staged == .added })

        try await fixture.perform { session.stage(session.status?.entries ?? [], staged: false) }
        #expect(session.status?.entries == [entry])

        // 储藏：只储藏这个目录，储藏里带着它的文件
        try await fixture.perform {
            _ = session.saveStash(snapshot: false, message: "dir", includeUntracked: true, entries: [entry])
        }

        #expect(try #require(session.status).entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))

        _ = try await fixture.runner.run(["stash", "pop", "-q"])
        await fixture.refresh()
        #expect(session.status?.entries == [entry])

        // 忽略：规则写的是目录本身
        try await fixture.perform { session.ignore([entry], scope: .items, in: .exclude) }

        let exclude = try String(contentsOf: fixture.directory.appending(path: ".git/info/exclude"), encoding: .utf8)

        #expect(exclude.split(separator: "\n").last == "/未跟踪 \"dir\" \\[\\*]/")
        #expect(try #require(session.status).entries.isEmpty)

        try Data().write(to: fixture.directory.appending(path: ".git/info/exclude"))
        await fixture.refresh()
        #expect(session.status?.entries == [entry])

        // 丢弃：整个目录移进废纸篓，是一项
        try await fixture.perform { session.discard([entry]) }

        #expect(!FileManager.default.fileExists(atPath: folder.path))
        #expect(try #require(session.status).entries.isEmpty)
        #expect(Self.trashed(in: session.undoHistory?.undoEntries.last).count == 1)

        // 撤销：目录连同里面的文件回到原处
        try await fixture.perform { session.undoLastOperation() }

        #expect(try files.map { try String(contentsOf: $0, encoding: .utf8) } == ["new\n", "new\n"])
        #expect(session.status?.entries == [entry])
    }
}
