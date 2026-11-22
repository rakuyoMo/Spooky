import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// 不访问网络的传输协议回归测试。
struct RemoteTransportTests {
    /// 仓库里的远端包装器，包装器的模式直接在本机运行。
    static let wrapper = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/SpookyKit/Resources/spooky-remote.pl")

    /// 完成帧跨任意输出块仍能识别，Git 的 255 与 SSH 的 255 分开处理。
    @Test("完成帧与 stderr 跨块解析")
    func completionFrame() throws {
        let id = UUID().uuidString.lowercased()
        let captured = Mutex(Data())
        let filter = RemoteOutputFilter(operation: id) {
            if case .standardError(let data) = $0 { captured.withLock { $0.append(data) } }
        }
        let stderr = Data(("git diagnostic\n" + "\u{1e}SPOOKY:\(id):255:0:0\u{1f}").utf8)

        for byte in stderr { filter.receive(.standardError(Data([byte]))) }
        #expect(captured.withLock { $0 } == Data("git diagnostic\n".utf8))
        let result = try filter.completed(result(stderr: stderr, exit: 255))
        #expect(result.exitCode == 255)
        #expect(result.standardError == Data("git diagnostic\n".utf8))
        #expect(captured.withLock { $0 } == result.standardError)

        let missing = RemoteOutputFilter(operation: id, onOutput: { _ in })
        let error = #expect(throws: RemoteConnectionError.self) {
            try missing.completed(self.result(stderr: Data("Connection closed by remote host\n".utf8), exit: 255))
        }
        #expect(error?.kind == .unavailable)
    }

    /// 口令的不同字节分别到达时，日志和失败结果都不能泄露原文。
    @Test("跨块口令脱敏与原始诊断保留")
    func secretRedaction() {
        let secret = Data("secret-'中文-$".utf8)
        let captured = Mutex(Data())
        let redactor = RemoteOutputRedactor(arguments: [], values: { [secret] }) {
            if case .standardError(let data) = $0 { captured.withLock { $0.append(data) } }
        }
        let message = Data("before ".utf8) + secret + Data(" after\n".utf8)
        for byte in message { redactor.receive(.standardError(Data([byte]))) }
        redactor.finish()
        let expected = Data("before [REDACTED] after\n".utf8)
        #expect(captured.withLock { $0 } == expected)
        #expect(redactor.result(result(stderr: message, exit: 1)).standardError == expected)
    }

    /// 参数里地址带的口令换成占位文字：结果的参数、逐字节到达的输出与结果里的输出都不留原文，解码后的写法同样替换；
    /// 只有账号的地址与其它参数原样保留。
    @Test("地址口令的参数与输出脱敏")
    func urlPasswordRedaction() {
        let arguments = [
            "-c", "remote.origin.url=https://review:p%40ss@example.invalid/a.git",
            "ls-remote", "--", "ssh://git:secret@[::1]:22/b", "https://user@example.invalid:8443/c",
        ]
        let captured = Mutex(Data())

        let redactor = RemoteOutputRedactor(arguments: arguments, values: { [] }) {
            if case .standardError(let data) = $0 { captured.withLock { $0.append(data) } }
        }

        // Git 原样打出地址，口令可能被拆在任意两个输出块之间
        let message = Data("clone of 'https://review:p%40ss@example.invalid/a.git' failed: p@ss secret\n".utf8)

        for byte in message { redactor.receive(.standardError(Data([byte]))) }
        redactor.finish()

        let failed = GitCommandResult(
            arguments: arguments,
            standardOutput: Data(),
            standardError: message,
            terminationStatus: .exited(128),
            isCancelled: false
        )
        let expected = Data(
            "clone of 'https://review:[REDACTED]@example.invalid/a.git' failed: [REDACTED] [REDACTED]\n".utf8
        )

        #expect(captured.withLock { $0 } == expected)
        #expect(redactor.result(failed).standardError == expected)

        #expect(failed.arguments == [
            "-c", "remote.origin.url=https://review:[REDACTED]@example.invalid/a.git",
            "ls-remote", "--", "ssh://git:[REDACTED]@[::1]:22/b", "https://user@example.invalid:8443/c",
        ])
    }

    /// 包装器替换写入：经符号链接写到它指向的文件并沿用权限位；输入提前结束或读到一半被 TERM 结束时原文件不变，不留临时文件。
    @Test("包装器替换写入的权限、符号链接与中途结束")
    func wrapperReplacement() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-replace-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appending(path: "run.sh")
        let link = directory.appending(path: "link")
        try Data("old\n".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "run.sh")

        // 经符号链接写入：链接保留，指向的文件换成新内容，可执行权限照旧
        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [Self.wrapper.path, "replace", link.path, "4"],
            input: Data("new\n".utf8)
        )

        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == "run.sh")
        #expect(try Data(contentsOf: target) == Data("new\n".utf8))
        #expect(try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int == 0o755)

        // 输入不到声明的字节数就结束，如连接中途断开：失败退出，原文件不变
        let incomplete = await #expect(throws: GitError.self) {
            try await CommandExecutor.execute(
                executable: "/usr/bin/perl",
                processArguments: [Self.wrapper.path, "replace", target.path, "100"],
                input: Data("partial".utf8)
            )
        }

        #expect(incomplete?.message == "incomplete content\n")
        #expect(try Data(contentsOf: target) == Data("new\n".utf8))

        // 读到一半被 TERM 结束，如取消写入：原文件不变
        try await terminateReplacement(of: target, in: directory)

        #expect(try Data(contentsOf: target) == Data("new\n".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted() == ["link", "run.sh"])
    }

    /// 伪造令牌、重复请求和已结束的操作均不能取得回调应答。
    @Test("回调会话认证与一次性应答")
    func callbackAuthentication() async throws {
        let directory = URL(fileURLWithPath: "/tmp/spooky-relay-" + UUID().uuidString.lowercased())
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let calls = Mutex(0)
        let relay = try CallbackRelay(path: directory.appending(path: "relay").path, host: "test") { _ in
            calls.withLock { $0 += 1 }
            return "test-answer"
        }
        try relay.start()
        defer { relay.stop() }
        let operation = UUID().uuidString.lowercased()
        relay.register(operation)

        let invalid = try await request(relay, token: "wrong", id: "first", operation: operation)
        #expect(!(invalid["accepted"] as? Bool ?? true))
        #expect(calls.withLock { $0 } == 0)

        let valid = try await request(relay, token: relay.token, id: "once", operation: operation)
        #expect(valid["value"] as? String == "test-answer")
        let repeated = try await request(relay, token: relay.token, id: "once", operation: operation)
        #expect(!(repeated["accepted"] as? Bool ?? true))
        #expect(calls.withLock { $0 } == 1)

        relay.unregister(operation)
        let expired = try await request(relay, token: relay.token, id: "late", operation: operation)
        #expect(!(expired["accepted"] as? Bool ?? true))
        relay.stop()
        #expect(!FileManager.default.fileExists(atPath: relay.path))
    }

    /// 使用真实 Unix socket 发送一条 JSON 报文，不绕过生产解析器。
    private func request(
        _ relay: CallbackRelay,
        token: String,
        id: String,
        operation: String
    ) async throws -> [String: Any] {
        let message = try JSONSerialization.data(withJSONObject: [
            "token": token, "id": id, "operation": operation, "kind": "askpass", "prompt": "Password:",
        ]) + Data([10])
        let script = """
            use IO::Socket::UNIX;
            my $socket = IO::Socket::UNIX->new(Type => SOCK_STREAM, Peer => $ARGV[0]) or die;
            local $/;
            my $request = <STDIN>;
            print {$socket} $request;
            print scalar <$socket>;
            """
        let response = try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: ["-e", script, relay.path],
            input: message
        )
        return try #require(JSONSerialization.jsonObject(with: response.standardOutput) as? [String: Any])
    }

    /// 启动替换写入并让输入一直打开，等目录里出现临时文件、包装器停在读取上时发 TERM，再等它退出。
    ///
    /// - Parameters:
    ///   - target: 要替换的文件。
    ///   - directory: 目标所在的目录，临时文件建在这里。
    private func terminateReplacement(of target: URL, in directory: URL) async throws {
        let descriptor = Darwin.open(directory.path, O_EVTONLY | O_CLOEXEC)
        try #require(descriptor >= 0)

        // 目录里新建条目时收到写事件，事件来得比等待早时留着最近的一次
        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .global()
        )
        let (changes, changed) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        watcher.setEventHandler { changed.yield() }
        watcher.setCancelHandler { Darwin.close(descriptor) }
        watcher.resume()
        defer { watcher.cancel() }

        let process = Process()
        let input = Pipe()
        let (exits, exited) = AsyncStream<Void>.makeStream()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [Self.wrapper.path, "replace", target.path, "100"]
        process.standardInput = input
        process.terminationHandler = { _ in exited.finish() }
        try process.run()

        for await _ in changes {
            let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            if names.contains(where: { $0.hasPrefix(".spooky-") }) { break }
        }

        process.terminate()

        for await _ in exits { }

        try input.fileHandleForWriting.close()
    }

    /// 协议测试的输入只包含输出字节与退出码。
    private func result(stderr: Data, exit: Int32) -> GitCommandResult {
        GitCommandResult(
            arguments: ["test"],
            standardOutput: Data(),
            standardError: stderr,
            terminationStatus: .exited(exit),
            isCancelled: false
        )
    }
}
