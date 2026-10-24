import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteHistoryDetailsTests

/// 提交详情的服务器验收：合并 Diff 方式、文件树、比较、签名查询，以及归档与补丁经标准输出流回本机存盘。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteHistoryDetailsTests {
    /// 查询与导出都由 B 上的 Git 执行，写出的文件在本机的临时目录里。
    @Test("服务器的合并 Diff、文件树、比较、签名与导出", .timeLimit(.minutes(3)))
    func historyDetails() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()
        let output = FileManager.default.temporaryDirectory.appending(path: "spooky-remote-export-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let files = RepositoryFiles(runner: runner)
            let working = WorkingCopyOperations(runner: runner)
            let references = RepositoryReferences(runner: runner)
            let path = "目录 [*]/你好.txt"

            // 两个分支各改一个文件后合并，合并提交的组合 Diff 没有文件
            try await files.write(Data("one\n".utf8), to: location.path + "/" + path)
            try await working.stageAll(staged: true)
            try await working.commit(subject: "第一版", body: "")
            let base = try await references.resolve("HEAD")
            try await references.create(name: "side", startingAt: "HEAD", track: false, checkout: true)
            try await files.write(Data("side\n".utf8), to: location.path + "/side.txt")
            try await working.stageAll(staged: true)
            try await working.commit(subject: "side", body: "")
            try await references.checkout("refs/heads/main")
            var options = MergeOptions()
            options.alwaysCreateCommit = true
            try await RepositorySync(runner: runner).merge("refs/heads/side", options: options)
            let merge = try await references.resolve("HEAD")

            let history = RepositoryHistory(runner: runner)
            #expect(try await history.changes(in: merge).map(\.path) == ["side.txt"])
            #expect(try await history.changes(in: merge, mergeMode: .mergedFilePaths).isEmpty)
            #expect(try await history.changes(in: merge, mergeMode: .off).isEmpty)

            let commit = try #require(try await history.page(roots: [merge], limit: 1).commits.first)
            let root = try await RepositoryFileViews(runner: runner).entries(ofTree: commit.tree)
            #expect(root.contains { $0.path == "目录 [*]" && $0.isDirectory })

            let comparison = RevisionComparison(runner: runner, base: base, target: merge)
            #expect(try await comparison.changes().map(\.path) == ["side.txt"])
            #expect(try await history.signatures(of: [merge])[merge]?.status == SignatureStatus.unsigned)

            // 归档、导出与补丁都写在本机
            let export = RevisionExport(runner: runner)
            try await export.archive(merge, format: .zip, to: output.appending(path: "a.zip"))
            try await export.export(merge, paths: ["目录 [*]"], to: output.appending(path: "files"))
            #expect(try Data(contentsOf: output.appending(path: "files/" + path)) == Data("one\n".utf8))
            let patches = try await export.savePatches([base, merge], omitsPrefixes: true, to: output)
            #expect(patches.map(\.lastPathComponent) == ["0001-.patch"])

            try? FileManager.default.removeItem(at: output)
            await remote.close()
            try await fixture.remove()
        } catch {
            if let error = error as? GitError { Issue.record(Comment(rawValue: error.message)) }
            try? FileManager.default.removeItem(at: output)
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
