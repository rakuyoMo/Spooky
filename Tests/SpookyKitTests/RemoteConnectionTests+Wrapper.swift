import Foundation
import Testing

@testable import SpookyKit

/// 连接时按 B 上是否装好了这一版包装器，在体检里直接新建会话，或者部署包装器。
extension RemoteConnectionTests {
    /// 主目录里没有这一版包装器时连接会安装它；重新连接时体检直接用它新建会话，包装器还是原来那个文件。
    @Test("连接时安装包装器，已安装时在体检里新建会话")
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
            // 没有安装：连接时部署
            _ = try await connection.open()
            _ = try await connection.execute(status)

            #expect(await connection.wrapper == wrapper)

            let installed = try await RemoteFixture.raw(["/bin/ls", "-i", wrapper]).standardOutput

            // 已安装：重新连接时体检里新建会话，不再重新安装
            _ = try await connection.reconnect()
            _ = try await connection.execute(status)

            #expect(await connection.wrapper == wrapper)
            #expect(try await RemoteFixture.raw(["/bin/ls", "-i", wrapper]).standardOutput == installed)

            await connection.close()
            try await fixture.remove()
        } catch {
            await connection.close()
            try await fixture.remove()
            throw error
        }
    }
}
