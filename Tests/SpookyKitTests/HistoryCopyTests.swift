import Foundation
import Testing

@testable import SpookyKit

/// 历史与版本比较不做复制检测，副本始终按新文件读取。
struct HistoryCopyTests {
    /// 被修改的源文件加上保留原文的副本会触发 Git 的复制检测，产品仍须返回新增。
    @Test("历史与比较的副本按新增显示", arguments: ["sha1", "sha256"])
    func addedCopy(objectFormat: String) async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }
        try await fixture.initialize(objectFormat: objectFormat)
        let runner = fixture.runner
        let source = fixture.directory.appending(path: "source.txt")
        let content = Data("one\ntwo\nthree\n".utf8)
        try content.write(to: source)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", "base"])
        let base = try await RepositoryReferences(runner: runner).resolve("HEAD")
        try content.write(to: fixture.directory.appending(path: "copy.txt"))
        try Data("changed\ntwo\nthree\n".utf8).write(to: source)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-qm", "copy"])
        let target = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let detected = try await runner.run(["diff", "--name-status", "-C", base, target])
        #expect(String(decoding: detected, as: UTF8.self).contains("C100\tsource.txt\tcopy.txt"))
        _ = try await runner.run(["config", "--local", "diff.renames", "copies"])
        let history = RepositoryHistory(runner: runner)
        let comparison = RevisionComparison(runner: runner, base: base, target: target)
        let historyFile = try #require(try await history.changes(in: target).first { $0.path == "copy.txt" })
        let comparedFile = try #require(try await comparison.changes().first { $0.path == "copy.txt" })
        #expect(historyFile.status == "A" && historyFile.originalPath == nil)
        #expect(comparedFile.status == "A" && comparedFile.originalPath == nil)
        let historyDiff = try #require(try await history.diff(in: target, file: historyFile).diff)
        let comparedDiff = try #require(try await comparison.diff(of: comparedFile).diff)

        for diff in [historyDiff, comparedDiff] {
            let file = try #require(diff.files.first)
            #expect(file.metadata.isAdded)
            #expect(file.metadata.rename == nil)
            #expect(file.hunks.flatMap(\.lines).allSatisfy { $0.prefix == 43 })
            #expect(file.hunks.flatMap(\.lines).count == 3)
        }
    }
}
