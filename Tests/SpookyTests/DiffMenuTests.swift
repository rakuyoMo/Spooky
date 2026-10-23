import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 上下文行数、保存补丁与导出 Diff 的菜单入口必须存在，并连到窗口的动作上，否则功能只能从底栏使用。
@MainActor
struct DiffMenuTests {
    /// View 菜单列出全部上下文档位，Working Copy 菜单提供保存补丁与导出 Diff。
    @Test("Diff 菜单入口")
    func menuItems() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-menu-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let controller = SpookyApplicationController(recent: RecentRepositories(defaults: defaults))
        _ = NSApplication.shared
        controller.configureMenu()

        let items = NSApp.mainMenu?.items.compactMap(\.submenu).flatMap(\.items) ?? []
        let context = try #require(items.first { $0.title == AppLocalization.text("diff.contextMenu") }?.submenu)

        // 每个档位一项，标签即行数，标题与底栏的弹出菜单一致
        #expect(context.items.map(\.tag) == DiffOptions.contextChoices)
        #expect(context.items.map(\.title) == DiffOptions.contextChoices.map(DiffPreferences.contextTitle))
        #expect(context.items.allSatisfy { $0.action == #selector(RepositoryWindowController.setDiffContextLines(_:)) })

        let actions = Set(items.compactMap(\.action))
        #expect(actions.contains(#selector(RepositoryWindowController.savePatch)))
        #expect(actions.contains(#selector(RepositoryWindowController.exportDiff)))
    }

    /// 偏好里没有记录或记录了不在档位中的值时，按默认的 3 行处理。
    @Test("上下文行数偏好的取值")
    func contextPreference() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-context-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let key = DiffPreferences.contextLinesKey
        #expect(DiffPreferences.options(defaults: defaults).contextLines == DiffOptions.defaultContextLines)

        defaults.set(7, forKey: key)
        #expect(DiffPreferences.options(defaults: defaults).contextLines == 7)

        defaults.set(11, forKey: key)
        #expect(DiffPreferences.options(defaults: defaults).contextLines == DiffOptions.defaultContextLines)

        defaults.set(true, forKey: DiffPreferences.ignoresWhitespaceKey)
        let options = DiffPreferences.options(showsEntireFile: true, defaults: defaults)
        #expect(options.ignoresWhitespace)
        #expect(options.showsEntireFile)
    }
}
