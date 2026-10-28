import Foundation
import Testing

@testable import SpookyKit

/// 用真实 Git 验证补丁的结果，断言未选内容仍留在原处。
struct WorkingCopyOperationsTests {
    /// 恢复到指定版本同时改写暂存区与工作区，旧版本里没有的文件随之删除，路径按字面匹配。
    @Test("文件恢复到指定版本")
    func restoreToRevision() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()

        let service = WorkingCopyOperations(runner: repository.runner)
        let target = repository.directory.appending(path: "文件 *.txt")
        let similar = repository.directory.appending(path: "文件 其它.txt")
        let added = repository.directory.appending(path: "added.txt")

        try Data("one\n".utf8).write(to: target)
        try Data("keep\n".utf8).write(to: similar)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "one", body: "")
        let revision = try #require(try await repository.runner.status().branch.oid)

        try Data("two\n".utf8).write(to: target)
        try Data("new\n".utf8).write(to: added)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "two", body: "")

        try Data("three\n".utf8).write(to: target)
        try Data("changed\n".utf8).write(to: similar)
        try await service.restore(["文件 *.txt", "added.txt"], to: revision)

        // 目标文件的暂存区与工作区都回到旧版本，旧版本里没有的文件被删除
        #expect(try Data(contentsOf: target) == Data("one\n".utf8))
        #expect(try await repository.runner.run(["show", ":文件 *.txt"]) == Data("one\n".utf8))
        #expect(!FileManager.default.fileExists(atPath: added.path))

        // 通配符按字面匹配，名字相近的其它文件保留改动
        #expect(try Data(contentsOf: similar) == Data("changed\n".utf8))
    }

    /// 新文件按非连续行暂存，取消暂存不改变工作区。
    @Test("未跟踪文件、非连续行与字面特殊路径")
    func newFileLines() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let path = "你好 ' \\\" [*]?\t\n.txt"
        let file = repository.directory.appending(path: path)
        try Data("one\ntwo\nthree".utf8).write(to: file)
        let service = WorkingCopyOperations(runner: repository.runner)
        let entry = try #require(try await repository.runner.status().entries.first)
        let snapshot = try await service.diff(for: entry, side: .unstaged)
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [0, 2])
        #expect(try await repository.runner.run(["show", ":" + path]) == Data("one\nthree".utf8))
        #expect(try Data(contentsOf: file) == Data("one\ntwo\nthree".utf8))

        let changed = try #require(try await repository.runner.status().entries.first)
        let staged = try await service.diff(for: changed, side: .staged)
        try await service.apply(staged, file: 0, hunk: 0, lines: [0])
        #expect(try await repository.runner.run(["show", ":" + path]) == Data("three".utf8))
        try await service.stageAll(staged: false)
        #expect(try await repository.runner.status().entries.first?.kind == .untracked)
    }

    /// 删除文件的部分暂存必须保留未选的原行，并能按行恢复工作区。
    @Test("删除文件、末尾无换行与部分丢弃")
    func deletedFile() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let file = repository.directory.appending(path: "file")
        try Data("a\nb\nc".utf8).write(to: file)
        let service = WorkingCopyOperations(runner: repository.runner)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        try FileManager.default.removeItem(at: file)

        let entry = try #require(try await repository.runner.status().entries.first)
        let snapshot = try await service.diff(for: entry, side: .unstaged)
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [1])
        #expect(try await repository.runner.run(["show", ":file"]) == Data("a\nc".utf8))
        #expect(!FileManager.default.fileExists(atPath: file.path))

        let current = try #require(try await repository.runner.status().entries.first)
        let second = try await service.diff(for: current, side: .unstaged)
        try await service.apply(second, file: 0, hunk: 0, lines: [1], discard: true)
        #expect(try Data(contentsOf: file) == Data("c".utf8))
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
        let edited = "extra\r\n" + original.replacingOccurrences(of: "line 25", with: "changed 25")
        try Data(edited.utf8).write(to: file)
        let entry = try #require(try await repository.runner.status().entries.first)
        let diff = try await service.diff(for: entry, side: .unstaged)
        #expect(diff.diff?.files.first?.hunks.count == 2)
        try await service.apply(diff, file: 0, hunk: 1)
        let index = try await repository.runner.run(["show", ":file"])
        #expect(index == Data(original.replacingOccurrences(of: "line 25", with: "changed 25").utf8))

        let current = try #require(try await repository.runner.status().entries.first)
        let stale = try await service.diff(for: current, side: .unstaged)
        try Data((edited + "external\r\n").utf8).write(to: file)
        await #expect(throws: WorkingCopyError.staleSnapshot) {
            try await service.apply(stale, file: 0, hunk: 0, discard: true)
        }
        #expect(try Data(contentsOf: file) == Data((edited + "external\r\n").utf8))
    }

    /// 暂存重命名与同名通配符文件必须独立操作，丢弃回到 HEAD。
    @Test("文件级暂存、重命名、删除与全部丢弃")
    func fileActions() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)

        for name in ["a[1]", "a1", "old"] {
            try Data("base\n".utf8).write(to: repository.directory.appending(path: name))
        }

        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")

        for name in ["a[1]", "a1"] {
            try Data("changed\n".utf8).write(to: repository.directory.appending(path: name))
        }

        let entries = try await repository.runner.status().entries
        try await service.stage(entries.filter { $0.path == "a[1]" }, staged: true)
        #expect(try await repository.runner.run(["show", ":a1"]) == Data("base\n".utf8))
        _ = try await repository.runner.run(["mv", "old", "new"])
        let renamed = try #require(try await repository.runner.status().entries.first { $0.staged == .renamed })
        try await service.stage([renamed], staged: false)
        #expect(try await repository.runner.run(["diff", "--cached", "--name-only"]) == Data("a[1]\n".utf8))
        try await service.stageAll(staged: true)
        try await service.discard(try await repository.runner.status().entries)
        #expect(try await repository.runner.status().entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: repository.directory.appending(path: "old").path))
        #expect(!FileManager.default.fileExists(atPath: repository.directory.appending(path: "new").path))
    }

    /// 二进制提示、空文件与大 Diff 使用补丁字节数，不使用文件大小。
    @Test("二进制、空文件、大 Diff 与类型变化")
    func diffKinds() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        try Data([0, 1, 2, 3]).write(to: repository.directory.appending(path: "binary"))
        try Data().write(to: repository.directory.appending(path: "empty"))
        try Data(String(repeating: "text\n", count: 1000).utf8).write(to: repository.directory.appending(path: "large"))
        let entries = try await repository.runner.status().entries
        let binary = try #require(entries.first { $0.path == "binary" })
        #expect(try await service.diff(for: binary, side: .unstaged).diff?.files.first?.isBinary ?? false)
        let empty = try #require(entries.first { $0.path == "empty" })
        #expect(try await service.diff(for: empty, side: .unstaged).diff?.files.first?.hunks.isEmpty ?? false)
        let large = try #require(entries.first { $0.path == "large" })
        let warning = try await service.diff(for: large, side: .unstaged, warningKilobytes: 1)
        #expect(warning.diff == nil && warning.byteCount > 1000)
        #expect(try await service.diff(for: large, side: .unstaged, warningKilobytes: 1, showLarge: true).diff != nil)
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        try FileManager.default.removeItem(at: repository.directory.appending(path: "empty"))
        try FileManager.default.createSymbolicLink(
            at: repository.directory.appending(path: "empty"), withDestinationURL: URL(fileURLWithPath: "large")
        )
        let type = try #require(try await repository.runner.status().entries.first { $0.path == "empty" })
        #expect(type.unstaged == .typeChanged)
        #expect(try await service.diff(for: type, side: .unstaged).diff?.files.count == 2)
    }

    /// Unicode 信息经 stdin 规范化，修补改写当前提交，钩子失败保持 HEAD。
    @Test("正文、Unicode、Amend、身份与钩子错误", arguments: ["sha1", "sha256"])
    func commits(format: String) async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize(objectFormat: format)
        let service = WorkingCopyOperations(runner: repository.runner)
        try Data("base\n".utf8).write(to: repository.directory.appending(path: "file"))
        try await service.stageAll(staged: true)
        try await service.commit(subject: "cafe\u{301} ' $HOME", body: "正文\n第二行")
        let context = try await service.context(head: try await repository.runner.status().branch.oid)
        let configuration = try await service.commitConfiguration()
        #expect(configuration.userName == "Spooky Test" && configuration.userEmail == "spooky@example.invalid")
        #expect(context.lastMessage == "café ' $HOME\n\n正文\n第二行")
        try await service.commit(subject: "amended", body: "正文", amend: true)
        #expect(try await repository.runner.run(["rev-list", "--count", "HEAD"]) == Data("1\n".utf8))
        let head = try await repository.runner.run(["rev-parse", "HEAD"])
        let hook = repository.directory.appending(path: ".git/hooks/pre-commit")
        try FileManager.default.createDirectory(at: hook.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nprintf 'hook rejected\\n' >&2\nexit 1\n".utf8).write(to: hook)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        let error = await #expect(throws: GitError.self) {
            try await service.commit(subject: "failed", body: "retain", amend: true)
        }
        #expect(error?.exitCode == 1)
        #expect(error?.message.contains("hook rejected") ?? false)
        #expect(try await repository.runner.run(["rev-parse", "HEAD"]) == head)
    }

    /// 整块操作保留文件的新增 / 删除语义，不能留下意外的空文件。
    @Test("完整块的新增、取消暂存和删除")
    func wholeFileChunks() async throws {
        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "file")
        try Data("one\ntwo".utf8).write(to: file)
        let initial = try #require(try await repository.runner.status().entries.first)
        try await service.apply(try await service.diff(for: initial, side: .unstaged), file: 0, hunk: 0)
        let added = try #require(try await repository.runner.status().entries.first)
        try await service.apply(try await service.diff(for: added, side: .staged), file: 0, hunk: 0)
        #expect(try await repository.runner.run(["ls-files", "-z"]).isEmpty)
        #expect(try Data(contentsOf: file) == Data("one\ntwo".utf8))
        try await service.stageAll(staged: true)
        try await service.commit(subject: "base", body: "")
        try FileManager.default.removeItem(at: file)
        let deleted = try #require(try await repository.runner.status().entries.first)
        try await service.apply(try await service.diff(for: deleted, side: .unstaged), file: 0, hunk: 0)
        #expect(try await repository.runner.status().entries.first?.staged == .deleted)
        #expect(try await repository.runner.run(["ls-files", "-z"]).isEmpty)
    }

    /// 复制记录独立于来源文件，NFC / NFD 路径在选择比较时等价。
    @Test("复制状态、Unicode 路径与非 UTF-8 补丁")
    func copiedAndEncodedFiles() async throws {
        let parsed = try WorkingCopyStatus(porcelainV2: Data(
            "2 C. N... 100644 100644 100644 aaaa aaaa C100 café.txt\0source.txt\0".utf8
        ))
        let copy = try #require(parsed.entries.first)
        #expect(copy.staged == .copied)
        #expect(copy.path == "cafe\u{301}.txt")
        #expect(copy.operationPaths == ["café.txt"])

        let repository = try TemporaryRepository()
        defer { repository.remove() }
        try await repository.initialize()
        let service = WorkingCopyOperations(runner: repository.runner)
        let file = repository.directory.appending(path: "cafe\u{301}.txt")
        let content = Data([0xE9, 10, 0xF1, 10])
        try content.write(to: file)
        let entry = try #require(try await repository.runner.status().entries.first)
        let snapshot = try await service.diff(for: entry, side: .unstaged)
        try await service.apply(snapshot, file: 0, hunk: 0, lines: [1])
        #expect(try await repository.runner.run(["show", ":" + entry.path]) == Data([0xF1, 10]))
        #expect(try Data(contentsOf: file) == content)
    }

    /// 损坏的行数、缺失终止符不能进入可写模型。
    @Test("Diff 格式错误拒绝", arguments: [
        "diff --git a/f b/f\n@@ -1 +1 @@\n-a\n",
        "diff --git a/f b/f\n@@ -x +1 @@\n-a\n+b\n",
        "diff --git a/f b/f\n@@ -1 +1 @@\n-a\n+b",
    ])
    func malformed(_ patch: String) {
        #expect(throws: WorkingCopyError.malformedDiff) {
            try RepositoryDiff(patch: Data(patch.utf8))
        }
    }
}
