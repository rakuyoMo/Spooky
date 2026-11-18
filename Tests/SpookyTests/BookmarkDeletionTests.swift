import Darwin
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - BookmarkDeletionTests

/// 仓库管理里删除书签与分组：要不要询问、询问的内容，以及勾选后把仓库文件夹移进废纸篓。
///
/// 移动经可以替换的入口核对，测试换成记录调用的闭包，不往真实的废纸篓里放东西，家目录换成临时目录。
@MainActor
struct BookmarkDeletionTests {
    /// 记下替换入口收到的调用。
    @MainActor
    private final class TrashRecorder {
        /// 交给本机入口的目录。
        var local: [URL] = []

        /// 交给服务器入口的仓库。
        var remote: [RepositoryLocation] = []

        /// 本机入口被调用时，克隆是否还在进行。
        var cloneRunning: [Bool] = []
    }

    /// 只剩空分组与目录已不存在的本机仓库时直接删除；有服务器仓库或目录还在的本机仓库时询问，单项与多选相同。
    /// 询问里勾选框的个数与两种说明；不勾选只移除书签，不移动任何文件夹。
    @Test("删除书签与分组：要不要询问与询问的内容")
    func prompts() throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let present = try Self.makeDirectory("present", in: directory)
        let other = try Self.makeDirectory("other", in: directory)
        let recorder = TrashRecorder()

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        manager.folderTrash = Self.trash(home: directory.appending(path: "home"), recorder: recorder)

        // 空分组、只有空子分组的分组、只有目录已不存在的仓库的分组
        let empty = bookmarks.addFolder(named: "Empty")
        let nested = bookmarks.addFolder(named: "Nested")
        bookmarks.addFolder(named: "Inner", into: nested)
        let gone = bookmarks.addFolder(named: "Gone")
        bookmarks.add(.local(path: directory.appending(path: "gone").path), into: gone)

        // 有目录还在的本机仓库、有服务器仓库
        let local = bookmarks.add(.local(path: present.path))
        let mixed = bookmarks.addFolder(named: "Mixed")
        bookmarks.add(.local(path: other.path), into: mixed)
        bookmarks.add(.remote(host: "spooky-test", path: "/srv/mixed"), into: mixed)

        // 多选里有要询问的项时，仓库管理没有窗口，询问出不来，书签都保留
        manager.confirmDelete([empty, local])
        #expect(bookmarks.bookmark(empty) != nil)
        #expect(bookmarks.bookmark(local) != nil)

        // 只剩直接删除的几种时不询问，多选同样
        manager.confirmDelete([empty, nested])
        manager.confirmDelete([gone])
        #expect([empty, nested, gone].allSatisfy { bookmarks.bookmark($0) == nil })

        // 一个本机仓库：勾选框写单数，说明是本机的写法
        let single = manager.deleteBookmarksPrompt([try #require(bookmarks.bookmark(local))]) { }
        #expect(single.checkbox == AppLocalization.text("bookmarks.delete.trash"))
        #expect(single.message == AppLocalization.text("bookmarks.delete.note"))

        // 本机与服务器仓库混在的分组：标题照旧写分组名，个数是两种合计，说明换成服务器的写法
        let group = manager.deleteBookmarksPrompt([try #require(bookmarks.bookmark(mixed))]) { }
        #expect(group.title == AppLocalization.text("bookmarks.delete.title", "Mixed"))
        #expect(group.checkbox == AppLocalization.text("bookmarks.delete.trashMultiple", 2))
        #expect(group.message == AppLocalization.text("bookmarks.delete.noteServer"))

        // 不勾选：书签连同分组里的一起移除，没有移动任何文件夹
        group.submit(false)
        single.submit(false)
        #expect(bookmarks.items.isEmpty)
        #expect(manager.trashTask == nil)
        #expect(recorder.local.isEmpty && recorder.remote.isEmpty)
    }

    /// 勾选后书签立即删除，本机与服务器仓库各走对应的入口；目录已不存在的跳过，家目录与它的上级不移，
    /// 服务器上受保护、没有废纸篓、连不上的留在原处列进错误框，克隆中的先停止克隆再移走还在的目录。
    @Test("勾选后移进废纸篓")
    func moving() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let home = try Self.makeDirectory("home", in: directory)
        let repository = try Self.makeDirectory("home/repo", in: directory)
        let failing = try Self.makeDirectory("failing", in: directory)
        let cloneTarget = try Self.makeDirectory("clone", in: directory)
        let recorder = TrashRecorder()

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let coordinator = SpookyApplicationController(bookmarks: bookmarks, recentDocuments: .ignoring)
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        manager.coordinator = coordinator

        // 克隆停在一个只接受连接、从不应答的本机端口上，不会自己结束
        let (listener, port) = try Self.silentListener()
        defer { close(listener) }

        let clone = coordinator.clones.start(
            RepositoryClone(url: "http://127.0.0.1:\(port)/app.git", destination: .local(path: cloneTarget.path))
        )

        manager.folderTrash = Self.trash(home: home, recorder: recorder) { url in
            if url.path == cloneTarget.path {
                recorder.cloneRunning.append(clone.isRunning)
            }

            if url.path == failing.path {
                throw CocoaError(.fileWriteNoPermission)
            }
        }

        let paths = ["/srv/moved", "/srv/home", "/srv/no-trash", "/srv/gone", "/srv/offline"]
        let servers = paths.map { RepositoryLocation.remote(host: "spooky-test", path: $0) }

        let locals = [repository, home, directory, failing, cloneTarget, directory.appending(path: "gone")]
            .map { RepositoryLocation.local(path: $0.path) }

        let ids = (locals + servers).map { bookmarks.add($0) }
        let prompt = manager.deleteBookmarksPrompt(ids.compactMap(bookmarks.bookmark)) { }

        // 目录已不存在的本机仓库不算进个数
        #expect(prompt.checkbox == AppLocalization.text("bookmarks.delete.trashMultiple", 10))

        prompt.submit(true)
        #expect(bookmarks.items.isEmpty)

        let failures = await manager.trashTask?.value ?? []

        // 本机：只移走家目录里的仓库、移动失败的与克隆的目录；家目录与它的上级、已不存在的没有交给入口
        #expect(recorder.local.map(\.path) == [repository, failing, cloneTarget].map(\.path))
        #expect(recorder.cloneRunning == [false])
        #expect({ if case .cancelled = clone.state { true } else { false } }())

        // 服务器：每个仓库都交给服务器的入口，不在本机移动
        #expect(recorder.remote == servers)

        let protected = AppLocalization.text("bookmarks.trashFailed.protected")

        #expect(failures.map(\.location) == [locals[1], locals[2], locals[3], servers[1], servers[2], servers[4]])
        #expect(failures[0].reason == protected && failures[1].reason == protected && failures[3].reason == protected)
        #expect(failures[2].reason == CocoaError(.fileWriteNoPermission).localizedDescription)
        #expect(failures[4].reason == AppLocalization.text("files.error.trashUnavailable"))

        // 错误框逐行列出仓库与原因，服务器仓库带主机前缀
        let notice = RepositoryManagerController.trashFailureNotice(failures) { }
        #expect(notice.title == AppLocalization.text("bookmarks.trashFailed.title"))
        #expect(notice.message.hasPrefix(AppLocalization.text("bookmarks.trashFailed.message") + "\n\n"))
        #expect(notice.message.contains("spooky-test:/srv/no-trash — " + AppLocalization.text("files.error.trashUnavailable")))

        // 卷与挂载点的顶层不移，不论家目录在哪里
        #expect(RepositoryFolderTrash.isProtected(URL(fileURLWithPath: "/System/Volumes/Data"), home: home.path))
        #expect(!RepositoryFolderTrash.isProtected(repository, home: home.path))
    }
}

// MARK: - Helpers

extension BookmarkDeletionTests {
    /// 每个用例独立的偏好域与它所在的临时目录；用例结束时删掉目录。
    private static func defaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-deletion-" + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }

    /// 在临时目录里建一个目录。
    private static func makeDirectory(_ name: String, in directory: URL) throws -> URL {
        let url = directory.appending(path: name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 记录调用的移动入口：服务器仓库按路径给出结果，本机目录先交给 `local` 再记下。
    ///
    /// - Parameters:
    ///   - home: 当作家目录的临时目录。
    ///   - recorder: 记下调用。
    ///   - local: 本机目录交来时执行，可以抛出移动失败。
    private static func trash(
        home: URL,
        recorder: TrashRecorder,
        local: @escaping @MainActor (URL) throws -> Void = { _ in }
    ) -> RepositoryFolderTrash {
        RepositoryFolderTrash(
            homeDirectory: home.path,
            moveLocal: { url in
                recorder.local.append(url)
                try local(url)
            },
            moveRemote: { location in
                recorder.remote.append(location)

                switch location.path {
                case "/srv/home": return .protected
                case "/srv/no-trash": throw RepositoryFileError.trashUnavailable
                case "/srv/gone": throw RemoteConnectionError(.pathUnavailable)
                case "/srv/offline": throw RemoteConnectionError(.unavailable)
                default: return .moved
                }
            }
        )
    }

    /// 在 127.0.0.1 上监听一个端口，只接受连接、从不应答，连上来的 HTTP 请求一直等着。
    ///
    /// - Returns: 监听的套接字与端口；用完关闭套接字。
    private static func silentListener() throws -> (Int32, UInt16) {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)

        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                bind(listener, address, length) == 0
                    && listen(listener, 8) == 0
                    && getsockname(listener, address, &length) == 0
            }
        }

        guard listener >= 0, bound else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return (listener, UInt16(bigEndian: address.sin_port))
    }
}
