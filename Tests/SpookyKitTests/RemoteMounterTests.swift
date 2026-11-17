import Darwin
import Foundation
import Testing
import TestSupport

@testable import SpookyKit

// MARK: - RemoteMounterTests

/// 挂载方式的检测与执行：SMB 端口检测、sshfs 的查找、NetFS 状态的换算、sshfs 的命令行与它的结束方式。
///
/// 不做真实挂载：端口检测连本机临时开的端口，sshfs 换成临时目录里的脚本。
struct RemoteMounterTests {
    /// 端口有程序在听时连得上，没有时连不上；检测超过时限算连不上；sshfs 装了才列出，两种方式各自判断。
    @Test("SMB 端口检测与列出的方式")
    func detection() async throws {
        let (listener, port) = try Self.listen()
        defer { close(listener) }

        let closedPort = try Self.unusedPort()

        #expect(await TCPPort.connects(to: "127.0.0.1", port: port))
        #expect(await !TCPPort.connects(to: "127.0.0.1", port: closedPort))

        // 连接一直没有结果时，到了时限就不再等
        let hanging = RemoteMountDetection(
            timeout: .milliseconds(10),
            connectsSMB: { _ in await Self.never() },
            sshfsExecutable: { "/usr/local/bin/sshfs" }
        )

        #expect(await hanging.methods(for: "spooky-test") == [.sshfs])

        let reachable = RemoteMountDetection(
            timeout: .seconds(60),
            connectsSMB: { _ in true },
            sshfsExecutable: { nil }
        )

        #expect(await reachable.methods(for: "spooky-test") == [.smb])

        let neither = RemoteMountDetection(
            timeout: .seconds(60),
            connectsSMB: { _ in false },
            sshfsExecutable: { nil }
        )

        #expect(await neither.methods(for: "spooky-test").isEmpty)
    }

    /// 先看常见的安装位置，再按 Environment 设置的 `PATH`，自定义变量覆盖登录 shell 的变量；
    /// 设置里都没有 `PATH` 时按继承的；不可执行的文件不算。
    @Test("找 sshfs")
    func executableLookup() throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let directory = temporary.directory

        let homebrew = try Self.script(in: directory.appending(path: "homebrew"), body: "exit 0")
        let custom = try Self.script(in: directory.appending(path: "custom"), body: "exit 0")
        let login = try Self.script(in: directory.appending(path: "login"), body: "exit 0")
        let plain = directory.appending(path: "plain/sshfs")

        try FileManager.default.createDirectory(at: plain.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: plain)

        let missing = directory.appending(path: "missing/sshfs").path
        let settings = LocalExecutionSettings(
            loginShellVariables: ["PATH": login.deletingLastPathComponent().path],
            customVariables: ["PATH": plain.deletingLastPathComponent().path + ":" + custom.deletingLastPathComponent().path]
        )

        #expect(SSHFSMount.executable(candidates: [missing, homebrew.path], settings: settings) == homebrew.path)
        #expect(SSHFSMount.executable(candidates: [missing], settings: settings) == custom.path)

        let loginOnly = LocalExecutionSettings(loginShellVariables: settings.loginShellVariables)

        #expect(SSHFSMount.executable(candidates: [missing], settings: loginOnly, inheritedPath: nil) == login.path)
        #expect(
            SSHFSMount.executable(
                candidates: [missing],
                settings: LocalExecutionSettings(),
                inheritedPath: custom.deletingLastPathComponent().path
            ) == custom.path
        )
        #expect(SSHFSMount.executable(candidates: [missing], settings: LocalExecutionSettings(), inheritedPath: nil) == nil)
    }

    /// 挂上与共享已经挂着都算挂上；登录框或共享列表里取消、不允许界面时没有可挂的共享，以及其它状态都是失败。
    @Test("NetFS 的状态换算")
    func smbOutcome() {
        #expect(SMBMount.outcome(of: 0).failure == nil)
        #expect(SMBMount.outcome(of: EEXIST).failure == nil)

        for status: Int32 in [-128, -6003, EHOSTUNREACH, EACCES] {
            #expect(SMBMount.outcome(of: status).failure == .smb(status: status))
        }

        #expect(!RemoteMountFailure.description(ofSMBStatus: EHOSTUNREACH).isEmpty)
    }

    /// 远端写作 `<别名>:<路径>`，路径里的空格与引号原样留在一个参数里；只另传严格核对主机密钥，
    /// 不允许询问时多 `BatchMode=yes`。
    @Test("sshfs 的命令行")
    func commandLine() {
        let path = "/Users/wgy/spooky-test/仓 库 \"引号\" 'single'"
        let folder = URL(filePath: "/Users/wgy/挂 载/\"仓库\"")

        #expect(
            SSHFSMount.arguments(host: "spooky-test", path: path, folder: folder, allowsInteraction: false) == [
                "spooky-test:" + path, folder.path, "-o", "StrictHostKeyChecking=yes", "-o", "BatchMode=yes",
            ]
        )
        #expect(
            SSHFSMount.arguments(host: "spooky-test", path: path, folder: folder, allowsInteraction: true) == [
                "spooky-test:" + path, folder.path, "-o", "StrictHostKeyChecking=yes",
            ]
        )
    }

    /// 前台以 0 退出算挂上，即使转入后台的进程还开着标准错误；非零时带上原样的标准错误；
    /// 写出标准错误后一直不结束、等着子进程的，过了等待时间连同子进程一起结束并报失败；启动不了时报原因。
    @Test("运行 sshfs 与它的结束方式")
    func running() async throws {
        let temporary = try TemporaryRepository()
        defer { temporary.remove() }

        let directory = temporary.directory

        let background = directory.appending(path: "background.pid")

        // 像 sshfs 一样留一个进程在后台，它仍开着标准错误
        let daemonizing = try Self.script(
            in: directory.appending(path: "daemonizing"),
            body: "/bin/sleep 600 &\necho $! > \"$PIDFILE\"\nexit 0"
        )

        let daemonized = await SSHFSMount.run(
            executable: daemonizing.path,
            arguments: [],
            environment: ["PIDFILE": background.path]
        )

        #expect(daemonized.failure == nil)

        let pid = try #require(pid_t(String(decoding: Data(contentsOf: background), as: UTF8.self).trimmed))
        kill(pid, SIGTERM)

        let failing = try Self.script(
            in: directory.appending(path: "failing"),
            body: "echo \"spooky-test:/nope: No such file or directory\" >&2\nexit 1"
        )

        #expect(
            await SSHFSMount.run(executable: failing.path, arguments: [], environment: [:]).failure
                == .sshfs(status: 1, standardError: "spooky-test:/nope: No such file or directory")
        )

        // 失败后一直等着子进程
        let hanging = try Self.script(
            in: directory.appending(path: "hanging"),
            body: "echo \"remote host has disconnected\" >&2\n/bin/sleep 600 &\nwait"
        )

        let result = await SSHFSMount.run(
            executable: hanging.path,
            arguments: [],
            environment: [:],
            grace: .milliseconds(10)
        )

        guard case .failure(.sshfs(_, let standardError)) = result else {
            Issue.record("卡住的 sshfs 没有报失败：\(result)")
            return
        }

        #expect(standardError == "remote host has disconnected")

        let missing = directory.appending(path: "missing/sshfs").path

        guard case .failure(.launch) = await SSHFSMount.run(executable: missing, arguments: [], environment: [:]) else {
            Issue.record("不存在的程序没有报启动失败")
            return
        }
    }
}

// MARK: - Helpers

extension RemoteMounterTests {
    /// 在本机回环地址上监听一个系统分配的端口。
    private static func listen() throws -> (descriptor: Int32, port: UInt16) {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        try #require(descriptor >= 0)

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        try #require(bind(descriptor, &address) == 0)
        try #require(Darwin.listen(descriptor, 4) == 0)

        return (descriptor, try port(of: descriptor))
    }

    /// 一个刚才分配过、现在没有程序在听的端口。
    private static func unusedPort() throws -> UInt16 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(descriptor) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        try #require(bind(descriptor, &address) == 0)

        return try port(of: descriptor)
    }

    /// 把套接字绑到地址上。
    private static func bind(_ descriptor: Int32, _ address: inout sockaddr_in) -> Int32 {
        withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    /// 套接字绑定到的端口。
    private static func port(of descriptor: Int32) throws -> UInt16 {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)

        let status = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }

        try #require(status == 0)

        return UInt16(bigEndian: address.sin_port)
    }

    /// 在目录里写一个名为 sshfs 的可执行脚本。
    private static func script(in directory: URL, body: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appending(path: "sshfs")
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)

        return url
    }

    /// 一直不结束、直到被取消的连接检测。
    private static func never() async -> Bool {
        let stream = AsyncStream<Bool> { _ in }

        for await value in stream {
            return value
        }

        return false
    }
}

// MARK: - String

extension String {
    /// 去掉首尾的空白与换行。
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Result

extension Result where Failure == RemoteMountFailure {
    /// 失败时的原因；挂上时为 nil。
    fileprivate var failure: RemoteMountFailure? {
        guard case .failure(let failure) = self else {
            return nil
        }

        return failure
    }
}
