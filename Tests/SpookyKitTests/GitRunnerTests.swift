import Foundation
import OSLog
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
