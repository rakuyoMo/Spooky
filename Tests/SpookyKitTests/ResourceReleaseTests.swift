import Darwin
import Foundation
import Testing

@testable import SpookyKit

/// 子进程、文件描述符与临时文件在成功、失败、取消三条路径上都必须释放。
struct ResourceReleaseTests {
    /// 取消先发送 TERM：Git 这类程序可以在退出前移除自己的锁文件；忽略 TERM 的进程在宽限期后由 KILL 结束，不会遗留在后台。
    @Test("取消先发 TERM 让进程清理锁文件，忽略 TERM 的进程在宽限期后被强制结束")
    func cancellation() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let lock = temporary.directory.appending(path: "index.lock")

        // 与 Git 一样在信号处理里直接删除锁文件：处理中再启动 rm 这类进程，负载高时可能赶不上宽限期后的 KILL
        let locking = try script(in: temporary, name: "locking-git", interpreter: "/usr/bin/perl", body: """
            use File::Basename;

            my $lock = dirname($0) . '/index.lock';
            $SIG{TERM} = sub { unlink $lock; exit 143 };

            open(my $file, '>', $lock) or die;
            close($file);

            $| = 1;
            print "$$\\n";
            sleep 1 while 1;
            """)

        let graceful = try await cancelAfterStart(temporary.runner(at: "/", executable: locking.path))

        #expect(!FileManager.default.fileExists(atPath: lock.path))
        #expect(kill(graceful, 0) == -1 && errno == ESRCH)

        // 忽略 TERM 的进程：取消要等满宽限期才以 KILL 结束它
        let stubborn = try script(in: temporary, name: "stubborn-git", body: """
            trap '' TERM
            printf '%s\\n' "$$"
            exec /bin/sleep 30
            """)

        let start = ContinuousClock.now
        let forced = try await cancelAfterStart(temporary.runner(at: "/", executable: stubborn.path))

        #expect(start.duration(to: .now) >= CommandExecutor.cancellationGrace)
        #expect(kill(forced, 0) == -1 && errno == ESRCH)
    }

    /// 反复执行成功、非零退出与取消后，进程打开的描述符数量不随次数增长。
    ///
    /// 本机仓库的 Git 命令在测试进程里共用一组主机槽，整套测试并行时 60 次调用要依次排队，上限按整套测试的耗时留足。
    @Test("成功、失败与取消都释放文件描述符")
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

        for _ in 0 ..< 20 {
            _ = try await temporary.runner.execute(["status", "--porcelain=v2", "-z"])

            await #expect(throws: GitError.self) {
                try await temporary.runner.execute(["rev-parse", "--verify", "missing-revision"])
            }

            _ = try await cancelAfterStart(cancelling)
        }

        // 其它并行测试也会短暂占用描述符：超出时隔一会儿再读，取最少的一次；
        // 逐次泄漏会让数量随 60 次调用明显增长，怎么读都降不下来
        var after = try openDescriptors()

        for _ in 0 ..< 20 where after - before >= 16 {
            try await Task.sleep(for: .milliseconds(250))
            after = min(after, try openDescriptors())
        }

        #expect(after - before < 16)
    }

    /// 本机凭据回调的私有会话目录在成功、失败和取消后都被删除。
    @Test("本机凭据会话目录在三条路径上删除")
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

        // 等脚本输出会话目录后取消
        let (stream, continuation) = AsyncStream<Data>.makeStream()

        let waiting = Task {
            try await runner.execute(["fetch", "waiting"]) {
                if case .standardOutput(let data) = $0 {
                    continuation.yield(data)
                }
            }
        }

        var cancelled = Data()

        for await data in stream {
            cancelled.append(data)

            if cancelled.contains(10) {
                break
            }
        }

        waiting.cancel()
        continuation.finish()
        _ = await waiting.result

        for output in [succeeded.standardOutput, failure?.result.standardOutput ?? Data(), cancelled] {
            let session = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)

            #expect(session.hasPrefix("/tmp/spooky-local-"), "\(session)")
            #expect(!FileManager.default.fileExists(atPath: session), "\(session)")
        }
    }

    /// 写入可执行的测试脚本，只放在本测试的临时目录中；默认由 `/bin/sh` 解释。
    private func script(
        in temporary: TemporaryRepository,
        name: String,
        interpreter: String = "/bin/sh",
        body: String
    ) throws -> URL {
        let url = temporary.directory.appending(path: name)

        try Data(("#!" + interpreter + "\n" + body + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)

        return url
    }

    /// 等到脚本输出自己的 PID 后取消，返回该 PID 供检查进程是否已经结束。
    private func cancelAfterStart(_ runner: GitRunner) async throws -> Int32 {
        let (stream, continuation) = AsyncStream<Data>.makeStream()

        let task = Task {
            // 进程意外提前退出时结束输出流，测试不会一直等待 PID
            defer { continuation.finish() }

            return try await runner.execute(["status"]) {
                if case .standardOutput(let data) = $0 {
                    continuation.yield(data)
                }
            }
        }

        var output = Data()

        for await data in stream {
            output.append(data)

            if output.contains(10) {
                break
            }
        }

        task.cancel()
        continuation.finish()

        let error = await #expect(throws: GitError.self) { try await task.value }

        #expect(error?.isCancelled ?? false)

        return try #require(Int32(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)))
    }

    /// 当前进程打开的文件描述符数量。
    private func openDescriptors() throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    }
}
