import Foundation
import Testing

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

    /// 仅关闭 Spooky 的主连接来模拟断线，原写入不重试，重连后读取仓库事实。
    @Test("主动断线、写入不重试与重连核对")
    func disconnectionAndRecovery() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()

        do {
            _ = try await connection.open()
            let operation = connection.operation([
                "-c", "alias.once=!echo once >> once; printf ready; sleep 30; echo finished >> once", "once",
            ])

            for await event in operation.events {
                if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
            }

            try await connection.interruptMaster()
            _ = await #expect(throws: RemoteConnectionError.self) { try await operation.value }

            _ = try await connection.reconnect()
            let recovery = try #require(await connection.recovery)
            #expect(recovery.status.branch.head == "main")
            #expect(!recovery.indexLocked && !recovery.merging && !recovery.rebasing)
            #expect(recovery.status.entries.contains { $0.path == "once" })

            let result = try await RemoteFixture.raw(["/bin/cat", fixture.repository + "/once"])
            #expect(result.standardOutput == Data("once\n".utf8))

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 被取消的命令在 B 上结束之前仍占着会话；同时取消占满主机名额的读取时，每个取消都得到确认，随后的写入照常执行。
    @Test("同时取消占满主机名额的读取")
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

            // 外部 Diff 程序报告开始后一直等待，每条读取都占着一个执行名额与 B 上的一个会话
            let reads = (0 ..< RepositoryOperationQueue.maximumHostCommands).map { _ in
                connection.operation(["-c", "diff.external=printf ready; sleep 60; :", "diff"])
            }

            for read in reads {
                for await event in read.events {
                    if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
                }
            }

            // 一起取消后马上写入：写入要等某条取消得到确认、放出执行名额才开始，这时 B 上被取消的会话可能还没释放
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
}
