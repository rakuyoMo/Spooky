import Foundation
import Synchronization
import Testing

@testable import SpookyKit

/// 不访问网络的传输协议回归测试。
struct RemoteTransportTests {
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
        let redactor = RemoteOutputRedactor(values: { [secret] }) {
            if case .standardError(let data) = $0 { captured.withLock { $0.append(data) } }
        }
        let message = Data("before ".utf8) + secret + Data(" after\n".utf8)
        for byte in message { redactor.receive(.standardError(Data([byte]))) }
        redactor.finish()
        let expected = Data("before [REDACTED] after\n".utf8)
        #expect(captured.withLock { $0 } == expected)
        #expect(redactor.result(result(stderr: message, exit: 1)).standardError == expected)
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
        #expect(invalid["accepted"] as? Bool == false)
        #expect(calls.withLock { $0 } == 0)

        let valid = try await request(relay, token: relay.token, id: "once", operation: operation)
        #expect(valid["value"] as? String == "test-answer")
        let repeated = try await request(relay, token: relay.token, id: "once", operation: operation)
        #expect(repeated["accepted"] as? Bool == false)
        #expect(calls.withLock { $0 } == 1)

        relay.unregister(operation)
        let expired = try await request(relay, token: relay.token, id: "late", operation: operation)
        #expect(expired["accepted"] as? Bool == false)
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
