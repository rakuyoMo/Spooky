import Foundation
import OSLog
import Synchronization
import Testing

@testable import SpookyKit

/// git 调用的拼装与执行
struct GitRunnerTests {
    /// 参数作为 shell 数据往返，别名、路径和提交信息都不能执行命令替换。
    @Test("远端参数经过 POSIX shell 后原样保留")
    func remoteShellRoundTrip() async throws {
        let arguments = ["主机'alias", "/path/仓 库'\"\\[*]?", "message ' $HOME `echo injected`\n"]
        let command = ["/usr/bin/printf", "%s\\0"] + arguments

        let result = try await CommandExecutor.execute(
            executable: "/bin/sh",
            processArguments: ["-c", command.map(GitRunner.shellQuoted).joined(separator: " ")]
        )

        let decoded = result.standardOutput.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }

        #expect(decoded == arguments)

        let options = SSHConfiguration().options

        #expect(options.contains("ForwardAgent=no"))
        #expect(options.contains("StrictHostKeyChecking=yes"))
    }

    /// 参数里可能有带凭据的地址，失败日志只能留下子命令名、退出码与错误类别。
    @Test("Git 失败日志只记子命令名，不记参数")
    func failureLogOmitsArguments() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()

        // 不存在的修订让 git show 以 128 退出；修订名充当可识别的假凭据
        let secret = "spooky-secret-" + UUID().uuidString
        let started = Date()

        await #expect(throws: GitError.self) {
            try await temporary.runner.execute(["show", secret])
        }

        let messages = try await loggedMessages(since: started) { $0.contains("show") }

        #expect(messages.contains { $0.contains("show") && $0.contains("128") })
        #expect(!messages.contains { $0.contains(secret) })
    }

    /// 服务器上规范等价、字节不同的两个仓库各用各的连接，命令不会送进另一个仓库；本机路径与 macOS 文件系统一样不区分规范化。
    @Test("服务器位置按字节区分仓库与连接")
    func remoteIdentityByBytes() {
        let composed = RepositoryLocation.remote(host: "spooky-identity", path: "/srv/caf\u{e9}")
        let decomposed = RepositoryLocation.remote(host: "spooky-identity", path: "/srv/cafe\u{301}")

        // 仓库身份，以及写队列与连接表的键
        #expect(composed != decomposed)
        #expect(Set([composed, decomposed]).count == 2)

        // 字节不同的各用各的连接，字节相同的共用一条
        let connection = GitRunner(location: composed).remote

        #expect(connection !== GitRunner(location: decomposed).remote)
        #expect(connection === GitRunner(location: .remote(host: "spooky-identity", path: "/srv/caf\u{e9}")).remote)

        // 主机连接的别名同样按字节区分
        #expect(RemoteConnection.host("spooky-caf\u{e9}") !== RemoteConnection.host("spooky-cafe\u{301}"))

        // 本机路径按字符串比较
        #expect(RepositoryLocation.local(path: "/srv/caf\u{e9}") == .local(path: "/srv/cafe\u{301}"))
    }

    /// 地址里的口令不进入错误与流式输出：经凭据中继与不经中继的两条本机路径都替换 Git 原样打出的地址。
    @Test("地址口令不进入错误与输出")
    func urlPasswordStaysOutOfFailures() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        try await temporary.initialize()

        // 回环上没有服务的端口立即拒绝连接；子模块克隆失败时 Git 在 stderr 里原样打出带口令的地址
        let secret = "spooky-secret-" + UUID().uuidString
        let address = "https://review:" + secret + "@127.0.0.1:1/repository"
        var relayed = temporary.runner
        relayed.credentialHandler = { _ in nil }

        for runner in [temporary.runner, relayed] {
            let output = Mutex(Data())

            let failure = await #expect(throws: GitError.self) {
                try await runner.execute(["submodule", "add", "--", address, "sub"]) { event in
                    switch event {
                    case .standardOutput(let data), .standardError(let data):
                        output.withLock { $0.append(data) }
                    }
                }
            }

            let error = try #require(failure)
            let streamed = String(decoding: output.withLock { $0 }, as: UTF8.self)

            #expect(error.arguments.contains("https://review:[REDACTED]@127.0.0.1:1/repository"))
            #expect(error.message.contains("https://review:[REDACTED]@127.0.0.1:1/repository"))
            #expect(!error.arguments.joined().contains(secret))
            #expect(!error.message.contains(secret))
            #expect(!streamed.contains(secret))
        }
    }

    /// 读取本进程在指定时间之后写入的应用日志，出现目标条目或重试用尽为止。
    ///
    /// 系统日志没有可等的写入事件，只能重读；日志库按创建时刻取快照，所以每次重试都重新打开。
    /// 上限放宽到整套测试并行、日志写入排队时也能读到。
    private func loggedMessages(
        since date: Date,
        until found: (String) -> Bool
    ) async throws -> [String] {
        let predicate = NSPredicate(format: "subsystem == %@", "com.rakuyo.spooky")
        var messages: [String] = []

        for _ in 0 ..< 50 {
            let store = try OSLogStore(scope: .currentProcessIdentifier)

            messages = try store
                .getEntries(at: store.position(date: date), matching: predicate)
                .compactMap { ($0 as? OSLogEntryLog)?.composedMessage }

            if messages.contains(where: found) {
                break
            }

            try await Task.sleep(for: .milliseconds(200))
        }

        return messages
    }
}
