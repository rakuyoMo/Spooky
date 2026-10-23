import Foundation
import Testing

@testable import SpookyKit

/// 真实 Git 验证历史协议、分页、第一父补丁及图模型。
struct RepositoryHistoryTests {
    /// 空仓库不执行无界 log，固定根使翻页不受新提交影响。
    @Test("历史空仓库、Unicode、长标题、分页与动态哈希", arguments: ["sha1", "sha256"])
    func pagination(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: objectFormat)
        let history = RepositoryHistory(runner: fixture.runner)
        let refs = RepositoryReferences(runner: fixture.runner)
        #expect(try await history.page(roots: []).commits.isEmpty)
        #expect(try await refs.snapshot().references.isEmpty)
        _ = try await fixture.runner.run(["config", "--local", "user.name", "李 café 🐈"])
        let subject = String(repeating: "长标题", count: 100)

        for index in 0 ..< 3 {
            _ = try await fixture.runner.run(
                ["commit", "--allow-empty", "-F", "-"],
                input: Data("\(subject) \(index)\n\n正文\u{1f}\u{1d}\n".utf8)
            )
        }
        let root = try await refs.resolve("HEAD")
        let first = try await history.page(roots: [root], limit: 2)
        #expect(first.commits.count == 2)
        #expect(first.hasMore)
        #expect(first.commits.first?.author == "李 café 🐈")
        #expect(first.commits.first?.subject == subject + " 2")
        #expect(first.commits.first?.id.count == (objectFormat == "sha1" ? 40 : 64))
        _ = try await fixture.runner.run(["commit", "--allow-empty", "-m", "new"])
        let second = try await history.page(roots: [root], offset: 2, limit: 2)
        #expect(second.commits.count == 1)
        #expect(!second.hasMore)
        #expect(second.commits.first?.subject == subject + " 0")
        #expect(Set((first.commits + second.commits).map(\.id)).count == 3)
    }

    /// 文件名包含换行和通配符，二进制统计不会使后续文本错位。
    @Test("提交变更集的特殊路径、二进制、重命名与第一父", arguments: ["sha1", "sha256"])
    func changes(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let history = RepositoryHistory(runner: runner)
        let refs = RepositoryReferences(runner: runner)
        let path = "你好 \t\n'[*]\\.txt"
        try Data("one\ntwo\n".utf8).write(to: fixture.directory.appendingPathComponent(path))
        try Data([0, 1, 2]).write(to: fixture.directory.appendingPathComponent("binary"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-m", "root"])
        let root = try await refs.resolve("HEAD")
        let initial = try await history.changes(in: root)
        #expect(initial.count == 2)
        #expect(initial.first { $0.path == "binary" }?.additions == nil)
        let text = try #require(initial.first { $0.path == path })
        #expect(text.additions == 2)
        let large = try await history.diff(in: root, file: text, warningKilobytes: 0)
        #expect(large.diff == nil && large.byteCount > 0)
        #expect(try await history.diff(in: root, file: text).diff?.files.first?.hunks.first?.lines.count == 2)

        try await refs.create(name: "topic", startingAt: "HEAD", track: false, checkout: true)
        _ = try await runner.run(["mv", "--", path, "renamed"])
        _ = try await runner.run(["commit", "-m", "rename"])
        let tip = try await refs.resolve("HEAD")
        let rename = try #require(try await history.changes(in: tip).first)
        #expect(rename.originalPath == path)
        #expect(rename.path == "renamed")
        #expect(
            try await history.diff(in: tip, file: rename).diff?.files.first?.headers
                .contains(where: { $0.hasPrefix("rename from") }) ?? false
        )
        try await refs.checkout("refs/heads/main")
        var options = MergeOptions()
        options.alwaysCreateCommit = true
        try await RepositorySync(runner: runner).merge("refs/heads/topic", options: options)
        let merged = try await refs.resolve("HEAD")
        let commits = try await history.page(roots: [merged])
        #expect(commits.commits.first?.parents.count == 2)
        #expect(try await history.changes(in: merged).first?.originalPath == path)
        var graph = CommitGraph()
        let rows = commits.commits.map { graph.append($0) }
        #expect(rows.first?.segments.filter(\.startsAtCommit).count == 2)
        #expect(rows.last?.segments.allSatisfy(\.endsAtCommit) ?? false)
    }

    /// 非法协议不能被静默当作空列表。
    @Test("历史、引用和变更集的损坏格式拒绝")
    func malformed() throws {
        #expect(throws: RepositoryReadError.self) { try HistoryCommit.parse(Data("bad\0".utf8)) }
        #expect(throws: RepositoryReadError.self) { try RepositoryReference.parse(Data("bad\0\n".utf8)) }
        #expect(throws: RepositoryReadError.self) { try CommitFileChange.parse(Data("1\t2\tfile\0".utf8)) }
        #expect(throws: RepositoryReadError.self) { try ReferenceDivergence.parse(Data("-1\t2".utf8)) }
        #expect(throws: RepositoryReadError.self) {
            try RemoteReferenceUpdate.parseFetch(Data("* broken".utf8))
        }
        #expect(throws: RepositoryReadError.self) {
            try RemoteReferenceUpdate.parsePush(Data("! broken".utf8))
        }
    }
}
