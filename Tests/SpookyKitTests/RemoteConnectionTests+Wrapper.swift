import Foundation
import Testing

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

    /// B 上为连接当前的会话运行的 serve 进程数。
    func servers(of connection: RemoteConnection) async throws -> Int {
        let session = try #require(await connection.remoteDirectory)

        // 方括号让匹配式不匹配 pgrep 所在命令行本身；没有匹配时 pgrep 以 1 退出
        let found = try await RemoteFixture.raw([
            "/bin/sh", "-c", #"pgrep -f "serv[e] $1" || :"#, "spooky-servers", session,
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
