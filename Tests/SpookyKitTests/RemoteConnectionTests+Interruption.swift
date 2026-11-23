import Foundation
import Testing
import TestSupport

@testable import SpookyKit

/// 远端写入被取消或断线打断时的串行、进程终止与重连核对。
extension RemoteConnectionTests {
    /// 两条写入必须依次进入临界区；排队取消不能运行，活动取消必须确认远端退出。
    @Test("写入串行、队列取消与远端进程组取消")
    func serialWritesAndCancellation() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()

        do {
            _ = try await connection.open()
            let arguments = [
                "-c", "alias.guard=!mkdir guard-lock || exit 77; sleep 0.3; rmdir guard-lock", "guard",
            ]
            async let first = connection.execute(arguments)
            async let second = connection.execute(arguments)
            _ = try await (first, second)

            let operation = connection.operation([
                "-c", "alias.wait=!echo $$ > own-process; trap '' TERM; printf ready; sleep 60 & wait", "wait",
            ])

            for await event in operation.events {
                if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
            }

            let queued = connection.operation(["-c", "alias.queued=!touch must-not-exist", "queued"])
            queued.cancel()
            await #expect(throws: CancellationError.self) { try await queued.value }
            operation.cancel()
            await #expect(throws: CancellationError.self) { try await operation.value }

            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", fixture.repository + "/must-not-exist"])
            let pid = try await RemoteFixture.raw(["/bin/cat", fixture.repository + "/own-process"])
            let process = String(decoding: pid.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
            _ = try await RemoteFixture.raw([
                "/bin/sh", "-c", "if kill -0 \"$1\" 2>/dev/null; then exit 7; fi", "fixture", process,
            ])
            _ = try await connection.execute(["status", "--porcelain=v2", "-z", "--branch"])

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 仅关闭 Spooky 的主连接来模拟断线，原写入不重试；旧会话的看守停住时，重连先关掉旧会话、结束其中的命令，再读取仓库事实。
    @Test("主动断线、写入不重试与重连核对")
    func disconnectionAndRecovery() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()
        var previousSession: String? = nil

        do {
            _ = try await connection.open()
            let operation = connection.operation([
                "-c",
                "alias.once=!echo once >> once; echo $$ > own-process; echo $SPOOKY_SESSION > session; "
                    + "printf ready; sleep 30; echo finished >> once",
                "once",
            ])

            for await event in operation.events {
                if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
            }

            // 停住旧会话的看守，旧会话只能由重连关掉
            let output = try await RemoteFixture.raw(["/bin/cat", fixture.repository + "/session"])
            let session = String(decoding: output.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
            previousSession = session
            try await signalWatcher(of: session, "-STOP")

            try await connection.interruptMaster()
            _ = await #expect(throws: RemoteConnectionError.self) { try await operation.value }

            _ = try await connection.reconnect()
            let recovery = try #require(await connection.recovery)
            #expect(recovery.status.branch.head == "main")
            #expect(!recovery.indexLocked && !recovery.merging && !recovery.rebasing)
            #expect(recovery.status.entries.contains { $0.path == "once" })

            // 重连之后旧命令已经结束，旧会话目录已经删除
            let pid = try await RemoteFixture.raw(["/bin/cat", fixture.repository + "/own-process"])
            let process = String(decoding: pid.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
            _ = try await RemoteFixture.raw([
                "/bin/sh", "-c", "if kill -0 \"$1\" 2>/dev/null; then exit 7; fi", "fixture", process,
            ])
            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", session])

            let result = try await RemoteFixture.raw(["/bin/cat", fixture.repository + "/once"])
            #expect(result.standardOutput == Data("once\n".utf8))

            try await signalWatcher(of: session, "-CONT")
            await connection.close()
            try await fixture.remove()
        } catch {
            if let previousSession { try? await signalWatcher(of: previousSession, "-CONT") }
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 旧命令的监管进程已经不在时，包装器永远确认不了它结束；重连只记下错误，照常核对仓库、算作连上。
    @Test("重连时关不掉旧会话")
    func reconnectingPastUnconfirmedSession() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()
        let processFile = fixture.repository + "/own-process"
        var previousSession: String? = nil

        do {
            _ = try await connection.open()
            let operation = connection.operation([
                "-c",
                "alias.hold=!echo $$ > own-process; echo $SPOOKY_SESSION > session; printf ready; sleep 30",
                "hold",
            ])

            for await event in operation.events {
                if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
            }

            // 停住旧会话的看守，旧会话只能由重连关掉
            let output = try await RemoteFixture.raw(["/bin/cat", fixture.repository + "/session"])
            let session = String(decoding: output.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
            previousSession = session
            try await signalWatcher(of: session, "-STOP")

            try await connection.interruptMaster()
            _ = await #expect(throws: RemoteConnectionError.self) { try await operation.value }

            // 断线后结束旧命令的监管进程：它不再写结束标记，也不再回应取消
            _ = try await RemoteFixture.raw(["/usr/bin/pkill", "-KILL", "-f", "ru[n] " + session + " "])

            _ = try await connection.reconnect()
            #expect(await connection.state == .connected)
            #expect(await connection.recovery != nil)

            await discardSession(session, processFile: processFile)
            await connection.close()
            try await fixture.remove()
        } catch {
            if let previousSession { await discardSession(previousSession, processFile: processFile) }
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 读取与路径检查之前不另外确认主连接；主连接断掉之后，它们经命令通道报告不可用，连接随之转为不可用状态。
    @Test("主连接断开后的读取与路径检查")
    func readsAfterMasterLoss() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()

        do {
            // 读取
            _ = try await connection.open()
            try await connection.interruptMaster()

            let readError = await #expect(throws: RemoteConnectionError.self) {
                try await connection.execute(["status", "--porcelain=v2"])
            }
            #expect(readError?.kind == .unavailable)
            #expect(await connection.state == .unavailable)

            // 路径检查
            _ = try await connection.reconnect()
            try await connection.interruptMaster()

            let inspectError = await #expect(throws: RemoteConnectionError.self) {
                try await connection.inspect([fixture.repository + "/.git"])
            }
            #expect(inspectError?.kind == .unavailable)
            #expect(await connection.state == .unavailable)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 占满主机名额的读取经常驻通道同时在 B 上执行；同时取消它们时每个取消都得到确认，随后的写入照常执行。
    /// 发出之前就被取消的命令直接以取消结束，不为它发出取消。
    @Test("占满主机名额的读取同时执行与取消")
    func cancellingFullHostCapacity() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()

        do {
            // 留一处没有提交的改动，Diff 才会调用外部程序
            _ = try await RemoteFixture.raw([
                "/bin/sh", "-c",
                "cd \"$1\" && echo one > file.txt && git add file.txt && git commit -q -m one && echo two > file.txt",
                "fixture", fixture.repository,
            ])
            _ = try await connection.open()

            // 发出之前就被取消的写入：不经通道发出命令与取消，也不要求重连核对
            let channeled = await connection.channelCommands

            let unsent = Task {
                withUnsafeCurrentTask { $0?.cancel() }

                return try await connection.runOperation(["/usr/bin/true"], arguments: ["true"], writing: true) { _ in }
            }

            await #expect(throws: CancellationError.self) { try await unsent.value }
            #expect(await connection.channelCommands == channeled)
            #expect(await !connection.requiresReconciliation)

            // 外部 Diff 程序报到后停在闸门上：每条读取都报到，说明它们同时在 B 上执行
            let gate = try ProcessGate(in: URL(fileURLWithPath: fixture.root))

            let reads = (0 ..< RepositoryOperationQueue.maximumHostCommands).map { _ in
                connection.operation(["-c", "diff.external=" + gate.command + "; :", "diff"])
            }

            for _ in reads {
                await gate.arrival()
            }

            // 一起取消后马上写入：写入要等某条取消得到确认、放出执行名额才开始
            for read in reads {
                read.cancel()
            }

            async let branch = connection.execute(["branch", "after-cancellation"])

            for read in reads {
                await #expect(throws: CancellationError.self) { try await read.value }
            }

            _ = try await branch
            #expect(await connection.state == .connected)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 给 B 上看守指定会话的包装器进程发信号。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - signal: `pkill` 的信号选项，如 `-STOP`。
    private func signalWatcher(of session: String, _ signal: String) async throws {
        // 方括号让匹配式不匹配 pkill 所在命令行本身
        _ = try await RemoteFixture.raw(["/usr/bin/pkill", signal, "-f", "watc[h] " + session])
    }

    /// 结束停住的看守与没人监管的命令所在的进程组，再删掉留在 B 上的会话目录。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - processFile: 命令写下自己 PID 的文件。
    private func discardSession(_ session: String, processFile: String) async {
        try? await signalWatcher(of: session, "-KILL")

        _ = try? await RemoteFixture.raw([
            "/bin/sh", "-c",
            "group=$(ps -o pgid= -p \"$(cat \"$1\")\" | tr -d ' ') && kill -9 -- \"-$group\"",
            "fixture", processFile,
        ])

        _ = try? await RemoteFixture.raw(["/bin/rm", "-rf", session])
    }
}
