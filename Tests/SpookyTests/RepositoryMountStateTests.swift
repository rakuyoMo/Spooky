import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryMountStateTests

/// 服务器目录的挂载查找结果按目录记下：查找期间是 “正在查找”，菜单项禁用且不提示；结束后要么是核对过的本机位置，要么是没有挂载。
/// 仓库目录在仓库设置里手动指定了本机目录时只用它。
///
/// 用指向 “服务器” 目录的符号链接模拟挂载卷，执行器直接在本机执行 Git。
@MainActor
struct RepositoryMountStateTests {
    /// 挂载着的仓库得到本机位置，另一个目录没有挂载；不要求重新查找时已有结果保持不变，关闭仓库后结果清空。
    @Test("按目录记下查找结果")
    func lookups() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-mount-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Git 写出的路径不带符号链接，临时目录同样解析成真实路径
        let resolved = try #require(realpath(directory.path, nil))
        defer { free(resolved) }

        let base = URL(filePath: String(cString: resolved))
        let repository = base.appending(path: "server/仓 库").path
        let missing = base.appending(path: "elsewhere/未挂载").path
        let mount = base.appending(path: "mount")

        try FileManager.default.createDirectory(atPath: repository, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: mount, withDestinationURL: base.appending(path: "server"))

        let runner = GitRunner(
            location: .local(path: repository),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])

        let state = RepositoryMountState()
        state.makeLocator = { _ in RemoteMountLocator(volumes: { [mount] }) }

        state.locate([repository, missing], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .searching)

        try await FileViewsTests.wait {
            state.lookups.values.allSatisfy { $0 != .searching }
        }

        guard case .found(let found) = state.lookups[repository] else {
            Issue.record("挂载着的仓库没有找到")
            return
        }

        #expect(found.localURL.path == mount.appending(path: "仓 库").path)
        #expect(state.lookups[missing] == .notMounted)

        // 只查还没有结果的目录，已有的结果不回到 “正在查找”
        state.locate([repository], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .found(found))

        state.reset()
        #expect(state.lookups.isEmpty)
    }

    /// 手动指定了本机目录后仓库目录只用它：先前自动查找的结果不再采用，卷变化时也不再查找；目录不在时没有位置；清除后照常自动查找。
    @Test("手动指定的目录优先于自动查找")
    func designation() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-mount-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Git 写出的路径不带符号链接，临时目录同样解析成真实路径
        let resolved = try #require(realpath(directory.path, nil))
        defer { free(resolved) }

        let base = URL(filePath: String(cString: resolved))
        let repository = base.appending(path: "server/仓 库").path
        let mount = base.appending(path: "mount")
        let chosen = base.appending(path: "chosen/仓 库")
        let gone = base.appending(path: "unmounted/仓 库")

        try FileManager.default.createDirectory(atPath: repository, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: mount, withDestinationURL: base.appending(path: "server"))

        let runner = GitRunner(
            location: .local(path: repository),
            environment: .inherit.updating([
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null",
                "GIT_CONFIG_NOSYSTEM": "1",
            ])
        )
        _ = try await runner.run(["-c", "init.templateDir=", "init", "-q", "-b", "main"])

        let state = RepositoryMountState()
        state.makeLocator = { _ in RemoteMountLocator(volumes: { [mount] }) }

        state.locate([repository], host: "spooky-test", runner: runner, refreshes: false)

        try await FileViewsTests.wait {
            state.lookups[repository] != .searching
        }

        #expect(state.repositoryMount(of: repository)?.localURL.path == mount.appending(path: "仓 库").path)

        // 指定之后只用指定的目录，自动查找的结果清掉
        state.designate(chosen, for: repository)
        #expect(state.lookups[repository] == nil)
        #expect(try #require(state.designation).exists)
        #expect(state.repositoryMount(of: repository)?.localURL.path == chosen.path)

        // 卷变化后的重新查找跳过仓库目录
        state.locate([repository], host: "spooky-test", runner: runner, refreshes: true)
        #expect(state.lookups[repository] == nil)

        // 指定的目录不在（如卷没有挂载）时没有位置，也不退回自动查找
        state.designate(gone, for: repository)
        #expect(try !#require(state.designation).exists)
        #expect(state.repositoryMount(of: repository) == nil)

        // 清除后照常自动查找
        state.designate(nil, for: repository)
        #expect(state.designation == nil)

        state.locate([repository], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .searching)

        try await FileViewsTests.wait {
            state.lookups[repository] != .searching
        }

        #expect(state.repositoryMount(of: repository)?.localURL.path == mount.appending(path: "仓 库").path)
    }

    /// 手动指定的本机目录按仓库的显示路径记在偏好里：同一路径在不同主机上各记各的，清除后读不到。
    @Test("记下与清除手动指定的目录")
    func storedFolders() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-local-folders-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/仓 库")
        let other = RepositoryLocation.remote(host: "spooky-other", path: "/Users/wgy/spooky-test/仓 库")
        let folder = URL(filePath: "/Volumes/spooky-test/仓 库")

        #expect(ServerLocalFolders.folder(for: repository, in: defaults) == nil)

        ServerLocalFolders.set(folder, for: repository, in: defaults)
        #expect(ServerLocalFolders.folder(for: repository, in: defaults)?.path == folder.path)
        #expect(ServerLocalFolders.folder(for: other, in: defaults) == nil)

        ServerLocalFolders.set(nil, for: repository, in: defaults)
        #expect(ServerLocalFolders.folder(for: repository, in: defaults) == nil)
    }
}
