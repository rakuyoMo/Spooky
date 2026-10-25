import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - RepositoryBookmarksTests

/// 仓库书签：旧记录的迁移、去重与打开时间、文件夹与手动顺序、改名与删除、失效标记，以及改指向工作区根目录。
@MainActor
struct RepositoryBookmarksTests {
    /// 每个用例独立的偏好域。
    private static func defaults() throws -> (UserDefaults, String) {
        let suite = "spooky-bookmarks-" + UUID().uuidString
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    /// 已有的最近记录变成同样顺序的书签，旧键随之删除；之后只读新键。
    @Test("旧版本的最近记录迁移成书签")
    func migratesLegacyRecords() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let locations: [RepositoryLocation] = [
            .remote(host: "spooky-test", path: "/srv/应用 app"),
            .local(path: "/tmp/repo"),
        ]
        defaults.set(try JSONEncoder().encode(locations), forKey: "recentRepositories")

        let bookmarks = RepositoryBookmarks(defaults: defaults)

        #expect(bookmarks.repositories.compactMap(\.location) == locations)
        #expect(bookmarks.repositories.map(\.displayName) == ["spooky-test:应用 app", "repo"])
        #expect(defaults.object(forKey: "recentRepositories") == nil)
        #expect(RepositoryBookmarks(defaults: defaults).items == bookmarks.items)
    }

    /// 同一位置只有一个书签；打开过的按最近打开时间排在前面，没打开过的不算最近。
    @Test("加入不重复，按打开时间列出最近打开")
    func addsAndRecordsOpening() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let first = RepositoryLocation.local(path: "/tmp/first")
        let second = RepositoryLocation.local(path: "/tmp/second")
        let never = RepositoryLocation.local(path: "/tmp/never")

        let id = bookmarks.add(first)
        #expect(bookmarks.add(first) == id)
        bookmarks.add(never)

        bookmarks.recordOpened(first, at: Date(timeIntervalSince1970: 100))
        bookmarks.recordOpened(second, at: Date(timeIntervalSince1970: 200))

        #expect(bookmarks.repositories.compactMap(\.location) == [first, never, second])
        #expect(bookmarks.recentlyOpened.compactMap(\.location) == [second, first])
    }

    /// 移进文件夹保持原来的先后；文件夹不能移进它自己或它里面的文件夹；排序只排一层。
    @Test("文件夹、移动与按名称排序")
    func foldersMoveAndSort() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let b10 = bookmarks.add(.local(path: "/tmp/b10"))
        let b9 = bookmarks.add(.local(path: "/tmp/b9"))
        let alpha = bookmarks.add(.local(path: "/tmp/alpha"))
        let outer = bookmarks.addFolder(named: "Outer")
        let inner = bookmarks.addFolder(named: "Inner", into: outer)

        bookmarks.move([b10, b9], into: outer, at: 0)
        #expect(bookmarks.items.children(of: outer).map(\.id) == [b10, b9, inner])
        #expect(bookmarks.parent(of: b9) == outer)

        #expect(!bookmarks.canMove([outer], into: outer))
        #expect(!bookmarks.canMove([outer], into: inner))
        #expect(!bookmarks.canMove([alpha], into: b9))
        #expect(bookmarks.canMove([inner], into: nil))

        // 数字按数值比较，b9 排在 b10 前面；外层的书签不受影响
        bookmarks.sortChildren(of: outer)
        #expect(bookmarks.items.children(of: outer).map(\.name) == ["b9", "b10", "Inner"])
        #expect(bookmarks.items.map(\.id) == [alpha, outer])

        // 持久化的是整棵树
        #expect(RepositoryBookmarks(defaults: defaults).items == bookmarks.items)
    }

    /// 改名去掉首尾空白，空名字不接受；删除文件夹连同里面的书签，失效标记一并清掉。
    @Test("改名、删除与失效标记")
    func renameDeleteAndMissing() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let gone = RepositoryLocation.local(path: "/tmp/gone")
        let folder = bookmarks.addFolder(named: "Group")
        let repository = bookmarks.add(gone, into: folder)

        bookmarks.rename(repository, to: "  工作 仓库  ")
        bookmarks.rename(repository, to: "   ")
        #expect(bookmarks.bookmark(repository)?.name == "工作 仓库")

        // 不在书签里的位置不做标记
        bookmarks.markMissing(.local(path: "/tmp/unknown"))
        bookmarks.markMissing(gone)
        #expect(bookmarks.missing == [gone])

        bookmarks.delete([folder])
        #expect(bookmarks.items.isEmpty)
        #expect(bookmarks.missing.isEmpty)
    }

    /// 书签指向子目录时改指向工作区根目录：没改过的名字随之更新，改过的保留；根目录已有书签时不动。
    @Test("书签改指向工作区根目录")
    func relocatesToWorkingTreeRoot() throws {
        let (defaults, suite) = try Self.defaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let nested = RepositoryLocation.local(path: "/tmp/app/Sources")
        let root = RepositoryLocation.local(path: "/tmp/app")
        let renamedNested = RepositoryLocation.local(path: "/tmp/tool/docs")
        let id = bookmarks.add(nested)
        let renamed = bookmarks.add(renamedNested)
        bookmarks.rename(renamed, to: "Tool")

        bookmarks.relocate(nested, to: root)
        bookmarks.relocate(renamedNested, to: .local(path: "/tmp/tool"))

        #expect(bookmarks.bookmark(id)?.location == root)
        #expect(bookmarks.bookmark(id)?.name == "app")
        #expect(bookmarks.bookmark(renamed)?.name == "Tool")

        // 根目录已有书签时，指向子目录的书签保持原样
        let other = bookmarks.add(.local(path: "/tmp/app/Tests"))
        bookmarks.relocate(.local(path: "/tmp/app/Tests"), to: root)
        #expect(bookmarks.bookmark(other)?.location == .local(path: "/tmp/app/Tests"))
    }
}
