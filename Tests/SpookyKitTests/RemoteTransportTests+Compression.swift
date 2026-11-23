import Foundation
import Testing

@testable import SpookyKit

/// 常驻通道里标准输出的压缩在本机运行：通道进程直接启动包装器，或一段发回坏压缩流的假 serve 脚本。
extension RemoteTransportTests {
    /// 就绪帧报出能压缩，探测立即应答；要求压缩的请求里，大块输出压缩、小块原样，压不小的内容第一块之后改为原样，
    /// 标准错误不压缩，接起来都与命令的原输出相同；放弃的请求不再收到帧。
    ///
    /// 一帧的负载可能分几段到达，每段各是一个事件：按压缩的字节数而不是事件数核对压缩了几块。
    @Test("包装器压缩要求压缩的请求的标准输出")
    func wrapperCompression() async throws {
        let session = try await createSession()
        let serve = try startServe(in: session)
        let random = FileManager.default.temporaryDirectory.appending(path: "spooky-random-" + UUID().uuidString)

        defer {
            try? serve.input.close()
            try? FileManager.default.removeItem(atPath: session)
            try? FileManager.default.removeItem(at: random)
        }

        var events = serve.events.makeAsyncIterator()
        #expect(await events.next() == .ready(version: 2, capabilities: RemoteCommandChannel.compressionCapability))

        // 探测不经命令，直接得到应答
        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.probe(identifier: 50))
        #expect(await events.next() == .probeReply(identifier: 50))

        // 好压缩的文本压缩发回，连同压缩的块在线路上的字节比原文少得多；标准错误原样发回，后面接着完成帧
        let text = (1 ... 10_000).map { "line \($0) of the compressible output\n" }.joined()
        let script = #"print "line $_ of the compressible output\n" for 1 .. 10000; print STDERR "e" x 4096"#
        let textEvents = try await serveRequest(
            operation(in: session, ["/usr/bin/perl", "-e", script]),
            identifier: 1,
            through: serve.input,
            events: &events
        )

        #expect(try decodedOutput(of: textEvents) == Data(text.utf8))
        #expect(
            String(decoding: standardError(of: textEvents), as: UTF8.self)
                .hasPrefix(String(repeating: "e", count: 4096) + "\u{1E}SPOOKY:")
        )
        #expect(wireBytes(of: textEvents) < text.utf8.count / 2)
        #expect(textEvents.last == .exit(identifier: 1, code: 0))

        // 不到 512 字节的块原样发回
        let smallEvents = try await serveRequest(
            operation(in: session, ["/usr/bin/printf", "hello"]),
            identifier: 2,
            through: serve.input,
            events: &events
        )

        #expect(smallEvents.first == .output(identifier: 2, isError: false, data: Data("hello".utf8)))
        #expect(compressedBytes(of: smallEvents) == 0)

        // 随机内容压不小：压缩的只有第一块，不超过一帧的上限，之后都原样发回
        let content = Data((0 ..< 512 * 1024).map { _ in UInt8.random(in: 0 ... 255) })
        try content.write(to: random)

        let randomEvents = try await serveRequest(
            operation(in: session, ["/bin/cat", random.path]),
            identifier: 3,
            through: serve.input,
            events: &events
        )

        let compressed = compressedBytes(of: randomEvents)
        let firstRaw = try #require(randomEvents.firstIndex {
            if case .output(_, false, _) = $0 { return true }
            return false
        })

        #expect(try decodedOutput(of: randomEvents) == content)
        #expect(compressed > 0)
        #expect(compressed <= RemoteCommandChannel.FrameReader.compressedChunkLimit)
        #expect(compressedBytes(of: Array(randomEvents[firstRaw...])) == 0)

        // 放弃一直输出的请求之后不再为它发帧，之后的请求照常完成
        let endless = [
            "/usr/bin/perl", "-e", "$| = 1; while (1) { print 'x' x 4096; select(undef, undef, undef, 0.01) }",
        ]

        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.request(
            identifier: 4,
            arguments: operation(in: session, endless),
            input: Data(),
            compressesOutput: true
        ))

        while let event = await events.next() {
            if case .compressedOutput(4, _) = event { break }
        }

        try serve.input.write(contentsOf: RemoteCommandChannel.Frame.abort(identifier: 4))

        let followingEvents = try await serveRequest(
            operation(in: session, ["/bin/echo", "done"]),
            identifier: 5,
            through: serve.input,
            events: &events
        )

        // 放弃之前已经发出的帧可能还在路上；请求 5 的第一帧之后不再有请求 4 的帧
        let identifiers = followingEvents.map(identifier(of:))
        let first = try #require(identifiers.firstIndex { $0 == 5 })

        #expect(!identifiers[first...].contains(4))
        #expect(!followingEvents.contains(.exit(identifier: 4, code: 0)))
        #expect(followingEvents.last == .exit(identifier: 5, code: 0))

        // 放弃的命令在下一次输出时结束；关掉会话时等它确认结束，再删会话目录
        _ = try await runWrapper(["close", session])
    }

    /// 加载不了 zlib 时包装器照常工作：就绪帧报出不能压缩，要求压缩的请求也原样发回。
    @Test("包装器加载不了 zlib 时不压缩")
    func wrapperWithoutCompression() async throws {
        let session = try await createSession()
        let modules = FileManager.default.temporaryDirectory.appending(path: "spooky-modules-" + UUID().uuidString)
        let fake = modules.appending(path: "Compress/Raw/Zlib.pm")

        try FileManager.default.createDirectory(
            at: fake.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("die 'unavailable';\n".utf8).write(to: fake)

        let serve = try startServe(in: session, perlOptions: ["-I", modules.path])

        defer {
            try? serve.input.close()
            try? FileManager.default.removeItem(atPath: session)
            try? FileManager.default.removeItem(at: modules)
        }

        var events = serve.events.makeAsyncIterator()
        #expect(await events.next() == .ready(version: 2, capabilities: 0))

        let textEvents = try await serveRequest(
            operation(in: session, ["/usr/bin/perl", "-e", "print 'x' x 200000"]),
            identifier: 1,
            through: serve.input,
            events: &events
        )

        #expect(try decodedOutput(of: textEvents) == Data(repeating: UInt8(ascii: "x"), count: 200_000))
        #expect(compressedBytes(of: textEvents) == 0)
    }

    /// 强制压缩时，并发请求各自解开自己的输出、逐字节不变；解开后超出上限按超限结束；取消照常，之后通道照常可用。
    @Test("常驻通道强制压缩下的并发、超限与取消")
    func compressedChannelRequests() async throws {
        let session = try await createSession()
        let channel = openChannel(in: session)

        defer {
            channel.close()
            try? FileManager.default.removeItem(atPath: session)
        }

        #expect(await channel.waitUntilReady())
        channel.chooseOutputCompression(.always)

        // 每个请求经 cat 送回自己的标准输入：前几个好压缩、内容各不相同，最后一个是随机内容
        var inputs: [Data] = (1 ... 5).map { (seed: Int) in
            Data((0 ..< 300 * 1024).map { (index: Int) in UInt8(truncatingIfNeeded: index / 64 * seed) })
        }
        inputs.append(Data((0 ..< 300 * 1024).map { _ in UInt8.random(in: 0 ... 255) }))

        let echoed = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (index, input) in inputs.enumerated() {
                group.addTask {
                    let result = try await channel.execute(
                        self.operation(in: session, ["/bin/cat"]),
                        input: input,
                        resultArguments: []
                    )

                    return (index, result.standardOutput)
                }
            }

            return try await group.reduce(into: [Int: Data]()) { $0[$1.0] = $1.1 }
        }

        for (index, input) in inputs.enumerated() {
            #expect(echoed[index] == input)
        }

        // 线路上压缩后很小，解开后是 257 MiB，超出 256 MiB 的上限
        let flooding = ["/usr/bin/perl", "-e", "print 'x' x 1048576 for 1 .. 257"]

        let error = await #expect(throws: GitError.self) {
            try await channel.execute(self.operation(in: session, flooding), input: Data(), resultArguments: [])
        }

        #expect(error?.category == .outputLimitExceeded)
        #expect(error?.result.standardOutput.count == 256 * 1024 * 1024)

        // 取消执行中的请求：带着已经解开的输出结束
        let started = String(repeating: "started\n", count: 1000)
        let command = ["/usr/bin/perl", "-e", #"$| = 1; print "started\n" x 1000; sleep 600"#]
        let cancelled = try await startLongRequest(operation(in: session, command), through: channel)
        cancelled.cancel()

        let cancellation = await #expect(throws: GitError.self) { try await cancelled.value }
        let received = cancellation?.result.standardOutput ?? Data()

        #expect(cancellation?.category == .cancelled)
        #expect(!received.isEmpty)
        #expect(Data(started.utf8).starts(with: received))

        // 之后的请求另起压缩流，照常解开
        let following = try await channel.execute(
            operation(in: session, ["/usr/bin/perl", "-e", "print 'y' x 100000"]),
            input: Data(),
            resultArguments: []
        )

        #expect(following.standardOutput == Data(repeating: UInt8(ascii: "y"), count: 100_000))

        // 关掉会话时等被放弃的命令确认结束，再删会话目录
        _ = try await runWrapper(["close", session])
    }

    /// 压缩的输出解不开时关掉通道：这个请求以 255 结束，持有者收到断开通知，之后的请求不执行。
    @Test("常驻通道的压缩输出解不开时关闭通道")
    func brokenCompressedOutput() async throws {
        // 发出能压缩的就绪帧，读到第一个请求后为它发回一段不是 raw deflate 的压缩帧；
        // 系统解压流攒够一定字节才开始解，坏数据要足够长才会报错
        let script = #"""
        $| = 1;
        syswrite STDOUT, pack('NCNC', 6, 0, 2, 1);
        sysread STDIN, my $header, 9;
        my (undef, undef, $id) = unpack('NCN', $header);
        syswrite STDOUT, pack('NCN', 5 + 4096, 4, $id) . ("\xff" x 4096);
        sleep 600;
        """#
        let (disconnected, disconnect) = AsyncStream<Void>.makeStream()
        let channel = RemoteCommandChannel(
            executable: "/usr/bin/perl",
            arguments: ["-e", script],
            environment: .inherit,
            onDisconnect: { _ in disconnect.finish() }
        )

        defer { channel.close() }

        #expect(await channel.waitUntilReady())
        channel.chooseOutputCompression(.always)

        let result = try await channel.execute(["inspect"], input: Data(), resultArguments: [])
        for await _ in disconnected { }

        #expect(result.exitCode == 255)
        #expect(result.standardOutput.isEmpty)
        await #expect(throws: RemoteCommandChannel.NotExecuted.self) {
            try await channel.execute(["inspect"], input: Data(), resultArguments: [])
        }
    }

    /// 自动时只在量到的往返时间不短于门槛、B 又能压缩时压缩；强制与关闭不看往返时间，B 不能压缩时一律不压缩。
    @Test("按往返时间、能力与设置决定是否压缩")
    func outputCompressionDecision() {
        let decides = RemoteCommandChannel.compressesOutput(roundTrip:capable:mode:)
        let threshold = RemoteCommandChannel.compressionRoundTrip

        // 自动：没量到、门槛之下不压缩，正好在门槛上压缩；B 不能压缩时不压缩
        #expect(!decides(nil, true, .automatic))
        #expect(!decides(threshold - .microseconds(1), true, .automatic))
        #expect(decides(threshold, true, .automatic))
        #expect(!decides(.seconds(1), false, .automatic))

        // 强制与关闭：不看往返时间
        #expect(decides(nil, true, .always))
        #expect(!decides(nil, false, .always))
        #expect(!decides(.seconds(1), true, .never))
    }

    /// 经 serve 发一个要求压缩的请求，收下它的帧直到它的结束帧。
    ///
    /// - Parameters:
    ///   - arguments: 请求的参数。
    ///   - identifier: 请求标识。
    ///   - input: serve 的标准输入。
    ///   - events: serve 发回的事件，之前的请求都已结束。
    /// - Returns: 结束帧之前收到的帧，连同结束帧。
    private func serveRequest(
        _ arguments: [String],
        identifier: UInt32,
        through input: FileHandle,
        events: inout AsyncStream<RemoteCommandChannel.FrameReader.Event>.Iterator
    ) async throws -> [RemoteCommandChannel.FrameReader.Event] {
        try input.write(contentsOf: RemoteCommandChannel.Frame.request(
            identifier: identifier,
            arguments: arguments,
            input: Data(),
            compressesOutput: true
        ))

        var received: [RemoteCommandChannel.FrameReader.Event] = []

        while let event = await events.next() {
            received.append(event)

            if case .exit(identifier, _) = event { break }
        }

        return received
    }

    /// 按到达顺序接起标准输出：压缩的块经同一个解压器解开，原样的块直接接上。
    private func decodedOutput(of events: [RemoteCommandChannel.FrameReader.Event]) throws -> Data {
        let inflater = RemoteCommandChannel.Inflater()
        var output = Data()

        for event in events {
            switch event {
            case .output(_, false, let data):
                output.append(data)

            case .compressedOutput(_, let data):
                output.append(try inflater.inflate(data))

            default:
                continue
            }
        }

        return output
    }

    /// 按到达顺序接起标准错误。
    private func standardError(of events: [RemoteCommandChannel.FrameReader.Event]) -> Data {
        events.reduce(into: Data()) { output, event in
            if case .output(_, true, let data) = event {
                output.append(data)
            }
        }
    }

    /// 标准输出在线路上的字节数：压缩的块按压缩后的大小算。
    private func wireBytes(of events: [RemoteCommandChannel.FrameReader.Event]) -> Int {
        events.reduce(0) { count, event in
            switch event {
            case .output(_, false, let data), .compressedOutput(_, let data): count + data.count
            default: count
            }
        }
    }

    /// 压缩的块在线路上的字节数。
    private func compressedBytes(of events: [RemoteCommandChannel.FrameReader.Event]) -> Int {
        events.reduce(0) { count, event in
            guard case .compressedOutput(_, let data) = event else { return count }
            return count + data.count
        }
    }
}
