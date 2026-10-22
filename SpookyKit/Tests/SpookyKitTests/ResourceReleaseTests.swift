import Darwin
import Foundation
import Testing

@testable import SpookyKit

/// 子进程、文件描述符与临时文件在成功、失败、取消三条路径上都必须释放。
struct ResourceReleaseTests {
    /// 取消先发送 TERM：Git 这类程序可以在退出前移除自己的锁文件。
    @Test("取消先发 TERM，进程可以清理锁文件", .timeLimit(.minutes(1)))
    func gracefulCancellation() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let lock = temporary.directory.appending(path: "index.lock")
        let executable = try script(in: temporary, name: "locking-git", body: """
        lock=\(GitRunner.shellQuoted(lock.path))
        trap 'rm -f "$lock"; exit 143' TERM
        touch "$lock"
        printf '%s\\n' "$$"
        while :; do sleep 0.1; done
        """)
        let runner = temporary.runner(at: "/", executable: executable.path)
        let pid = try await cancelAfterStart(runner)

        #expect(!FileManager.default.fileExists(atPath: lock.path))
        #expect(kill(pid, 0) == -1 && errno == ESRCH)
    }

    /// 忽略 TERM 的进程在宽限期后由 KILL 结束，不会遗留在后台。
    @Test("忽略 TERM 的进程在宽限期后被强制结束", .timeLimit(.minutes(1)))
    func forcedCancellation() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let executable = try script(in: temporary, name: "stubborn-git", body: """
        trap '' TERM
        printf '%s\\n' "$$"
        exec /bin/sleep 30
        """)
        let runner = temporary.runner(at: "/", executable: executable.path)
        let start = ContinuousClock.now
        let pid = try await cancelAfterStart(runner)

        #expect(start.duration(to: .now) >= CommandExecutor.cancellationGrace)
        #expect(kill(pid, 0) == -1 && errno == ESRCH)
    }

    /// 反复执行成功、非零退出与取消后，进程打开的描述符数量不随次数增长。
    @Test("成功、失败与取消都释放文件描述符", .timeLimit(.minutes(2)))
    func descriptors() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        try await temporary.initialize()
        let waiting = try script(in: temporary, name: "waiting-git", body: """
        printf '%s\\n' "$$"
        exec /bin/sleep 30
        """)
        let cancelling = temporary.runner(at: "/", executable: waiting.path)
        let before = try openDescriptors()

        for _ in 0..<20 {
            _ = try await temporary.runner.execute(["status", "--porcelain=v2", "-z"])
            await #expect(throws: GitError.self) {
                try await temporary.runner.execute(["rev-parse", "--verify", "missing-revision"])
            }
            _ = try await cancelAfterStart(cancelling)
        }

        // 其它并行测试也会短暂占用描述符；逐次泄漏会让数量随 60 次调用明显增长。
        #expect(try openDescriptors() - before < 16)
    }

    /// 本机凭据回调的私有会话目录在成功、失败和取消后都被删除。
    @Test("本机凭据会话目录在三条路径上删除", .timeLimit(.minutes(1)))
    func credentialSessions() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }
        let executable = try script(in: temporary, name: "session-git", body: """
        printf '%s\\n' "$SPOOKY_SESSION"
        for argument in "$@"; do
            case "$argument" in
                failing) exit 1 ;;
                waiting) exec /bin/sleep 30 ;;
            esac
        done
        """)
        var runner = temporary.runner(at: temporary.directory.path, executable: executable.path)
        runner.credentialHandler = { _ in nil }

        let succeeded = try await runner.execute(["fetch", "succeeding"])
        let failure = await #expect(throws: GitError.self) { try await runner.execute(["fetch", "failing"]) }
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let waiting = Task {
            try await runner.execute(["fetch", "waiting"]) {
                if case .standardOutput(let data) = $0 { continuation.yield(data) }
            }
        }
        var cancelled = Data()

        for await data in stream {
            cancelled.append(data)
            if cancelled.contains(10) { break }
        }

        waiting.cancel()
        continuation.finish()
        _ = await waiting.result

        for output in [succeeded.standardOutput, failure?.result.standardOutput ?? Data(), cancelled] {
            let session = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
            #expect(session.hasPrefix("/tmp/spooky-local-"))
            #expect(!FileManager.default.fileExists(atPath: session))
        }
    }

    /// 写入可执行的测试脚本，只放在本测试的临时目录中。
    private func script(in temporary: TemporaryRepository, name: String, body: String) throws -> URL {
        let url = temporary.directory.appending(path: name)
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    /// 等到脚本输出自己的 PID 后取消，返回该 PID 供检查进程是否已经结束。
    private func cancelAfterStart(_ runner: GitRunner) async throws -> Int32 {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        let task = Task {
            // 进程意外提前退出时结束输出流，测试不会一直等待 PID。
            defer { continuation.finish() }

            return try await runner.execute(["status"]) {
                if case .standardOutput(let data) = $0 { continuation.yield(data) }
            }
        }
        var output = Data()

        for await data in stream {
            output.append(data)
            if output.contains(10) { break }
        }

        task.cancel()
        continuation.finish()
        let error = await #expect(throws: GitError.self) { try await task.value }
        #expect(error?.isCancelled == true)
        return try #require(Int32(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)))
    }

    /// 当前进程打开的文件描述符数量。
    private func openDescriptors() throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    }
}
