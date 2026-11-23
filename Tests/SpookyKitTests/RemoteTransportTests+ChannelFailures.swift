import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// 常驻通道的放弃、取消与断开在本机运行：通道进程直接启动包装器或一段假的 serve 脚本。
extension RemoteTransportTests {
    /// 放弃一个请求之后 B 不再为它发帧；B 按顺序处理请求，之后的请求照常完成。
    @Test("常驻通道放弃的请求不再收到帧")
    func abortedChannelRequest() async throws {
        let session = try await createSession()
        let serve = try startServe(in: session)

        defer {
            try? serve.input.close()
            try? FileManager.default.removeItem(atPath: session)
        }

        var events = serve.events.makeAsyncIterator()
        #expect(await events.next() == .ready(version: 2, capabilities: RemoteCommandChannel.compressionCapability))

        // 请求 1 一直输出，收到它的第一段输出后放弃它，紧接着发请求 2 与请求 3
        let endless = ["/usr/bin/perl", "-e", "$| = 1; while (1) { print 'x'; select(undef, undef, undef, 0.01) }"]
        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.request(
            identifier: 1,
            arguments: operation(in: session, endless),
            input: Data()
        ))

        while let event = await events.next() {
            if case .output(1, _, _) = event { break }
        }

        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.abort(identifier: 1))
        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.request(
            identifier: 2,
            arguments: operation(in: session, ["/bin/echo", "done"]),
            input: Data()
        ))
        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.request(
            identifier: 3,
            arguments: ["inspect", session],
            input: Data()
        ))

        // 收到请求 2 与请求 3 的结束帧为止
        var received: [RemoteCommandChannel.FrameReader.Event] = []

        while let event = await events.next() {
            received.append(event)

            let exited = received.filter {
                if case .exit = $0 { return true }
                return false
            }

            if exited.count == 2 { break }
        }

        // 放弃之前已经发出的帧可能还在路上；请求 2 的第一帧之后不再有请求 1 的帧，请求 1 也没有结束帧
        let identifiers = received.map(identifier(of:))
        let first = try #require(identifiers.firstIndex { $0 != 1 })

        #expect(!identifiers[first...].contains(1))
        #expect(received.contains(.exit(identifier: 2, code: 0)))
        #expect(received.contains(.exit(identifier: 3, code: 0)))
        #expect(received.contains(.output(identifier: 2, isError: false, data: Data("done\n".utf8))))

        // 放弃的命令在下一次输出时结束；关掉会话时等它确认结束，再删会话目录
        _ = try await runWrapper(["close", session])
    }

    /// 命令退出后，脱离进程组的后代仍占着请求的输出管道；结束帧不等这些管道关闭，
    /// 后代不停往管道里写时也只转发有限的输出，之后的请求照常完成。
    @Test("逃逸的后代占着输出管道时请求照常结束")
    func escapedDescendant() async throws {
        let session = try await createSession()
        let channel = openChannel(in: session)
        let tag = UUID().uuidString

        defer {
            channel.close()
            try? FileManager.default.removeItem(atPath: session)
        }

        // 子进程脱离进程组之后父进程才退出，子进程一直占着继承来的输出管道
        let script = #"""
        pipe(my $read, my $write);
        if (fork) { close $write; sysread($read, my $byte, 1); print "started\n"; exit 0 }
        close $read; POSIX::setsid(); close $write; sleep 600
        """#
        let result = try await channel.execute(
            operation(in: session, ["/usr/bin/perl", "-MPOSIX", "-e", script, tag]),
            input: Data(),
            resultArguments: []
        )

        _ = try? await CommandExecutor.execute(executable: "/usr/bin/pkill", processArguments: ["-f", tag])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput == Data("started\n".utf8))

        // 脱离进程组的后代换成不停输出的 yes，它开始执行之后父进程才输出并退出
        let flooding = UUID().uuidString
        let flood = #"""
        pipe(my $read, my $write);
        if (fork) { close $write; sysread($read, my $byte, 1); print "started\n"; exit 0 }
        close $read; POSIX::setsid(); exec '/usr/bin/yes', $ARGV[0];
        """#

        let flooded = try await channel.execute(
            operation(in: session, ["/usr/bin/perl", "-MPOSIX", "-e", flood, flooding]),
            input: Data(),
            resultArguments: []
        )
        let following = try await channel.execute(["inspect", session], input: Data(), resultArguments: [])

        _ = try? await CommandExecutor.execute(executable: "/usr/bin/pkill", processArguments: ["-f", flooding])

        // 父进程退出之前写下的输出都转发到了
        #expect(flooded.exitCode == 0)
        #expect(String(decoding: flooded.standardOutput, as: UTF8.self).contains("started\n"))
        #expect(following.exitCode == 0)
    }

    /// 编码后超过上限的请求不交给 B；标准错误超过上限的请求按超限结束，只留上限内的字节；两种情况之后通道都照常可用。
    @Test("常驻通道的请求与标准错误超出上限")
    func channelLimits() async throws {
        let session = try await createSession()
        let channel = openChannel(in: session)

        defer {
            channel.close()
            try? FileManager.default.removeItem(atPath: session)
        }

        // 只是标准输入就到了上限
        await #expect(throws: RemoteCommandChannel.NotExecuted.self) {
            try await channel.execute(
                ["inspect", session],
                input: Data(count: RemoteCommandChannel.requestLimit),
                resultArguments: []
            )
        }

        #expect(try await channel.execute(["inspect", session], input: Data(), resultArguments: []).exitCode == 0)

        // 标准错误写 2 MiB，上限是 1 MiB
        let flooding = ["/usr/bin/perl", "-e", "print STDERR 'x' x (2 * 1024 * 1024)"]

        let error = await #expect(throws: GitError.self) {
            try await channel.execute(self.operation(in: session, flooding), input: Data(), resultArguments: [])
        }

        #expect(error?.category == .outputLimitExceeded)
        #expect(error?.result.standardError == Data(repeating: UInt8(ascii: "x"), count: 1024 * 1024))
        #expect(try await channel.execute(["inspect", session], input: Data(), resultArguments: []).exitCode == 0)

        // 关掉会话时等被放弃的命令确认结束，再删会话目录
        _ = try await runWrapper(["close", session])
    }

    /// 取消的请求带着已经收到的输出立即结束，通道照常可用；通道进程被结束时执行中的请求以 255 结束，
    /// 之后的请求不执行，持有者收到断开通知。
    @Test("常驻通道的取消与通道进程被结束")
    func channelCancellationAndLoss() async throws {
        let session = try await createSession()
        let (disconnected, disconnect) = AsyncStream<Void>.makeStream()
        let channel = openChannel(in: session) { _ in disconnect.finish() }
        let command = ["/bin/sh", "-c", "echo started; exec /bin/sleep 600"]

        defer { channel.close() }

        // 取消执行中的请求
        let cancelled = try await startLongRequest(operation(in: session, command), through: channel)
        cancelled.cancel()

        let error = await #expect(throws: GitError.self) { try await cancelled.value }
        #expect(error?.category == .cancelled)
        #expect(error?.result.standardOutput == Data("started\n".utf8))
        #expect(try await channel.execute(["inspect", session], input: Data(), resultArguments: []).exitCode == 0)

        // 结束通道进程
        let pending = try await startLongRequest(operation(in: session, command), through: channel)
        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/pkill",
            processArguments: ["-KILL", "-f", "serv[e] " + session]
        )

        let result = try await pending.value
        for await _ in disconnected { }

        #expect(result.exitCode == 255)
        #expect(result.standardOutput == Data("started\n".utf8))
        await #expect(throws: RemoteCommandChannel.NotExecuted.self) {
            try await channel.execute(["inspect", session], input: Data(), resultArguments: [])
        }

        // 关掉会话，结束还在执行的命令
        _ = try await runWrapper(["close", session])
    }

    /// 写入一直等着时，开始写之前任务已被取消的请求与排在后面时被取消的请求都不交给 B；
    /// 通道进程不再读取标准输入后被结束：正在写的请求与之后的请求都不执行，测试进程不会收到 SIGPIPE。
    @Test("写出之前取消的请求不执行，通道进程退出后写入请求不触发 SIGPIPE")
    func channelWriteAfterExit() async throws {
        let tag = UUID().uuidString

        // 读到请求的第一个字节就发出就绪帧，之后不再读取
        let channel = RemoteCommandChannel(
            executable: "/usr/bin/perl",
            arguments: ["-e", "sysread STDIN, my $byte, 1; syswrite STDOUT, pack('NCNC', 6, 0, 2, 0); sleep 600", tag],
            environment: .inherit,
            onDisconnect: { _ in }
        )

        defer { channel.close() }

        // 请求远大于管道容量，通道进程不再读取后写入一直等着
        let pending = Task {
            try await channel.execute(["inspect"], input: Data(count: 512 * 1024), resultArguments: [])
        }

        #expect(await channel.waitUntilReady())

        // 开始之前任务已被取消的请求
        let cancelledFirst = Task {
            withUnsafeCurrentTask { $0?.cancel() }

            return try await channel.execute(["inspect"], input: Data(), resultArguments: [])
        }

        await #expect(throws: RemoteCommandChannel.NotExecuted.self) { try await cancelledFirst.value }

        // 排在一直等着的写入后面时被取消的请求
        let queued = Task {
            try await channel.execute(["inspect"], input: Data(), resultArguments: [])
        }

        queued.cancel()
        await #expect(throws: RemoteCommandChannel.NotExecuted.self) { try await queued.value }

        _ = try await CommandExecutor.execute(executable: "/usr/bin/pkill", processArguments: ["-f", tag])

        await #expect(throws: RemoteCommandChannel.NotExecuted.self) { try await pending.value }
        await #expect(throws: RemoteCommandChannel.NotExecuted.self) {
            try await channel.execute(["inspect"], input: Data(), resultArguments: [])
        }
    }

    /// 通道进程没有发出就绪帧就退出时，等待就绪得到失败，已经写进去的请求不执行；等待就绪期间被取消时关闭通道。
    @Test("常驻通道没有就绪时请求不执行，等待就绪可以取消")
    func channelNeverReady() async throws {
        // 读到请求的第一个字节就退出
        let channel = RemoteCommandChannel(
            executable: "/usr/bin/perl",
            arguments: ["-e", "sysread STDIN, my $byte, 1"],
            environment: .inherit,
            onDisconnect: { _ in }
        )
        let pending = Task {
            try await channel.execute(["inspect"], input: Data(), resultArguments: [])
        }

        #expect(await !channel.waitUntilReady())
        #expect(!channel.isReady)
        await #expect(throws: RemoteCommandChannel.NotExecuted.self) { try await pending.value }

        // 带前导的通道在分隔标记之前不计就绪期限，通道进程也一直不退出：等待被取消时关闭通道，等待随之结束
        let waiting = RemoteCommandChannel(
            executable: "/bin/sh",
            arguments: ["-c", "exec /bin/cat > /dev/null"],
            environment: .inherit,
            preamble: RemoteCommandChannel.Preamble(
                input: Data(),
                marker: RemoteHealthCheck.channelMarker("marker"),
                arguments: []
            ),
            onDisconnect: { _ in }
        )
        let wait = Task { await waiting.waitUntilReady() }
        wait.cancel()

        #expect(await !wait.value)
    }

    /// 经通道发出一条一直执行的请求，等它的命令打印出第一行后返回。
    ///
    /// - Parameters:
    ///   - arguments: 包装器 run 模式的参数。
    ///   - channel: 常驻通道。
    /// - Returns: 执行请求的任务。
    func startLongRequest(
        _ arguments: [String],
        through channel: RemoteCommandChannel
    ) async throws -> Task<GitCommandResult, any Error> {
        let (started, start) = AsyncStream<Void>.makeStream()

        let task = Task {
            try await channel.execute(arguments, input: Data(), resultArguments: []) { event in
                if case .standardOutput = event { start.finish() }
            }
        }

        for await _ in started { }
        return task
    }

    /// 直接启动 serve 模式的包装器，逐帧读出它发回的事件；读到 EOF 或格式错误的帧时事件流结束。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - perlOptions: 加在包装器路径之前的 Perl 选项。
    /// - Returns: 写请求的标准输入，以及发回的事件。
    func startServe(
        in session: String,
        perlOptions: [String] = []
    ) throws -> (input: FileHandle, events: AsyncStream<RemoteCommandChannel.FrameReader.Event>) {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let reader = Mutex(RemoteCommandChannel.FrameReader())
        let (events, continuation) = AsyncStream<RemoteCommandChannel.FrameReader.Event>.makeStream()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = perlOptions + [Self.wrapper.path, "serve", session]
        process.standardInput = input
        process.standardOutput = output

        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            let parsed = data.isEmpty ? nil : reader.withLock { try? $0.receive(data) }

            guard let parsed else {
                handle.readabilityHandler = nil
                continuation.finish()
                return
            }

            for event in parsed {
                continuation.yield(event)
            }
        }

        try process.run()
        return (input.fileHandleForWriting, events)
    }

    /// 事件所属的请求；就绪帧与探测的应答不属于任何请求。
    func identifier(of event: RemoteCommandChannel.FrameReader.Event) -> UInt32? {
        switch event {
        case .ready, .probeReply: nil
        case .output(let identifier, _, _): identifier
        case .compressedOutput(let identifier, _): identifier
        case .exit(let identifier, _): identifier
        }
    }
}
