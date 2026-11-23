import Foundation
import Subprocess
import Testing

@testable import SpookyKit

/// 常驻通道的帧与包装器的 serve 模式在本机运行：通道进程直接启动包装器，不经 SSH。
extension RemoteTransportTests {
    /// 帧头与负载跨任意块到达时照样切开，空负载的帧不产出输出；长度或类型不对的帧让通道不能再用。
    @Test("常驻通道的帧跨块切开、空负载与格式错误")
    func channelFrames() throws {
        // 请求帧：参数个数、逐个参数的长度与内容，余下的是标准输入
        let request = RemoteCommandChannel.Frame.request(identifier: 7, arguments: ["run", "中文"], input: Data([0, 1]))
        let expected = Data([0, 0, 0, 28, 1, 0, 0, 0, 7, 0, 0, 0, 2, 0, 0, 0, 3])
            + Data("run".utf8)
            + Data([0, 0, 0, 6])
            + Data("中文".utf8)
            + Data([0, 1])

        #expect(request == expected)
        #expect(RemoteCommandChannel.Frame.requestSize(arguments: ["run", "中文"], input: Data([0, 1])) == expected.count)
        #expect(RemoteCommandChannel.Frame.abort(identifier: 7) == Data([0, 0, 0, 5, 2, 0, 0, 0, 7]))

        // 整块输出含 NUL、0x1E 与 0x1F，按长短不一的块喂进去
        let payload = Data((0 ..< RemoteCommandChannel.FrameReader.chunkLimit).map { UInt8(truncatingIfNeeded: $0) })
        let stream = frame(type: 0, identifier: 1)
            + frame(type: 1, identifier: 3)
            + frame(type: 2, identifier: 3, payload: Data("err".utf8))
            + frame(type: 1, identifier: 3, payload: payload)
            + frame(type: 3, identifier: 3, payload: Data([137]))

        var reader = RemoteCommandChannel.FrameReader()
        var events: [RemoteCommandChannel.FrameReader.Event] = []
        let sizes = [1, 2, 3, 5, 8, 13, 4096]
        var offset = stream.startIndex
        var round = 0

        while offset < stream.endIndex {
            let end = min(offset + sizes[round % sizes.count], stream.endIndex)
            events += try reader.receive(stream[offset ..< end])
            offset = end
            round += 1
        }

        #expect(events.first == .ready(version: 1))
        #expect(events.last == .exit(identifier: 3, code: 137))
        #expect(output(of: events, identifier: 3, isError: false) == payload)
        #expect(output(of: events, identifier: 3, isError: true) == Data("err".utf8))

        // 未知类型、带负载的就绪帧、负载不是 1 字节的结束帧、超过一块上限的输出、长度不足帧头
        let invalid = [
            frame(type: 9, identifier: 1),
            frame(type: 0, identifier: 1, payload: Data([0])),
            frame(type: 3, identifier: 1, payload: Data([0, 0])),
            frame(type: 1, identifier: 1, payload: Data(count: RemoteCommandChannel.FrameReader.chunkLimit + 1)),
            Data([0, 0, 0, 4, 1, 0, 0, 0, 1]),
        ]

        for frame in invalid {
            var reader = RemoteCommandChannel.FrameReader()
            #expect(throws: RemoteCommandChannel.FrameReader.InvalidFrame.self) { try reader.receive(frame) }
        }
    }

    /// 通道里的请求与单独启动的包装器走同一套分派：未知模式的退出码与报错、inspect 的输出、run 的完成帧都相同。
    @Test("常驻通道里的请求与单独启动的包装器结果相同")
    func servedRequestsMatchStandalone() async throws {
        let session = try await createSession()
        let channel = openChannel(in: session)

        defer {
            channel.close()
            try? FileManager.default.removeItem(atPath: session)
        }

        // 未知模式
        let served = try await channel.execute(["unknown"], input: Data(), resultArguments: [])
        let standalone = try await standaloneWrapper(["unknown"])

        #expect(served.exitCode == standalone.exitCode)
        #expect(served.exitCode != 0)
        #expect(served.standardError == standalone.standardError)

        // inspect
        let paths = [session, session + "/missing"]
        let inspected = try await channel.execute(["inspect"] + paths, input: Data(), resultArguments: [])

        #expect(inspected.exitCode == 0)
        #expect(inspected.standardOutput == Data("1\n0\n".utf8))
        #expect(try await standaloneWrapper(["inspect"] + paths).standardOutput == inspected.standardOutput)

        // run 的输出与完成帧，两边只差操作标识
        let command = ["/bin/sh", "-c", "printf out; printf err >&2; exit 3"]
        let servedRun = try await channel.execute(operation(in: session, command), input: Data(), resultArguments: [])
        let standaloneRun = try await standaloneWrapper(operation(in: session, command))

        #expect(servedRun.exitCode == 3)
        #expect(servedRun.exitCode == standaloneRun.exitCode)
        #expect(servedRun.standardOutput == standaloneRun.standardOutput)
        #expect(withoutOperation(servedRun.standardError) == withoutOperation(standaloneRun.standardError))
    }

    /// 同时进行的请求各自收到自己的输出；大段二进制输出与标准输入逐字节不变，
    /// 空的标准输入、超过管道容量的标准输入与不读标准输入就退出的命令都能正常结束。
    @Test("常驻通道并发请求的二进制输出与标准输入")
    func channelBinaryRequests() async throws {
        let session = try await createSession()
        let channel = openChannel(in: session)

        defer {
            channel.close()
            try? FileManager.default.removeItem(atPath: session)
        }

        // 每个请求经 cat 送回自己的标准输入：内容各不相同，都大于管道容量
        let inputs: [Data] = (1 ... 6).map { (seed: Int) in
            Data((0 ..< 300 * 1024).map { (index: Int) in UInt8(truncatingIfNeeded: index * seed + seed) })
        }

        let echoed = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (index, input) in inputs.enumerated() {
                group.addTask {
                    let result = try await channel.execute(
                        self.operation(in: session, ["/bin/cat"]),
                        input: input,
                        resultArguments: []
                    )

                    return (index, result.standardOutput)
                }
            }

            return try await group.reduce(into: [Int: Data]()) { $0[$1.0] = $1.1 }
        }

        for (index, input) in inputs.enumerated() {
            #expect(echoed[index] == input)
        }

        // 4 MiB 的二进制输出跨越很多块
        let block = Data((0 ..< 1024 * 1024).map { UInt8(truncatingIfNeeded: $0) })
        let large = try await channel.execute(
            operation(in: session, [
                "/usr/bin/perl", "-e", "binmode STDOUT; print pack('C*', map { $_ % 256 } 0 .. 1048575) for 1 .. 4",
            ]),
            input: Data(),
            resultArguments: []
        )

        #expect(large.standardOutput == block + block + block + block)

        // 空的标准输入读到 EOF；不读标准输入的命令照常结束
        let empty = try await channel.execute(operation(in: session, ["/bin/cat"]), input: Data(), resultArguments: [])
        let unread = try await channel.execute(operation(in: session, ["/usr/bin/true"]), input: inputs[0], resultArguments: [])

        #expect(empty.exitCode == 0)
        #expect(empty.standardOutput.isEmpty)
        #expect(unread.exitCode == 0)
    }

    /// 在本机会话上打开常驻通道：通道进程直接以 serve 模式运行包装器。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - onDisconnect: 通道自行断开时的通知。
    func openChannel(
        in session: String,
        onDisconnect: @escaping @Sendable (RemoteCommandChannel) -> Void = { _ in }
    ) -> RemoteCommandChannel {
        RemoteCommandChannel(
            executable: "/usr/bin/perl",
            arguments: [Self.wrapper.path, "serve", session],
            environment: .inherit,
            onDisconnect: onDisconnect
        )
    }

    /// 包装器 run 模式的参数：在会话里以新的操作标识执行命令。
    ///
    /// - Parameters:
    ///   - session: 会话目录。
    ///   - command: 要执行的命令。
    func operation(in session: String, _ command: [String]) -> [String] {
        ["run", session, UUID().uuidString.lowercased(), "2"] + command
    }

    /// 单独启动包装器执行一个模式，接受任何退出码。
    ///
    /// - Parameter arguments: 模式与它的参数。
    func standaloneWrapper(_ arguments: [String]) async throws -> GitCommandResult {
        try await CommandExecutor.execute(
            executable: "/usr/bin/perl",
            processArguments: [Self.wrapper.path] + arguments,
            acceptedExitCodes: Set(0 ... 255)
        )
    }

    /// serve 模式发回的一个帧。
    ///
    /// - Parameters:
    ///   - type: 帧的类型。
    ///   - identifier: 请求标识，就绪帧里是协议版本。
    ///   - payload: 负载。
    private func frame(type: UInt8, identifier: UInt32, payload: Data = Data()) -> Data {
        var frame = Data()
        withUnsafeBytes(of: UInt32(5 + payload.count).bigEndian) { frame.append(contentsOf: $0) }
        frame.append(type)
        withUnsafeBytes(of: identifier.bigEndian) { frame.append(contentsOf: $0) }
        return frame + payload
    }

    /// 把一个请求的一路输出按到达顺序接起来。
    private func output(
        of events: [RemoteCommandChannel.FrameReader.Event],
        identifier: UInt32,
        isError: Bool
    ) -> Data {
        events.reduce(into: Data()) { output, event in
            if case .output(identifier, isError, let data) = event {
                output.append(data)
            }
        }
    }

    /// 去掉完成帧里的操作标识，只留输出与退出信息。
    private func withoutOperation(_ standardError: Data) -> String {
        String(decoding: standardError, as: UTF8.self)
            .replacing(/SPOOKY:[a-f0-9-]{36}:/, with: "SPOOKY:")
    }
}
