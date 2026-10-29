import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteHistorySearchTests

/// M7 的服务器历史搜索只在显式启用时访问 spooky-test 的独立测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteHistorySearchTests {
    /// 搜索、计数、可达性与补全用的文件清单都在 B 上执行，路径按字面传过去。
    @Test("服务器历史的组合搜索、哈希、计数与文件清单", .timeLimit(.minutes(3)))
    func search() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let files = RepositoryFiles(runner: runner)
            let working = WorkingCopyOperations(runner: runner)
            let path = "文档/说明 [*].md"

            try await files.write(Data("one\n".utf8), to: location.path + "/" + path)
            try await working.stageAll(staged: true)
            try await working.commit(subject: "服务器 fix *star*", body: "")
            _ = try await runner.run(["commit", "--allow-empty", "-m", "later"])

            let history = RepositoryHistory(runner: runner)
            let head = try await RepositoryReferences(runner: runner).resolve("HEAD")

            // 说明按正则匹配，反斜杠与星号原样传到 B 上
            let message = HistoryQuery(conditions: [.init(kind: .message, text: "FIX \\*STAR\\*")])
            let found = try await history.page(roots: [head], query: message)
            #expect(found.commits.map(\.subject) == ["服务器 fix *star*"])
            #expect(try await history.count(roots: [head], query: message, limit: 100) == 1)

            let file = HistoryQuery(conditions: [.init(kind: .file, text: path)])
            #expect(try await history.page(roots: [head], query: file).commits.map(\.subject) == ["服务器 fix *star*"])

            let target = try #require(found.commits.first)
            let hash = HistoryQuery(conditions: [.init(kind: .hash, text: String(target.id.prefix(7)))])
            #expect(try await history.page(roots: [head], query: hash).commits.map(\.id) == [target.id])
            #expect(try await history.contains(target.id, roots: [head]))

            let listed = try await RepositoryFileViews(runner: runner).files(in: head)
            #expect(listed.map(\.path) == [path])

            await remote.close()
            try await fixture.remove()
        } catch {
            if let error = error as? GitError { Issue.record(Comment(rawValue: error.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
