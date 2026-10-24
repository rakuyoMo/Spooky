import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteRewriteTests

/// M7 的改写操作在服务器上执行：内联的序列编辑器与信息编辑器只在 B 上运行，不依赖 A 的路径。只在显式启用时访问 spooky-test。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteRewriteTests {
    /// 在 B 上依次反转、摘取、改信息、压缩、编辑后继续、并入暂存改动与重置，再核对序列被改变时不改写。
    @Test("服务器上的反转、摘取、交互式变基与重置", .timeLimit(.minutes(3)))
    func rewriteFlow() async throws {
        let fixture = try await RemoteFixture.create()
        let remote = fixture.connection()

        do {
            let location = try await remote.open().location
            let runner = GitRunner(location: location, remote: remote)
            let rewrite = RepositoryRewrite(runner: runner)
            let commits = try await commit(["一", "二 'q'", "三 $HOME"], at: location.path, runner: runner)

            try await rewrite.revert([commits[2]], options: PickOptions())
            try await rewrite.cherryPick([commits[2]], options: PickOptions())
            #expect(try await subjects(runner).prefix(2) == ["三 $HOME", "Revert \"三 $HOME\""])

            try await rewrite.perform(try await rewrite.plan(.reword(commits[0], message: "新标题 `x`\n\n#1 正文\n")))
            let reworded = try await rewrite.commits([try await rewrite.resolve("HEAD~4")]).first?.message
            #expect(reworded?.trimmingCharacters(in: .newlines) == "新标题 `x`\n\n#1 正文")

            try await rewrite.reset(to: "HEAD~2", mode: .hard)
            let head = try await rewrite.resolve("HEAD")
            let second = try await rewrite.resolve("HEAD~1")
            try await rewrite.perform(try await rewrite.plan(.squash([head, second], into: nil)))
            #expect(try await subjects(runner) == ["二 'q'", "新标题 `x`"])

            try await RepositoryFiles(runner: runner).write(Data("补充\n".utf8), to: location.path + "/文件 0 [*].txt")
            _ = try await runner.run(["add", "--all"])
            try await rewrite.perform(try await rewrite.plan(.amend(try await rewrite.resolve("HEAD~1"))))
            #expect(try await subjects(runner) == ["二 'q'", "新标题 `x`"])

            let stale = try await rewrite.plan(.drop([try await rewrite.resolve("HEAD")]))
            _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "终端里的提交"])
            await #expect(throws: RewriteError.self) { try await rewrite.perform(stale) }

            await remote.close()
            try await fixture.remove()
        } catch {
            await remote.close()
            try await fixture.remove()
            throw error
        }
    }
}

// MARK: - Helpers

extension RemoteRewriteTests {
    /// 在 B 上依次提交，每个提交新增一个文件；返回从旧到新的提交。
    private func commit(_ subjects: [String], at path: String, runner: GitRunner) async throws -> [String] {
        var commits: [String] = []

        for (index, subject) in subjects.enumerated() {
            try await RepositoryFiles(runner: runner).write(Data("\(subject)\n".utf8), to: path + "/文件 \(index) [*].txt")
            _ = try await runner.run(["add", "--all"])
            _ = try await runner.run(["commit", "-q", "-m", subject])
            commits.append(try await RepositoryRewrite(runner: runner).resolve("HEAD"))
        }

        return commits
    }

    /// 当前分支从新到旧的提交标题。
    private func subjects(_ runner: GitRunner) async throws -> [String] {
        let output = try await runner.run(["log", "-z", "--format=%s"])
        return String(decoding: output, as: UTF8.self).split(separator: "\0").map(String.init)
    }
}
