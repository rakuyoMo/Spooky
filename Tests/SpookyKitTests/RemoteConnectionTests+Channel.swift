import Foundation
import Testing

@testable import SpookyKit

/// 主连接上的常驻通道：命令、文件读写与取消经它执行，通道断开后另开会话执行并重新打开；关掉通道时逐条执行的流程照常可用。
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

    /// 建目录、写入、移动、读取、下载与删除都经常驻通道执行；超出内联预算的大文件经 SFTP 取回与下载，内容与写入的一致。
    @Test("文件读写经常驻通道执行，大文件经 SFTP 取回")
    func filesThroughChannel() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()
        let local = FileManager.default.temporaryDirectory.appending(path: "spooky-download-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: local) }

        do {
            let location = try await connection.open().location
            let files = RepositoryFiles(runner: GitRunner(location: location, remote: connection))
            let note = fixture.repository + "/nested/deeper/note.txt"
            var counts = [await connection.channelCommands]

            try await files.createDirectory(fixture.repository + "/nested/deeper")
            counts.append(await connection.channelCommands)

            try await files.write(Data("note\n".utf8), to: fixture.repository + "/note.txt")
            counts.append(await connection.channelCommands)

            try await files.move(fixture.repository + "/note.txt", to: note)
            counts.append(await connection.channelCommands)

            let read = try await files.read([note, fixture.repository + "/missing"])
            counts.append(await connection.channelCommands)

            try await files.download(note, to: local.appending(path: "note"))
            counts.append(await connection.channelCommands)

            try await files.remove([note])
            counts.append(await connection.channelCommands)

            // 每一步都经通道执行了命令
            #expect(zip(counts, counts.dropFirst()).allSatisfy { $0 < $1 })
            #expect(read == [note: Data("note\n".utf8)])
            #expect(try Data(contentsOf: local.appending(path: "note")) == Data("note\n".utf8))
            #expect(try await files.read([note]).isEmpty)

            // 不存在的文件下载失败
            await #expect(throws: CocoaError.self) {
                try await files.download(note, to: local.appending(path: "missing"))
            }

            // 比内联预算大一个字节的文件：写入经本机临时文件，读取与下载经 SFTP
            let size = RepositoryFiles.inlineReadBudget + 1
            var content = Data(count: size)
            content.withUnsafeMutableBytes { arc4random_buf($0.baseAddress, size) }
            let large = fixture.repository + "/large.bin"

            try await files.write(content, to: large)
            try await files.download(large, to: local.appending(path: "large"))

            #expect(try await files.read([large])[large] == content)
            #expect(try Data(contentsOf: local.appending(path: "large")) == content)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 这台主机的取消名额被占着时，经常驻通道发出的取消照常得到确认；取消要是等名额，这项测试会一直等下去。
    @Test("经常驻通道的取消不等取消名额")
    func channelCancellation() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()
        let (released, release) = AsyncStream<Void>.makeStream()

        do {
            _ = try await connection.open()

            let operation = connection.operation(["-c", "alias.wait=!printf ready; sleep 60", "wait"])

            for await event in operation.events {
                if case .output(.standardOutput(let data)) = event, data == Data("ready".utf8) { break }
            }

            // 命令开始执行之后再占住名额，取消得到确认之后才放开
            let (held, hold) = AsyncStream<Void>.makeStream()

            let holder = Task {
                try await RepositoryOperationQueue.shared.performCancellation(on: connection.host) {
                    hold.finish()

                    for await _ in released { }
                }
            }

            for await _ in held { }

            operation.cancel()
            await #expect(throws: CancellationError.self) { try await operation.value }

            release.finish()
            try await holder.value

            await connection.close()
            try await fixture.remove()
        } catch {
            release.finish()
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 关掉常驻通道后，读取、写入、文件读写与取消都逐条另开会话执行，B 上不开 serve 会话。
    @Test("关掉常驻通道时逐条执行的读取、写入与取消")
    func withoutResidentChannel() async throws {
        let fixture = try await RemoteFixture.create()
        var configuration = RemoteFixture.configuration
        configuration.usesResidentChannel = false
        let connection = fixture.connection(configuration: configuration)

        do {
            let location = try await connection.open().location

            // 写入与读取
            _ = try await connection.execute(["commit", "--allow-empty", "-m", "message"])
            let log = try await connection.execute(["log", "-1", "--format=%s"])

            #expect(log.standardOutput == Data("message\n".utf8))

            // 文件的写入、建目录、移动、读取与删除
            let files = RepositoryFiles(runner: GitRunner(location: location, remote: connection))
            let note = fixture.repository + "/folder/note.txt"

            try await files.write(Data("note\n".utf8), to: fixture.repository + "/note.txt")
            try await files.createDirectory(fixture.repository + "/folder")
            try await files.move(fixture.repository + "/note.txt", to: note)

            #expect(try await files.read([note]) == [note: Data("note\n".utf8)])

            try await files.remove([note])

            #expect(try await files.read([note]).isEmpty)

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

            // B 上这个会话没有 serve，看守照样由新建会话分出
            let session = try #require(await connection.remoteDirectory)
            let watchers = try await RemoteFixture.raw([
                "/bin/sh", "-c", #"pgrep -f "watc[h] $1" || :"#, "spooky-watchers", session,
            ])

            #expect(try await servers(of: connection) == 0)
            #expect(!watchers.standardOutput.isEmpty)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }
}
