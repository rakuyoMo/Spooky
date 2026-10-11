import Foundation
import Testing

@testable import SpookyKit

/// git 调用的拼装与执行
struct GitRunnerTests {
    @Test("shell 转义：空格与单引号")
    func shellQuoting() {
        #expect(GitRunner.shellQuoted("a b") == "'a b'")
        #expect(GitRunner.shellQuoted("it's") == "'it'\\''s'")
    }

    @Test("远端仓库：经 ssh 别名执行，远端命令的每个参数都转义")
    func remoteCommandLine() {
        let runner = GitRunner(location: .remote(host: "b", path: "/Users/me/My Repo"))
        let command = runner.commandLine(for: ["log", "--format=%H %s"])

        #expect(command.executable == "/usr/bin/ssh")

        #expect(command.arguments == [
            "-o", "BatchMode=yes", "--", "b",
            "'git' '-C' '/Users/me/My Repo' '--no-pager' '--no-optional-locks' "
                + "'-c' 'color.ui=never' '-c' 'core.quotepath=off' 'log' '--format=%H %s'",
        ])
    }

    @Test("本机仓库：真实跑一次 git status")
    func localStatus() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        // 新建一个空仓库，再放一个文件名带空格与中文的未跟踪文件
        let runner = GitRunner(location: .local(path: directory.path))
        _ = try await runner.run(["init", "-q", "-b", "main"])
        try Data("hi".utf8).write(to: directory.appending(path: "你好 世界.txt"))

        let status = try await runner.status()

        #expect(status.branch.head == "main")
        #expect(status.branch.oid == nil)

        #expect(status.entries == [
            StatusEntry(
                kind: .untracked,
                path: "你好 世界.txt",
                originalPath: nil,
                staged: nil,
                unstaged: nil
            ),
        ])
    }

    @Test("git 失败时抛出 GitError，带上退出码与错误信息")
    func failure() async {
        let runner = GitRunner(location: .local(path: "/nonexistent-\(UUID().uuidString)"))

        let error = await #expect(throws: GitError.self) {
            try await runner.status()
        }

        #expect(error?.exitCode == 128)
        #expect(error?.message.contains("cannot change to") == true)
    }
}
