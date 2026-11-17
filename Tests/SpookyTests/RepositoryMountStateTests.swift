import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryMountStateTests

/// 服务器目录的挂载查找结果按目录记下：查找期间是 “正在查找”，菜单项禁用且不提示；结束后要么是核对过的本机位置，要么是没有挂载。
/// 仓库目录在仓库设置里手动指定了本机目录时只用它。
///
/// 用指向 “服务器” 目录的符号链接模拟挂载卷，执行器直接在本机执行 Git。
@MainActor
struct RepositoryMountStateTests {
    /// 挂载着的仓库得到本机位置，另一个目录没有挂载，不要求重新查找时已有结果保持不变；
    /// 手动指定了本机目录后只用它，卷变化时也不再查找，目录不在时没有位置，清除后照常自动查找；关闭仓库后结果清空。
    @Test("挂载查找结果与手动指定的目录")
    func lookups() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // Git 写出的路径不带符号链接，临时目录同样解析成真实路径
        let resolved = try #require(realpath(directory.path, nil))
        defer { free(resolved) }

        let base = URL(filePath: String(cString: resolved))
        let repository = base.appending(path: "server/仓 库").path
        let missing = base.appending(path: "elsewhere/未挂载").path
        let mount = base.appending(path: "mount")
        let mounted = mount.appending(path: "仓 库").path

        try FileManager.default.createDirectory(atPath: repository, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: mount,
            withDestinationURL: base.appending(path: "server")
        )

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: repository))

        let state = RepositoryMountState()
        state.makeLocator = { _ in RemoteMountLocator(volumes: { [mount] }) }

        state.locate([repository, missing], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .searching)

        await until { state.lookups.values.allSatisfy { $0 != .searching } }

        guard case .found(let found) = state.lookups[repository] else {
            Issue.record("挂载着的仓库没有找到")
            return
        }

        #expect(found.localURL.path == mounted)
        #expect(state.lookups[missing] == .notMounted)

        // 只查还没有结果的目录，已有的结果不回到 “正在查找”
        state.locate([repository], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .found(found))

        try await checkDesignation(state, repository: repository, base: base, runner: runner)
        #expect(state.repositoryMount(of: repository)?.localURL.path == mounted)

        state.reset()
        #expect(state.lookups.isEmpty)
    }

    /// 本机位置按仓库的显示路径记在偏好里：同一路径在不同主机上各记各的，四种方式都原样读回，自动查找记作删掉；
    /// 升级前只在旧键里手动指定过文件夹的仓库读作指定文件夹并迁进新键；Reset User Defaults 之后照样读得到。
    @Test("本机位置的读写、迁移与 Reset 后保留")
    func storedLocations() throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let domain = directory.appending(path: "defaults").path
        let defaults = try #require(UserDefaults(suiteName: domain))

        let repository = RepositoryLocation.remote(host: "spooky-test", path: "/Users/wgy/spooky-test/仓 库")
        let other = RepositoryLocation.remote(host: "spooky-other", path: "/Users/wgy/spooky-test/仓 库")
        let folder = URL(filePath: "/Volumes/spooky-test/仓 库")
        let share = try #require(URL(string: "smb://wgy@127.0.0.1/wgy"))

        #expect(ServerLocalLocation.stored(for: repository, defaults: defaults) == .automatic)

        // 各方式原样读回，另一台主机上的同一路径不受影响
        for location in [
            ServerLocalLocation.smbMount(share: nil),
            .smbMount(share: share),
            .sshfsMount(folder: folder),
            .chosenFolder(folder),
        ] {
            ServerLocalLocation.store(location, for: repository, defaults: defaults)

            #expect(ServerLocalLocation.stored(for: repository, defaults: defaults) == location)
            #expect(ServerLocalLocation.stored(for: other, defaults: defaults) == .automatic)
        }

        ServerLocalLocation.store(.automatic, for: repository, defaults: defaults)
        #expect(defaults.dictionary(forKey: ServerLocalLocation.key)?[repository.displayPath] == nil)

        // 旧键只记手动指定的文件夹；读到时迁成指定文件夹，旧键里的这一项删掉，别的仓库的旧记录留到它被读到
        defaults.set(
            [repository.displayPath: folder.path, other.displayPath: "/Volumes/other"],
            forKey: ServerLocalLocation.legacyKey
        )

        #expect(ServerLocalLocation.stored(for: repository, defaults: defaults) == .chosenFolder(folder))
        #expect(defaults.dictionary(forKey: ServerLocalLocation.legacyKey)?.keys.sorted() == [other.displayPath])

        // Reset 之后新键与还没迁移的旧记录都在
        DeveloperPreferences.removeValues(in: domain, of: defaults, keepingData: true)

        #expect(ServerLocalLocation.stored(for: repository, defaults: defaults) == .chosenFolder(folder))
        #expect(
            ServerLocalLocation.stored(for: other, defaults: defaults) == .chosenFolder(URL(filePath: "/Volumes/other"))
        )
        #expect(defaults.object(forKey: ServerLocalLocation.legacyKey) == nil)
    }
}

// MARK: - Steps

extension RepositoryMountStateTests {
    /// 手动指定了本机目录后仓库目录只用它：自动查找的结果清掉，卷变化时也不再查找；目录不在时没有位置，也不退回自动查找；
    /// 清除后照常自动查找，返回时查找已结束。
    private func checkDesignation(
        _ state: RepositoryMountState,
        repository: String,
        base: URL,
        runner: GitRunner
    ) async throws {
        let chosen = base.appending(path: "chosen/仓 库")
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)

        state.designate(chosen, for: repository)

        #expect(state.lookups[repository] == nil)
        #expect(try #require(state.designation).exists)
        #expect(state.repositoryMount(of: repository)?.localURL.path == chosen.path)

        // 卷变化后的重新查找跳过仓库目录
        state.locate([repository], host: "spooky-test", runner: runner, refreshes: true)
        #expect(state.lookups[repository] == nil)

        // 指定的目录不在（如卷没有挂载）
        state.designate(base.appending(path: "unmounted/仓 库"), for: repository)

        #expect(try !#require(state.designation).exists)
        #expect(state.repositoryMount(of: repository) == nil)

        state.designate(nil, for: repository)
        #expect(state.designation == nil)

        state.locate([repository], host: "spooky-test", runner: runner, refreshes: false)
        #expect(state.lookups[repository] == .searching)

        await until { state.lookups[repository] != .searching }
    }
}
