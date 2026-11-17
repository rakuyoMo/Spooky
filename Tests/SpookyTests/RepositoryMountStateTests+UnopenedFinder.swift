import AppKit
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Show in Finder Without Session

extension RepositoryMountStateTests {
    /// 仓库管理与最近克隆没有打开的会话：指定的文件夹在、或 sshfs 挂载到的文件夹正挂着时不经连接就有位置；
    /// sheet 或表单取消后，等已开始的连接与挂载结束才收尾，收尾只做一次；仓库在流程期间关闭时 sheet 随之关闭。
    @Test("仓库管理的 Show in Finder：不经连接的位置与流程结束后的收尾")
    func showInFinderWithoutSession() async throws {
        // 换步骤的动画要读应用的模态窗口
        _ = NSApplication.shared

        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let location = RepositoryLocation.remote(host: "spooky-test", path: site.repository)

        // 指定的文件夹在：不查找也不连接就有位置
        let chosen = Self.makeState(site: site)
        chosen.load(.chosenFolder(directory), for: location, mountsInBackground: false)
        await chosen.checkFolder()
        #expect(chosen.repositoryMount()?.localURL == directory)

        // sshfs 挂载到的文件夹没挂着时没有位置，是卷的根时有
        let sshfs = Self.makeState(site: site)
        sshfs.load(.sshfsMount(folder: directory), for: location, mountsInBackground: false)
        await sshfs.checkFolder()
        #expect(sshfs.repositoryMount() == nil)

        let root = URL(filePath: "/")
        sshfs.apply(.sshfsMount(folder: root))
        await sshfs.checkFolder()
        #expect(sshfs.repositoryMount()?.localURL == root)

        // 同一个文件夹先没挂着、之后挂上卷：再查看时是卷的根；先卸下再核对，核对失败也不留下挂载
        let image = directory.appending(path: "volume.dmg")
        let volume = directory.appending(path: "volume")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: false)

        sshfs.apply(.sshfsMount(folder: volume))
        await sshfs.checkFolder()
        let unmounted = sshfs.repositoryMount()

        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/hdiutil",
            processArguments: [
                "create", "-quiet", "-size", "1m", "-fs", "HFS+", "-volname", "Spooky",
                image.path,
            ]
        )

        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/hdiutil",
            processArguments: [
                "attach", "-quiet", "-nobrowse", "-noautoopen",
                "-mountpoint", volume.path,
                image.path,
            ]
        )

        await sshfs.checkFolder()
        let mounted = sshfs.repositoryMount()?.localURL

        _ = try await CommandExecutor.execute(
            executable: "/usr/bin/hdiutil",
            processArguments: ["detach", "-quiet", volume.path]
        )

        #expect(unmounted == nil)
        #expect(mounted == volume)

        await Self.checkFinishAfterCancel(site: site, location: location)
        try await Self.checkFinishAfterForm(site: site, location: location)
        await Self.checkEndAfterClose(site: site, location: location)
    }
}

// MARK: - Show in Finder Finish Steps

extension RepositoryMountStateTests {
    /// sheet 在连接期间取消：连接结束后才收尾，之后不再查找；sheet 关闭报了两次也只收尾一次。
    private static func checkFinishAfterCancel(site: Site, location: RepositoryLocation) async {
        let state = makeState(site: site)
        state.load(.automatic, for: location, mountsInBackground: false)

        let gate = AsyncStream<Void>.makeStream()
        let connected = Mutex(false)

        let flow = ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository],
            isConnected: false
        ) {
            for await _ in gate.stream { break }

            connected.withLock { $0 = true }
            return .connected(site.runner)
        }

        // 收尾时记下连接是否已经结束
        let finishes = Mutex<[Bool]>([])
        flow.onFinish = { finishes.withLock { $0.append(connected.withLock { $0 }) } }

        flow.start(reveal: { _ in }, end: { })
        flow.cancel()
        flow.closed()
        flow.closed()

        gate.continuation.yield()
        await until { !finishes.withLock { $0 }.isEmpty }

        #expect(finishes.withLock { $0 } == [true])
        #expect(state.lookups[site.repository] == nil)
    }

    /// 表单在挂载期间取消：挂载结束后才收尾。
    private static func checkFinishAfterForm(site: Site, location: RepositoryLocation) async throws {
        let state = makeState(site: site)
        let mounted = Mutex(false)
        let release = AsyncStream<Void>.makeStream()

        state.mounter = RemoteMounter(
            methods: { _ in [.smb] },
            mountSMB: { _, _, _ in
                for await _ in release.stream { break }

                mounted.withLock { $0 = true }
                return .failure(.smb(status: 2))
            },
            mountSSHFS: { _, _, _, _ in .failure(.launch("sshfs")) }
        )

        state.load(.automatic, for: location, mountsInBackground: false)

        let flow = connectedFlow(state, site: site)
        let finishes = Mutex<[Bool]>([])
        flow.onFinish = { finishes.withLock { $0.append(mounted.withLock { $0 }) } }

        // 自动查找没找到，换成表单；表单改成 SMB 挂载，挂载停住时取消表单
        flow.start(reveal: { _ in }, end: { })
        await until { form(of: flow) != nil }

        let form = try #require(form(of: flow))
        form.method = .smbMount

        let submitting = Task { await form.submit() }
        await until { form.progress != nil }

        form.cancel()
        flow.formClosed(saved: false) { _ in }
        flow.closed()

        release.continuation.yield()
        await until { !finishes.withLock { $0 }.isEmpty }

        #expect(finishes.withLock { $0 } == [true])
        #expect(await !submitting.value)
    }

    /// 连接期间仓库关闭：流程不换成表单，sheet 随之关闭。
    private static func checkEndAfterClose(site: Site, location: RepositoryLocation) async {
        let state = makeState(site: site)
        state.load(.automatic, for: location, mountsInBackground: false)

        let gate = AsyncStream<Void>.makeStream()

        let flow = ShowInFinderFlow(
            mounts: state,
            host: "spooky-test",
            paths: [site.repository],
            isConnected: false
        ) {
            for await _ in gate.stream { break }

            return .connected(site.runner)
        }

        let ended = Mutex(false)
        flow.start(reveal: { _ in }, end: { ended.withLock { $0 = true } })

        state.reset()
        gate.continuation.yield()

        await until { ended.withLock { $0 } }
        #expect(form(of: flow) == nil)
    }
}
