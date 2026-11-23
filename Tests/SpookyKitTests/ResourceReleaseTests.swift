import Darwin
import Foundation
import Testing

@testable import SpookyKit

// MARK: - ResourceReleaseTests

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
    /// 在只运行这一项的子进程里计数：数的是整个进程打开的描述符，与其它测试同在一个进程时，它们的连接与管道也会算进来。
    @Test("成功、失败与取消都释放文件描述符")
    func descriptors() async {
        await #expect(processExitsWith: .success) {
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

            let after = try openDescriptors()

            // 任一条路径每次泄漏一个，20 次就多出 20 个
            #expect(after - before < 16)
        }
    }

    /// 常驻通道反复经历持有者关闭、通道进程被结束、没有就绪、前导没写完就结束与等前导时被取消之后，
    /// 进程打开的描述符数量不随次数增长。
    ///
    /// 与 ``descriptors()`` 一样在只运行这一项的子进程里计数；通道进程直接以 serve 模式运行本机的包装器。
    @Test("常驻通道的各条结束路径都释放文件描述符")
    func channelDescriptors() async {
        await #expect(processExitsWith: .success) {
            let transport = RemoteTransportTests()
            let session = try await transport.createSession()
            defer { try? FileManager.default.removeItem(atPath: session) }

            let before = try openDescriptors()

            for _ in 0 ..< 20 {
                // 执行一条请求后由持有者关闭
                let closed = transport.openChannel(in: session)
                _ = try await closed.execute(["inspect", session], input: Data(), resultArguments: [])
                closed.close()

                // 就绪之后通道进程被结束
                let (disconnected, disconnect) = AsyncStream<Void>.makeStream()
                let killed = transport.openChannel(in: session) { _ in disconnect.finish() }

                #expect(await killed.waitUntilReady())

                _ = try await CommandExecutor.execute(
                    executable: "/usr/bin/pkill",
                    processArguments: ["-KILL", "-f", "serv[e] " + session]
                )

                for await _ in disconnected { }

                // 通道进程读到请求的第一个字节就退出，没有就绪
                let starting = RemoteCommandChannel(
                    executable: "/usr/bin/perl",
                    arguments: ["-e", "sysread STDIN, my $byte, 1"],
                    environment: .inherit,
                    onDisconnect: { _ in }
                )

                await #expect(throws: RemoteCommandChannel.NotExecuted.self) {
                    try await starting.execute(["inspect"], input: Data(), resultArguments: [])
                }

                // 前导没写完就结束，或等前导时被取消
                try await endPreambleChannels()
            }

            let after = try openDescriptors()

            // 任一条路径每次泄漏一个，20 次就多出 20 个
            #expect(after - before < 16)
        }
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
}

// MARK: - Helpers

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

/// 让两条帧之前带前导的通道在前导阶段结束：一条没写分隔标记就退出，一条在等前导时被取消。
private func endPreambleChannels() async throws {
    let open: ([String]) -> RemoteCommandChannel = {
        RemoteCommandChannel(
            executable: "/bin/sh",
            arguments: $0,
            environment: .inherit,
            preamble: RemoteCommandChannel.Preamble(
                input: Data("marker\n".utf8),
                marker: RemoteHealthCheck.channelMarker("marker"),
                arguments: []
            ),
            onDisconnect: { _ in }
        )
    }

    // 读完前导的输入就以 3 退出，没写分隔标记：前导带着结束状态，通道随之关闭
    let unfinished = open(["-c", "read -r line; exit 3"])

    #expect(try await unfinished.preambleResult().exitCode == 3)
    #expect(await !unfinished.waitUntilReady())

    // 等前导期间被取消：通道关闭，通道进程随之结束
    let waiting = open(["-c", "exec /bin/sleep 60"])
    let task = Task { try await waiting.preambleResult() }
    task.cancel()

    await #expect(throws: GitError.self) { try await task.value }
}

/// 当前进程打开的文件描述符数量。
private func openDescriptors() throws -> Int {
    try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
}
