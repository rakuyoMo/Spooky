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

    /// 参数作为 shell 数据往返，别名、路径和提交信息都不能执行命令替换。
    @Test("远端参数经过 POSIX shell 后原样保留")
    func remoteShellRoundTrip() async throws {
        let arguments = ["主机'alias", "/path/仓 库'\"\\[*]?", "message ' $HOME `echo injected`\n"]
        let command = ["/usr/bin/printf", "%s\\0"] + arguments
        let result = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", command.map(GitRunner.shellQuoted).joined(separator: " ")]
        )
        let decoded = result.standardOutput.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
        #expect(decoded == arguments)
        let options = SSHConfiguration().options
        #expect(options.contains("ForwardAgent=no"))
        #expect(options.contains("StrictHostKeyChecking=yes"))
    }

    /// 隔离配置的临时工作区应原样返回带空格和中文的文件名。
    @Test("本机仓库：真实跑一次 git status")
    func localStatus() async throws {
        let temporary = try TemporaryRepository()
        let directory = temporary.directory

        defer {
            temporary.remove()
        }

        // 新建一个空仓库，再放一个文件名带空格与中文的未跟踪文件
        let runner = temporary.runner
        try await temporary.initialize()
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

    /// 失效路径的错误分类和原文不受用户全局配置影响。
    @Test("git 失败时抛出 GitError，带上退出码与错误信息")
    func failure() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let runner = temporary.runner(at: temporary.directory.appending(path: "missing").path)

        let error = await #expect(throws: GitError.self) {
            try await runner.status()
        }

        #expect(error?.exitCode == 128)
        #expect(error?.message.contains("cannot change to") ?? false)
    }
}
