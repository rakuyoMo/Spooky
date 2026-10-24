import AppKit

// MARK: - Sidebar Menu

extension SpookyApplicationController {
    /// View › Sidebar 子菜单：与侧边栏底栏的视图设置按钮是同一张菜单，打开时按当前偏好重建。
    func configureSidebarMenu(in view: NSMenu) {
        let item = NSMenuItem(title: AppLocalization.text("sidebar.menu"), action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)
        submenu.delegate = SidebarViewSettingsMenu.shared
        item.submenu = submenu
        view.addItem(item)
    }
}
