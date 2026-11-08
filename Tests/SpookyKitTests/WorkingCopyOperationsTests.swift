import Foundation
import Testing

@testable import SpookyKit

/// 用真实 Git 验证补丁的结果，断言未选内容仍留在原处。
struct WorkingCopyOperationsTests {
    /// 暂存重命名与同名通配符文件必须独立操作，丢弃回到 HEAD；
    /// 恢复到指定版本同时改写暂存区与工作区，旧版本里没有的文件随之删除，路径按字面匹配。
    @Test("文件级暂存、重命名、丢弃与恢复到指定版本")
    func fileActions() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let target = repository.directory.appending(path: "文件 *.txt")
        let similar = repository.directory.appending(path: "文件 其它.txt")
        let added = repository.directory.appending(path: "added.txt")

        for name in ["a[1]", "a1", "old"] {
            try Data("base\n".utf8).write(to: repository.directory.appending(path: name))
        }

        try Data("one\n".utf8).write(to: target)
        try Data("keep\n".utf8).write(to: similar)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        let revision = try #require(try await repository.runner.status().branch.oid)

        // 只暂存带通配符的文件，名字相近的文件留在工作区
        for name in ["a[1]", "a1"] {
            try Data("changed\n".utf8).write(to: repository.directory.appending(path: name))
        }

        let entries = try await repository.runner.status().entries
        try await service.stage(entries.filter { $0.path == "a[1]" }, staged: true)
        #expect(try await repository.runner.run(["show", ":a1"]) == Data("base\n".utf8))

        // 取消暂存重命名不影响已暂存的其它文件
        _ = try await repository.runner.run(["mv", "old", "new"])
        let renamed = try #require(try await repository.runner.status().entries.first { $0.staged == .renamed })
        try await service.stage([renamed], staged: false)
        #expect(try await repository.runner.run(["diff", "--cached", "--name-only"]) == Data("a[1]\n".utf8))

        // 全部丢弃回到 HEAD，重命名随之撤销
        try await service.stageAll(staged: true)
        try await service.discard(try await repository.runner.status().entries)
        #expect(try await repository.runner.status().entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: repository.directory.appending(path: "old").path))
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "new").path))

        // 新提交改写目标并加入新文件，之后再把两者恢复到第一版
        try Data("two\n".utf8).write(to: target)
        try Data("new\n".utf8).write(to: added)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "two", body: "")

        try Data("three\n".utf8).write(to: target)
        try Data("changed\n".utf8).write(to: similar)
        try await service.restore(["文件 *.txt", "added.txt"], to: revision)

        #expect(try Data(contentsOf: target) == Data("one\n".utf8))
        #expect(try await repository.runner.run(["show", ":文件 *.txt"]) == Data("one\n".utf8))
        #expect(!FileManager.default.fileExists(atPath: added.path))
        #expect(try Data(contentsOf: similar) == Data("changed\n".utf8))
    }

    /// 新文件按非连续行暂存、按行与整块取消暂存都不改变工作区，整块操作保留新增 / 删除语义；
    /// 删除文件的部分暂存保留未选的原行，并能按行恢复工作区。
    @Test("新增与删除文件的按行和整块操作")
    func addedAndDeletedFiles() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)

        // 要按行删除的文件先进入提交，整块操作的新文件保持未跟踪
        try Data("a\nb\nc".utf8).write(to: repository.directory.appending(path: "deleted"))
        try Data("one\ntwo".utf8).write(to: repository.directory.appending(path: "whole"))
        _ = try await repository.runner.run(["add", "--", "deleted"])
        try await service.commit(subject: "base", body: "")

        try await stageNewFileLines(repository, service: service)
        try await stageWholeFile(repository, service: service)
        try await stageDeletedLines(repository, service: service)
    }

    /// 后一块的定位不能带入前一块未暂存的行数偏移。
    @Test("多块定位、CRLF 与旧快照拒绝")
    func staleSnapshotAndLaterHunk() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "file")
        let original = (1 ... 30).map { "line \($0)\r\n" }.joined()

        try Data(original.utf8).write(to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")

        // 开头插入一行、第 25 行改写，只暂存后一块
        let edited = "extra\r\n" + original.replacingOccurrences(of: "line 25", with: "changed 25")
        try Data(edited.utf8).write(to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let diff = try await service.diff(for: entry, side: .unstaged)
        #expect(diff.diff?.files.first?.hunks.count == 2)

        try await service.apply(diff, file: 0, hunk: 1)
        let index = try await repository.runner.run(["show", ":file"])
        #expect(index == Data(original.replacingOccurrences(of: "line 25", with: "changed 25").utf8))

        // 取样之后文件又被改动，旧快照的丢弃被拒绝
        let current = try #require(try await repository.runner.status().entries.first)
        let stale = try await service.diff(for: current, side: .unstaged)
        try Data((edited + "external\r\n").utf8).write(to: file)

        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await service.apply(stale, file: 0, hunk: 0, discard: true)
        }

        #expect(try Data(contentsOf: file) == Data((edited + "external\r\n").utf8))
    }

    /// 二进制提示、空文件与大 Diff 使用补丁字节数，不使用文件大小；
    /// 分解形式 Unicode 路径上的非 UTF-8 内容按行暂存后逐字节保留。
    @Test("二进制、空文件、大 Diff、类型变化与非 UTF-8 内容")
    func diffKinds() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let large = Data(String(repeating: "text\n", count: 1000).utf8)

        try Data([0, 1, 2, 3]).write(to: repository.directory.appending(path: "binary"))
        try Data().write(to: repository.directory.appending(path: "empty"))
        try large.write(to: repository.directory.appending(path: "large"))

        // 二进制与空文件
        let binary = try await entry("binary", in: repository)
        #expect(try await service.diff(for: binary, side: .unstaged).diff?.files.first?.isBinary ?? false)

        let empty = try await entry("empty", in: repository)
        #expect(try await service.diff(for: empty, side: .unstaged).diff?.files.first?.hunks.isEmpty ?? false)

        // 补丁超过提示上限时不解析，明确要求时照常解析
        let largeEntry = try await entry("large", in: repository)
        let warning = try await service.diff(for: largeEntry, side: .unstaged, warningKilobytes: 1)
        #expect(warning.diff == nil && warning.byteCount > 1000)

        let shown = try await service.diff(
            for: largeEntry,
            side: .unstaged,
            warningKilobytes: 1,
            showLarge: true
        )
        #expect(shown.diff != nil)

        try await stageEncodedLines(repository, service: service)

        // 空文件换成符号链接，类型变化读出两个补丁段
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        try FileManager.default.removeItem(at: repository.directory.appending(path: "empty"))
        try FileManager.default.createSymbolicLink(
            at: repository.directory.appending(path: "empty"),
            withDestinationURL: URL(fileURLWithPath: "large")
        )

        let type = try await entry("empty", in: repository)
        #expect(type.unstaged == .typeChanged)
        #expect(try await service.diff(for: type, side: .unstaged).diff?.files.count == 2)
    }

    /// 带特殊字符的新文件按非连续行暂存，再按行取消，最后整体取消暂存回到未跟踪。
    private func stageNewFileLines(
        _ repository: TemporaryRepository,
        service: WorkingCopyOperations
    ) async throws {
        let path = "你好 ' \\\" [*]?\t\n.txt"
        let file = repository.directory.appending(path: path)
        try Data("one\ntwo\nthree".utf8).write(to: file)

        let snapshot = try await service.diff(for: try await entry(path, in: repository), side: .unstaged)
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [0, 2])
        #expect(try await repository.runner.run(["show", ":" + path]) == Data("one\nthree".utf8))
        #expect(try Data(contentsOf: file) == Data("one\ntwo\nthree".utf8))

        let staged = try await service.diff(for: try await entry(path, in: repository), side: .staged)
        try await service.apply(staged, file: 0, hunk: 0, lines: [0])
        #expect(try await repository.runner.run(["show", ":" + path]) == Data("three".utf8))

        try await service.stageAll(staged: false)
        #expect(try await entry(path, in: repository).kind == .untracked)
    }

    /// 整块暂存与取消暂存新文件不留下空文件，整块暂存删除得到删除记录。
    private func stageWholeFile(
        _ repository: TemporaryRepository,
        service: WorkingCopyOperations
    ) async throws {
        let file = repository.directory.appending(path: "whole")

        let initial = try await service.diff(for: try await entry("whole", in: repository), side: .unstaged)
        try await service.apply(initial, file: 0, hunk: 0)

        let added = try await service.diff(for: try await entry("whole", in: repository), side: .staged)
        try await service.apply(added, file: 0, hunk: 0)
        #expect(try await repository.runner.run(["ls-files", "-z", "--", "whole"]).isEmpty)
        #expect(try Data(contentsOf: file) == Data("one\ntwo".utf8))

        // 提交之后删除文件，整块暂存这次删除
        _ = try await repository.runner.run(["add", "--", "whole"])
        try await service.commit(subject: "whole", body: "")
        try FileManager.default.removeItem(at: file)

        let deleted = try await service.diff(for: try await entry("whole", in: repository), side: .unstaged)
        try await service.apply(deleted, file: 0, hunk: 0)
        #expect(try await entry("whole", in: repository).staged == .deleted)
        #expect(try await repository.runner.run(["ls-files", "-z", "--", "whole"]).isEmpty)
    }

    /// 末尾无换行的删除文件只暂存中间一行的删除，再按行丢弃恢复工作区里的一行。
    private func stageDeletedLines(
        _ repository: TemporaryRepository,
        service: WorkingCopyOperations
    ) async throws {
        let file = repository.directory.appending(path: "deleted")
        try FileManager.default.removeItem(at: file)

        let snapshot = try await service.diff(for: try await entry("deleted", in: repository), side: .unstaged)
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [1])
        #expect(try await repository.runner.run(["show", ":deleted"]) == Data("a\nc".utf8))
        #expect(!FileManager.default.fileExists(atPath: file.path))

        let second = try await service.diff(for: try await entry("deleted", in: repository), side: .unstaged)
        try await service.apply(second, file: 0, hunk: 0, lines: [1], discard: true)
        #expect(try Data(contentsOf: file) == Data("c".utf8))
    }

    /// 分解形式路径上的非 UTF-8 新文件只暂存第二行，工作区字节不变。
    private func stageEncodedLines(
        _ repository: TemporaryRepository,
        service: WorkingCopyOperations
    ) async throws {
        let file = repository.directory.appending(path: "cafe\u{301}.txt")
        let content = Data([0xE9, 10, 0xF1, 10])
        try content.write(to: file)

        let encoded = try await entry("cafe\u{301}.txt", in: repository)
        let snapshot = try await service.diff(for: encoded, side: .unstaged)
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [1])

        #expect(try await repository.runner.run(["show", ":" + encoded.path]) == Data([0xF1, 10]))
        #expect(try Data(contentsOf: file) == content)
    }

    /// 按路径取状态条目。
    private func entry(_ path: String, in repository: TemporaryRepository) async throws -> StatusEntry {
        try #require(try await repository.runner.status().entries.first { $0.path == path })
    }
}
