import AppKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - AppKitContextMenuTests

/// `List` 行上的 AppKit 右键菜单：点按这一行的任意位置都经表格弹出，表格才会给这一行画右键高亮框；
/// 表格自己打开的 SwiftUI 菜单（旁白的 “显示菜单”）与 AppKit 菜单的项目一致。
@MainActor
struct AppKitContextMenuTests {
    /// 只接本行上的右键与 ⌃ 点按，行首的空白处也算；表格为这次点按给出菜单，记下点按的行；挂着表单时不接。
    @Test("经表格弹出右键菜单")
    func routesThroughTable() async throws {
        let fixture = try await Fixture()
        let table = fixture.table
        let view = fixture.menuView

        let click = try Self.click(.rightMouseDown, row: 1, in: table)
        let controlClick = try Self.click(.leftMouseDown, row: 1, in: table, flags: .control)
        let plainClick = try Self.click(.leftMouseDown, row: 1, in: table)
        let otherRow = try Self.click(.rightMouseDown, row: 0, in: table)

        #expect(view.isContextClick(onRowOf: table, click))
        #expect(view.isContextClick(onRowOf: table, controlClick))
        #expect(!view.isContextClick(onRowOf: table, plainClick))
        #expect(!view.isContextClick(onRowOf: table, otherRow))

        // 表格给出菜单时从表格弹出，并记下点按的行
        #expect(view.menuTarget(for: click, in: table) === table)
        #expect(table.clickedRow == 1)

        // 窗口挂着表单时，点按不落到窗口里
        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        fixture.window.beginSheet(sheet, completionHandler: nil)
        #expect(!view.isContextClick(onRowOf: table, click))
        fixture.window.endSheet(sheet)
    }

    /// SwiftUI 菜单逐项对应：分隔线、按住 ⌥ 的替换项、子菜单、打勾与可用性都保留，选中后执行同一个动作。
    @Test("SwiftUI 菜单与 AppKit 菜单项目一致")
    func swiftUIMenuMirrorsItems() async throws {
        let fixture = try await Fixture()
        let table = fixture.table

        let menu = try #require(table.menu(for: Self.click(.rightMouseDown, row: 1, in: table)))

        #expect(
            Self.describe(menu) == [
                "Open on",
                "- off",
                "Fetch on",
                "Quick Fetch on ⌥",
                "Revisions on [Branches off; main off checked; feature on]",
                "Delete off",
            ]
        )

        // 选中 SwiftUI 菜单的项目，执行的是 AppKit 菜单项的动作
        let revisions = try #require(menu.items[4].submenu)
        menu.performActionForItem(at: 0)
        menu.performActionForItem(at: 3)
        revisions.performActionForItem(at: 2)

        try await FileViewsTests.wait { fixture.performed.titles.count == 3 }
        #expect(fixture.performed.titles == ["Open", "Quick Fetch", "feature"])
    }
}

// MARK: - Fixture

extension AppKitContextMenuTests {
    /// 不显示的窗口里的两行 `List`：第一行是普通行，第二行挂着 AppKit 右键菜单。
    @MainActor
    struct Fixture {
        /// 承载列表的窗口。
        let window: NSWindow

        /// 列表背后的表格。
        let table: NSTableView

        /// 第二行里监听右键的视图。
        let menuView: AppKitContextMenu.RowMenuView

        /// 选中菜单项时记下的标题。
        let performed: Performed

        /// 建好窗口并等到两行都显示出来。
        init() async throws {
            _ = NSApplication.shared

            let performed = Performed()
            let list = List {
                Text(verbatim: "plain")
                Text(verbatim: "menu")
                    .appKitContextMenu { AppKitContextMenuTests.sampleMenu(performed) }
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )

            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: list)
            window.contentView?.layoutSubtreeIfNeeded()

            let root = try #require(window.contentView)
            let menuViews = { AppKitContextMenuTests.views(AppKitContextMenu.RowMenuView.self, in: root) }

            try await FileViewsTests.wait { !menuViews().isEmpty }

            self.window = window
            self.performed = performed
            table = try #require(AppKitContextMenuTests.views(NSTableView.self, in: root).first)
            menuView = try #require(menuViews().first)
        }
    }

    /// 记下选中的菜单项。
    @MainActor
    final class Performed {
        /// 依次选中的菜单项标题。
        var titles: [String] = []
    }
}

// MARK: - Helpers

extension AppKitContextMenuTests {
    /// 各类菜单项都有的菜单：普通项、分隔线、带 ⌥ 替换项的一项、带组名与打勾项的子菜单、不可用的一项。
    static func sampleMenu(_ performed: Performed) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        func item(_ title: String, enabled: Bool = true) -> NSMenuItem {
            FileViewMenuItem(
                FileViewAction(title: title, enabled: enabled) {
                    performed.titles.append(title)
                }
            )
        }

        let quick = item("Quick Fetch")
        quick.isAlternate = true
        quick.keyEquivalentModifierMask = .option

        let header = NSMenuItem(title: "Branches", action: nil, keyEquivalent: "")
        header.isEnabled = false

        let current = item("main", enabled: false)
        current.state = .on
        current.indentationLevel = 1

        let other = item("feature")
        other.indentationLevel = 1

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        [header, current, other].forEach(submenu.addItem)

        let revisions = NSMenuItem(title: "Revisions", action: nil, keyEquivalent: "")
        revisions.submenu = submenu

        let items: [NSMenuItem] = [
            item("Open"),
            .separator(),
            item("Fetch"),
            quick,
            revisions,
            item("Delete", enabled: false),
        ]

        items.forEach(menu.addItem)
        return menu
    }

    /// 在窗口坐标里点按某一行的行首空白处。
    static func click(
        _ type: NSEvent.EventType,
        row: Int,
        in table: NSTableView,
        flags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        let rect = table.rect(ofRow: row)
        let point = table.convert(NSPoint(x: rect.minX + 4, y: rect.midY), to: nil)

        let event = NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: table.window?.windowNumber ?? 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        return try #require(event)
    }

    /// 菜单的结构，每项写作 “标题 可用性 替换项 打勾 [子菜单]”，便于逐项比对。
    static func describe(_ menu: NSMenu) -> [String] {
        menu.items.map { item in
            let flags = [
                item.isSeparatorItem ? "-" : item.title,
                item.isEnabled ? "on" : "off",
                item.isAlternate && item.keyEquivalentModifierMask == .option ? "⌥" : "",
                item.state == .on ? "checked" : "",
                item.submenu.map { "[\(describe($0).joined(separator: "; "))]" } ?? "",
            ]

            return flags.filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    /// 视图层级里给定类型的全部视图，按深度优先的顺序。
    static func views<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + views(Element.self, in: child)
        }
    }
}
