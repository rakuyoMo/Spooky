import AppKit

// MARK: - History View Settings

extension RepositoryWindowController {
    /// 只显示第一父提交的开关，所有窗口共用。
    @objc
    func toggleFirstParentOnly() {
        toggle(HistoryViewSettings.firstParentKey)
    }

    /// 按拓扑序排序的开关；显示提交图时总按拓扑序，菜单项灰掉。
    @objc
    func toggleSortByTopoOrder() {
        toggle(HistoryViewSettings.topoOrderKey)
    }

    /// 按日期排序的开关；关掉后日期分组随之失效。
    @objc
    func toggleSortByDate() {
        toggle(HistoryViewSettings.dateOrderKey)
    }

    /// 选择日期分组方式，菜单项的 tag 是分组的原始值。
    @objc
    func selectHistoryGrouping(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: HistoryViewSettings.groupingKey)
    }

    /// 视图设置菜单各项的勾选与可用状态；动作不属于本组时为 nil。
    func historyViewSettingsAvailability(of item: any NSValidatedUserInterfaceItem) -> Bool? {
        let settings = HistoryViewSettings()
        let historyView = !showsManager && session.activeView == .history
        let menuItem = item as? NSMenuItem

        switch item.action {
        case #selector(toggleFirstParentOnly):
            menuItem?.state = settings.showsFirstParentOnly ? .on : .off
            return historyView

        case #selector(toggleSortByTopoOrder):
            menuItem?.state = settings.sortsByTopoOrder ? .on : .off
            return historyView && !settings.showsGraph

        case #selector(toggleSortByDate):
            menuItem?.state = settings.sortsByDate ? .on : .off
            return historyView

        case #selector(selectHistoryGrouping(_:)):
            let stored = UserDefaults.standard.integer(forKey: HistoryViewSettings.groupingKey)
            menuItem?.state = menuItem?.tag == stored ? .on : .off
            return historyView && settings.sortsByDate

        default:
            return nil
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 反转一个布尔偏好。
    private func toggle(_ key: String) {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }
}
