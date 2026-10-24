import Foundation
import Testing

@testable import SpookyKit

// MARK: - DiffOptionsTests

/// 上下文行数、显示整个文件与忽略空白改变了 Diff 的分块，按块 / 按行写回的结果必须与选择一致。
struct DiffOptionsTests {
    /// 上下文只有 1 行时远处的两处改动分成两块，只暂存第二块不会碰到第一块。
    @Test("少量上下文下按块暂存")
    func narrowContext() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: (1 ... 20).map { "line \($0)" })
        try write((1 ... 20).map { [2, 18].contains($0) ? "changed \($0)" : "line \($0)" }, to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let snapshot = try await service.diff(for: entry, side: .unstaged, options: DiffOptions(contextLines: 1))
        let diff = try #require(snapshot.diff)

        // 两处改动相隔十几行，1 行上下文不会把它们并成一块
        #expect(diff.files.first?.hunks.count == 2)
        #expect(diff.files.first?.hunks.first?.lines.count == 4)

        try await service.apply(snapshot, file: 0, hunk: 1)
        let index = try await indexText(in: repository)
        #expect(index.contains("changed 18"))
        #expect(!index.contains("changed 2\n"))
    }

    /// 显示整个文件时整份文件是一块，选中中间的一行暂存，丢弃另一行，其余改动保持原样。
    @Test("显示整个文件下按行暂存与丢弃")
    func entireFile() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: (1 ... 30).map { "line \($0)" })
        try write((1 ... 30).map { [3, 15, 28].contains($0) ? "changed \($0)" : "line \($0)" }, to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let options = DiffOptions(showsEntireFile: true)
        let snapshot = try await service.diff(for: entry, side: .unstaged, options: options)
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)

        // 整个文件都是上下文，全部 30 行原文加上 3 行新内容都在同一块里
        #expect(snapshot.diff?.files.first?.hunks.count == 1)
        #expect(hunk.lines.count == 33)

        let added = try #require(hunk.lines.first { $0.prefix == 43 && $0.content == Data("changed 15".utf8) })
        let removed = try #require(hunk.lines.first { $0.prefix == 45 && $0.content == Data("line 15".utf8) })
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [added.id, removed.id])
        #expect(try await indexText(in: repository) == text((1 ... 30).map { $0 == 15 ? "changed 15" : "line \($0)" }))

        // 丢弃第 28 行的改动，第 3 行仍是工作区里的新内容
        let current = try #require(try await repository.runner.status().entries.first)
        let unstaged = try await service.diff(for: current, side: .unstaged, options: options)
        let lines = try #require(unstaged.diff?.files.first?.hunks.first?.lines)
        let target = Set(lines.filter { $0.isChange && $0.content.contains(Data("28".utf8)) }.map(\.id))
        try await service.apply(unstaged, file: 0, hunk: 0, lines: target, discard: true)
        #expect(try String(contentsOf: file, encoding: .utf8).contains("changed 3\n"))
        #expect(try String(contentsOf: file, encoding: .utf8).contains("line 28\n"))
    }

    /// 大 Diff 警告按显示的这份补丁的字节数判断：同一处改动在显示整个文件时可能超过阈值，放行后才解析。
    @Test("显示整个文件时的大 Diff 警告")
    func entireFileThreshold() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: (1 ... 3000).map { "line \($0)" })
        try write((1 ... 3000).map { $0 == 1500 ? "changed" : "line \($0)" }, to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let narrow = try await service.diff(for: entry, side: .unstaged, warningKilobytes: 1)
        #expect(narrow.byteCount < 1000)
        #expect(narrow.diff != nil)

        let options = DiffOptions(showsEntireFile: true)
        let whole = try await service.diff(for: entry, side: .unstaged, options: options, warningKilobytes: 1)
        #expect(whole.byteCount > 1000)
        #expect(whole.diff == nil)

        let shown = try await service.diff(
            for: entry,
            side: .unstaged,
            options: options,
            warningKilobytes: 1,
            showLarge: true
        )
        #expect(shown.diff?.files.first?.hunks.first?.lines.count == 3001)
    }

    /// 忽略空白时只写回显示出的改动：缩进变化留在工作区，真正的修改进入暂存区。
    @Test("忽略空白下按块暂存与丢弃")
    func ignoredWhitespace() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: ["func a() {", "one", "two", "}"])
        try write(["func a() {", "    one", "    two", "}", "three"], to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let options = DiffOptions(ignoresWhitespace: true)
        let snapshot = try await service.diff(for: entry, side: .unstaged, options: options)
        let hunk = try #require(snapshot.diff?.files.first?.hunks.first)

        // 缩进变化不显示，只剩末尾新增的一行
        #expect(hunk.lines.filter(\.isChange).map(\.content) == [Data("three".utf8)])

        try await service.apply(snapshot, file: 0, hunk: 0)
        #expect(try await indexText(in: repository) == text(["func a() {", "one", "two", "}", "three"]))

        // 丢弃同样只撤掉显示出的改动，缩进仍留在工作区
        let current = try #require(try await repository.runner.status().entries.first)
        try write(["func a() {", "    one", "    two", "}", "three", "four"], to: file)
        let refreshed = try #require(try await repository.runner.status().entries.first { $0.path == current.path })
        let unstaged = try await service.diff(for: refreshed, side: .unstaged, options: options)
        try await service.apply(unstaged, file: 0, hunk: 0, discard: true)
        let discarded = try String(contentsOf: file, encoding: .utf8)
        #expect(discarded == text(["func a() {", "    one", "    two", "}", "three"]))
    }

    /// 只剩空白差异时显示为空并给出标记；快照仍按逐字节内容校验，外部只改空白也会被拒绝写入。
    @Test("只有空白改动与只改空白的外部编辑")
    func whitespaceOnly() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: ["a", "b"])
        try write(["a ", "b"], to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let options = DiffOptions(ignoresWhitespace: true)
        let whitespace = try await service.diff(for: entry, side: .unstaged, options: options)
        #expect(whitespace.onlyWhitespaceChanges)
        #expect(try #require(whitespace.diff).files.isEmpty)

        try write(["a ", "b", "c"], to: file)
        let snapshot = try await service.diff(for: entry, side: .unstaged, options: options)
        #expect(!snapshot.onlyWhitespaceChanges)

        // 忽略空白的补丁不变，逐字节的补丁变了，写入前的核对必须发现
        try write(["a  ", "b", "c"], to: file)
        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await service.apply(snapshot, file: 0, hunk: 0)
        }
    }

    /// 忽略空白与逐字节比较对齐方式不同时，拒绝生成补丁，暂存区保持不变。
    @Test("忽略空白的行对应不上时拒绝写入")
    func whitespaceMismatch() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: ["a", "b"])
        try write(["b ", "a"], to: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let options = DiffOptions(ignoresWhitespace: true)
        let snapshot = try await service.diff(for: entry, side: .unstaged, options: options)
        let deletion = try #require(snapshot.diff?.files.first?.hunks.first?.lines.first { $0.prefix == 45 })

        await #expect(throws: WorkingCopyError.whitespaceMismatch) {
            try await service.apply(snapshot, file: 0, hunk: 0, lines: [deletion.id])
        }

        #expect(try await indexText(in: repository) == text(["a", "b"]))
    }

    /// 历史补丁同样遵循上下文与忽略空白；只改空白的文件得到空补丁和标记。
    @Test("历史 Diff 的上下文与忽略空白")
    func historyOptions() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }

        let (service, file) = try await committedFile(in: repository, lines: (1 ... 12).map { "line \($0)" })
        try write((1 ... 12).map { $0 == 6 ? "line \($0) " : "line \($0)" }, to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "space", body: "")

        let history = RepositoryHistory(runner: repository.runner)
        let commit = try #require(try await repository.runner.status().branch.oid)
        let change = try #require(try await history.changes(in: commit).first)

        let narrow = try await history.diff(in: commit, file: change, options: DiffOptions(contextLines: 1))
        #expect(narrow.diff?.files.first?.hunks.first?.lines.count == 4)

        let whole = try await history.diff(in: commit, file: change, options: DiffOptions(showsEntireFile: true))
        #expect(whole.diff?.files.first?.hunks.first?.lines.count == 13)

        let ignored = try await history.diff(in: commit, file: change, options: DiffOptions(ignoresWhitespace: true))
        #expect(ignored.onlyWhitespaceChanges)
        #expect(!narrow.onlyWhitespaceChanges)
    }

    /// `index` 头给出两侧对象；全零、缺失与格式不对时没有对象。
    @Test("文件段的对象哈希")
    func objectIDs() throws {
        let old = String(repeating: "1", count: 40)
        let new = String(repeating: "a", count: 64)
        let parsed = try RepositoryDiff(patch: Data("""
            diff --git a/x b/x
            index \(old)..\(new) 100644
            Binary files a/x and b/x differ

            """.utf8))
        #expect(parsed.files.first?.objectIDs.old == old)
        #expect(parsed.files.first?.objectIDs.new == new)

        let added = try RepositoryDiff(patch: Data("""
            diff --git a/x b/x
            new file mode 100644
            index \(String(repeating: "0", count: 40))..\(old)
            Binary files /dev/null and b/x differ

            """.utf8))
        #expect(added.files.first?.objectIDs.old == nil)
        #expect(added.files.first?.objectIDs.new == old)

        let malformed = try RepositoryDiff(patch: Data("diff --git a/x b/x\nindex \(old)\n".utf8))
        #expect(malformed.files.first?.objectIDs.old == nil)
        #expect(malformed.files.first?.objectIDs.new == nil)
    }

    /// 图片两侧分别来自对象库与工作区；暂存侧两边都取对象，新增文件没有旧图。
    @Test("图片 Diff 两侧的内容")
    func imageContents() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let service = WorkingCopyOperations(runner: repository.runner)
        let image = repository.directory.appending(path: "图 片.png")
        let first = Data([0x89, 0x50, 0x4E, 0x47, 0, 1, 2])
        let second = Data([0x89, 0x50, 0x4E, 0x47, 0, 3, 4, 5])
        try first.write(to: image)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "image", body: "")
        try second.write(to: image)

        let source = DiffImageSource(runner: repository.runner)
        let entry = try #require(try await repository.runner.status().entries.first)
        let unstaged = try #require(try await service.diff(for: entry, side: .unstaged).diff?.files.first)
        #expect(unstaged.isBinary)

        let worktree = try await source.contents(of: unstaged, path: entry.path, newFromWorkingTree: true)
        #expect(worktree.old == first)
        #expect(worktree.new == second)

        try await service.stageAll(staged: true)
        let staged = try #require(try await repository.runner.status().entries.first)
        let indexFile = try #require(try await service.diff(for: staged, side: .staged).diff?.files.first)
        let index = try await source.contents(of: indexFile, path: staged.path, newFromWorkingTree: false)
        #expect(index.old == first)
        #expect(index.new == second)

        let added = repository.directory.appending(path: "new.png")
        try first.write(to: added)
        let untracked = try #require(try await repository.runner.status().entries.first { $0.kind == .untracked })
        let addedFile = try #require(try await service.diff(for: untracked, side: .unstaged).diff?.files.first)
        let addedContents = try await source.contents(of: addedFile, path: untracked.path, newFromWorkingTree: true)
        #expect(addedContents.old == nil)
        #expect(addedContents.new == first)
    }
}

// MARK: - Helpers

extension DiffOptionsTests {
    /// 提交一个固定内容的文件，返回工作区服务与文件位置。
    private func committedFile(
        in repository: TemporaryRepository,
        lines: [String]
    ) async throws -> (WorkingCopyOperations, URL) {
        try await repository.initialize()

        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "file")
        try write(lines, to: file)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        return (service, file)
    }

    /// 暂存区里的文件内容。
    private func indexText(in repository: TemporaryRepository) async throws -> String {
        String(decoding: try await repository.runner.run(["show", ":file"]), as: UTF8.self)
    }

    /// 每行带换行的文件内容。
    private func write(_ lines: [String], to file: URL) throws {
        try Data(text(lines).utf8).write(to: file)
    }

    /// 每行末尾都有换行的文本。
    private func text(_ lines: [String]) -> String {
        lines.map { $0 + "\n" }.joined()
    }
}
