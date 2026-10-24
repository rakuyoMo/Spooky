import Foundation
import Testing

@testable import SpookyKit

// MARK: - HistoryDetailsTests

/// 真实 Git 验证合并提交的三种 Diff 方式、历史文件树与两个版本的比较。
struct HistoryDetailsTests {
    /// 冲突解决过的合并：第一父列出相对第一父的全部改动，组合 Diff 只列出两侧都改过的文件，不显示时为空。
    @Test("合并提交的三种 Diff 方式", arguments: ["sha1", "sha256"])
    func mergeModes(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let path = "合并 [*]'\".txt"

        try await commit(fixture, files: [path: "a\nb\nc\n", "g.txt": "x\n"], message: "root")
        _ = try await runner.run(["switch", "-q", "-c", "side"])
        try await commit(fixture, files: [path: "a\nB\nc\n", "h.txt": "side\n"], message: "side")
        _ = try await runner.run(["switch", "-q", "main"])
        try await commit(fixture, files: [path: "a\nb\nC\n", "g.txt": "y\n"], message: "main")

        // 相邻两行的改动在合并时冲突，手工解决后提交
        _ = try await runner.execute(["merge", "--no-edit", "side"], acceptedExitCodes: [0, 1])
        try await commit(fixture, files: [path: "a\nB\nC\nresolved\n"], message: "merge")

        let merge = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let history = RepositoryHistory(runner: runner)

        let first = try await history.changes(in: merge, mergeMode: .firstParent)
        #expect(Set(first.map(\.path)) == [path, "h.txt"])
        #expect(first.first { $0.path == path }?.additions == 2)

        #expect(try await history.changes(in: merge, mergeMode: .off).isEmpty)

        let combined = try await history.changes(in: merge, mergeMode: .mergedFilePaths)
        let file = try #require(combined.first)
        #expect(combined.map(\.path) == [path])
        #expect(file.status == "M" && file.additions == nil)

        // 组合补丁折成单列：两侧各自删除的行、各自新增的行与解决时新增的行
        let diff = try #require(try await history.diff(in: merge, file: file, mergeMode: .mergedFilePaths).diff)
        let lines = try #require(diff.files.first?.hunks.first?.lines)
        #expect(lines.map { String(decoding: [$0.prefix], as: UTF8.self) } == [" ", "-", "+", "-", "+", "+"])
        #expect(lines.map { String(decoding: $0.content, as: UTF8.self) } == ["a", "b", "B", "c", "C", "resolved"])
        #expect(lines.map(\.newNumber) == [1, nil, 2, nil, 3, 4])
        #expect(lines.map(\.oldNumber) == [1, 2, nil, nil, nil, nil])

        // 普通提交不受方式影响，组合 Diff 下仍有增删行数
        let parent = try await RepositoryReferences(runner: runner).resolve("HEAD^1")
        #expect(try await history.changes(in: parent, mergeMode: .mergedFilePaths).first { $0.path == "g.txt" }?.additions == 1)
        #expect(try await history.changes(in: parent, mergeMode: .off).count == 2)
    }

    /// 八爪鱼合并有三个父提交；没有冲突的合并在组合 Diff 下没有文件。
    @Test("八爪鱼合并与干净合并的组合 Diff", arguments: ["sha1", "sha256"])
    func octopus(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner

        try await commit(fixture, files: ["base.txt": "base\n"], message: "root")

        for branch in ["one", "two"] {
            _ = try await runner.run(["switch", "-q", "-c", branch, "main"])
            try await commit(fixture, files: [branch + ".txt": branch + "\n"], message: branch)
        }

        _ = try await runner.run(["switch", "-q", "main"])
        try await commit(fixture, files: ["main.txt": "main\n"], message: "main")
        _ = try await runner.run(["merge", "-q", "-m", "octopus", "one", "two"])

        let merge = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let history = RepositoryHistory(runner: runner)

        #expect(try await history.changes(in: merge).map(\.path).sorted() == ["one.txt", "two.txt"])
        #expect(try await history.changes(in: merge, mergeMode: .mergedFilePaths).isEmpty)
        #expect(try await history.changes(in: merge, mergeMode: .off).isEmpty)
    }

    /// 组合 Diff 的 raw 与补丁格式；格式错误不能显示成不完整的数据。
    @Test("组合 Diff 的解析与格式错误")
    func combinedParsing() throws {
        let hash = String(repeating: "a", count: 64)
        let raw = "::100644 100644 100644 \(hash) \(hash) \(hash) AM\0new\nline.txt\0"
        let files = try CommitFileChange.parse(Data(raw.utf8), combined: true)
        #expect(files.map(\.path) == ["new\nline.txt"])
        #expect(files.first?.status == "M")

        // 统计属于第一父提交，组合请求里对不上单父记录时忽略；普通请求里同样的输出是格式错误
        let mixed = Data(("3\t1\tother\0" + raw).utf8)
        #expect(try CommitFileChange.parse(mixed, combined: true).count == 1)
        #expect(throws: RepositoryReadError.self) { try CommitFileChange.parse(mixed) }

        for malformed in [
            "::100644 100644 \(hash) \(hash) M\0file\0",
            "::100644 100644 100644 \(hash) \(hash) \(hash) M\0file\0",
            "::100644 100644 100644 \(hash) \(hash) \(hash) MZ\0file\0",
            "::100644 100644 100644 \(hash) \(hash) \(hash) MM\0",
        ] {
            #expect(throws: RepositoryReadError.self) { try CommitFileChange.parse(Data(malformed.utf8), combined: true) }
        }

        let patch = "diff --cc f\nindex 1,2..3\n--- a/f\n+++ b/f\n@@@ -1,1 -1,1 +1,1 @@@\n- a\n -b\n++c\n"
        let lines = try #require(try RepositoryDiff(patch: Data(patch.utf8)).files.first?.hunks.first?.lines)
        #expect(lines.map(\.prefix) == [45, 45, 43])

        for malformed in [
            "diff --cc f\n@@@ -1,1 -1,1 +1,1 @@@\n a\n",
            "diff --cc f\n@@@ -1,1 -1,1 +1,1 @@@\n-x a\n",
            "diff --cc f\n@@@ -1,1 +1,1 @@@\n  a\n",
        ] {
            #expect(throws: WorkingCopyError.self) { try RepositoryDiff(patch: Data(malformed.utf8)) }
        }
    }

    /// 文件树逐层列出：特殊字符、子模块条目与 NFD 路径都保留树中存储的形式。
    @Test("历史文件树的逐层条目", arguments: ["sha1", "sha256"])
    func tree(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let special = "目录 [*]/文件 '\"\t\n?.txt"
        let decomposed = "caf\u{65}\u{301}.txt"

        try await commit(fixture, files: [special: "one\n", "top.txt": "top\n"], message: "files")

        // 子模块与 NFD 路径直接写进索引
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let blob = String(
            decoding: try await runner.run(["hash-object", "-w", "--stdin"], input: Data("é\n".utf8)),
            as: UTF8.self
        )
        .trimmingCharacters(in: .newlines)
        _ = try await runner.run(
            ["update-index", "--add", "-z", "--index-info"],
            input: Data("160000 commit \(head)\tmodule\0100644 blob \(blob)\t\(decomposed)\0".utf8)
        )
        _ = try await runner.run(["commit", "-q", "-m", "module"])

        let tip = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let commit = try #require(try await RepositoryHistory(runner: runner).page(roots: [tip], limit: 1).commits.first)
        let views = RepositoryFileViews(runner: runner)
        let root = try await views.entries(ofTree: commit.tree)

        #expect(root.contains { $0.path == "module" && $0.isSubmodule })
        #expect(root.contains { Array($0.path.utf8) == Array(decomposed.utf8) && $0.type == "blob" })

        let directory = try #require(root.first { $0.isDirectory })
        #expect(directory.path == "目录 [*]")

        let children = try await views.entries(ofTree: directory.objectID, in: directory.path)
        #expect(children.map(\.path) == [special])
        #expect(try await views.contents(of: children[0]) == Data("one\n".utf8))

        await #expect(throws: RepositoryReadError.self) { try await views.contents(of: directory) }
        await #expect(throws: RepositoryReadError.self) { try await views.entries(ofTree: "--all") }

        // 类型与模式对不上的记录是格式错误
        let hash = String(repeating: "c", count: 64)

        for record in ["040000 blob \(hash)\tdir\0", "100644 commit \(hash)\tsub\0", "160000 tree \(hash)\tdir\0"] {
            #expect(throws: RepositoryReadError.self) { try TreeEntry.parse(Data(record.utf8)) }
        }
    }

    /// 比较列出目标独有的提交与两侧之间的改动，单个文件的补丁按需读取。
    @Test("两个版本的比较", arguments: ["sha1", "sha256"])
    func comparison(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let references = RepositoryReferences(runner: runner)
        let path = "比较 [*] '\".txt"

        try await commit(fixture, files: [path: "one\n"], message: "base")
        let base = try await references.resolve("HEAD")
        try await commit(fixture, files: [path: "one\ntwo\n"], message: "second")
        try await commit(fixture, files: ["other.bin": "\u{0}\u{1}"], message: "third")
        let target = try await references.resolve("HEAD")

        let comparison = RevisionComparison(runner: runner, base: base, target: target)
        let page = try await comparison.commits(limit: 1)
        #expect(page.commits.map(\.subject) == ["third"])
        #expect(page.hasMore)

        let changes = try await comparison.changes()
        #expect(Set(changes.map(\.path)) == [path, "other.bin"])
        #expect(changes.first { $0.path == "other.bin" }?.additions == nil)

        let file = try #require(changes.first { $0.path == path })
        let lines = try #require(try await comparison.diff(of: file).diff?.files.first?.hunks.first?.lines)
        #expect(lines.filter(\.isChange).map { String(decoding: $0.content, as: UTF8.self) } == ["two"])

        // 反过来比较时没有目标独有的提交，改动方向相反
        let reversed = RevisionComparison(runner: runner, base: target, target: base)
        #expect(try await reversed.commits().commits.isEmpty)
        #expect(try await reversed.changes().first { $0.path == "other.bin" }?.status == "D")

        await #expect(throws: RepositoryReadError.self) {
            try await RevisionComparison(runner: runner, base: "HEAD", target: target).changes()
        }
    }
}

// MARK: - Helpers

extension HistoryDetailsTests {
    /// 写入文件后提交全部改动。
    private func commit(_ fixture: TemporaryRepository, files: [String: String], message: String) async throws {
        for (path, content) in files {
            let url = fixture.directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }

        _ = try await fixture.runner.run(["add", "--all"])
        _ = try await fixture.runner.run(["commit", "-q", "-m", message])
    }
}
