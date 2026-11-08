import Foundation
import Subprocess
import Synchronization
import Testing

@testable import SpookyKit

/// 可控传输验证错误类别、实时日志、取消和凭据回调，不连接用户的真实 Git 远端。
struct RepositoryNetworkTests {
    /// 真实 Git 经临时 SSH 程序产生稳定失败，检查退出状态和完整原文；原始 stderr 在进程结束前到达，
    /// 取消后仓库写槽可再次取得。
    @Test("Git 网络失败分类与原始输出，Fetch 流式日志、排队取消与写槽释放")
    func transfers() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        try await fixture.initialize()
        _ = try await fixture.runner.run(["remote", "add", "origin", "ssh://spooky.invalid/repository"])

        // 传输失败按 SSH 的诊断分类
        for (diagnostic, expected) in [
            ("Permission denied (publickey).", GitError.Category.authenticationFailed),
            ("ssh: connect to host test port 22: Operation timed out", .connectionTimedOut),
            ("Connection reset by peer", .connectionUnavailable),
        ] {
            let runner = try failingTransport(in: fixture, diagnostic: diagnostic)

            do {
                _ = try await RepositorySync(runner: runner).fetch()
                Issue.record("传输失败不能报告成功：\(diagnostic)")
            } catch let error as GitError {
                #expect(error.category == expected, "\(diagnostic)")
                #expect(error.exitCode == 128, "\(diagnostic)")
                #expect(error.message.contains(diagnostic), "\(diagnostic)")
            }
        }

        // 假的 Git 先在 stderr 报到，再一直等待，直到被取消
        let executable = fixture.directory.appendingPathComponent("git-test")

        try Data("#!/bin/sh\n/bin/sleep 30 &\necho TRANSFER_STARTED >&2\nwait\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let runner = fixture.runner(at: fixture.directory.path, executable: executable.path)
        let operation = runner.operation(["fetch", "--porcelain", "--progress"])
        var received = false

        for await event in operation.events {
            if
                case .output(.standardError(let data)) = event,
                String(decoding: data, as: UTF8.self).contains("TRANSFER_STARTED")
            {
                received = true
                break
            }
        }

        #expect(received)

        // 排在获取之后的命令先取消，再取消获取
        let queued = fixture.runner.operation(["branch", "--list"])

        queued.cancel()
        operation.cancel()

        do {
            _ = try await operation.value
            Issue.record("已取消的获取不能成功")
        } catch let error as GitError {
            #expect(error.isCancelled)
        }

        await #expect(throws: (any Error).self) { _ = try await queued.value }

        #expect(try await fixture.runner.run(["branch", "--list"]).isEmpty)
    }

    /// 解锁临时加密私钥后只加入本测试的 agent；口令回显不能进入流和结果。
    @Test("本机私钥口令中继、独立 agent 与跨块脱敏")
    func localPassphrase() async throws {
        let fixture = try TemporaryRepository()
        defer { fixture.remove() }

        // 用口令加密的临时私钥
        let key = fixture.directory.appendingPathComponent("id_test").path
        let passphrase = "Spooky test passphrase 你好"

        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/ssh-keygen",
            processArguments: ["-q", "-t", "ed25519", "-N", passphrase, "-f", key]
        )

        // 只给本测试用的 agent
        let socket = "/tmp/spooky-agent-" + UUID().uuidString.lowercased()
        let (listening, signal) = AsyncStream<Void>.makeStream()

        let agent = Task {
            defer { signal.finish() }

            // ssh-agent 绑好套接字之后才在标准输出写出环境变量
            return try await CommandExecutor.execute(
                executable: "/usr/bin/ssh-agent",
                processArguments: ["-D", "-a", socket]
            ) { event in
                if case .standardOutput = event {
                    signal.yield()
                }
            }
        }

        do {
            for await _ in listening {
                break
            }

            // 假的 git：经 askpass 解锁私钥加入 agent，再把 askpass 的回答写进标准错误，最后列出 agent 里的私钥
            let executable = fixture.directory.appendingPathComponent("git-test")
            let script = """
                #!/bin/sh
                /usr/bin/ssh-add "$SPOOKY_TEST_KEY" || exit $?
                value=$("$SSH_ASKPASS" 'Enter passphrase for test:') || exit $?
                printf '%s' "$value" >&2
                /usr/bin/ssh-add -l
                """

            try Data(script.utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

            let calls = Mutex(0)
            let streamed = Mutex(Data())

            var runner = GitRunner(
                location: .local(path: fixture.directory.path),
                executablePath: executable.path,
                environment: .inherit.updating(["SSH_AUTH_SOCK": socket, "SPOOKY_TEST_KEY": key])
            )

            runner.credentialHandler = { request in
                #expect(request.kind == .sshAskpass)
                calls.withLock { $0 += 1 }
                return passphrase
            }

            let result = try await runner.execute(["fetch", "--porcelain", "--progress"]) { event in
                if case .standardError(let data) = event { streamed.withLock { $0.append(data) } }
            }

            #expect(calls.withLock { $0 } >= 2)
            #expect(String(decoding: result.standardOutput, as: UTF8.self).contains("ED25519"))
            #expect(String(decoding: result.standardError, as: UTF8.self).contains("[REDACTED]"))
            #expect(!String(decoding: result.standardError, as: UTF8.self).contains(passphrase))
            #expect(!String(decoding: streamed.withLock { $0 }, as: UTF8.self).contains(passphrase))

            agent.cancel()
            _ = try? await agent.value
        } catch {
            agent.cancel()
            _ = try? await agent.value
            throw error
        }
    }

    /// 写一个只在 stderr 输出诊断、以 255 退出的 SSH 程序，返回经它传输、忽略系统与用户配置的执行器。
    ///
    /// - Parameter diagnostic: SSH 程序输出的诊断原文。
    private func failingTransport(in fixture: TemporaryRepository, diagnostic: String) throws -> GitRunner {
        let transport = fixture.directory.appendingPathComponent("transport")

        try Data(("#!/bin/sh\nprintf '%s\\n' " + GitRunner.shellQuoted(diagnostic) + " >&2\nexit 255\n").utf8)
            .write(to: transport)

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: transport.path)

        return GitRunner(
            location: .local(path: fixture.directory.path),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_SSH_COMMAND": GitRunner.shellQuoted(transport.path),
                "GIT_SSH_VARIANT": "ssh",
            ])
        )
    }
}
