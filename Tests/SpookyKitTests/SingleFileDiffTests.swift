import Foundation
import Testing

@testable import SpookyKit

/// 精确单文件补丁不能因同名目录或路径环境变量混入其它变更。
struct SingleFileDiffTests {
    /// 普通类型变化和祖先重命名都必须只返回目标文件。
    @Test("类型变化与祖先重命名的逐文件补丁", arguments: [false, true], ["sha1", "sha256"])
    func fileDirectoryTransition(rename: Bool, format: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize(objectFormat: format)
        let node = fixture.directory.appending(path: "node")
        try Data("original\n".utf8).write(to: node)
        let base = try await commit(fixture, message: "file")

        try FileManager.default.removeItem(at: node)
        try FileManager.default.createDirectory(at: node.appending(path: "sub"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: node.appending(path: "other"), withIntermediateDirectories: true)
        try Data((rename ? "original\n" : "changed\n").utf8).write(to: node.appending(path: "sub/a.txt"))
        try Data("sibling\n".utf8).write(to: node.appending(path: "sub/b.txt"))
        try Data("branch\n".utf8).write(to: node.appending(path: "other/c.txt"))
        let target = try await commit(fixture, message: "directory")
        let history = RepositoryHistory(runner: fixture.runner)
        let changes = try await history.changes(in: target)

        #expect(changes.count == (rename ? 3 : 4))

        for file in changes {
            let diff = try await history.diff(in: target, file: file)
            #expect(diff.diff?.files.count == 1)

            let comparison = RevisionComparison(runner: fixture.runner, base: base, target: target)
            let compared = try await comparison.diff(of: file)
            #expect(compared.diff?.files.count == 1)

            if file.path == "node/sub/a.txt", rename {
                #expect(file.originalPath == "node")
                #expect(diff.diff?.files.first?.headers.contains("rename from node") ?? false)
            }
        }

        let reverse = RevisionComparison(runner: fixture.runner, base: target, target: base)

        for file in try await reverse.changes() {
            #expect(try await reverse.diff(of: file).diff?.files.count == 1)
        }
    }

    /// 魔法字符、分隔符与非 ASCII 字节只作为文件名，不成为模式。
    @Test("精确单文件 pathspec 按字面匹配", arguments: [
        "目录 [*]", "name?", "-name", ":(glob)name", "back\\slash", "tab\tname", "line\nname", "cafe\u{301}",
    ])
    func literalNames(path: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()

        let file = fixture.directory.appending(path: path)
        try Data("old\n".utf8).write(to: file)
        _ = try await commit(fixture, message: "file")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        try Data("child\n".utf8).write(to: file.appending(path: "child.txt"))
        let head = try await commit(fixture, message: "directory")
        let history = RepositoryHistory(runner: fixture.runner)
        let changes = try await history.changes(in: head)
        #expect(changes.count == 2)

        for change in changes {
            #expect(try await history.diff(in: head, file: change).diff?.files.count == 1)
        }
    }

    /// 目录收缩为文件时，父目录和子项各自只有自己的补丁；符号链接变化保留两个段。
    @Test("目录变文件与符号链接的补丁范围", arguments: ["sha1", "sha256"])
    func directoryAndSymlink(format: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: format)
        let node = fixture.directory.appending(path: "node")
        try FileManager.default.createDirectory(at: node, withIntermediateDirectories: false)
        try Data("first\n".utf8).write(to: node.appending(path: "a.txt"))
        try Data("second\n".utf8).write(to: node.appending(path: "b.txt"))
        let directory = try await commit(fixture, message: "directory")
        try FileManager.default.removeItem(at: node)
        try Data("regular\n".utf8).write(to: node)
        let regular = try await commit(fixture, message: "regular")
        let history = RepositoryHistory(runner: fixture.runner)
        let changes = try await history.changes(in: regular)
        #expect(changes.map(\.path) == ["node", "node/a.txt", "node/b.txt"])
        let comparison = RevisionComparison(runner: fixture.runner, base: directory, target: regular)
        let contents = ["node": "regular", "node/a.txt": "first", "node/b.txt": "second"]

        for file in changes {
            let diff = try #require(try await history.diff(in: regular, file: file).diff)
            #expect(diff.files.count == 1)
            #expect(try await comparison.diff(of: file).diff == diff)
            let text = diff.files.flatMap(\.hunks).flatMap(\.lines).map { String(decoding: $0.content, as: UTF8.self) }
            #expect(text == [try #require(contents[file.path])])
        }

        try FileManager.default.removeItem(at: node)
        try FileManager.default.createSymbolicLink(atPath: node.path, withDestinationPath: "target")
        let linked = try await commit(fixture, message: "symlink")
        let file = try #require(try await history.changes(in: linked).first)
        let diff = try #require(try await history.diff(in: linked, file: file).diff)
        #expect(diff.files.count == 2)
        #expect(diff.files.contains { $0.deletedMode == "100644" })
        #expect(diff.files.contains { $0.addedMode == "120000" })
        let linkComparison = RevisionComparison(runner: fixture.runner, base: regular, target: linked)
        #expect(try await linkComparison.diff(of: file).diff == diff)
    }

    /// 规范等价的目录可定位，但文件选择器仍然只返回文件。
    @Test("目录对象支持 Unicode 等价定位")
    func directoryUnicode() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize()

        let blob = try await fixture.runner.run(["hash-object", "-w", "--stdin"], input: Data("text\n".utf8))
        let id = String(decoding: blob, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let path = "cafe\u{301}/file.txt"
        _ = try await fixture.runner.run(
            ["update-index", "--add", "-z", "--index-info"], input: Data("100644 blob \(id)\t\(path)\0".utf8)
        )
        _ = try await fixture.runner.run(["commit", "-qm", "nfd"])
        let head = try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
        let views = RepositoryFileViews(runner: fixture.runner)
        let entry = try #require(try await views.storedEntry(for: "café", in: head))
        #expect(entry.isDirectory)
        #expect(Array(entry.path.utf8) == Array("cafe\u{301}".utf8))
        #expect(try await views.files(in: head).allSatisfy { !$0.isDirectory })
    }

    /// 固定提交时间与身份由隔离仓库提供，不依赖用户配置。
    private func commit(_ fixture: TemporaryRepository, message: String) async throws -> String {
        _ = try await fixture.runner.run(["add", "--all"])
        let runner = GitRunner(
            location: .local(path: fixture.directory.path),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_AUTHOR_DATE": "2020-01-01T00:00:00Z",
                "GIT_COMMITTER_DATE": "2020-01-01T00:00:00Z",
            ])
        )
        _ = try await runner.run(["commit", "-qm", message])
        return try await RepositoryReferences(runner: fixture.runner).resolve("HEAD")
    }
}
