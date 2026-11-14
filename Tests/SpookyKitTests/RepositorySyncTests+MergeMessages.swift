import Foundation
import Testing

@testable import SpookyKit

// MARK: - MergeMessages

extension RepositorySyncTests {
    /// 合并、拉取与 Update Branch 生成的合并提交用 Git 对名字的默认说明，不写成 “Merge commit '<哈希>'”。
    @Test("合并提交的说明")
    func mergeMessages() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        let runner = fixture.runner
        let sync = RepositorySync(runner: runner)
        let bare = fixture.directory.appendingPathComponent("remote.git").path

        try Self.exclude("remote.git/\nother/\n", in: fixture)
        _ = try await runner.run(["init", "--bare", bare])
        _ = try await runner.run(["remote", "add", "origin", bare])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "root"])
        _ = try await runner.run(["push", "-u", "origin", "main"])

        // 本地分支：说明里是短名
        _ = try await runner.run(["branch", "feature/login"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "main"])
        _ = try await runner.run(["switch", "feature/login"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "login"])
        _ = try await runner.run(["switch", "main"])

        try await sync.merge("refs/heads/feature/login")
        #expect(try await Self.subject(in: runner) == "Merge branch 'feature/login'")

        // 拉取：说明里是远端分支与远端地址，Git 去掉地址末尾的 .git
        let clone = fixture.directory.appendingPathComponent("other").path
        let other = fixture.runner(at: clone)
        _ = try await runner.run(["clone", "-b", "main", bare, clone])
        _ = try await other.run(["config", "--local", "user.name", "Other"])
        _ = try await other.run(["config", "--local", "user.email", "other@example.invalid"])
        _ = try await other.run(["commit", "--allow-empty", "-m", "remote"])
        _ = try await other.run(["push", "origin", "main"])

        try await sync.pull(rebase: false)

        let pulled = try await Self.subject(in: runner)
        #expect(pulled == "Merge branch 'main' of " + bare.dropLast(".git".count))

        // Update Branch：并入父分支，说明里写出并入的分支
        _ = try await runner.run(["switch", "-c", "topic", "HEAD~1"])
        _ = try await runner.run(["commit", "--allow-empty", "-m", "topic"])

        try await sync.updateBranch("refs/heads/topic", from: "refs/heads/main", rebase: false)
        #expect(try await Self.subject(in: runner) == "Merge branch 'main' into topic")
    }

    /// HEAD 提交的标题。
    private static func subject(in runner: GitRunner) async throws -> String {
        let output = try await runner.run(["log", "-1", "--format=%s"])
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
    }
}
