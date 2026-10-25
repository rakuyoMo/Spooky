import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteHostOperationsTests

/// 仓库还不存在时在 B 上执行的操作：列目录、新建、扫描与克隆，都只在本次测试的目录里进行。
///
/// 主机连接先以测试专用的认证与隔离的 Git 环境登记，之后的主机操作都复用它。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteHostOperationsTests {
    /// 测试用的主机别名。
    private static let host = "spooky-test"

    /// 以测试配置登记主机连接；同一别名已登记时沿用。
    private static func connection() -> RemoteConnection {
        RemoteConnection.host(host, configuration: RemoteFixture.configuration)
    }

    /// 列目录只列子目录并标出工作区；在测试目录里新建仓库，扫描找到两个仓库。
    @Test("服务器上列目录、新建与扫描", .timeLimit(.minutes(2)))
    func listCreateAndScan() async throws {
        let fixture = try await RemoteFixture.create()
        _ = Self.connection()

        do {
            _ = try await RemoteFixture.raw(["/bin/sh", "-c", "printf x > \"$1/file.txt\"", "sh", fixture.root])

            let entries = try await HostDirectories.list(.remote(host: Self.host, path: fixture.root))
            #expect(entries.map(\.path) == [fixture.repository])
            #expect(entries.first?.isRepository ?? false)

            let created = fixture.root + "/新 仓库/子目录"
            try await RepositoryCreation.initialize(.remote(host: Self.host, path: created))
            #expect(try await HostDirectories.status(of: .remote(host: Self.host, path: created)).isRepository)

            var found: [String] = []

            for try await location in RepositoryScan.repositories(in: .remote(host: Self.host, path: fixture.root)) {
                #expect(location.host == Self.host)
                found.append(location.path)
            }

            #expect(Set(found) == [fixture.repository, created])
        } catch {
            try await fixture.remove()
            throw error
        }

        try await fixture.remove()
    }

    /// 克隆在 B 上执行，目标是 B 上的目录；报告的进度来自 stderr，克隆好的是工作区。
    @Test("服务器上克隆", .timeLimit(.minutes(2)))
    func cloneOnServer() async throws {
        let fixture = try await RemoteFixture.create()
        _ = Self.connection()

        do {
            let origin = fixture.root + "/origin.git"
            _ = try await RemoteFixture.raw(["git", "-C", fixture.repository, "commit", "--allow-empty", "-q", "-m", "first"])
            _ = try await RemoteFixture.raw(["git", "clone", "-q", "--bare", fixture.repository, origin])

            let destination = RepositoryLocation.remote(host: Self.host, path: fixture.root + "/克隆 clone")
            let clone = RepositoryClone(url: origin, destination: destination)
            _ = try await clone.start().value

            let status = try await HostDirectories.status(of: destination)
            #expect(status.isRepository)

            // 目标已存在且不是空目录时，B 上的 Git 拒绝克隆
            await #expect(throws: GitError.self) {
                _ = try await clone.start().value
            }
        } catch {
            try await fixture.remove()
            throw error
        }

        try await fixture.remove()
    }
}
