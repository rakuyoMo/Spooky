import Foundation
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - LocalLocationFormTests

/// 本机位置对话框的表单：方式菜单按检测结果列出挂载方式，主按钮与必填项随方式变化；
/// 挂载或核对失败时不关、设置不变，取消后结果不再采用，通过后记下本机位置。
///
/// 仓库在本机临时目录里，执行器直接在本机执行 Git，挂载由注入的实现代替，不挂 sheet。
@MainActor
struct LocalLocationFormTests {
    /// 检测中挂载方式的位置是一个 “正在检测”，检测后只列出可用的，现在的方式即使不可用也列出；
    /// 挂载方式的主按钮是 Mount，其余是 Save；sshfs 挂载与指定文件夹没选文件夹时不能提交，挂载文件夹不空时说明原因。
    @Test("方式菜单、主按钮与必填项")
    func methodsAndRequiredFields() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        site.mounts.mounter = Self.mounter(methods: [.sshfs])

        let form = LocalLocationForm(mounts: site.mounts, host: "spooky-test", runner: site.runner)

        // 检测前与检测后的菜单
        #expect(form.items == [.method(.automatic), .checking, .method(.chosenFolder)])

        await form.detect()
        #expect(form.items == [.method(.automatic), .method(.sshfsMount), .method(.chosenFolder)])

        // 自动查找
        #expect(form.submitTitle == AppLocalization.text("localLocation.save"))
        #expect(form.canSubmit)

        // sshfs 挂载：没选文件夹、选了不空的文件夹都不能提交
        form.method = .sshfsMount
        #expect(form.submitTitle == AppLocalization.text("localLocation.mount"))
        #expect(!form.canSubmit)

        form.selectMountFolder(directory)
        #expect(form.error == AppLocalization.text("localLocation.notEmpty", HomePath.abbreviated(directory.path)))
        #expect(!form.canSubmit)

        let empty = directory.appending(path: "空")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        form.selectMountFolder(empty)
        #expect(form.error == nil)
        #expect(form.canSubmit)

        // 指定文件夹：没选时不能提交
        form.method = .chosenFolder
        #expect(form.submitTitle == AppLocalization.text("localLocation.save"))
        #expect(!form.canSubmit)

        // 现在的方式是 SMB 挂载时，即使检测不到也列出
        site.mounts.apply(.smbMount(share: nil))

        let smb = LocalLocationForm(mounts: site.mounts, host: "spooky-test", runner: site.runner)
        await smb.detect()

        #expect(smb.items == [.method(.automatic), .method(.smbMount), .method(.sshfsMount), .method(.chosenFolder)])
        #expect(smb.submitTitle == AppLocalization.text("localLocation.mount"))
    }

    /// 挂载失败时错误区写出原因，偏好与这次运行里的本机位置都不变；取消后挂载照常结束，结果不再采用；
    /// 指定的文件夹没通过核对时说明原因，通过后记下；改回自动查找后记作删掉并重新查找。
    @Test("挂载失败与取消不改设置，通过后记下")
    func submitting() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let site = try await Self.makeSite(in: directory)
        let gate = AsyncStream<Void>.makeStream()
        let empty = directory.appending(path: "mnt")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        // 第一次挂载失败，第二次等放行后 “挂上”
        let attempts = Mutex(0)

        site.mounts.mounter = RemoteMounter(
            methods: { _ in [.sshfs] },
            mountSMB: { _, _, _ in .failure(.smb(status: 2)) },
            mountSSHFS: { _, _, _, _ in
                let attempt = attempts.withLock { count in
                    count += 1
                    return count
                }

                guard attempt > 1 else {
                    return .failure(.sshfs(status: 1, standardError: "read: Connection reset by peer"))
                }

                for await _ in gate.stream { break }

                return .success(())
            }
        )

        let form = LocalLocationForm(mounts: site.mounts, host: "spooky-test", runner: site.runner)
        form.method = .sshfsMount
        form.selectMountFolder(empty)

        // 挂载失败
        #expect(await !form.submit())
        #expect(form.error == "read: Connection reset by peer")
        #expect(form.progress == nil)
        #expect(site.mounts.location == .automatic)
        #expect(site.stored == .automatic)

        // 挂载期间取消
        let submitting = Task { await form.submit() }
        await until { form.progress != nil }

        #expect(form.progress == AppLocalization.text("localLocation.mounting"))

        form.cancel()
        gate.continuation.yield()

        #expect(await !submitting.value)
        #expect(site.mounts.location == .automatic)
        #expect(site.stored == .automatic)

        try await Self.checkChosenFolder(site: site, base: directory)
    }
}

// MARK: - Steps

extension LocalLocationFormTests {
    /// 本机临时目录里的服务器仓库现场。
    private struct Site {
        /// 仓库的本机位置状态，偏好只在内存里。
        let mounts: RepositoryMountState

        /// 仓库的执行器。
        let runner: GitRunner

        /// 仓库目录。
        let repository: URL

        /// 偏好里记下的本机位置。
        @MainActor
        var stored: ServerLocalLocation {
            ServerLocalLocation.stored(for: mounts.repository ?? .local(path: ""), defaults: mounts.defaults)
        }
    }

    /// 在临时目录里建出仓库，状态按服务器仓库读入自动查找，查找时没有挂着的卷。
    private static func makeSite(in directory: URL) async throws -> Site {
        let repository = directory.appending(path: "仓 库")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: repository.path))

        let mounts = RepositoryMountState()
        mounts.defaults = MemoryDefaults()
        mounts.makeLocator = { _ in RemoteMountLocator(volumes: { [] }) }
        mounts.load(.automatic, for: .remote(host: "spooky-test", path: repository.path), mountsInBackground: false)

        return Site(mounts: mounts, runner: runner, repository: repository)
    }

    /// 只给出检测结果、从不挂上的挂载实现。
    private static func mounter(methods: Set<RemoteMountMethod>) -> RemoteMounter {
        RemoteMounter(
            methods: { _ in methods },
            mountSMB: { _, _, _ in .failure(.smb(status: 2)) },
            mountSSHFS: { _, _, _, _ in .failure(.launch("sshfs")) }
        )
    }

    /// 指定文件夹：不是这个仓库时说明原因、设置不变，是时记下；改回自动查找后偏好里删掉，仓库目录重新查找。
    private static func checkChosenFolder(site: Site, base: URL) async throws {
        let form = LocalLocationForm(mounts: site.mounts, host: "spooky-test", runner: site.runner)
        let elsewhere = base.appending(path: "elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)

        form.method = .chosenFolder
        form.chosenFolder = elsewhere

        #expect(await !form.submit())
        #expect(form.error?.contains(HomePath.abbreviated(elsewhere.path)) ?? false)
        #expect(site.stored == .automatic)

        form.chosenFolder = site.repository

        #expect(await form.submit())
        #expect(site.stored == .chosenFolder(site.repository))
        #expect(site.mounts.status == .available(site.repository))

        // 改回自动查找
        let automatic = LocalLocationForm(mounts: site.mounts, host: "spooky-test", runner: site.runner)
        automatic.method = .automatic

        #expect(await automatic.submit())
        #expect(site.stored == .automatic)
        #expect(site.mounts.lookups[site.repository.path] == .searching)

        await site.mounts.waitForSearch(of: site.repository.path)
    }
}
