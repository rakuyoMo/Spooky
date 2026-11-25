import Foundation
import SpookyKit
import Testing

@testable import Spooky

// MARK: - BookmarkLocationEditingTests

/// 在仓库管理的详情里编辑书签的位置。
@MainActor
struct BookmarkLocationEditingTests {
    /// 换位置要重新设置名称与所在的文件夹，就失去了编辑的意义：书签改指向验证过的工作区根目录，
    /// 改过的名称、所在的文件夹与打开时间都保留，选中的位置与详情区跟到新位置；
    /// 不是仓库的位置与已有书签的位置都不接受，书签保持原样。
    @Test("编辑位置后书签改指过去，名称、文件夹与打开时间保留")
    func relocatesBookmark() async throws {
        let created = FileManager.default.temporaryDirectory
            .appending(path: "spooky-location-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: created, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: created) }

        // Git 报出的是解析过符号链接的绝对路径，临时目录在 /var 下时是 /private/var
        let resolved = try #require(realpath(created.path, nil))
        defer { free(resolved) }

        let directory = URL(fileURLWithPath: String(cString: resolved))
        let moved = directory.appending(path: "moved")
        let other = directory.appending(path: "other")
        let plain = directory.appending(path: "plain")

        for folder in [moved.appending(path: "Sources"), other, plain] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        _ = try await FileViewsTests.initializeRepository(at: .local(path: moved.path))
        _ = try await FileViewsTests.initializeRepository(at: .local(path: other.path))

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())

        let gone = RepositoryLocation.local(path: directory.appending(path: "gone").path)
        let group = bookmarks.addFolder(named: "Group")
        let id = bookmarks.add(gone, into: group)
        bookmarks.add(.local(path: other.path))
        bookmarks.rename(id, to: "Work")
        bookmarks.recordOpened(gone, at: Date(timeIntervalSince1970: 100))
        bookmarks.markMissing(gone)
        manager.selection = [id]

        // 不是仓库的文件夹：说明原因，书签不动
        #expect(await manager.relocate(id, to: .local(path: plain.path)) != nil)
        #expect(bookmarks.bookmark(id)?.location == gone)

        // 已有书签的仓库：不让两个书签指向同一个仓库
        #expect(
            await manager.relocate(id, to: .local(path: other.path))
                == AppLocalization.text("bookmarks.location.exists")
        )
        #expect(bookmarks.bookmark(id)?.location == gone)

        // 填的是工作区里的子目录：书签指向工作区根目录
        let root = RepositoryLocation.local(path: moved.path)
        #expect(await manager.relocate(id, to: .local(path: moved.appending(path: "Sources").path)) == nil)

        let bookmark = try #require(bookmarks.bookmark(id))
        #expect(bookmark.location == root)
        #expect(bookmark.name == "Work")
        #expect(bookmark.lastOpened == Date(timeIntervalSince1970: 100))
        #expect(bookmarks.parent(of: id) == group)
        #expect(bookmarks.missing.isEmpty)

        // 选中的还是这个书签，菜单与详情区用的位置跟到新位置
        #expect(manager.session.selectedRecentLocation == root)
        #expect(manager.detailLocation == root)
    }
}
