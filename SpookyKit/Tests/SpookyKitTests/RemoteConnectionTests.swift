import Foundation
import Testing

@testable import SpookyKit

/// 远端验收必须显式启用，只使用专用别名、密钥和测试目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteConnectionTests {
    /// 建立专属主连接、完成体检并原样传递特殊路径和提交信息。
    @Test("远端体检、状态与 stdin 转义", .timeLimit(.minutes(1)))
    func connectionAndStatus() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()

        do {
            let repository = try await connection.open()
            #expect(repository.path == fixture.repository)
            #expect(await connection.state == .connected)
            let status = try await connection.execute(["status", "--porcelain=v2", "-z", "--branch"])
            #expect(try WorkingCopyStatus(porcelainV2: status.standardOutput).branch.head == "main")
            let message = "单引号 ' 空格 $HOME `echo unsafe` \\ [*] 中文\n"
            _ = try await connection.execute(["commit", "--allow-empty", "-F", "-"], input: Data(message.utf8))
            let log = try await connection.execute(["log", "-1", "--format=%B"])
            #expect(String(decoding: log.standardOutput, as: UTF8.self) == message + "\n")
            _ = try await RemoteFixture.raw(["/bin/mkdir", fixture.repository + "/nested"])
            let child = RemoteConnection(
                host: "spooky-test",
                path: fixture.repository + "/nested",
                configuration: RemoteFixture.configuration
            )
            #expect(try await child.open().location == repository.location)
            let transfer = try await connection.sftpCommand()
            let childTransfer = try await child.sftpCommand()
            #expect(transfer.executable == "/usr/bin/sftp")
            #expect(transfer.arguments == childTransfer.arguments)
            #expect(transfer.arguments.contains("ProxyCommand=/usr/bin/false"))
            let childSession = try await child.execute([
                "-c", "alias.session=!printf '%s' \"$SPOOKY_SESSION\"", "session",
            ])
            let session = try await connection.execute([
                "-c", "alias.session=!printf '%s' \"$SPOOKY_SESSION\"", "session",
            ])
            let sessionPath = String(decoding: session.standardOutput, as: UTF8.self)
            #expect(sessionPath.hasPrefix("/tmp/spooky-"))
            #expect(childSession.standardOutput == session.standardOutput)
            let wrapper = try await connection.execute(["config", "--get", "core.askPass"])
            let wrapperPath = String(decoding: wrapper.standardOutput.dropLast(), as: UTF8.self)
            let permissions = try await RemoteFixture.raw(["/usr/bin/stat", "-f", "%Lp", sessionPath, wrapperPath])
            #expect(permissions.standardOutput == Data("700\n700\n".utf8))
            await connection.close()
            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", sessionPath])
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 目录和 Git 环境失败不能误报成 SSH 连接故障。
    @Test("远端路径、权限、Git 缺失与低版本", .timeLimit(.minutes(1)))
    func healthFailures() async throws {
        let fixture = try await RemoteFixture.create()

        do {
            let missing = RemoteConnection(
                host: "spooky-test", path: fixture.root + "/missing", configuration: RemoteFixture.configuration
            )
            let missingError = await #expect(throws: RemoteConnectionError.self) { try await missing.open() }
            #expect(missingError?.kind == .pathUnavailable)
            #expect(missingError?.result?.exitCode == 2)
            await missing.close()

            let plain = RemoteConnection(host: "spooky-test", path: fixture.root, configuration: RemoteFixture.configuration)
            let plainError = await #expect(throws: RemoteConnectionError.self) { try await plain.open() }
            #expect(plainError?.kind == .notWorkingTree)
            await plain.close()

            var absentConfiguration = RemoteFixture.configuration
            absentConfiguration.remoteEnvironment["PATH"] = fixture.root + "/empty"
            let absent = fixture.connection(configuration: absentConfiguration)
            let absentError = await #expect(throws: RemoteConnectionError.self) { try await absent.open() }
            #expect(absentError?.kind == .gitUnavailable)
            await absent.close()

            _ = try await RemoteFixture.raw([
                "/bin/sh", "-c", "mkdir \"$1/bin\"; cat > \"$1/bin/git\"; chmod 700 \"$1/bin/git\"", "fixture", fixture.root,
            ], input: Data("#!/bin/sh\nprintf 'git version 2.40.0\\n'\n".utf8))
            var oldConfiguration = RemoteFixture.configuration
            oldConfiguration.remoteEnvironment["PATH"] = fixture.root + "/bin"
            let old = fixture.connection(configuration: oldConfiguration)
            let oldError = await #expect(throws: RemoteConnectionError.self) { try await old.open() }
            #expect(oldError?.kind == .gitVersion)
            #expect(oldError?.result?.exitCode == 0)
            await old.close()

            let invalidStatusScript = """
            #!/bin/sh
            for spooky_argument in "$@"; do
                if test "$spooky_argument" = status; then printf '? missing NUL'; exit 0; fi
            done
            exec /usr/bin/git "$@"
            """
            _ = try await RemoteFixture.raw([
                "/bin/sh", "-c", "cat > \"$1/bin/git\"", "fixture", fixture.root,
            ], input: Data(invalidStatusScript.utf8))
            oldConfiguration.remoteEnvironment["PATH"] = fixture.root + "/bin:/usr/bin:/bin"
            let malformed = fixture.connection(configuration: oldConfiguration)
            let formatError = await #expect(throws: RemoteConnectionError.self) { try await malformed.open() }
            #expect(formatError?.kind == .statusFormat)
            await malformed.close()

            _ = try await RemoteFixture.raw(["/bin/chmod", "000", fixture.repository])
            let unreadable = fixture.connection()
            let permissionError = await #expect(throws: RemoteConnectionError.self) { try await unreadable.open() }
            #expect(permissionError?.kind == .pathPermission)
            await unreadable.close()
            _ = try await RemoteFixture.raw(["/bin/chmod", "700", fixture.repository])
            try await fixture.remove()
        } catch {
            _ = try? await RemoteFixture.raw(["/bin/chmod", "700", fixture.repository])
            try await fixture.remove()
            throw error
        }
    }

    /// 临时 known_hosts 与临时密钥只改变本次连接，不写 A 或 B 的 SSH 配置。
    @Test("未知指纹、变化指纹与认证失败", .timeLimit(.minutes(1)))
    func authenticationFailures() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Spooky-SSH-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = directory.appending(path: "other-key")
        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/ssh-keygen",
            processArguments: ["-q", "-t", "ed25519", "-N", "", "-f", key.path]
        )
        let resolved = try await CommandExecutor.execute(
            executable: "/usr/bin/ssh",
            processArguments: ["-G", "--", "spooky-test"]
        )
        let values = Dictionary(uniqueKeysWithValues: String(decoding: resolved.standardOutput, as: UTF8.self)
            .split(separator: "\n")
            .compactMap { line -> (String, String)? in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, ["hostname", "user", "port"].contains(String(parts[0])) else { return nil }
                return (String(parts[0]), String(parts[1]))
            })
        let hostname = try #require(values["hostname"])
        let user = try #require(values["user"])
        let port = try #require(values["port"])
        let config = directory.appending(path: "config")
        try "Host spooky-test\n  HostName \(hostname)\n  User \(user)\n  Port \(port)\n"
            .write(to: config, atomically: true, encoding: .utf8)
        let knownHosts = directory.appending(path: "known_hosts")
        try Data().write(to: knownHosts)
        var configuration = RemoteFixture.configuration
        configuration.file = config.path
        configuration.knownHosts = knownHosts.path

        let unknown = RemoteConnection(host: "spooky-test", path: "/Users/wgy/spooky-test", configuration: configuration)
        let unknownError = await #expect(throws: RemoteConnectionError.self) { try await unknown.open() }
        #expect(unknownError?.kind == .unknownHostKey)
        #expect(unknownError?.result?.exitCode == 255)
        await unknown.close()

        let publicKey = try String(contentsOf: URL(fileURLWithPath: key.path + ".pub"), encoding: .utf8)
        try (hostname + " " + publicKey).write(to: knownHosts, atomically: true, encoding: .utf8)
        let changed = RemoteConnection(host: "spooky-test", path: "/Users/wgy/spooky-test", configuration: configuration)
        let changedError = await #expect(throws: RemoteConnectionError.self) { try await changed.open() }
        #expect(changedError?.kind == .changedHostKey)
        await changed.close()

        // 只向 B 提交测试专用密钥的公钥；禁用私钥签名即可构造认证失败。
        // 临时生成的另一把密钥只用于伪造 known_hosts，绝不用于登录 B。
        configuration.knownHosts = nil
        configuration.identity = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".ssh/spooky-test_ed25519.pub").path
        let denied = RemoteConnection(host: "spooky-test", path: "/Users/wgy/spooky-test", configuration: configuration)
        let deniedError = await #expect(throws: RemoteConnectionError.self) { try await denied.open() }
        #expect(deniedError?.kind == .authentication)
        await denied.close()
    }

    /// 两条写入必须依次进入临界区；排队取消不能运行，活动取消必须确认远端退出。
    @Test("写入串行、队列取消与远端进程组取消", .timeLimit(.minutes(1)))
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
    @Test("主动断线、写入不重试与重连核对", .timeLimit(.minutes(1)))
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

    /// Git 返回 255 仍是 Git 错误；凭据和编辑器回调走同一反向 Unix socket。
    @Test("Git 255、凭据脱敏与编辑器回调", .timeLimit(.minutes(1)))
    func callbacksAndExitStatus() async throws {
        let fixture = try await RemoteFixture.create()
        let connection = fixture.connection()

        do {
            await connection.setCallbackHandler { request in
                if request.kind == .editor { return "edited on A\n" }
                return request.prompt.lowercased().hasPrefix("username") ? "spooky" : "test-secret-'$-never-log"
            }
            _ = try await connection.open()
            let gitError = await #expect(throws: GitError.self) {
                try await connection.execute(["-c", "alias.failure=!echo git-failure >&2; exit 255", "failure"])
            }
            #expect(gitError?.exitCode == 255)
            #expect(gitError?.message == "git-failure\n")
            #expect(await connection.state == .connected)

            let credentials = try await connection.execute(
                ["credential", "fill"],
                input: Data("protocol=https\nhost=spooky.example.invalid\n\n".utf8)
            )
            let text = String(decoding: credentials.standardOutput, as: UTF8.self)
            #expect(text.contains("username=spooky"))
            #expect(text.contains("password=[REDACTED]"))
            #expect(!text.contains("test-secret"))

            let sshAskpass = try await connection.execute([
                "-c",
                "alias.ssh-pass=!spooky_pass=$(git config core.askPass); "
                    + "\"${spooky_pass%-git-askpass}-askpass\" 'Enter passphrase for key test:'",
                "ssh-pass",
            ])
            #expect(sshAskpass.standardOutput == Data("[REDACTED]\n".utf8))

            _ = try await connection.execute(["commit", "--allow-empty"])
            let message = try await connection.execute(["log", "-1", "--format=%B"])
            #expect(message.standardOutput == Data("edited on A\n\n".utf8))
            await connection.close()
            try await fixture.remove()
        } catch {
            if let git = error as? GitError {
                Issue.record(Comment(rawValue: git.message.replacingOccurrences(
                    of: "test-secret-'$-never-log",
                    with: "[REDACTED]"
                )))
            }

            await connection.close()
            try await fixture.remove()
            throw error
        }
    }
}

/// 每个测试独占 B 上一个目录，所有 Git 配置都限制在该目录中的仓库。
struct RemoteFixture: Sendable {
    /// B 上本次测试的根目录。
    let root: String

    /// 覆盖空格、中文、引号、反斜杠和通配符的工作区路径。
    var repository: String { root + "/仓 库'\"\\[*]?" }

    /// 固定测试别名对应的专用认证和隔离 Git 环境。
    static var configuration: SSHConfiguration {
        SSHConfiguration(
            identity: FileManager.default.homeDirectoryForCurrentUser
                .appending(path: ".ssh/spooky-test_ed25519").path,
            remoteEnvironment: [
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ]
        )
    }

    /// 创建私有测试根目录，初始化空工作区和仓库本地身份。
    static func create() async throws -> Self {
        let result = try await raw([
            "/bin/sh", "-c",
            """
            umask 077
            test -d /Users/wgy/spooky-test || mkdir -m 700 /Users/wgy/spooky-test
            mktemp -d /Users/wgy/spooky-test/m2.XXXXXXXX
            """,
        ])
        let root = String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
        guard root.hasPrefix("/Users/wgy/spooky-test/m2."), !root.contains("\n") else {
            throw RemoteConnectionError(.protocolFailure, result: result)
        }

        let fixture = Self(root: root)

        do {
            _ = try await raw(["git", "-c", "init.templateDir=", "init", "-q", "-b", "main", fixture.repository])
            _ = try await raw(["git", "-C", fixture.repository, "config", "--local", "user.name", "Spooky Test"])
            _ = try await raw(["git", "-C", fixture.repository, "config", "--local", "user.email", "spooky@example.invalid"])
            _ = try await raw(["git", "-C", fixture.repository, "config", "--local", "commit.gpgSign", "false"])
            return fixture
        } catch {
            try await fixture.remove()
            throw error
        }
    }

    /// 使用生产连接实现，测试选项仅隔离认证和全局配置。
    func connection(configuration: SSHConfiguration = Self.configuration) -> RemoteConnection {
        RemoteConnection(host: "spooky-test", path: repository, configuration: configuration)
    }

    /// 仅删除本测试刚创建的目录。
    func remove() async throws {
        _ = try await Self.raw(["/bin/rm", "-rf", "--", root])
    }

    /// 夹具建立前没有 Git 工作区，通过核心进程边界执行固定的初始化命令。
    static func raw(_ command: [String], input: Data? = nil) async throws -> GitCommandResult {
        let shell = (configuration.environmentPrefix + command).map(GitRunner.shellQuoted).joined(separator: " ")
        return try await CommandExecutor.execute(
            executable: "/usr/bin/ssh",
            processArguments: configuration.options + [
                "-S", "none", "-o", "ControlMaster=no", "--", "spooky-test", shell,
            ],
            arguments: ["remote-test-fixture"],
            input: input
        )
    }
}
