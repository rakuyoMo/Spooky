import AppKit
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Show in Finder

extension RepositoryMountStateTests {
    /// 没连上 B 时先写 “正在连接”：这一次没连上时错误区写出原因，连上后继续；查找不沿用之前 “没有挂载” 的结果。
    @Test("Show in Finder：先连接，连不上时报错，连上后重新查找")
    func showInFinderConnecting() async throws {
        // 换步骤的动画要读应用的模态窗口
        _ = NSApplication.shared

        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let state = Self.makeState(site: site)
        let location = RepositoryLocation.remote(host: "spooky-test", path: site.repository)

        state.load(.automatic, for: location, mountsInBackground: false)

        // 连不上：错误区用这一次的失败
        let failure = AppFailure(error: RemoteConnectionError(.unavailable), opening: false, location: location)

        let unreachable = ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository],
            isConnected: false
        ) { .failed(failure) }

        #expect(unreachable.progress == AppLocalization.text("action.revealFinder.connecting", "spooky-test"))
        #expect(await unreachable.run() == nil)
        #expect(Self.failure(of: unreachable)?.id == failure.id)

        // 之前查过、没有挂载；之后卷挂上了，但这台 Mac 没发出通知
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: false)
        await state.waitForSearch(of: site.repository)
        #expect(state.status == .notMounted)

        site.volumes.withLock { $0 = [site.mount] }

        // 连接放行之前一直是 “正在连接”，连上后重新查找，找到挂载
        let gate = AsyncStream<Void>.makeStream()

        let flow = ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository + "/a b.txt"],
            isConnected: false
        ) {
            for await _ in gate.stream { break }

            return .connected(site.runner)
        }

        let running = Task { await flow.run() }
        #expect(flow.progress == AppLocalization.text("action.revealFinder.connecting", "spooky-test"))

        gate.continuation.yield()

        #expect(await running.value?.map(\.path) == [site.mounted + "/a b.txt"])
    }

    /// 查找已在进行时等它的结果，不另查一次；后台挂载已在进行时等它挂上，不再挂第二次。
    @Test("Show in Finder：查找或挂载进行中时等它的结果")
    func showInFinderWaiting() async throws {
        // 换步骤的动画要读应用的模态窗口
        _ = NSApplication.shared

        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let state = Self.makeState(site: site)
        let location = RepositoryLocation.remote(host: "spooky-test", path: site.repository)

        state.load(.automatic, for: location, mountsInBackground: false)
        site.volumes.withLock { $0 = [site.mount] }

        // 查找停在取卷列表的地方，直到放行
        let searches = Mutex(0)
        let release = AsyncStream<Void>.makeStream()

        state.makeLocator = { _ in
            RemoteMountLocator(volumes: {
                searches.withLock { $0 += 1 }

                for await _ in release.stream { break }

                return site.volumes.withLock { $0 }
            })
        }

        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: true)

        let searching = ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository],
            isConnected: false
        ) { .connected(site.runner) }

        let found = Task { await searching.run() }

        // 换到 “正在查找” 时流程已在等那一次查找
        await until { searching.progress == AppLocalization.text("localLocation.searching") }
        release.continuation.yield()

        #expect(await found.value?.map(\.path) == [site.mounted])
        #expect(searches.withLock { $0 } == 1)

        try await Self.checkWaitingForMount(state, site: site, location: location)
    }

    /// 自动查找没找到、指定的文件夹不在时换成表单，说明前面写原因；表单改回自动查找后等那次查找结束再打开。
    /// 方式是 SMB 挂载时允许询问地挂载，失败时换成表单，错误区写出原因与原始输出；挂载期间取消后不换成表单，设置不变。
    @Test("Show in Finder：换成表单与取消")
    func showInFinderForm() async throws {
        // 换步骤的动画要读应用的模态窗口
        _ = NSApplication.shared

        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let state = Self.makeState(site: site)
        let location = RepositoryLocation.remote(host: "spooky-test", path: site.repository)

        state.load(.automatic, for: location, mountsInBackground: false)

        // 自动查找没找到
        let notMounted = Self.connectedFlow(state, site: site)

        #expect(await notMounted.run() == nil)

        let form = try #require(Self.form(of: notMounted))
        #expect(form.reason == AppLocalization.text("action.revealFinder.notMounted", location.displayPath))
        #expect(form.error == nil)

        // 表单保存自动查找，等保存后开始的查找结束再打开
        site.volumes.withLock { $0 = [site.mount] }

        #expect(await form.submit())
        #expect(await notMounted.savedLocation()?.map(\.path) == [site.mounted])

        // 指定的文件夹不在
        let missing = directory.appending(path: "不在")
        state.apply(.chosenFolder(missing))

        let folderMissing = Self.connectedFlow(state, site: site)
        #expect(await folderMissing.run() == nil)

        #expect(
            Self.form(of: folderMissing)?.reason
                == AppLocalization.text("action.revealFinder.folderMissing", HomePath.abbreviated(missing.path))
        )

        try await Self.checkMountFailure(state, site: site, location: location)
    }
}

// MARK: - Show in Finder Steps

extension RepositoryMountStateTests {
    /// 后台挂载已在进行：流程等它挂上，直接得到位置，SMB 只挂了一次。
    private static func checkWaitingForMount(
        _ state: RepositoryMountState,
        site: Site,
        location: RepositoryLocation
    ) async throws {
        let mounts = Mutex(0)
        let release = AsyncStream<Void>.makeStream()

        // 卷推出后重新查过，没有挂载
        site.volumes.withLock { $0 = [] }
        state.makeLocator = { _ in RemoteMountLocator(volumes: { site.volumes.withLock { $0 } }) }
        state.locate([site.repository], host: "spooky-test", runner: site.runner, refreshes: true)
        await state.waitForSearch(of: site.repository)

        // SMB 挂载停住，放行后卷出现
        state.mounter = RemoteMounter(
            methods: { _ in [.smb] },
            mountSMB: { _, _, _ in
                mounts.withLock { $0 += 1 }

                for await _ in release.stream { break }

                site.volumes.withLock { $0 = [site.mount] }

                return .success(())
            },
            mountSSHFS: { _, _, _, _ in .failure(.launch("sshfs")) }
        )

        state.load(.smbMount(share: nil), for: location, mountsInBackground: false)

        let background = Task {
            await state.mountRepository(host: "spooky-test", runner: site.runner, interactive: false)
        }

        await until { state.isMounting }

        let flow = ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository],
            isConnected: false
        ) { .connected(site.runner) }

        let found = Task { await flow.run() }

        // 换到 “正在查找” 时流程已在等那一次挂载
        await until { flow.progress == AppLocalization.text("localLocation.searching") }
        release.continuation.yield()

        #expect(await found.value?.map(\.path) == [site.mounted])
        #expect(mounts.withLock { $0 } == 1)

        await background.value
    }

    /// SMB 挂载失败：挂载允许询问，失败后换成表单，错误区写出原因与原始输出；挂载期间取消后不换成表单，偏好不变。
    private static func checkMountFailure(
        _ state: RepositoryMountState,
        site: Site,
        location: RepositoryLocation
    ) async throws {
        let asks = Mutex<[Bool]>([])
        let release = AsyncStream<Void>.makeStream()

        site.volumes.withLock { $0 = [] }

        // 第一次立即失败，之后等放行再失败
        state.mounter = RemoteMounter(
            methods: { _ in [.smb] },
            mountSMB: { _, _, allowsInteraction in
                let count = asks.withLock { calls in
                    calls.append(allowsInteraction)
                    return calls.count
                }

                if count > 1 {
                    for await _ in release.stream { break }
                }

                return .failure(.smb(status: 2))
            },
            mountSSHFS: { _, _, _, _ in .failure(.launch("sshfs")) }
        )

        ServerLocalLocation.store(.smbMount(share: nil), for: location, defaults: state.defaults)
        state.apply(.smbMount(share: nil))

        let failing = connectedFlow(state, site: site)
        #expect(await failing.run() == nil)

        let form = try #require(form(of: failing))
        #expect(asks.withLock { $0 } == [true])
        #expect(form.method == .smbMount)
        #expect(form.reason == nil)
        #expect(form.error == LocalLocationFailure(.smb(status: 2)).message)

        // 挂载期间取消：挂载照常结束，不换成表单
        let cancelled = connectedFlow(state, site: site)
        let running = Task { await cancelled.run() }

        await until { cancelled.progress == AppLocalization.text("localLocation.mounting") }

        cancelled.cancel()
        release.continuation.yield()

        #expect(await running.value == nil)
        #expect(cancelled.progress == AppLocalization.text("localLocation.mounting"))
        #expect(ServerLocalLocation.stored(for: location, defaults: state.defaults) == .smbMount(share: nil))
    }

    /// 已经连着 B 的流程，选中仓库目录。
    static func connectedFlow(_ state: RepositoryMountState, site: Site) -> ShowInFinderFlow {
        ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository],
            isConnected: true
        ) { .connected(site.runner) }
    }

    /// 流程换成的本机位置表单；没有换成表单时为 nil。
    static func form(of flow: ShowInFinderFlow) -> LocalLocationForm? {
        guard case .form(let form) = flow.step else {
            return nil
        }

        return form
    }

    /// 流程显示的连接失败；不是连接失败时为 nil。
    private static func failure(of flow: ShowInFinderFlow) -> AppFailure? {
        guard case .failed(let failure) = flow.step else {
            return nil
        }

        return failure
    }
}
