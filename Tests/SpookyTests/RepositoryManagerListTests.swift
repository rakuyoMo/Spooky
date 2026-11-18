import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryManagerListTests

/// 仓库管理列表的两个显示设置：服务器仓库行上的主机别名，以及列出仓库的工作树。
@MainActor
struct RepositoryManagerListTests {
    /// 主机别名默认写在服务器仓库的名称前；关掉后行上只写名称，改动随即生效。
    /// 悬停提示与 VoiceOver 的名字照旧带主机前缀，右键菜单里的名字同样不变。
    @Test("服务器仓库行上的主机别名")
    func hostAliases() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let server = try #require(bookmarks.bookmark(bookmarks.add(.remote(host: "spooky-test", path: "/srv/app"))))
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        let sidebar = BookmarkSidebarController(manager: manager, defaults: defaults)
        _ = sidebar.view

        // 默认写别名
        let shown = try Self.cell(of: server.id, in: sidebar)
        #expect(Self.visibleTexts(in: shown) == ["spooky-test:", "app"])

        // 关掉后列表随即重新载入，行上只写名称
        defaults.set(false, forKey: RepositoryManagerPreferences.showsHostAliasesKey)
        await until { !sidebar.displayOptions.hostAliases }

        let hidden = try Self.cell(of: server.id, in: sidebar)
        #expect(Self.visibleTexts(in: hidden) == ["app"])

        // 悬停提示、VoiceOver 的名字与右键菜单照旧带主机前缀
        #expect(hidden.toolTip == "spooky-test:/srv/app")
        #expect(hidden.accessibilityLabel() == "spooky-test:app")
        #expect(sidebar.singleItems(for: server).first?.title == AppLocalization.text("bookmarks.open", "spooky-test:app"))
    }
}

// MARK: - Helpers

extension RepositoryManagerListTests {
    /// 每个用例独立的偏好域与它所在的临时目录；用例结束时删掉目录。
    private static func defaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-manager-list-" + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }

    /// 侧边栏为一个书签建出的行。
    private static func cell(of id: Bookmark.ID, in sidebar: BookmarkSidebarController) throws -> BookmarkCellView {
        let view = sidebar.outlineView(sidebar.outlineView, viewFor: nil, item: sidebar.item(for: id))
        return try #require(view as? BookmarkCellView)
    }

    /// 视图里看得到的文字，按视图层级的先后排列。
    private static func visibleTexts(in view: NSView) -> [String] {
        view.subviews.flatMap { subview -> [String] in
            guard !subview.isHidden else {
                return []
            }

            if let field = subview as? NSTextField, !field.stringValue.isEmpty {
                return [field.stringValue]
            }

            return visibleTexts(in: subview)
        }
    }
}
