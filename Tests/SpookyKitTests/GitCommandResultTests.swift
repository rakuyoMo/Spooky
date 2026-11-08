import Darwin
import Foundation
import Testing

@testable import SpookyKit

/// 命令结果、流式输出和真正回收本机子进程的验证。
struct GitCommandResultTests {
    /// 调用方接受的退出码照常返回完整结果，没有接受时抛错；标准输入经同一执行层传递，失败结果不丢 stdout 或 stderr；
    /// 启动失败保留进程库诊断；stderr 先超过管道容量时不会阻塞等待 stdout，超出输出上限时保留已读取的原文。
    @Test("退出码、标准输入与两条输出管道、启动失败与输出上限")
    func results() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()

        // 接受退出 1 时取得完整结果，没有接受时抛出带原始参数的错误
        let arguments = ["rev-parse", "--verify", "--quiet", "refs/heads/missing"]
        let accepted = try await temporary.runner.execute(arguments, acceptedExitCodes: [0, 1])

        #expect(accepted.arguments == arguments)
        #expect(accepted.terminationStatus == .exited(1))
        #expect(accepted.standardOutput.isEmpty && accepted.standardError.isEmpty)
        #expect(!accepted.isCancelled)

        let rejected = await #expect(throws: GitError.self) {
            try await temporary.runner.run(arguments)
        }

        #expect(rejected?.exitCode == 1)
        #expect(rejected?.arguments == arguments)

        // 标准输入原样到达程序，非零退出时两条输出都保留
        let input = Data("空 格'\"\\[*]?\n\0尾部".utf8)
        let streams = try script(in: temporary, name: "streams-git", body: "/bin/cat\nprintf '原始错误\\n' >&2\nexit 7")

        let failed = await #expect(throws: GitError.self) {
            try await streams.execute(["status"], input: input)
        }

        #expect(failed?.result.standardOutput == input)
        #expect(failed?.message == "原始错误\n")
        #expect(failed?.exitCode == 7)
        #expect(failed?.category == .commandFailed)

        // 启动失败没有 stderr，使用独立的错误类别
        let missing = temporary.runner(at: "/", executable: temporary.directory.appending(path: "missing-git").path)

        let unlaunched = await #expect(throws: GitError.self) {
            try await missing.execute(["--version"])
        }

        #expect(unlaunched?.category == .launchFailed)
        #expect(unlaunched?.exitCode == nil)
        #expect(!(unlaunched?.diagnostic?.isEmpty ?? true))
        #expect(unlaunched?.result.arguments == ["--version"])

        // 两条管道各写 128 KiB 时并发排空
        let large = try script(
            in: temporary,
            name: "large-output-git",
            body: "/usr/bin/head -c 131072 /dev/zero >&2\n/usr/bin/head -c 131072 /dev/zero"
        )

        let drained = try await large.execute(["status"])

        #expect(drained.standardOutput.count == 131_072)
        #expect(drained.standardError.count == 131_072)

        // 超过 1 MiB 的输出上限时保留已读取的部分，不算取消
        let excessive = try script(in: temporary, name: "excessive-git", body: "/usr/bin/head -c 1048577 /dev/zero >&2")

        let exceeded = await #expect(throws: GitError.self) {
            try await excessive.execute(["status"])
        }

        #expect(exceeded?.category == .outputLimitExceeded)
        #expect(exceeded?.result.standardError.count == 1_048_576)
        #expect(!(exceeded?.isCancelled ?? true))
    }

    /// 运行中取消：流式回调在进程退出前可用，取消后输出仍保留且 PID 已消失；任务启动前已取消时不启动程序，结果仍带取消状态。
    @Test("取消运行中与尚未启动的命令")
    func cancellation() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let runner = try script(
            in: temporary,
            name: "waiting-git",
            body: "printf 'ready\\n' >&2\nprintf '%s\\n' \"$$\"\nexec /bin/sleep 30"
        )

        let (stream, continuation) = AsyncStream<GitOutputEvent>.makeStream()

        let task = Task {
            try await runner.execute(["status"]) { continuation.yield($0) }
        }

        var output = Data()
        var stderr = Data()

        // 等到两条管道都有输出再取消，验证取消保留的是运行中的真实数据
        for await event in stream {
            switch event {
            case .standardOutput(let data): output.append(data)
            case .standardError(let data): stderr.append(data)
            }

            if output.contains(10), stderr.contains(10) {
                break
            }
        }

        let pidText = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = try #require(Int32(pidText))

        task.cancel()
        continuation.finish()

        let error = await #expect(throws: GitError.self) { try await task.value }

        #expect(error?.category == .cancelled)
        #expect(error?.isCancelled ?? false)
        #expect(error?.message == "ready\n")
        #expect(error?.result.standardOutput == output)
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)

        // 任务启动前已取消
        let early: GitError? = await withTaskGroup(of: GitError?.self) { group in
            group.cancelAll()

            group.addTask {
                do {
                    _ = try await temporary.runner.execute(["status"])
                    return nil
                } catch {
                    return error as? GitError
                }
            }

            return await group.next() ?? nil
        }

        #expect(early?.isCancelled ?? false)
        #expect(early?.result.terminationStatus == nil)
    }

    /// 特殊路径与同路径双记录按 Git 原文返回，不能被 shell 或解析器改写。
    @Test("特殊文件名、重命名与同路径双记录")
    func specialPaths() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()

        let original = "旧 文件'\"\\[*]?.txt"
        let renamed = "新 -> 文件'\"\\[*]?\n尾部.txt"

        try Data("content".utf8).write(to: temporary.directory.appendingPathComponent(original))
        _ = try await temporary.runner.run(["--literal-pathspecs", "add", "--", original])
        _ = try await temporary.runner.run(["commit", "-q", "-m", "initial"])
        _ = try await temporary.runner.run(["mv", "--", original, renamed])

        let moved = try await temporary.runner.status()

        #expect(moved.entries.count == 1)
        #expect(moved.entries.first?.path == renamed)
        #expect(moved.entries.first?.originalPath == original)

        _ = try await temporary.runner.run(["commit", "-q", "-m", "rename"])
        _ = try await temporary.runner.run(["--literal-pathspecs", "rm", "--cached", "--", renamed])

        let removed = try await temporary.runner.status()

        #expect(removed.entries.filter { $0.path == renamed }.count == 2)
        #expect(Set(removed.entries.map(\.kind)) == [.tracked, .untracked])
    }

    /// 在临时目录里写一个由 `/bin/sh` 解释的假 git，返回在根目录执行它的执行器。
    private func script(
        in temporary: TemporaryRepository,
        name: String,
        body: String
    ) throws -> GitRunner {
        let executable = temporary.directory.appending(path: name)

        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        return temporary.runner(at: "/", executable: executable.path)
    }
}
