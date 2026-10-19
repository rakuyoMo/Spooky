import Darwin
import Foundation
import Testing

@testable import SpookyKit

/// 命令结果、流式输出和真正回收本机子进程的验证。
struct GitCommandResultTests {
    /// 调用方接受退出 1 时仍能取得完整状态，旧 API 则继续抛错。
    @Test("接受指定退出码并保留原始参数")
    func acceptedExitCode() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()

        let arguments = ["rev-parse", "--verify", "--quiet", "refs/heads/missing"]
        let result = try await temporary.runner.execute(arguments, acceptedExitCodes: [0, 1])
        #expect(result.arguments == arguments)
        #expect(result.terminationStatus == .exited(1))
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.isEmpty)
        #expect(!result.isCancelled)

        let error = await #expect(throws: GitError.self) {
            try await temporary.runner.run(arguments)
        }
        #expect(error?.exitCode == 1)
        #expect(error?.arguments == arguments)
    }

    /// stdin 通过同一执行层传递，失败结果不能丢失 stdout 或 stderr。
    @Test("标准输入、两条输出管道与非零退出")
    func streamsAndInput() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let executable = temporary.directory.appending(path: "streams-git")
        let script = "#!/bin/sh\n/bin/cat\nprintf '原始错误\\n' >&2\nexit 7\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let input = Data("空 格'\"\\[*]?\n\0尾部".utf8)
        let runner = temporary.runner(at: temporary.directory.path, executable: executable.path)
        let error = await #expect(throws: GitError.self) {
            try await runner.execute(["status"], input: input)
        }

        #expect(error?.result.standardOutput == input)
        #expect(error?.message == "原始错误\n")
        #expect(error?.exitCode == 7)
        #expect(error?.category == .commandFailed)
    }

    /// 启动失败没有 stderr，但必须保留进程库诊断并使用独立错误类别。
    @Test("启动失败转换为错误值")
    func launchFailure() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let runner = temporary.runner(at: "/", executable: temporary.directory.appending(path: "missing-git").path)

        let error = await #expect(throws: GitError.self) {
            try await runner.execute(["--version"])
        }

        #expect(error?.category == .launchFailed)
        #expect(error?.exitCode == nil)
        #expect(error?.diagnostic?.isEmpty == false)
        #expect(error?.result.arguments == ["--version"])
    }

    /// 流式回调在进程退出前可用，取消后输出仍保留且 PID 已消失。
    @Test("取消真正终止本机子进程", .timeLimit(.minutes(1)))
    func cancellation() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let executable = temporary.directory.appending(path: "waiting-git")
        let script = "#!/bin/sh\nprintf 'ready\\n' >&2\nprintf '%s\\n' \"$$\"\nexec /bin/sleep 30\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let runner = temporary.runner(at: "/", executable: executable.path)
        let (stream, continuation) = AsyncStream<GitOutputEvent>.makeStream()
        let task = Task {
            try await runner.execute(["status"]) { continuation.yield($0) }
        }
        var output = Data()
        var stderr = Data()

        // 等到两条管道都有输出再取消，验证取消保留的是运行中的真实数据。
        for await event in stream {
            switch event {
            case .standardOutput(let data): output.append(data)
            case .standardError(let data): stderr.append(data)
            }

            if output.contains(10), stderr.contains(10) {
                break
            }
        }

        let pidText = String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = try #require(Int32(pidText))
        task.cancel()
        continuation.finish()

        let error = await #expect(throws: GitError.self) { try await task.value }
        #expect(error?.category == .cancelled)
        #expect(error?.isCancelled == true)
        #expect(error?.message == "ready\n")
        #expect(error?.result.standardOutput == output)
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)
    }

    /// 任务启动前已取消时不启动程序，结果仍携带取消状态与参数。
    @Test("启动前取消")
    func cancellationBeforeLaunch() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let error: GitError? = await withTaskGroup(of: GitError?.self) { group in
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

        #expect(error?.isCancelled == true)
        #expect(error?.result.terminationStatus == nil)
    }

    /// stderr 先超过管道容量时也不会阻塞等待 stdout，超限则保留已读取原文。
    @Test("并发排空管道并拒绝超限输出", .timeLimit(.minutes(1)))
    func outputPressureAndLimit() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let executable = temporary.directory.appending(path: "large-output-git")
        let script = "#!/bin/sh\n/usr/bin/head -c 131072 /dev/zero >&2\n/usr/bin/head -c 131072 /dev/zero\n"
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let runner = temporary.runner(at: "/", executable: executable.path)

        let result = try await runner.execute(["status"])
        #expect(result.standardOutput.count == 131_072)
        #expect(result.standardError.count == 131_072)

        try Data("#!/bin/sh\n/usr/bin/head -c 1048577 /dev/zero >&2\n".utf8).write(to: executable)
        let error = await #expect(throws: GitError.self) {
            try await runner.execute(["status"])
        }
        #expect(error?.category == .outputLimitExceeded)
        #expect(error?.result.standardError.count == 1_048_576)
        #expect(error?.isCancelled == false)
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
}
