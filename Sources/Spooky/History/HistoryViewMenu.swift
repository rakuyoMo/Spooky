import AppKit
import SwiftUI

// MARK: - HistoryViewMenu

/// 历史的视图设置菜单：View › History 子菜单与列表头的设置按钮是同一张菜单。
///
/// 菜单项的动作沿响应链交给仓库窗口，勾选与可用状态由窗口的菜单校验统一设置；只有主菜单里的那份带快捷键。
@MainActor
enum HistoryViewMenu {
    /// 依次加入提交图、第一父、排序、分组与行高各项。
    static func addItems(to menu: NSMenu, keyEquivalents: Bool) {
        let graph = item("history.showGraph", action: #selector(RepositoryWindowController.toggleHistoryGraph))

        if keyEquivalents {
            graph.keyEquivalent = "g"
            graph.keyEquivalentModifierMask = [.control, .command]
        }

        menu.addItem(graph)
        menu.addItem(item("history.firstParentOnly", action: #selector(RepositoryWindowController.toggleFirstParentOnly)))

        // 两种排序是两个独立的勾选项
        menu.addItem(.separator())
        menu.addItem(item("history.sortBy", action: nil))
        menu.addItem(item(
            "history.sort.topo",
            action: #selector(RepositoryWindowController.toggleSortByTopoOrder),
            indented: true
        ))
        menu.addItem(item("history.sort.date", action: #selector(RepositoryWindowController.toggleSortByDate), indented: true))

        menu.addItem(.separator())
        menu.addItem(item("history.groupBy", action: nil))

        for grouping in [HistoryGrouping.day, .week, .month, .ungrouped] {
            let groupItem = item(
                grouping.titleKey,
                action: #selector(RepositoryWindowController.selectHistoryGrouping(_:)),
                indented: true
            )
            groupItem.tag = grouping.rawValue
            menu.addItem(groupItem)
        }

        menu.addItem(.separator())
        menu.addItem(item("history.medium", action: #selector(RepositoryWindowController.mediumHistoryRows)))
        menu.addItem(item("history.small", action: #selector(RepositoryWindowController.smallHistoryRows)))
    }

    /// 一个菜单项；没有动作的是灰色的小标题。
    private static func item(_ key: String, action: Selector?, indented: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: AppLocalization.text(key), action: action, keyEquivalent: "")
        item.indentationLevel = indented ? 1 : 0
        return item
    }
}

// MARK: - HistoryViewMenuButton

/// 列表头右侧的设置按钮：下拉出与 View › History 相同的菜单。
struct HistoryViewMenuButton: NSViewRepresentable {
    /// 无边框的下拉按钮，第一项只提供按钮的图标。
    func makeNSView(context _: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.isBordered = false
        button.setAccessibilityLabel(AppLocalization.text("history.viewOptions"))
        button.toolTip = AppLocalization.text("history.viewOptions")

        button.imagePosition = .imageOnly

        let menu = NSMenu()
        let icon = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        icon.image = NSImage(
            systemSymbolName: "slider.horizontal.3",
            accessibilityDescription: AppLocalization.text("history.viewOptions")
        )
        menu.addItem(icon)

        HistoryViewMenu.addItems(to: menu, keyEquivalents: false)
        button.menu = menu
        return button
    }

    /// 菜单状态在打开时由窗口校验，这里不需要更新。
    func updateNSView(_: NSPopUpButton, context _: Context) { }
}
