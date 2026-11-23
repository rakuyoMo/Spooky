import Foundation
import Subprocess
import Testing

@testable import SpookyKit

/// 体检的会话步骤与部署脚本在本机按 B 上的方式运行：主目录换成临时目录，`/bin/sh` 与 `/bin/dash` 各运行一遍。
extension RemoteHealthCheckTests {
    /// 部署脚本安装包装器时删掉超过保留天数没有新建过会话的旧版本；会话步骤只在包装器与全部回调入口都在、
    /// 字节数与本机一致时新建会话，并且只更新包装器的访问时间。
    @Test("部署时清理旧版本，体检只复用完整的包装器", arguments: ["/bin/sh", "/bin/dash"])
    func installedWrapper(shell: String) async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        let bin = home.appending(path: ".spooky/bin")
        let bundled = try #require(RemoteConnection.bundledWrapper)
        let wrapper = bin.appending(path: bundled.filename).path
        var sessions: [String] = []

        defer {
            try? FileManager.default.removeItem(at: home)

            for session in sessions {
                try? FileManager.default.removeItem(atPath: session)
            }
        }

        // 还没有安装：会话步骤失败
        let absent = try await sessionStep(shell, home: home, length: bundled.source.count)
        #expect(absent.exitCode != 0)

        // 旧版本连同回调入口超过保留天数没有新建过会话，另一个版本在保留天数之内；不属于包装器的文件不动
        let days = RemoteConnection.wrapperRetentionDays
        let stale = bin.appending(path: "spooky-remote-v1-stale").path
        let recent = bin.appending(path: "spooky-remote-v1-recent").path
        let unrelated = bin.appending(path: "notes").path

        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

        for path in [stale, recent, unrelated] {
            FileManager.default.createFile(atPath: path, contents: Data())
        }

        try FileManager.default.linkItem(atPath: stale, toPath: stale + "-askpass")
        try setTimes(of: stale, daysAgo: days + 1)
        try setTimes(of: unrelated, daysAgo: days + 1)
        try setTimes(of: recent, daysAgo: days - 1)

        // 部署：安装包装器、新建会话，删掉超过保留天数的旧版本
        let deployed = try await deploy(shell, home: home, bundled: bundled)
        sessions += deployed.dropFirst()

        #expect(deployed.first == wrapper)
        #expect(deployed.count == 2)
        #expect(!FileManager.default.fileExists(atPath: stale))
        #expect(!FileManager.default.fileExists(atPath: stale + "-askpass"))
        #expect(FileManager.default.fileExists(atPath: recent))
        #expect(FileManager.default.fileExists(atPath: unrelated))

        // 已安装：会话步骤输出包装器路径与新的会话目录；访问时间记下这次使用，修改时间不变
        try setTimes(of: wrapper, daysAgo: days + 1)
        let installed = try times(of: wrapper)
        let reused = try await sessionStep(shell, home: home, length: bundled.source.count)
        let lines = String(decoding: reused.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
        sessions += lines.dropFirst()

        #expect(reused.exitCode == 0)
        #expect(lines.first == wrapper)
        #expect(lines.count == 2)
        #expect(try times(of: wrapper).modified == installed.modified)
        #expect(try times(of: wrapper).accessed > installed.accessed)

        // 字节数与本机不一致
        let resized = try await sessionStep(shell, home: home, length: bundled.source.count + 1)
        #expect(resized.exitCode != 0)
        #expect(resized.standardOutput.isEmpty)

        // 缺少一个回调入口
        try FileManager.default.removeItem(atPath: wrapper + "-gpg")

        let incomplete = try await sessionStep(shell, home: home, length: bundled.source.count)
        #expect(incomplete.exitCode != 0)
        #expect(incomplete.standardOutput.isEmpty)
    }

    /// 转成常驻通道的体检：会话步骤成功之后，同一个进程接着作为常驻通道执行请求；
    /// 包装器还没安装时脚本照常结束，前导带着脚本的结束状态，通道随之关闭。
    @Test("体检的会话转成常驻通道", arguments: ["/bin/sh", "/bin/dash"])
    func channelHealthCheck(shell: String) async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        let bundled = try #require(RemoteConnection.bundledWrapper)
        var sessions: [String] = []

        defer {
            try? FileManager.default.removeItem(at: home)

            for session in sessions {
                try? FileManager.default.removeItem(atPath: session)
            }
        }

        // 还没有安装：会话步骤失败，脚本照常结束，通道没有就绪就关闭
        let absent = try await channelCheck(shell, home: home)
        let absentSession = try #require(absent.checks.completed(.session, argument: "session"))

        #expect(absentSession.exitCode != 0)
        #expect(await !absent.channel.waitUntilReady())

        sessions += try await deploy(shell, home: home, bundled: bundled).dropFirst()

        // 已安装：会话步骤照常输出包装器路径与会话目录，之后经同一个进程执行请求
        let entered = try await channelCheck(shell, home: home)
        defer { entered.channel.close() }

        let session = try #require(entered.checks.completed(.session, argument: "session"))
        let lines = String(decoding: session.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
        let directory = try #require(lines.last)
        sessions.append(directory)

        #expect(session.exitCode == 0)
        #expect(lines.count == 2)
        #expect(await entered.channel.waitUntilReady())

        let inspected = try await entered.channel.execute(["inspect", directory], input: Data(), resultArguments: [])
        #expect(inspected.standardOutput == Data("1\n".utf8))

        let closed = try await entered.channel.execute(["close", directory], input: Data(), resultArguments: [])
        #expect(closed.exitCode == 0)
    }

    /// 在临时主目录下用 `shell` 只执行体检的会话步骤。
    ///
    /// - Parameters:
    ///   - shell: 执行脚本的 shell。
    ///   - home: 临时主目录。
    ///   - length: 本机包装器的字节数。
    /// - Returns: 会话步骤的结果。
    private func sessionStep(_ shell: String, home: URL, length: Int) async throws -> GitCommandResult {
        let marker = UUID().uuidString
        let filename = try #require(RemoteConnection.bundledWrapper).filename

        let result = try await CommandExecutor.execute(
            executable: shell,
            processArguments: [
                "-c", RemoteHealthCheck.script([.session], entersChannel: false), "spooky-check",
                "/", filename, String(length), "600", "300",
            ],
            environment: .inherit.updating(["HOME": home.path]),
            input: Data((marker + "\n").utf8) + sessionRequest()
        )

        let checks = RemoteHealthCheck(result, marker: marker, steps: [.session])
        return try #require(checks.completed(.session, argument: "session"))
    }

    /// 在临时主目录下用 `shell` 只执行体检的会话步骤，会话步骤成功之后转成常驻通道。
    ///
    /// - Parameters:
    ///   - shell: 执行脚本的 shell。
    ///   - home: 临时主目录。
    /// - Returns: 切开的体检结果与通道。
    private func channelCheck(
        _ shell: String,
        home: URL
    ) async throws -> (checks: RemoteHealthCheck, channel: RemoteCommandChannel) {
        let marker = UUID().uuidString
        let bundled = try #require(RemoteConnection.bundledWrapper)

        let channel = RemoteCommandChannel(
            executable: shell,
            arguments: [
                "-c", RemoteHealthCheck.script([.session], entersChannel: true), "spooky-check",
                "/", bundled.filename, String(bundled.source.count), "600", "300",
            ],
            environment: .inherit.updating(["HOME": home.path]),
            preamble: RemoteCommandChannel.Preamble(
                input: Data((marker + "\n").utf8) + sessionRequest(),
                marker: RemoteHealthCheck.channelMarker(marker),
                arguments: ["health-check"]
            ),
            onDisconnect: { _ in }
        )

        let result = try await channel.preambleResult()
        return (RemoteHealthCheck(result, marker: marker, steps: [.session]), channel)
    }

    /// 在临时主目录下用 `shell` 执行部署脚本。
    ///
    /// - Parameters:
    ///   - shell: 执行脚本的 shell。
    ///   - home: 临时主目录。
    ///   - bundled: 包装器的源码与文件名。
    /// - Returns: 输出的各行：包装器路径与会话目录。
    private func deploy(
        _ shell: String,
        home: URL,
        bundled: (source: Data, filename: String)
    ) async throws -> [String] {
        let script = RemoteConnection.deploymentScript(filename: bundled.filename, length: bundled.source.count)

        let result = try await CommandExecutor.execute(
            executable: shell,
            processArguments: ["-c", script, "spooky-deploy", "600", "300"],
            environment: .inherit.updating(["HOME": home.path]),
            input: bundled.source + sessionRequest()
        )

        return String(decoding: result.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    /// 把文件的访问时间与修改时间都设为 `days` 天前。
    private func setTimes(of path: String, daysAgo days: Int) throws {
        let seconds = Int(Date().timeIntervalSince1970) - days * 24 * 60 * 60
        let times = [timeval(tv_sec: seconds, tv_usec: 0), timeval(tv_sec: seconds, tv_usec: 0)]

        guard utimes(path, times) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    /// 文件的访问时间与修改时间，单位是秒。
    private func times(of path: String) throws -> (accessed: Int, modified: Int) {
        var info = stat()

        guard stat(path, &info) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return (info.st_atimespec.tv_sec, info.st_mtimespec.tv_sec)
    }
}
