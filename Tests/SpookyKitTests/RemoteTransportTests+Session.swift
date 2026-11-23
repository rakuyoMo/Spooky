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
        let closing = try await createSession(tolerance: "6")
        defer { try? FileManager.default.removeItem(atPath: closing) }

        let closingSteps = try await watch(closing, plan: ["close"])
        #expect(closingSteps == ["close"])

        _ = try await runWrapper(["close", closing])

        // 停顿短于容忍期时看守接着发心跳；得到回应后重新计时，之后连续两次没有回应才超过容忍期
        let stalled = try await createSession(tolerance: "6")
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

        // 看守等到转发的 socket 出现才开始心跳
        var relay = try await startRelay(in: session, plan: ["answer"])
        defer { relay.process.terminate() }

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

    /// 看守在清理过期操作的同一节拍上记下包装器的使用：只更新访问时间，修改时间不变。
    @Test("会话看守定期记下包装器的使用")
    func watcherRecordsUse() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-wrapper-" + UUID().uuidString)
        let wrapper = directory.appending(path: "spooky-remote")
        defer { try? FileManager.default.removeItem(at: directory) }

        // 会话与看守从测试自己的副本新建，记下的是这份副本的使用；保留期 1 秒，每一轮心跳之后都记一次
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try FileManager.default.copyItem(at: Self.wrapper, to: wrapper)

        // 新建会话之前就把两个时间改到 100 天前：新建会话与看守都先读出修改时间再连同访问时间写回，写回的修改时间都相同
        let past = time(nil) - 100 * 24 * 60 * 60
        var times = [timeval(tv_sec: past, tv_usec: 0), timeval(tv_sec: past, tv_usec: 0)]
        try #require(utimes(wrapper.path, &times) == 0)

        let session = try await createSession(retention: "1", wrapper: wrapper)
        defer { try? FileManager.default.removeItem(atPath: session) }

        var relay = try await startRelay(in: session, plan: ["answer"])
        defer { relay.process.terminate() }

        #expect(try await relay.steps.next() == "answer")

        // 看守已经开始心跳，访问时间这时再改回 100 天前，之后只会因看守记下使用而更新
        try #require(utimes(wrapper.path, &times) == 0)

        let watching = try attributeChanges(of: wrapper.path)
        defer { watching.source.cancel() }

        var changes = watching.changes.makeAsyncIterator()

        while try status(of: wrapper.path).st_atimespec.tv_sec == past {
            _ = await changes.next()
        }

        #expect(try status(of: wrapper.path).st_mtimespec.tv_sec == past)

        // 关掉会话后看守随之退出
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

        // relay.sock 出现了却没有人监听，看守的第一次心跳就连不上，随即开始清理
        let exit = try await watcherExit(in: session)
        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [
                "-MIO::Socket::UNIX",
                "-e",
                "IO::Socket::UNIX->new(Type => SOCK_STREAM, Local => $ARGV[0], Listen => 1) or die",
                session + "/relay.sock",
            ]
        )

        for await _ in exit { }

        // 看守一直撑到 done 出现，确认操作结束后删掉了会话目录
        #expect(!FileManager.default.fileExists(atPath: session))
    }

    /// 新建会话不读标准输入，也不分出看守；开始会话先校验看守的两个参数，写入令牌之后才分出看守，
    /// 分出的看守不留调用方的输出与其它描述符；转发的 socket 到期仍没有出现时，看守不发心跳，按心跳失败清理会话。
    @Test("开始会话时分出看守，转发到期没有出现就清理会话")
    func sessionWatcher() async throws {
        // 新建会话不读标准输入，之后的 cat 读到全部输入；会话目录是空的，没有看守
        let input = tokenLine()
        let created = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", #"/usr/bin/perl "$0" create-session && exec cat"#, Self.wrapper.path],
            input: input
        )
        let output = String(decoding: created.standardOutput, as: UTF8.self)
        let session = String(output.prefix { $0 != "\n" })
        defer { try? FileManager.default.removeItem(atPath: session) }

        #expect(session.hasPrefix("/tmp/spooky-"))
        #expect(Data(output.dropFirst(session.count + 1).utf8) == input)
        #expect(try FileManager.default.contentsOfDirectory(atPath: session).isEmpty)
        #expect(try await watchers(of: session) == 0)

        // 参数不对时报错，不写令牌，也不分出看守
        for arguments in [["x", "300"], ["6"]] {
            let rejected = try await startSession(input, in: session, arguments: arguments)
            #expect(rejected.exitCode != 0)
        }

        #expect(try FileManager.default.contentsOfDirectory(atPath: session).isEmpty)
        #expect(try await watchers(of: session) == 0)

        // 标准输出另有一份在 3 号描述符上：看守留着其中任何一个，这里就读不到输出结束
        _ = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: [
                "-c", #"exec 3>&1; exec /usr/bin/perl "$0" start-session "$1" 600 300"#,
                Self.wrapper.path, session,
            ],
            input: input
        )

        #expect(try FileManager.default.contentsOfDirectory(atPath: session) == ["session.json"])
        #expect(try await watchers(of: session) == 1)
        _ = try await runWrapper(["close", session])

        // 容忍期 1 秒内 relay.sock 一直没出现，看守按心跳失败清理会话
        let expiring = try await createSession(tolerance: "1")
        defer { try? FileManager.default.removeItem(atPath: expiring) }

        for await _ in try removal(of: expiring) { }

        #expect(!FileManager.default.fileExists(atPath: expiring))
    }

    /// 开始会话时令牌只认标准输入的一行 64 个小写十六进制字符，会话目录不对或已经写过时拒绝；
    /// 写成之后会话目录里只有完整的 session.json，不留临时文件。
    @Test("写入令牌只接受格式正确的第一次")
    func sessionToken() async throws {
        let session = try await createSession(startsSession: false)
        defer { try? FileManager.default.removeItem(atPath: session) }

        let token = String(repeating: "0123456789abcdef", count: 4)
        let path = session + "/session.json"
        let written = Data(#"{"token":"\#(token)"}"#.utf8)

        // 大写、少一个字符、缺少换行与空输入都不对
        for line in [token.uppercased() + "\n", String(token.dropLast()) + "\n", token, ""] {
            let rejected = try await startSession(Data(line.utf8), in: session)
            #expect(rejected.exitCode != 0)
        }

        #expect(!FileManager.default.fileExists(atPath: path))

        // 会话目录不在
        let missing = try await startSession(Data((token + "\n").utf8), in: session + "/missing")
        #expect(missing.exitCode != 0)

        let accepted = try await startSession(Data((token + "\n").utf8), in: session)
        #expect(accepted.exitCode == 0)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == written)
        #expect(try FileManager.default.contentsOfDirectory(atPath: session) == ["session.json"])

        // 已经写过：拒绝，内容不变
        let repeated = try await startSession(Data((String(repeating: "f", count: 64) + "\n").utf8), in: session)
        #expect(repeated.exitCode != 0)
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == written)
        #expect(try FileManager.default.contentsOfDirectory(atPath: session) == ["session.json"])
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

    /// 用包装器建一个本机会话目录，再开始会话：写入随机的令牌，分出它的看守。
    ///
    /// 看守等到 relay.sock 出现才开始心跳；默认的容忍期足够长，不接假中继的测试里看守不会中途清理会话，
    /// 测试删掉会话目录后它随之退出。
    ///
    /// - Parameters:
    ///   - tolerance: 看守的心跳容忍期，也是等 relay.sock 出现的期限。
    ///   - retention: 看守保留已结束操作的秒数。
    ///   - wrapper: 运行的包装器。
    ///   - startsSession: 是否开始会话；为 false 时只建会话目录，没有令牌与看守。
    /// - Returns: 会话目录的路径。
    func createSession(
        tolerance: String = "600",
        retention: String = "300",
        wrapper: URL = RemoteTransportTests.wrapper,
        startsSession: Bool = true
    ) async throws -> String {
        let created = try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [wrapper.path, "create-session"]
        )
        let session = String(decoding: created.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)

        if startsSession {
            _ = try await CommandExecutor.execute(
                executable: "/usr/bin/perl",
                processArguments: [wrapper.path, "start-session", session, tolerance, retention],
                input: tokenLine()
            )
        }

        return session
    }

    /// 会话令牌的一行：64 个随机的小写十六进制字符。
    private func tokenLine() -> Data {
        let token = (0 ..< 32).map { _ in String(format: "%02x", UInt8.random(in: 0 ... 255)) }.joined()
        return Data((token + "\n").utf8)
    }

    /// 开始会话：经标准输入把一行令牌写进会话并分出看守，接受全部退出码。
    ///
    /// - Parameters:
    ///   - line: 标准输入。
    ///   - session: 会话目录。
    ///   - arguments: 看守的心跳容忍期与操作保留期。
    /// - Returns: 包装器的输出与退出状态。
    private func startSession(
        _ line: Data,
        in session: String,
        arguments: [String] = ["600", "300"]
    ) async throws -> GitCommandResult {
        try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [Self.wrapper.path, "start-session", session] + arguments,
            input: line,
            acceptedExitCodes: Set(0 ... 255)
        )
    }

    /// 本机看着 `session` 的看守进程数，按看守的进程标题找。
    private func watchers(of session: String) async throws -> Int {
        // 方括号让匹配式不匹配 pgrep 所在命令行本身；一个也没有时 pgrep 以 1 退出
        let found = try await CommandExecutor.execute(
            executable: "/usr/bin/pgrep",
            processArguments: ["-f", "watc[h] " + session],
            acceptedExitCodes: [0, 1]
        )

        return String(decoding: found.standardOutput, as: UTF8.self).split(separator: "\n").count
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

    /// 给会话接上假中继，让等着的看守开始心跳，等会话目录被删除后收起假中继。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - plan: 假中继处理各个连接的计划。
    /// - Returns: 会话目录被删除之前，假中继处理过的每一步。
    private func watch(_ session: String, plan: [String]) async throws -> [String] {
        // 删除事件要在 relay.sock 出现之前开始监听
        let removal = try removal(of: session)

        var relay = try await startRelay(in: session, plan: plan)
        defer { relay.process.terminate() }

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

        // 目录已经不在时直接结束
        if descriptor < 0, errno == ENOENT {
            return AsyncStream { $0.finish() }
        }

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

        // 开始监听之前目录已被删掉时，删除事件不会再来
        if !FileManager.default.fileExists(atPath: session) {
            source.cancel()
        }

        return removed
    }

    /// 文件属性每变化一次产出一个元素的事件流；取消监听源时关掉描述符并结束事件流。
    ///
    /// - Parameter path: 文件路径。
    /// - Returns: 属性变化的事件流，以及用来停止监听的监听源。
    private func attributeChanges(
        of path: String
    ) throws -> (changes: AsyncStream<Void>, source: any DispatchSourceFileSystemObject) {
        let descriptor = Darwin.open(path, O_EVTONLY | O_CLOEXEC)
        try #require(descriptor >= 0)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .attrib,
            queue: .global()
        )

        let (changes, continuation) = AsyncStream<Void>.makeStream()

        source.setEventHandler { continuation.yield() }
        source.setCancelHandler {
            Darwin.close(descriptor)
            continuation.finish()
        }
        source.resume()

        return (changes, source)
    }

    /// 文件的状态信息。
    private func status(of path: String) throws -> stat {
        var info = stat()

        guard stat(path, &info) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

        return info
    }
}
