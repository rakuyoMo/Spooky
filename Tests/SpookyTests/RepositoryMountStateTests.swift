import Foundation
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryMountStateTests

/// 服务器仓库在这台 Mac 上的位置：其它目录与自动查找、SMB 挂载时的仓库目录按目录记下查找结果，查找期间是 “正在查找”，
/// 结束后要么是核对过的本机位置，要么是没有挂载；本机位置带文件夹时仓库目录只用那个文件夹。
///
/// 用指向 “服务器” 目录的符号链接模拟挂载卷，执行器直接在本机执行 Git，挂载由注入的实现代替。
@MainActor
struct RepositoryMountStateTests {
    /// 挂载着的仓库得到本机位置，没有挂载的目录在重新连上 B 后重查；不要求重新查找时已有结果保持不变；
    /// 指定了文件夹后只用它，卷变化时也不再查找，文件夹不在时没有位置，改回自动查找后照常查找；关闭仓库后结果清空。
    @Test("查找结果、重连后重查与指定文件夹")
    func lookups() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let state = Self.makeState(site: site)

        state.load(.automatic, for: .remote(host: "spooky-test", path: site.repository), mountsInBackground: false)

        // 卷还没挂上：查找期间是 “正在查找”，结束后没有挂载
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: false)
        #expect(state.status == .searching)

        await until { state.status == .notMounted }

        // 重新连上 B 后，没有挂载的目录重新查找
        site.volumes.withLock { $0 = [site.mount] }
        state.relocateUnmounted()
        #expect(state.lookups[site.repository] == .searching)

        await until { state.lookups[site.repository] != .searching }

        let found = try #require(state.repositoryMount())
        #expect(found.localURL.path == site.mounted)
        #expect(state.status == .available(found.localURL))

        // 只查还没有结果的目录，已有的结果不回到 “正在查找”
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: false)
        #expect(state.lookups[site.repository] == .found(found))

        try await Self.checkChosenFolder(state, site: site, base: directory)

        state.reset()
        #expect(state.lookups.isEmpty)
        #expect(state.status == .unknown)
    }

    /// 打开仓库后的后台挂载只做一次，不允许系统界面也不询问口令：SMB 等查找确认没有挂着再挂记下的共享，挂上后记下位置；
    /// sshfs 失败只记下原因，偏好里的本机位置不变。
    @Test("后台挂载只做一次、不询问，失败只记原因")
    func backgroundMount() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let state = Self.makeState(site: site)
        let calls = Mutex<[String]>([])

        // SMB “挂上” 时卷出现；sshfs 总是失败。记下每次挂载是否允许界面
        state.mounter = RemoteMounter(
            methods: { _ in [.smb, .sshfs] },
            mountSMB: { _, _, allowsInteraction in
                let asks = allowsInteraction || RemoteCallbackRequest.allowsInteraction
                calls.withLock { $0.append("smb \(asks)") }
                site.volumes.withLock { $0 = [site.mount] }

                return .success(())
            },
            mountSSHFS: { _, _, _, handler in
                calls.withLock { $0.append("sshfs \(handler != nil || RemoteCallbackRequest.allowsInteraction)") }

                return .failure(.sshfs(status: 1, standardError: "read: Connection reset by peer"))
            }
        )

        let location = RepositoryLocation.remote(host: "spooky-test", path: site.repository)
        let share = try #require(URL(string: "smb://wgy@127.0.0.1/wgy"))

        // SMB：查找结束没有挂着，挂上记下的共享后找到仓库
        state.load(.smbMount(share: share), for: location, mountsInBackground: true)
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: false)
        state.mountInBackground(host: "spooky-test", runner: site.runner)

        await until { state.status == .available(URL(filePath: site.mounted)) && !state.isMounting }

        #expect(calls.withLock { $0 } == ["smb false"])
        #expect(ServerLocalLocation.stored(for: location, defaults: state.defaults) == .smbMount(share: share))

        // 已经做过的后台挂载不再做
        state.mountInBackground(host: "spooky-test", runner: site.runner)
        #expect(calls.withLock { $0.count } == 1)

        // sshfs：失败只记下原因
        let folder = directory.appending(path: "mnt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        state.load(.sshfsMount(folder: folder), for: location, mountsInBackground: true)
        state.mountInBackground(host: "spooky-test", runner: site.runner)

        await until { state.failure != nil }

        #expect(calls.withLock { $0 } == ["smb false", "sshfs false"])
        #expect(state.status == .failed(LocalLocationFailure(reason: "read: Connection reset by peer")))
        #expect(ServerLocalLocation.stored(for: location, defaults: state.defaults) == .smbMount(share: share))
    }

    /// 服务器仓库不能直接打开时，Show in Finder 的提示写原因：还没有查找结果是没有连上，没有挂载、Spooky 挂载失败与指定的文件夹不在各写各的；
    /// 能直接打开时没有提示，位置在那个文件夹里。
    @Test("Show in Finder 的提示按本机位置的状态写原因")
    func finderTips() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })
        defer { session.close() }

        session.mounts.defaults = MemoryDefaults()
        session.mounts.makeLocator = { _ in RemoteMountLocator(volumes: { [] }) }
        session.display(.remote(host: "spooky-test", path: "/srv/仓 库"))

        let mounts = session.mounts
        let runner = try #require(session.runner)

        // 还没有查找结果
        #expect(mounts.unavailableReason == AppLocalization.text("action.revealFinder.notConnected", "spooky-test"))

        // 查找结束，没有挂载
        mounts.locate(["/srv/仓 库"], host: "spooky-test", runner: runner, refreshes: false)
        await until { mounts.status == .notMounted }

        #expect(
            mounts.unavailableReason == AppLocalization.text("action.revealFinder.notMounted", "spooky-test:/srv/仓 库")
        )

        // Spooky 上次挂载失败
        mounts.setMounting(nil, failure: LocalLocationFailure(reason: "mount_smbfs: server connection failed"))
        #expect(mounts.unavailableReason == "mount_smbfs: server connection failed")

        // 指定的文件夹不在
        let missing = directory.appending(path: "不在")
        mounts.apply(.chosenFolder(missing))

        #expect(
            mounts.unavailableReason
                == AppLocalization.text("action.revealFinder.folderMissing", HomePath.abbreviated(missing.path))
        )

        // 指定的文件夹在：能直接打开
        mounts.apply(.chosenFolder(directory))

        #expect(mounts.unavailableReason == nil)
        #expect(session.finderURL("a b.txt") == directory.appending(path: "a b.txt"))
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
    /// 模拟的现场：B 上的仓库目录、指向 “服务器” 的挂载卷与可以随时挂上的卷列表。
    final class Site: Sendable {
        /// B 上的仓库目录。
        let repository: String

        /// 模拟的挂载卷。
        let mount: URL

        /// 经挂载卷看到的仓库目录。
        let mounted: String

        /// 仓库的执行器。
        let runner: GitRunner

        /// 这台 Mac 现在挂着的卷，开始时为空。
        let volumes = Mutex<[URL]>([])

        /// 建出现场。
        init(repository: String, mount: URL, runner: GitRunner) {
            self.repository = repository
            self.mount = mount
            self.runner = runner
            mounted = mount.appending(path: "仓 库").path
        }
    }

    /// 在临时目录里建出 B 上的仓库与指向它的挂载卷；Git 写出的路径不带符号链接，临时目录同样解析成真实路径。
    static func makeSite(in directory: URL) async throws -> Site {
        let resolved = try #require(realpath(directory.path, nil))
        defer { free(resolved) }

        let base = URL(filePath: String(cString: resolved))
        let repository = base.appending(path: "server/仓 库").path
        let mount = base.appending(path: "mount")

        try FileManager.default.createDirectory(atPath: repository, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: mount, withDestinationURL: base.appending(path: "server"))

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: repository))

        return Site(repository: repository, mount: mount, runner: runner)
    }

    /// 在给定卷里查找、偏好只在内存里的状态。
    static func makeState(site: Site) -> RepositoryMountState {
        let state = RepositoryMountState()
        state.defaults = MemoryDefaults()
        state.makeLocator = { _ in RemoteMountLocator(volumes: { site.volumes.withLock { $0 } }) }

        return state
    }

    /// 指定了文件夹后仓库目录只用它：自动查找的结果清掉，卷变化时也不再查找；文件夹不在时没有位置，也不退回自动查找；
    /// 改回自动查找后照常查找，返回时查找已结束。
    private static func checkChosenFolder(_ state: RepositoryMountState, site: Site, base: URL) async throws {
        let chosen = base.appending(path: "chosen/仓 库")
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)

        state.apply(.chosenFolder(chosen))

        #expect(state.lookups[site.repository] == nil)
        #expect(state.status == .available(chosen))
        #expect(state.repositoryMount()?.localURL == chosen)

        // 卷变化后的重新查找跳过仓库目录
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: true)
        #expect(state.lookups[site.repository] == nil)

        // 指定的文件夹不在（如卷没有挂载）
        let unmounted = base.appending(path: "unmounted/仓 库")
        state.apply(.chosenFolder(unmounted))

        #expect(state.status == .folderMissing(unmounted))
        #expect(state.repositoryMount() == nil)

        state.apply(.automatic)
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: false)
        #expect(state.status == .searching)

        await until { state.lookups[site.repository] != .searching }
    }
}
