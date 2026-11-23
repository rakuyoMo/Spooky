import Foundation
import Testing
import TestSupport

@testable import SpookyKit

/// 连接时按 B 上是否装好了这一版包装器，在体检里直接新建会话，或者部署包装器。
extension RemoteConnectionTests {
    /// 主目录里没有这一版包装器时连接会安装它，另开一个 serve 会话作常驻通道；
    /// 重新连接时体检直接用它新建会话，体检的会话转成常驻通道，B 上这个会话只有这一个 serve，包装器还是原来那个文件。
    /// 从子目录打开同一个工作区时，体检转成的通道与体检新建的会话都被关掉，连接共享规范会话。
    @Test("连接时安装包装器，已安装时体检的会话转成常驻通道")
    func wrapperInstallation() async throws {
        let fixture = try await RemoteFixture.create()
        let bundled = try #require(RemoteConnection.bundledWrapper)
        let wrapper = fixture.root + "/home/.spooky/bin/" + bundled.filename
        let status = ["status", "--porcelain=v2", "-z", "--branch"]

        // 主目录换成测试目录里的空目录，不碰 B 上真正的主目录
        var configuration = RemoteFixture.configuration
        configuration.remoteEnvironment["HOME"] = fixture.root + "/home"
        let connection = fixture.connection(configuration: configuration)

        do {
            // 没有安装：连接时部署，常驻通道是另开的 serve 会话
            _ = try await connection.open()
            _ = try await connection.execute(status)

            #expect(await connection.wrapper == wrapper)
            #expect(await connection.resident?.preamble == nil)
            #expect(try await servers(of: connection) == 1)

            let installed = try await RemoteFixture.raw(["/bin/ls", "-i", wrapper]).standardOutput

            // 已安装：重新连接时体检里新建会话，不再重新安装；常驻通道就是体检的会话
            _ = try await connection.reconnect()
            _ = try await connection.execute(status)

            #expect(await connection.wrapper == wrapper)
            #expect(try await RemoteFixture.raw(["/bin/ls", "-i", wrapper]).standardOutput == installed)
            #expect(await connection.resident?.preamble != nil)
            #expect(try await servers(of: connection) == 1)

            // 从子目录打开：体检转成的通道关掉，体检新建的会话经 close 关掉，只留规范会话
            _ = try await RemoteFixture.raw(["/bin/mkdir", fixture.repository + "/nested"])
            let child = RemoteConnection(
                host: "spooky-test",
                path: fixture.repository + "/nested",
                configuration: configuration
            )

            _ = try await child.open()
            let session = try #require(await connection.remoteDirectory)

            #expect(await child.pendingChannel == nil)
            #expect(await child.resident == nil)
            #expect(try await watchedSessions(of: wrapper) == [session])

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 已安装包装器时，体检新建会话之后，转发中继在其余步骤还没结束时就开始，开始会话的请求随之发进还没就绪的通道：
    /// 状态检查停在闸门上时中继已经转发进会话，B 上还没有这个会话的看守；
    /// 放行之后常驻通道就是体检的会话，令牌已经写入，看守有且只有一个。
    /// 新建会话之后的检查失败时，体检新建的会话随连接一起关掉。
    @Test("体检期间开始转发，检查成功之后才分出看守，失败时关掉会话")
    func sessionDuringHealthCheck() async throws {
        let fixture = try await RemoteFixture.create()
        let gate = try ProcessGate(in: URL(fileURLWithPath: fixture.root))
        let configuration = try await gatedConfiguration(fixture, gate: gate)
        let connection = fixture.connection(configuration: configuration)

        do {
            // 第一次连接安装包装器，之后的连接都在体检里新建会话
            _ = try await connection.open()
            await connection.close()

            // 状态检查停住时转发就能完成：会话已经记下，B 的会话目录里已有 relay.sock；
            // 会话还没有开始，状态检查再慢也没有看守会清理它
            try gate.arm()
            let opening = Task { try await connection.open() }
            await gate.arrival()

            try await #require(await connection.sessionSetup).forward.value
            let session = try #require(await connection.remoteDirectory)

            #expect(try await sessionFiles(session).contains("relay.sock"))
            #expect(try await watchers(of: session) == 0)

            // 放行之后：常驻通道是体检的会话，令牌经它写入，同时分出看守
            gate.release()
            _ = try await opening.value
            let token = try #require(await connection.relay?.token)
            let written = try await RemoteFixture.raw(["/bin/cat", session + "/session.json"]).standardOutput

            #expect(await connection.resident?.preamble != nil)
            #expect(await connection.sessionSetup == nil)
            #expect(written == Data(#"{"token":"\#(token)"}"#.utf8))
            #expect(try await watchers(of: session) == 1)

            await connection.close()

            // 状态检查失败：停住时会话已经建好，连接失败之后它被关掉
            _ = try await RemoteFixture.raw(["/usr/bin/touch", fixture.root + "/malformed"])
            try gate.arm()
            let failing = Task { try await connection.open() }
            await gate.arrival()

            try await #require(await connection.sessionSetup).forward.value
            let created = try #require(await connection.remoteDirectory)
            gate.release()

            let error = await #expect(throws: RemoteConnectionError.self) { try await failing.value }
            #expect(error?.kind == .statusFormat)
            #expect(try await sessionFiles(created).isEmpty)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }

    /// 逐条执行命令时令牌经体检脚本的标准输入写入，体检之后转发中继，没有常驻通道；
    /// 主机连接同样在体检里新建会话，体检的会话转成常驻通道。
    @Test("逐条执行与主机连接时体检新建的会话")
    func sessionWithoutWorkTree() async throws {
        let fixture = try await RemoteFixture.create()

        // 主目录换成测试目录里的空目录，不碰 B 上真正的主目录
        var configuration = RemoteFixture.configuration
        configuration.remoteEnvironment["HOME"] = fixture.root + "/home"
        let host = RemoteConnection(host: "spooky-test", path: "", hostScoped: true, configuration: configuration)

        configuration.usesResidentChannel = false
        let separate = fixture.connection(configuration: configuration)

        do {
            // 逐条执行：第一次连接安装包装器，重新连接时体检新建会话，会话目录里有转发的 relay.sock 与令牌
            _ = try await separate.open()
            _ = try await separate.reconnect()
            let session = try #require(await separate.remoteDirectory)
            _ = try await separate.execute(["status", "--porcelain=v2", "-z"])

            #expect(await separate.resident == nil)
            #expect(await separate.pendingChannel == nil)
            #expect(try await Set(sessionFiles(session)).isSuperset(of: ["relay.sock", "session.json"]))

            // 主机连接：体检的会话转成常驻通道
            _ = try await host.connectHost()
            let hostSession = try #require(await host.remoteDirectory)

            #expect(await host.resident?.preamble != nil)
            #expect(try await Set(sessionFiles(hostSession)).isSuperset(of: ["relay.sock", "session.json"]))

            await separate.close()
            await host.close()
            try await fixture.remove()
        } catch {
            await separate.close()
            await host.close()
            try await fixture.remove()
            throw error
        }
    }

    /// B 上为连接当前的会话运行的 serve 进程数。
    func servers(of connection: RemoteConnection) async throws -> Int {
        let session = try #require(await connection.remoteDirectory)

        // 方括号让匹配式不匹配 pgrep 所在命令行本身；没有匹配时 pgrep 以 1 退出
        let found = try await RemoteFixture.raw([
            "/bin/sh", "-c", #"pgrep -f "serv[e] $1" || :"#, "spooky-servers", session,
        ])

        return String(decoding: found.standardOutput, as: UTF8.self).split(separator: "\n").count
    }

    /// 主目录换成测试目录里的空目录，PATH 最前面放一个代理 Git：状态命令在闸门武装时停住，
    /// 测试目录里有 `malformed` 文件时输出格式不对的状态，其余命令交给真正的 Git。
    private func gatedConfiguration(_ fixture: RemoteFixture, gate: ProcessGate) async throws -> SSHConfiguration {
        let malformed = GitRunner.shellQuoted(fixture.root + "/malformed")
        let script = """
            #!/bin/sh
            for spooky_argument in "$@"; do
                if test "$spooky_argument" = status; then
                    if \(gate.claim); then \(gate.hold); fi
                    if test -e \(malformed); then printf '? missing NUL'; exit 0; fi
                    break
                fi
            done
            exec /usr/bin/git "$@"
            """

        _ = try await RemoteFixture.raw([
            "/bin/sh", "-c",
            "mkdir \"$1/bin\" && cat > \"$1/bin/git\" && chmod 700 \"$1/bin/git\"",
            "fixture", fixture.root,
        ], input: Data(script.utf8))

        var configuration = RemoteFixture.configuration
        configuration.remoteEnvironment["HOME"] = fixture.root + "/home"
        configuration.remoteEnvironment["PATH"] = fixture.root + "/bin:/usr/bin:/bin"
        return configuration
    }

    /// B 上会话目录里的文件名，按名字排序；会话目录不在时为空。
    private func sessionFiles(_ session: String) async throws -> [String] {
        let listed = try await RemoteFixture.raw([
            "/bin/sh", "-c", #"test ! -d "$1" || ls "$1""#, "spooky-session-files", session,
        ])

        return String(decoding: listed.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init).sorted()
    }

    /// B 上看着 `session` 的看守进程数，按看守的进程标题找。
    private func watchers(of session: String) async throws -> Int {
        // 方括号让匹配式不匹配 pgrep 所在的命令行本身；一个也没有时 pgrep 以 1 退出
        let found = try await RemoteFixture.raw([
            "/bin/sh", "-c", #"pgrep -f "watc[h] $1" || :"#, "spooky-watchers", session,
        ])

        return String(decoding: found.standardOutput, as: UTF8.self).split(separator: "\n").count
    }

    /// B 上由 `wrapper` 分出的看守里，会话目录还在的那些看守所看的会话。
    ///
    /// 看守在会话目录被删掉后才退出，刚关掉的会话可能还有看守，但它的目录已经不在。
    /// 改写的进程标题后面可能跟着原来命令行区域里残留的字节，会话目录按它的格式取出。
    private func watchedSessions(of wrapper: String) async throws -> [String] {
        let found = try await RemoteFixture.raw([
            "/bin/sh", "-c",
            #"""
            pgrep -lf "$1 watc[h] " | sed -n 's|.* watch \(/tmp/spooky-[A-Za-z0-9_]*\).*|\1|p' |
            while read -r session; do
                if test -d "$session"; then printf '%s\n' "$session"; fi
            done
            """#,
            "spooky-watchers", wrapper,
        ])

        return String(decoding: found.standardOutput, as: UTF8.self).split(separator: "\n").map(String.init)
    }
}
