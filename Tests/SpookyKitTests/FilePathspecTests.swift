import Foundation
import Testing

@testable import SpookyKit

// MARK: - FilePathspecTests

/// 单文件 pathspec 对子模块、文件换成的同名目录与带通配字符的路径不多不少。
struct FilePathspecTests {
    /// 子模块换了提交时，补丁是一块两行的 Subproject commit；文件换成同名目录时，文件的补丁不带目录里的新文件，
    /// 路径里的通配字符按字面匹配；暂存区里的子模块改动同样读得出。
    @Test("子模块、文件换目录与通配字符路径的单文件补丁")
    func submoduleAndDirectory() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()

        let runner = fixture.runner
        let old = String(repeating: "a", count: 40)
        let new = String(repeating: "b", count: 40)
        let zero = String(repeating: "0", count: 40)

        let output = try await runner.run(["hash-object", "-w", "--stdin"], input: Data("file\n".utf8))
        let blob = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

        // 目录里的新文件内容不同，不被认成重命名
        let otherOutput = try await runner.run(["hash-object", "-w", "--stdin"], input: Data("other\n".utf8))
        let other = String(decoding: otherOutput, as: UTF8.self).trimmingCharacters(in: .newlines)

        // 第一个提交：子模块 sub 与文件 d[1]
        try await Self.updateIndex("160000 commit \(old)\tsub\u{0}100644 blob \(blob)\td[1]\u{0}", runner: runner)
        _ = try await runner.run(["commit", "-qm", "base"])

        // 第二个提交：子模块换了提交，d[1] 从文件换成目录
        try await Self.updateIndex(
            "160000 commit \(new)\tsub\u{0}0 \(zero)\td[1]\u{0}100644 blob \(other)\td[1]/x\u{0}",
            runner: runner
        )
        _ = try await runner.run(["commit", "-qm", "change"])

        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let history = RepositoryHistory(runner: runner)
        let changes = try await history.changes(in: head)

        #expect(Set(changes.map(\.path)) == ["sub", "d[1]", "d[1]/x"])

        // 子模块：一块，旧哈希删去、新哈希加入
        let submodule = try #require(changes.first { $0.path == "sub" })
        let submoduleDiff = try #require(try await history.diff(in: head, file: submodule).diff)

        #expect(submoduleDiff.files.count == 1)
        #expect(submoduleDiff.files.first?.hunks.count == 1)
        #expect(Self.lines(submoduleDiff) == ["-Subproject commit \(old)", "+Subproject commit \(new)"])

        // 文件换成目录：文件的补丁只有它自己，目录里的新文件单独读得出
        let file = try #require(changes.first { $0.path == "d[1]" })
        let fileDiff = try #require(try await history.diff(in: head, file: file).diff)

        #expect(fileDiff.files.map { $0.headers.first } == ["diff --git a/d[1] b/d[1]"])

        let child = try #require(changes.first { $0.path == "d[1]/x" })
        let childDiff = try #require(try await history.diff(in: head, file: child).diff)

        #expect(childDiff.files.map { $0.headers.first } == ["diff --git a/d[1]/x b/d[1]/x"])

        // 暂存区里的子模块改动按同样的 pathspec 读出
        try await Self.updateIndex("160000 commit \(old)\tsub\u{0}", runner: runner)

        let arguments = RepositoryFileViews.filePathOptions
            + ["diff", "--cached", "--"]
            + RepositoryFileViews.filePathspecs(["sub"])

        let staged = try await runner.run(arguments)
        let stagedDiff = try RepositoryDiff(patch: staged)

        #expect(Self.lines(stagedDiff) == ["-Subproject commit \(new)", "+Subproject commit \(old)"])
    }
}

// MARK: - Helpers

extension FilePathspecTests {
    /// 按 `--index-info` 的格式直接写入索引，模式为 0 的一项从索引里删去。
    private static func updateIndex(_ info: String, runner: GitRunner) async throws {
        _ = try await runner.run(["update-index", "--add", "-z", "--index-info"], input: Data(info.utf8))
    }

    /// 补丁里的全部改动行，前缀与内容连在一起。
    private static func lines(_ diff: RepositoryDiff) -> [String] {
        diff.files
            .flatMap(\.hunks)
            .flatMap(\.lines)
            .filter(\.isChange)
            .map { String(decoding: [$0.prefix] + $0.content, as: UTF8.self) }
    }
}
