import Foundation
import Testing

@testable import SpookyKit

/// 服务器上的 Diff 选项与图片两侧都在 B 上生成；只在显式启用时访问测试专用仓库。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteDiffTests {
    /// 显示整个文件与忽略空白下的按块暂存在 B 上执行，图片新的一侧经 SFTP 读取。
    @Test("服务器 Diff 选项与图片", .timeLimit(.minutes(2)))
    func remoteDiff() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let service = WorkingCopyOperations(runner: runner)
            let files = RepositoryFiles(runner: runner)
            let path = "空白 [*].txt"
            let absolute = fixture.repository + "/" + path

            try await files.write(Data("one\ntwo\n".utf8), to: absolute)
            try await service.stageAll(staged: true)
            try await service.commit(subject: "base", body: "")

            // 缩进变化不显示，只暂存新增的一行
            try await files.write(Data("  one\ntwo\nthree\n".utf8), to: absolute)
            let entry = try #require(try await runner.status().entries.first { $0.path == path })
            let options = DiffOptions(showsEntireFile: true, ignoresWhitespace: true)
            let snapshot = try await service.diff(for: entry, side: .unstaged, options: options)
            try await service.apply(snapshot, file: 0, hunk: 0)
            #expect(try await runner.run(["show", ":" + path]) == Data("one\ntwo\nthree\n".utf8))

            // 图片的工作区一侧经 SFTP 读取
            let image = fixture.repository + "/图 片.png"
            let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0, 1, 2])
            try await files.write(bytes, to: image)
            let untracked = try #require(try await runner.status().entries.first { $0.path == "图 片.png" })
            let binary = try #require(try await service.diff(for: untracked, side: .unstaged).diff?.files.first)
            let contents = try await DiffImageSource(runner: runner)
                .contents(of: binary, path: untracked.path, newFromWorkingTree: true)
            #expect(contents.old == nil)
            #expect(contents.new == bytes)

            await remote.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError { Issue.record(Comment(rawValue: git.message)) }
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}
