import Foundation
import Testing

@testable import SpookyKit

/// 包装器的会话看守与关闭在本机运行：中继换成按计划应答的假中继。
extension RemoteTransportTests {
    /// 假中继：在会话目录里监听 relay.sock，按参数里的计划处理每个连接，接受连接时打印这一步的名字。
    ///
    /// `answer` 回应一次心跳，`close` 立即关掉连接，`hold` 一直不回应；计划只剩最后一步时一直重复它。
    private static let fakeRelay = #"""
    use IO::Socket::UNIX;
    $| = 1;
    my ($path, @plan) = @ARGV;
    my $server = IO::Socket::UNIX->new(Type => SOCK_STREAM, Local => $path, Listen => 8) or die;
    my @held;
    print "ready\n";

    while (my $client = $server->accept) {
        my $step = @plan > 1 ? shift(@plan) : $plan[0];
        print "$step\n";

        if ($step eq 'hold') {
            push @held, $client;
            next;
        }

        if ($step eq 'answer') {
            my $request = <$client>;
            print {$client} qq({"accepted":true,"value":""}\n);
        }

        close $client;
    }
    """#

    /// 心跳没有回应时看守等过容忍期才结束会话，其间执行中的命令照常运行；通道被关闭时立即结束会话，会话目录已不在时关闭照样成功。
    @Test("会话看守容忍网络停顿，通道关闭时立即清理")
    func watcherTolerance() async throws {
        // 通道一被关闭就清理会话，不再发心跳
        let closing = try await createSession()
        defer { try? FileManager.default.removeItem(atPath: closing) }

        let closingSteps = try await watch(closing, plan: ["close"])
        #expect(closingSteps == ["close"])

        _ = try await runWrapper(["close", closing])

        // 停顿短于容忍期时看守接着发心跳；得到回应后重新计时，之后连续两次没有回应才超过容忍期
        let stalled = try await createSession()
        defer { try? FileManager.default.removeItem(atPath: stalled) }

        let operation = UUID().uuidString.lowercased()
        let command = try await startOperation(operation, in: stalled)
        defer { if command.process.isRunning { command.process.terminate() } }

        let stalledSteps = try await watch(stalled, plan: ["hold", "answer", "hold"])
        #expect(stalledSteps == ["hold", "answer", "hold", "hold"])

        // 命令一直执行到会话结束，由看守取消并等到确认
        for await _ in command.exits { }

        let marker = try command.errors.fileHandleForReading.readToEnd() ?? Data()
        #expect(String(decoding: marker, as: UTF8.self) == "\u{1E}SPOOKY:\(operation):0:15:1\u{1F}")
    }

    /// 看守删掉结束超过保留期的操作目录与过期的取消标记；保留期内结束的操作与新近的取消标记留着，对这条操作的取消直接得到确认。
    @Test("会话看守清理过期的操作")
    func operationPruning() async throws {
        let session = try await createSession()
        defer { try? FileManager.default.removeItem(atPath: session) }

        var relay = try await startRelay(in: session, plan: ["answer"])
        defer { relay.process.terminate() }

        // 两条已结束的操作；早的那条结束后又被取消过，取消直接得到确认，留下取消标记
        let early = UUID().uuidString.lowercased()
        let recent = UUID().uuidString.lowercased()

        for operation in [early, recent] {
            _ = try await runWrapper(["run", session, operation, "2", "/usr/bin/true"])
        }

        _ = try await runWrapper(["cancel", session, early, "2"])

        // 两个没开始执行的操作留下的取消标记：一个早已过期，一个刚留下
        let abandoned = "cancel-" + UUID().uuidString.lowercased()
        let pending = "cancel-" + UUID().uuidString.lowercased()
        try Data().write(to: URL(fileURLWithPath: session + "/" + abandoned))
        try Data().write(to: URL(fileURLWithPath: session + "/" + pending))

        // 早的那条操作与过期的标记改成 10 分钟以前留下的
        for name in [early + "/done", "cancel-" + early, abandoned] {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: -600)],
                ofItemAtPath: session + "/" + name
            )
        }

        _ = try await runWrapper(["watch", session, "6", "300"])

        // 看守第一轮心跳之后就清理一遍，第二次心跳时这一遍已经清理完
        for _ in 0 ..< 2 {
            #expect(try await relay.steps.next() == "answer")
        }

        let remaining = try FileManager.default.contentsOfDirectory(atPath: session)
        #expect(Set(remaining) == [recent, pending, "relay.sock", "session.json"])
        #expect(FileManager.default.fileExists(atPath: session + "/" + recent + "/done"))

        // 保留期内结束的操作，取消照样直接得到确认；关掉会话后看守随之退出
        _ = try await runWrapper(["cancel", session, recent, "2"])
        _ = try await runWrapper(["close", session])
    }

    /// 心跳连不上中继之后，看守接着清理会话；清理比心跳的超时更久时，看守不会中途被定时器结束。
    @Test("心跳失败后的清理不受心跳定时器影响")
    func watcherOutlivesHeartbeatTimer() async throws {
        let session = try await createSession()
        defer { try? FileManager.default.removeItem(atPath: session) }

        // 执行它的 run 已被强行结束的操作：目录还在，没有控制 socket 也没有 done，取消只能等 done 出现
        let operation = UUID().uuidString.lowercased()
        try FileManager.default.createDirectory(
            atPath: session + "/" + operation,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        // 看守留下取消标记 4 秒后才补上 done，比心跳的 3 秒超时更久，又在取消的期限之内
        let finisher = Process()
        finisher.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        finisher.arguments = [
            "-MTime::HiRes=sleep",
            "-e",
            #"sleep(0.05) until -e $ARGV[0]; sleep(4); open(my $f, '>', $ARGV[1]) or die;"#,
            session + "/cancel-" + operation,
            session + "/" + operation + "/done",
        ]
        try finisher.run()
        defer { if finisher.isRunning { finisher.terminate() } }

        // 会话里没有 relay.sock，看守的第一次心跳就连不上，随即开始清理
        _ = try await runWrapper(["watch", session, "6", "300"])

        for await _ in try await watcherExit(in: session) { }

        // 看守一直撑到 done 出现，确认操作结束后删掉了会话目录
        #expect(!FileManager.default.fileExists(atPath: session))
    }

    /// 控制连接没发报文就断开时，run 继续监督命令直到它结束，不会被读报文的定时器结束。
    @Test("控制连接断开后 run 照常等命令结束")
    func supervisorOutlivesControlTimer() async throws {
        let session = try await createSession()
        defer { try? FileManager.default.removeItem(atPath: session) }

        // 命令执行 4 秒，比读控制报文的 2 秒超时更久
        let operation = UUID().uuidString.lowercased()
        let command = try await startOperation(operation, in: session, duration: 4)
        defer { if command.process.isRunning { command.process.terminate() } }

        // 连上控制 socket 立即断开，不发任何报文
        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [
                "-MIO::Socket::UNIX",
                "-e",
                "IO::Socket::UNIX->new(Type => SOCK_STREAM(), Peer => $ARGV[0]) or die;",
                session + "/" + operation + "/control.sock",
            ]
        )

        for await _ in command.exits { }

        let marker = try command.errors.fileHandleForReading.readToEnd() ?? Data()
        #expect(command.process.terminationReason == .exit)
        #expect(command.process.terminationStatus == 0)
        #expect(String(decoding: marker, as: UTF8.self) == "\u{1E}SPOOKY:\(operation):0:0:0\u{1F}")
    }

    /// 控制连接没回报文就断开、之后再也连不上时，cancel 等到期限后报告未确认，不会被读报文的定时器结束。
    @Test("控制连接断开后 cancel 照常等到期限")
    func cancellationOutlivesControlTimer() async throws {
        let session = try await createSession()
        defer { try? FileManager.default.removeItem(atPath: session) }

        let operation = UUID().uuidString.lowercased()
        let directory = session + "/" + operation

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        // 假的控制 socket：接受一次连接后不回报文就关闭，之后不再监听
        let script = #"""
        $| = 1;
        my $server = IO::Socket::UNIX->new(Type => SOCK_STREAM(), Local => $ARGV[0], Listen => 1) or die;
        print "ready\n";
        close $server->accept;
        close $server;
        """#

        let control = Process()
        let output = Pipe()
        control.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        control.arguments = ["-MIO::Socket::UNIX", "-e", script, directory + "/control.sock"]
        control.standardOutput = output
        try control.run()
        defer { if control.isRunning { control.terminate() } }

        var lines = output.fileHandleForReading.bytes.lines.makeAsyncIterator()
        #expect(try await lines.next() == "ready")

        // 读报文的定时器比取消的期限早到期；cancel 一直等到期限，以未确认退出
        let result = try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [Self.wrapper.path, "cancel", session, operation, "2"],
            acceptedExitCodes: [0, 1]
        )

        #expect(result.exitCode == 1)
    }

    /// 在本机运行包装器的一个模式，退出码不为 0 时抛出。
    ///
    /// - Parameters:
    ///   - arguments: 模式与它的参数。
    ///   - input: 标准输入。
    /// - Returns: 包装器的输出与退出状态。
    func runWrapper(_ arguments: [String], input: Data? = nil) async throws -> GitCommandResult {
        try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [Self.wrapper.path] + arguments,
            input: input
        )
    }

    /// 用包装器建一个本机会话目录。
    ///
    /// - Returns: 会话目录的路径。
    func createSession() async throws -> String {
        let token = (0 ..< 32).map { _ in String(format: "%02x", UInt8.random(in: 0 ... 255)) }.joined()
        let created = try await runWrapper(
            ["create-session"],
            input: Data(#"{"token":"\#(token)"}"#.utf8) + Data([10])
        )

        return String(decoding: created.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
    }

    /// 在会话里经 `run` 启动一条执行一段时间的命令，等它开始执行后返回。
    ///
    /// - Parameters:
    ///   - operation: 操作标识。
    ///   - session: 会话目录。
    ///   - duration: 命令执行的秒数。
    /// - Returns: 包装器进程、它的标准错误与退出事件。
    private func startOperation(
        _ operation: String,
        in session: String,
        duration: Int = 60
    ) async throws -> (process: Process, errors: Pipe, exits: AsyncStream<Void>) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        let (exits, exited) = AsyncStream<Void>.makeStream()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            Self.wrapper.path, "run", session, operation, "2",
            "/bin/sh", "-c", "echo started; exec /bin/sleep \(duration)",
        ]
        process.standardOutput = output
        process.standardError = errors
        process.terminationHandler = { _ in exited.finish() }
        try process.run()

        // 命令打印出第一行时已经在包装器的进程组里执行
        var lines = output.fileHandleForReading.bytes.lines.makeAsyncIterator()
        #expect(try await lines.next() == "started")

        return (process, errors, exits)
    }

    /// 给会话接上假中继并启动看守，等会话目录被删除后收起假中继。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - plan: 假中继处理各个连接的计划。
    /// - Returns: 会话目录被删除之前，假中继处理过的每一步。
    private func watch(_ session: String, plan: [String]) async throws -> [String] {
        var relay = try await startRelay(in: session, plan: plan)
        defer { relay.process.terminate() }

        // 删除事件要在启动看守之前开始监听
        let removal = try removal(of: session)

        _ = try await runWrapper(["watch", session, "6", "300"])

        for await _ in removal { }

        // 会话目录删除后看守已经退出，收起假中继，读完它处理过的步骤
        relay.process.terminate()
        var steps: [String] = []

        while let step = try await relay.steps.next() {
            steps.append(step)
        }

        return steps
    }

    /// 在会话目录里启动假中继，等它开始监听后返回。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - plan: 假中继处理各个连接的计划。
    /// - Returns: 假中继进程，以及逐行读出它处理的每一步。
    private func startRelay(
        in session: String,
        plan: [String]
    ) async throws -> (process: Process, steps: AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.fakeRelay, session + "/relay.sock"] + plan
        process.standardOutput = output
        try process.run()

        var steps = output.fileHandleForReading.bytes.lines.makeAsyncIterator()
        #expect(try await steps.next() == "ready")

        return (process, steps)
    }

    /// 会话看守进程退出时结束的事件流。
    ///
    /// - Parameter session: 会话目录。
    /// - Returns: 只在看守退出时结束、不产出元素的事件流。
    private func watcherExit(in session: String) async throws -> AsyncStream<Void> {
        // 方括号让匹配式不匹配 pgrep 所在命令行本身
        let found = try await CommandExecutor.execute(
            executable: "/usr/bin/pgrep",
            processArguments: ["-f", "watc[h] " + session]
        )
        let line = String(decoding: found.standardOutput, as: UTF8.self).split(separator: "\n").first
        let pid = try #require(line.flatMap { pid_t($0) })

        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .global())
        let (exited, finished) = AsyncStream<Void>.makeStream()

        source.setEventHandler { source.cancel() }
        source.setCancelHandler { finished.finish() }
        source.resume()

        // 开始监听之前看守已经退出时，退出事件不会再来
        if kill(pid, 0) != 0, errno == ESRCH {
            source.cancel()
        }

        return exited
    }

    /// 会话目录被删除时结束的事件流。
    ///
    /// - Parameter session: 会话目录。
    /// - Returns: 只在目录被删除时结束、不产出元素的事件流。
    private func removal(of session: String) throws -> AsyncStream<Void> {
        let descriptor = Darwin.open(session, O_EVTONLY | O_CLOEXEC)
        try #require(descriptor >= 0)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .delete,
            queue: .global()
        )
        let (removed, finished) = AsyncStream<Void>.makeStream()

        // 收到删除事件就取消监听，取消时关掉描述符并结束事件流
        source.setEventHandler { source.cancel() }
        source.setCancelHandler {
            Darwin.close(descriptor)
            finished.finish()
        }
        source.resume()

        return removed
    }
}
