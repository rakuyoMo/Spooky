import Foundation
import Testing

@testable import SpookyKit

/// 主连接上的常驻通道：命令经它执行，通道断开后另开会话执行并重新打开；关掉通道时逐条执行的流程照常可用。
extension RemoteConnectionTests {
    /// 连上后命令经常驻通道执行；通道被结束后，下一条命令另开会话照常完成，通道随后重新打开。
    @Test("命令经常驻通道执行，通道断开后重新打开")
    func residentChannel() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()
        let status = ["status", "--porcelain=v2", "-z", "--branch"]

        do {
            _ = try await connection.open()

            // 连上之后的命令走常驻通道，主连接检查不另开会话
            let before = await connection.channelCommands
            _ = try await connection.execute(status)
            try await connection.check()

            #expect(await connection.channelCommands > before)

            // 通道里留一条一直执行的请求，通道被结束时它以 255 结束，这时连接已经知道通道断了
            let channel = try #require(await connection.resident)
            let session = try #require(await connection.remoteDirectory)
            let (started, start) = AsyncStream<Void>.makeStream()

            let pending = Task {
                try await channel.execute(
                    ["run", session, UUID().uuidString.lowercased(), "2", "/bin/sh", "-c", "echo started; exec sleep 600"],
                    input: Data(),
                    resultArguments: []
                ) { _ in start.finish() }
            }

            for await _ in started { }

            _ = try await RemoteFixture.raw(["/usr/bin/pkill", "-KILL", "-f", "serv[e] " + session])
            #expect(try await pending.value.exitCode == 255)

            // 下一条命令另开会话执行
            let afterLoss = await connection.channelCommands
            _ = try await connection.execute(status)

            #expect(await connection.channelCommands == afterLoss)
            #expect(await connection.state == .connected)

            // 断开的通知到达之后，命令触发后台重新打开；打开之后命令重新经通道执行
            while await connection.channelCommands == afterLoss, await connection.channelFailures == 0 {
                if let reopening = await connection.reopening { await reopening.value }

                _ = try await connection.execute(status)
            }

            #expect(await connection.channelFailures == 0)
            #expect(await connection.resident !== channel)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 关掉常驻通道后，读取、写入与取消都逐条另开会话执行。
    @Test("关掉常驻通道时逐条执行的读取、写入与取消")
    func withoutResidentChannel() async throws {
        let fixture = try await RemoteFixture.create()
        var configuration = RemoteFixture.configuration
        configuration.usesResidentChannel = false
        let connection = fixture.connection(configuration: configuration)

        do {
            _ = try await connection.open()

            // 写入与读取
            _ = try await connection.execute(["commit", "--allow-empty", "-m", "message"])
            let log = try await connection.execute(["log", "-1", "--format=%s"])

            #expect(log.standardOutput == Data("message\n".utf8))

            // 取消执行中的命令后，连接照常可用
            let operation = connection.operation(["-c", "alias.wait=!printf ready; sleep 60", "wait"])

            for await event in operation.events {
                if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
            }

            operation.cancel()
            await #expect(throws: CancellationError.self) { try await operation.value }
            _ = try await connection.execute(["status", "--porcelain=v2", "-z", "--branch"])

            #expect(await connection.channelCommands == 0)
            #expect(await connection.resident == nil)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }
}
