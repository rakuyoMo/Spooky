import Foundation
import Testing

@testable import SpookyKit

/// 文件历史、Blame 与原文的服务器验收，只在显式启用时访问 spooky-test 的独立测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteFileViewsTests {
    /// 查询都由 B 上的 Git 执行；工作区文件经 SFTP 下载到本机缓存后才交给本机程序。
    @Test("服务器文件历史、Blame、原文、NFD 路径与 SFTP 副本", .timeLimit(.minutes(3)))
    func fileViews() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let files = RepositoryFiles(runner: runner)
            let working = WorkingCopyOperations(runner: runner)
            let path = "你好 [*].txt"

            // 两次修改同一文件，第二次只改第二行
            try await files.write(Data("one\n".utf8), to: location.path + "/" + path)
            try await working.stageAll(staged: true)
            try await working.commit(subject: "第一版", body: "")
            try await files.write(Data("one\ntwo\n".utf8), to: location.path + "/" + path)
            try await working.stageAll(staged: true)
            try await working.commit(subject: "第二版", body: "")

            // 以 NFD 形式写进索引的文件按 NFC 请求时仍能找到
            let decomposed = "caf\u{65}\u{301}.txt"
            let blob = try await runner.run(["hash-object", "-w", "--stdin"], input: Data("nfd\n".utf8))
            let id = String(decoding: blob, as: UTF8.self).trimmingCharacters(in: .newlines)
            _ = try await runner.run(
                ["update-index", "--add", "-z", "--index-info"],
                input: Data("100644 blob \(id)\t\(decomposed)\0".utf8)
            )
            try await working.commit(subject: "NFD", body: "")

            let views = RepositoryFileViews(runner: runner)
            let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
            let page = try await views.page(of: path, from: head)
            #expect(page.commits.map(\.subject) == ["第二版", "第一版"])
            #expect(try await views.blame(path, at: head).lines == ["one", "two"])

            let composed = decomposed.precomposedStringWithCanonicalMapping
            let entry = try #require(try await views.storedEntry(for: composed, in: head))
            #expect(Array(entry.path.utf8) == Array(decomposed.utf8))
            #expect(try await views.contents(of: entry) == Data("nfd\n".utf8))

            // 工作区文件的本机副本来自 SFTP，路径在本机的临时缓存中
            let cache = RepositoryFileCache(runner: runner)
            let copy = try await cache.workingTreeFile(path)
            #expect(try Data(contentsOf: copy) == Data("one\ntwo\n".utf8))
            #expect(copy.path.hasPrefix(FileManager.default.temporaryDirectory.path))
            cache.removeAll()
            #expect(!FileManager.default.fileExists(atPath: copy.path))

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
