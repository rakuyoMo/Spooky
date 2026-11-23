import Foundation
import Subprocess
import Testing

@testable import SpookyKit

/// 体检的会话步骤与部署脚本在本机按 B 上的方式运行：主目录换成临时目录，`/bin/sh` 与 `/bin/dash` 各运行一遍。
extension RemoteHealthCheckTests {
    /// 部署脚本安装包装器时删掉超过保留天数没有新建过会话的旧版本，再新建会话、开始会话；
    /// 会话步骤只在包装器与全部回调入口都在、字节数与本机一致时新建会话，并且只更新包装器的访问时间；
    /// 会话步骤失败时其余步骤照常执行，令牌步骤只在会话新建之后执行。
    @Test("部署时清理旧版本，体检只复用完整的包装器", arguments: ["/bin/sh", "/bin/dash"])
    func installedWrapper(shell: String) async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        let bin = home.appending(path: ".spooky/bin")
        let bundled = try #require(RemoteConnection.bundledWrapper)
        let wrapper = bin.appending(path: bundled.filename).path
        let length = bundled.source.count
        var sessions: [String] = []

        defer {
            try? FileManager.default.removeItem(at: home)

            for session in sessions {
                try? FileManager.default.removeItem(atPath: session)
            }
        }

        // 还没有安装：会话步骤失败，之后的步骤照常执行
        let absent = try await healthCheck(shell, home: home, length: length, steps: [.session, .gitPath])
        #expect(absent.completed(.session, argument: "session")?.exitCode != 0)
        #expect(absent.completed(.gitPath, argument: "gitPath")?.exitCode == 0)

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

        // 部署：安装包装器、新建会话并写入源码之后的那行令牌，删掉超过保留天数的旧版本
        let token = tokenLine()
        let deployed = try await deploy(shell, home: home, bundled: bundled, token: token)
        sessions += deployed.dropFirst()

        #expect(deployed.first == wrapper)
        #expect(deployed.count == 2)
        #expect(try deployed.last.map { try sessionToken(in: $0) } == token)
        #expect(!FileManager.default.fileExists(atPath: stale))
        #expect(!FileManager.default.fileExists(atPath: stale + "-askpass"))
        #expect(FileManager.default.fileExists(atPath: recent))
        #expect(FileManager.default.fileExists(atPath: unrelated))

        // 已安装：会话步骤输出包装器路径与新的会话目录，令牌步骤写入标准输入里的令牌；
        // 访问时间记下这次使用，修改时间不变
        try setTimes(of: wrapper, daysAgo: days + 1)
        let installed = try times(of: wrapper)
        let reused = try await healthCheck(shell, home: home, length: length, steps: [.session, .token], input: token)
        let session = try #require(reused.completed(.session, argument: "session"))
        let lines = String(decoding: session.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
        sessions += lines.dropFirst()

        #expect(session.exitCode == 0)
        #expect(lines.first == wrapper)
        #expect(lines.count == 2)
        #expect(reused.completed(.token, argument: "token")?.exitCode == 0)
        #expect(try lines.last.map { try sessionToken(in: $0) } == token)
        #expect(try times(of: wrapper).modified == installed.modified)
        #expect(try times(of: wrapper).accessed > installed.accessed)

        // 字节数与本机不一致：没有新建会话，脚本不执行令牌步骤
        let resized = try await healthCheck(shell, home: home, length: length + 1, steps: [.session, .token], input: token)
        let resizedSession = try #require(resized.completed(.session, argument: "session"))
        #expect(resizedSession.exitCode != 0)
        #expect(resizedSession.standardOutput.isEmpty)
        #expect(resized.completed(.token, argument: "token") == nil)

        // 缺少一个回调入口
        try FileManager.default.removeItem(atPath: wrapper + "-gpg")

        let incomplete = try await healthCheck(shell, home: home, length: length, steps: [.session])
        let incompleteSession = try #require(incomplete.completed(.session, argument: "session"))
        #expect(incompleteSession.exitCode != 0)
        #expect(incompleteSession.standardOutput.isEmpty)
    }

    /// 转成常驻通道的体检：会话步骤的分隔帧先于前导结束交出，经还没就绪的通道开始会话的请求，
    /// 由同一个进程转成 serve 之后执行；包装器还没安装时脚本照常结束，通道没有就绪就关闭。
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
        let absent = try channelCheck(shell, home: home)
        let absentFrame = await absent.preamble.firstFrame()
        let absentChecks = try await RemoteHealthCheck(absent.channel.preambleResult(), steps: [.session, .gitPath])

        #expect(try #require(absentFrame).code != 0)
        #expect(absentChecks.completed(.gitPath, argument: "gitPath")?.exitCode == 0)
        #expect(await !absent.channel.waitUntilReady())

        sessions += try await deploy(shell, home: home, bundled: bundled, token: tokenLine()).dropFirst()

        // 已安装：会话步骤的帧一到就经通道发出开始会话的请求，之后体检的其余步骤照常执行
        let entered = try channelCheck(shell, home: home)
        defer { entered.channel.close() }

        let frame = try #require(await entered.preamble.firstFrame())
        let lines = String(decoding: frame.output, as: UTF8.self).split(separator: "\n").map(String.init)
        let directory = try #require(lines.last)
        sessions.append(directory)

        #expect(frame.code == 0)
        #expect(lines.count == 2)

        let token = tokenLine()
        async let written = entered.channel.execute(
            ["start-session", directory, "600", "300"],
            input: token,
            resultArguments: []
        )
        let checks = try await RemoteHealthCheck(entered.channel.preambleResult(), steps: [.session, .gitPath])

        #expect(checks.completed(.gitPath, argument: "gitPath")?.exitCode == 0)
        #expect(try await written.exitCode == 0)
        #expect(try sessionToken(in: directory) == token)
        #expect(await entered.channel.waitUntilReady())

        let closed = try await entered.channel.execute(["close", directory], input: Data(), resultArguments: [])
        #expect(closed.exitCode == 0)
    }

    /// 脚本的标准输入另存在 3 号描述符上留给令牌步骤，体检各步启动的程序都拿不到它：
    /// PATH 最前面的假 Git、wc 与 uname 核对自己 3 号及以后的描述符都没有打开，再执行真的程序；
    /// bash 为了恢复重定向另存的副本在 10 号，只查 3 号查不出来。令牌步骤照旧读到令牌。
    @Test("体检步骤启动的程序拿不到脚本的标准输入", arguments: ["/bin/sh", "/bin/dash"])
    func inheritedDescriptors(shell: String) async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "spooky-home-" + UUID().uuidString)
        let fakes = home.appending(path: "fakes")
        let bundled = try #require(RemoteConnection.bundledWrapper)
        let repository = try TemporaryRepository()
        var sessions: [String] = []

        defer {
            try? FileManager.default.removeItem(at: home)
            repository.remove()

            for session in sessions {
                try? FileManager.default.removeItem(atPath: session)
            }
        }

        try await repository.initialize()
        try FileManager.default.createDirectory(at: fakes, withIntermediateDirectories: true)
        try fakeProgram(named: ["git", "wc", "uname"], in: fakes)
        sessions += try await deploy(shell, home: home, bundled: bundled, token: tokenLine()).dropFirst()

        // 包括令牌步骤在内的全部步骤都成功，任何一步的程序报出打开的描述符，这一步就失败并留下诊断
        let token = tokenLine()
        let steps = RemoteHealthCheck.repositorySteps + [.token]
        let searchPath = fakes.path + ":" + (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")

        let checks = try await healthCheck(
            shell,
            home: home,
            length: bundled.source.count,
            steps: steps,
            path: repository.directory.path,
            environment: [
                "PATH": searchPath,
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ],
            input: token
        )
        let session = try #require(checks.completed(.session, argument: "session"))
        let lines = String(decoding: session.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
        sessions += lines.dropFirst()

        for step in steps {
            let result = try #require(checks.completed(step, argument: "\(step)"))
            #expect(result.exitCode == 0, "\(step)")
            #expect(String(decoding: result.standardError, as: UTF8.self).isEmpty, "\(step)")
        }

        #expect(try lines.last.map { try sessionToken(in: $0) } == token)
    }

    /// 在临时主目录下用 `shell` 执行体检的 `steps`，不转成常驻通道。
    ///
    /// - Parameters:
    ///   - shell: 执行脚本的 shell。
    ///   - home: 临时主目录。
    ///   - length: 本机包装器的字节数。
    ///   - steps: 要执行的步骤。
    ///   - path: 要检查的仓库路径。
    ///   - environment: 主目录之外要改的环境变量。
    ///   - input: 脚本的标准输入，令牌步骤从中读令牌。
    /// - Returns: 切开的各步骤结果。
    private func healthCheck(
        _ shell: String,
        home: URL,
        length: Int,
        steps: [RemoteHealthCheck.Step],
        path: String = "/",
        environment: [Environment.Key: String?] = [:],
        input: Data? = nil
    ) async throws -> RemoteHealthCheck {
        let filename = try #require(RemoteConnection.bundledWrapper).filename
        var overrides = environment
        overrides["HOME"] = home.path

        let result = try await CommandExecutor.execute(
            executable: shell,
            processArguments: [
                "-c", RemoteHealthCheck.script(steps, entersChannel: false), "spooky-check",
                path, filename, String(length), "600", "300",
            ],
            environment: .inherit.updating(overrides),
            input: input
        )

        return RemoteHealthCheck(result, steps: steps)
    }

    /// 在临时主目录下用 `shell` 执行体检的会话步骤与找 Git 的步骤，全部成功之后转成常驻通道。
    ///
    /// - Parameters:
    ///   - shell: 执行脚本的 shell。
    ///   - home: 临时主目录。
    /// - Returns: 通道与它的前导。
    private func channelCheck(
        _ shell: String,
        home: URL
    ) throws -> (channel: RemoteCommandChannel, preamble: RemoteCommandChannel.Preamble) {
        let bundled = try #require(RemoteConnection.bundledWrapper)
        let preamble = RemoteCommandChannel.Preamble(arguments: ["health-check"])

        let channel = RemoteCommandChannel(
            executable: shell,
            arguments: [
                "-c", RemoteHealthCheck.script([.session, .gitPath], entersChannel: true), "spooky-check",
                "/", bundled.filename, String(bundled.source.count), "600", "300",
            ],
            environment: .inherit.updating(["HOME": home.path]),
            preamble: preamble,
            onDisconnect: { _ in }
        )

        return (channel, preamble)
    }

    /// 会话目录里 session.json 记的令牌，按令牌的一行返回。
    private func sessionToken(in session: String) throws -> Data {
        let content = try Data(contentsOf: URL(fileURLWithPath: session).appending(path: "session.json"))
        let token = String(decoding: content, as: UTF8.self)
            .replacingOccurrences(of: #"{"token":""#, with: "")
            .replacingOccurrences(of: #""}"#, with: "")

        return Data((token + "\n").utf8)
    }

    /// 在临时主目录下用 `shell` 执行部署脚本。
    ///
    /// - Parameters:
    ///   - shell: 执行脚本的 shell。
    ///   - home: 临时主目录。
    ///   - bundled: 包装器的源码与文件名。
    ///   - token: 源码之后的那行令牌。
    /// - Returns: 输出的各行：包装器路径与会话目录。
    private func deploy(
        _ shell: String,
        home: URL,
        bundled: (source: Data, filename: String),
        token: Data
    ) async throws -> [String] {
        let script = RemoteConnection.deploymentScript(filename: bundled.filename, length: bundled.source.count)

        let result = try await CommandExecutor.execute(
            executable: shell,
            processArguments: ["-c", script, "spooky-deploy", "600", "300"],
            environment: .inherit.updating(["HOME": home.path]),
            input: bundled.source + token
        )

        return String(decoding: result.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    /// 在 `directory` 下写一个假程序，以 `names` 里的每个名字各留一个硬链接：
    /// 它在 3 号及以后的描述符有打开的就报错退出，否则执行 /usr/bin 下的同名程序。
    private func fakeProgram(named names: [String], in directory: URL) throws {
        let source = #"""
        #!/usr/bin/perl
        use POSIX ();
        my @open = grep { my $copy = POSIX::dup($_); defined $copy && POSIX::close($copy) } 3 .. 255;
        die "open descriptors: @open\n" if @open;
        exec '/usr/bin/' . ($0 =~ m{([^/]+)\z})[0], @ARGV;
        """#
        let program = directory.appending(path: names[0])

        try Data((source + "\n").utf8).write(to: program)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)

        for name in names.dropFirst() {
            try FileManager.default.linkItem(at: program, to: directory.appending(path: name))
        }
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
