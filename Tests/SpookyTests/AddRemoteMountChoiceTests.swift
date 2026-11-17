import Foundation
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - AddRemoteMountChoiceTests

/// 添加服务器仓库的挂载选项：主机别名为空时不检测，点开时按别名检测一次，改别名回到不挂载、检测作废；
/// 选 sshfs 要选了能用的文件夹才能提交；仓库打开后记下所选方式并允许询问地挂载，失败只记下原因。
@MainActor
@Suite("添加服务器仓库的挂载选项")
struct AddRemoteMountChoiceTests {
    /// 同一份选择依次核对检测、选项与提交条件。
    @Test("挂载选项的检测、选择与提交条件")
    func choice() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let detections = Mutex<[String]>([])
        let available = Mutex<Set<RemoteMountMethod>>([.smb, .sshfs])
        let gate = AsyncStream<Void>.makeStream()

        let choice = AddRemoteMountChoice()

        // 别名 “slow” 的检测停住，直到放行
        choice.mounter = RemoteMounter(
            methods: { host in
                detections.withLock { $0.append(host) }

                guard host == "slow" else {
                    return available.withLock { $0 }
                }

                for await _ in gate.stream { break }

                return [.smb]
            },
            mountSMB: { _, _, _ in .success(()) },
            mountSSHFS: { _, _, _, _ in .success(()) }
        )

        // 主机别名为空时不检测
        choice.detect()
        #expect(detections.withLock { $0 }.isEmpty)
        #expect(choice.items == [.method(.automatic), .checking])

        // 点开时按别名检测，再点开不再检测，列出可用的方式
        choice.setHost("spooky-test")
        choice.detect()
        await until { choice.methods != nil }
        choice.detect()

        #expect(detections.withLock { $0 } == ["spooky-test"])
        #expect(choice.items == [.method(.automatic), .method(.smbMount), .method(.sshfsMount)])

        try checkSSHFSFolder(choice, in: directory)

        // 改别名回到不挂载、检测作废；检测期间又改了别名时，那次的结果不采用
        choice.setHost("slow")
        #expect(choice.method == .automatic)
        #expect(choice.location == nil)
        #expect(choice.items == [.method(.automatic), .checking])

        choice.detect()
        await until { detections.withLock { $0 }.count == 2 }

        available.withLock { $0 = [] }
        choice.setHost("other")
        gate.continuation.yield()

        // 两种都不可用
        choice.detect()
        await until { choice.methods != nil }

        #expect(detections.withLock { $0 } == ["spooky-test", "slow", "other"])
        #expect(choice.items == [.method(.automatic), .unavailable])
    }

    /// 仓库打开后本机位置记为所选的方式并允许询问地挂载；失败不影响仓库，只记下原因，sshfs 的文件夹不标成能用。
    @Test("仓库打开后记下所选方式并挂载，失败只记原因")
    func mountAfterAdding() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })
        defer { session.close() }

        let asks = Mutex<[String]>([])

        session.mounts.defaults = MemoryDefaults()
        session.mounts.makeLocator = { _ in RemoteMountLocator(volumes: { [] }) }
        session.mounts.mounter = RemoteMounter(
            methods: { _ in [.smb, .sshfs] },
            mountSMB: { _, _, allowsInteraction in
                asks.withLock { $0.append("smb \(allowsInteraction)") }
                return .failure(.smb(status: 2))
            },
            mountSSHFS: { _, _, _, handler in
                asks.withLock { $0.append("sshfs \(handler != nil || RemoteCallbackRequest.allowsInteraction)") }
                return .failure(.sshfs(status: 1, standardError: "read: Connection reset by peer"))
            }
        )

        let location = RepositoryLocation.remote(host: "spooky-test", path: "/srv/repo")
        session.display(location)

        // SMB：允许询问，失败只记下原因
        session.mountAddedRepository(.smbMount(share: nil))
        await until { session.mounts.failure != nil }

        #expect(asks.withLock { $0 } == ["smb true"])
        #expect(session.repository == location)
        #expect(session.mounts.status == .failed(LocalLocationFailure(.smb(status: 2))))
        #expect(ServerLocalLocation.stored(for: location, defaults: session.mounts.defaults) == .smbMount(share: nil))

        // sshfs：记下方式，文件夹没挂上时不能用
        let folder = directory.appending(path: "mnt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        session.mountAddedRepository(.sshfsMount(folder: folder))
        await until { asks.withLock { $0 }.count == 2 && session.mounts.failure != nil }

        #expect(asks.withLock { $0 } == ["smb true", "sshfs true"])
        #expect(!session.mounts.isFolderAvailable)
        #expect(ServerLocalLocation.stored(for: location, defaults: session.mounts.defaults) == .sshfsMount(folder: folder))
    }

    /// 选 sshfs：没选文件夹、文件夹不空时不能提交，空文件夹可以；提示项不可选。
    private func checkSSHFSFolder(_ choice: AddRemoteMountChoice, in directory: URL) throws {
        choice.select(.method(.sshfsMount))
        #expect(!choice.isReady)
        #expect(choice.location == nil)

        let full = directory.appending(path: "full")
        try FileManager.default.createDirectory(at: full, withIntermediateDirectories: true)
        try Data().write(to: full.appending(path: "a"))

        choice.selectMountFolder(full)
        #expect(!choice.isReady)
        #expect(choice.mountFolderProblem == AppLocalization.text("localLocation.notEmpty", HomePath.abbreviated(full.path)))

        let empty = directory.appending(path: "empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        choice.selectMountFolder(empty)
        #expect(choice.isReady)
        #expect(choice.location == .sshfsMount(folder: empty))

        choice.select(.checking)
        #expect(choice.method == .sshfsMount)
    }
}
