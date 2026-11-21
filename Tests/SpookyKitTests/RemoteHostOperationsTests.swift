import Foundation
import Testing

@testable import SpookyKit

// MARK: - RemoteHostOperationsTests

/// 仓库还不存在时在 B 上执行的操作：列目录、新建、扫描与克隆，都只在本次测试的目录里进行。
///
/// 主机连接先以测试专用的认证与隔离的 Git 环境登记，之后的主机操作都复用它；每项测试结束时关掉，主连接随之退出，本机不留下会话目录。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SPOOKY_REMOTE_TESTS"] == "1"))
struct RemoteHostOperationsTests {
    /// 测试用的主机别名。
    private static let host = "spooky-test"

    /// 以测试配置登记主机连接；同一别名已登记时沿用。
    private static func connection() -> RemoteConnection {
        RemoteConnection.host(host, configuration: RemoteFixture.configuration)
    }

    /// 列目录只列子目录并标出工作区；在测试目录里新建仓库，扫描找到两个仓库。
    @Test("服务器上列目录、新建与扫描")
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
            await RemoteConnection.closeHosts()
            try await fixture.remove()
            throw error
        }

        await RemoteConnection.closeHosts()
        try await fixture.remove()
    }

    /// 克隆在 B 上执行，目标是 B 上的目录；报告的进度来自 stderr，克隆好的是工作区。
    @Test("服务器上克隆")
    func cloneOnServer() async throws {
        let fixture = try await RemoteFixture.create()
        _ = Self.connection()

        do {
            let origin = fixture.root + "/origin.git"
            _ = try await RemoteFixture.raw([
                "git", "-C", fixture.repository, "commit", "--allow-empty", "-q", "-m", "first",
            ])

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
            await RemoteConnection.closeHosts()
            try await fixture.remove()
            throw error
        }

        await RemoteConnection.closeHosts()
        try await fixture.remove()
    }

    /// 选了 LFS 的克隆在 B 上执行：B 的 PATH 里找不到 git-lfs 时在克隆前失败，不建出目标目录；
    /// 找得到 git-lfs、全局配置登记了 LFS 过滤器时，检出的是文件内容。
    @Test("服务器上带 LFS 的克隆")
    func lfsCloneOnServer() async throws {
        let fixture = try await RemoteFixture.create()

        do {
            let directory = try await RemoteFixture.lfsDirectory()
            let origin = try await Self.makeLFSOrigin(in: fixture, directory: directory)
            let destination = fixture.root + "/LFS 克隆"

            let clone = RepositoryClone(
                url: origin,
                destination: .remote(host: Self.host, path: destination),
                options: CloneOptions(lfs: true)
            )

            // 主机连接按别名登记，换配置前先关掉已有的
            await RemoteConnection.closeHosts()
            _ = RemoteConnection.host(
                Self.host,
                configuration: RemoteFixture.lfsConfiguration(searchPath: "/usr/bin:/bin")
            )

            let error = await #expect(throws: HostOperationError.self) {
                _ = try await clone.start().value
            }

            #expect({ if case .lfsUnavailable = error { true } else { false } }())
            _ = try await RemoteFixture.raw(["/bin/test", "!", "-e", destination])

            // 全局配置是测试目录里的文件，只登记 LFS 过滤器
            let global = fixture.root + "/全局.gitconfig"

            for (key, value) in Self.lfsFilters {
                _ = try await RemoteFixture.raw(["git", "config", "--file", global, key, value])
            }

            var configuration = RemoteFixture.lfsConfiguration(searchPath: directory + ":/usr/bin:/bin")
            configuration.remoteEnvironment["GIT_CONFIG_GLOBAL"] = global

            await RemoteConnection.closeHosts()
            _ = RemoteConnection.host(Self.host, configuration: configuration)
            _ = try await clone.start().value

            let content = try await RemoteFixture.raw(["/bin/cat", destination + "/大 文件.bin"])
            #expect(content.standardOutput == Data("LFS 内容\n".utf8))
        } catch {
            await RemoteConnection.closeHosts()
            try await fixture.remove()
            throw error
        }

        await RemoteConnection.closeHosts()
        try await fixture.remove()
    }
}

// MARK: - Steps

extension RemoteHostOperationsTests {
    /// `git lfs install` 写进全局配置的 LFS 过滤器。
    private static let lfsFilters = [
        ("filter.lfs.clean", "git-lfs clean -- %f"),
        ("filter.lfs.smudge", "git-lfs smudge -- %f"),
        ("filter.lfs.process", "git-lfs filter-process"),
        ("filter.lfs.required", "true"),
    ]

    /// 新建仓库并用 LFS 提交一个文件，推到 B 上新建的裸仓库，pre-push 钩子一并上传 LFS 对象；返回裸仓库的路径。
    ///
    /// 仓库路径里不放通配符：git-lfs 推送时把仓库路径当成匹配模式，遇到 `[` 报出语法错误。
    private static func makeLFSOrigin(in fixture: RemoteFixture, directory: String) async throws -> String {
        let source = fixture.root + "/LFS 源"
        let origin = fixture.root + "/origin.git"

        try await RemoteFixture.initializeRepository(at: source)

        _ = try await RemoteFixture.raw([
            "/usr/bin/env", "PATH=" + directory + ":/usr/bin:/bin",
            "/bin/sh", "-c",
            """
            set -e
            cd "$1"
            git lfs install --local >/dev/null
            git lfs track '*.bin' >/dev/null
            printf 'LFS 内容\\n' > '大 文件.bin'
            git add --all
            git commit -q -m LFS
            git -c init.templateDir= init -q --bare -b main "$2"
            git remote add origin "$2"
            git push -q origin main
            """,
            "sh", source, origin,
        ])

        return origin
    }
}
