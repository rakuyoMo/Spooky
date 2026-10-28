import AppKit
import SwiftUI

// MARK: - SidebarViewSettingsMenu

/// 侧边栏视图设置的菜单：底栏的视图设置按钮与主菜单 View › Sidebar 是同一张菜单，每次打开时按当前偏好重建。
///
/// 菜单项的目标是本对象，选择后直接写偏好；侧边栏以 `@AppStorage` 读取同一组键，随即刷新。
@MainActor
final class SidebarViewSettingsMenu: NSObject, NSMenuDelegate {
    /// 主菜单使用的实例，写入标准偏好。
    static let shared = SidebarViewSettingsMenu()

    /// 保存设置的位置，测试使用独立的偏好域。
    let defaults: UserDefaults

    /// 创建菜单的生成者。
    ///
    /// - Parameter defaults: 保存设置的位置。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 打开前按当前偏好重建；依赖项的可用状态由这里决定，不交给自动校验。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.autoenablesItems = false
        menu.removeAllItems()

        for item in makeItems() {
            menu.addItem(item)
        }
    }

    /// 按当前偏好生成全部菜单项：显示类、分组类、徽标类与数量类之间各有一条分隔线。
    func makeItems() -> [NSMenuItem] {
        let groupsRefs = SidebarPreferences.isOn(SidebarPreferences.groupRefsKey, in: defaults)
        let showsStale = SidebarPreferences.isOn(SidebarPreferences.showStaleInfoKey, in: defaults)

        return [
            toggle("sidebar.showReflog", key: SidebarPreferences.showReflogKey),
            toggle("sidebar.showStashCount", key: SidebarPreferences.showStashCountKey),
            .separator(),
            toggle("sidebar.groupRefs", key: SidebarPreferences.groupRefsKey),
            toggle("sidebar.groupedRefsOnTop", key: SidebarPreferences.groupedRefsOnTopKey, enabled: groupsRefs),
            .separator(),
            toggle("sidebar.showStaleInfo", key: SidebarPreferences.showStaleInfoKey),
            staleIntervalItem(enabled: showsStale),
            toggle("sidebar.autoArchive", key: SidebarPreferences.autoArchiveKey),
            .separator(),
            remoteBranchFilterItem(),
            tagFilterItem(),
        ]
    }

    /// 切换菜单项代表的开关。
    @objc
    func toggleSetting(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else {
            return
        }

        defaults.set(!SidebarPreferences.isOn(key, in: defaults), forKey: key)
    }

    /// 选中某个数值档位：菜单项的标签是数值，代表的对象是偏好键。
    @objc
    func selectNumber(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String, SidebarPreferences.isValid(sender.tag, for: key) else {
            return
        }

        defaults.set(sender.tag, forKey: key)
    }
}

// MARK: - Items

extension SidebarViewSettingsMenu {
    /// 勾选类菜单项，勾选状态取当前偏好。
    private func toggle(_ titleKey: String, key: String, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(
            title: AppLocalization.text(titleKey),
            action: #selector(toggleSetting(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = key
        item.state = SidebarPreferences.isOn(key, in: defaults) ? .on : .off
        item.isEnabled = enabled
        return item
    }

    /// 单选类菜单项，当前值打勾。
    private func choice(_ title: String, value: Int, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(selectNumber(_:)), keyEquivalent: "")
        item.target = self
        item.tag = value
        item.representedObject = key
        item.state = SidebarPreferences.integer(key, in: defaults) == value ? .on : .off
        return item
    }

    /// 不可点的小标题，用来分隔子菜单里的两组单选。
    private func heading(_ titleKey: String) -> NSMenuItem {
        let item = NSMenuItem(title: AppLocalization.text(titleKey), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// 带子菜单的菜单项；子菜单同样不自动校验可用状态。
    private func submenu(_ titleKey: String, items: [NSMenuItem], enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: AppLocalization.text(titleKey), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: item.title)
        menu.autoenablesItems = false
        items.forEach(menu.addItem)
        item.submenu = menu
        item.isEnabled = enabled
        return item
    }

    /// 陈旧阈值：只在显示陈旧信息时可选。
    private func staleIntervalItem(enabled: Bool) -> NSMenuItem {
        let choices = SidebarPreferences.staleIntervals.map { months in
            choice(
                months == 1
                    ? AppLocalization.text("sidebar.month")
                    : AppLocalization.text("sidebar.months", months),
                value: months,
                key: SidebarPreferences.staleIntervalKey
            )
        }

        return submenu("sidebar.staleInterval", items: choices, enabled: enabled)
    }

    /// 远端分支的显示数量。
    private func remoteBranchFilterItem() -> NSMenuItem {
        submenu(
            "sidebar.remoteFilter",
            items: [heading("sidebar.showNewest")] + newestChoices(key: SidebarPreferences.newestRemoteBranchesKey)
        )
    }

    /// 标签的排序与显示数量。
    private func tagFilterItem() -> NSMenuItem {
        let orders = [
            choice(
                AppLocalization.text("sidebar.nameAscending"),
                value: SidebarPreferences.TagOrder.nameAscending.rawValue,
                key: SidebarPreferences.tagOrderKey
            ),
            choice(
                AppLocalization.text("sidebar.nameDescending"),
                value: SidebarPreferences.TagOrder.nameDescending.rawValue,
                key: SidebarPreferences.tagOrderKey
            ),
        ]

        return submenu(
            "sidebar.tagsFilter",
            items: [heading("sidebar.sortBy")] + orders + [.separator(), heading("sidebar.showNewest")]
                + newestChoices(key: SidebarPreferences.newestTagsKey)
        )
    }

    /// “全部” 与各个数量档位。
    private func newestChoices(key: String) -> [NSMenuItem] {
        SidebarPreferences.newestChoices.map { count in
            choice(
                count == 0 ? AppLocalization.text("sidebar.all") : count.formatted(),
                value: count,
                key: key
            )
        }
    }
}

// MARK: - Pop Up

extension SidebarViewSettingsMenu {
    /// 在按钮下方弹出菜单。
    @objc
    func popUp(_ sender: NSButton) {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }
}

// MARK: - SidebarViewSettingsButton

/// 侧边栏底栏的视图设置按钮：点按弹出与 View › Sidebar 相同的菜单。
struct SidebarViewSettingsButton: NSViewRepresentable {
    /// 保存设置的位置。
    let defaults: UserDefaults

    /// 菜单的生成者由按钮持有，按钮存在期间一直有效。
    func makeCoordinator() -> SidebarViewSettingsMenu {
        SidebarViewSettingsMenu(defaults: defaults)
    }

    /// 无边框的图标按钮，用次要文字颜色着色。
    func makeNSView(context: Context) -> NSButton {
        let title = AppLocalization.text("sidebar.viewSettings")
        let image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: title) ?? NSImage()

        let button = NSButton(
            image: image,
            target: context.coordinator,
            action: #selector(SidebarViewSettingsMenu.popUp(_:))
        )
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = title
        return button
    }

    /// 按钮没有随 SwiftUI 状态变化的内容。
    func updateNSView(_: NSButton, context _: Context) { }
}
