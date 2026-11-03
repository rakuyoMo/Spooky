import AppKit
import SpookyKit

// MARK: - Recent Menu

extension SpookyApplicationController {
    /// 最近菜单各项的标题：仓库文件夹的名字，服务器仓库取远端路径的最后一段；同名的几项在后面加 “ — ” 与上一级文件夹名。
    ///
    /// - Parameter locations: 最近打开的仓库，按菜单顺序排列。
    /// - Returns: 与 `locations` 一一对应的标题。
    static func recentTitles(for locations: [RepositoryLocation]) -> [String] {
        let urls = locations.map { URL(fileURLWithPath: $0.path) }
        let names = urls.map(\.lastPathComponent)

        return zip(urls, names).map { url, name in
            // 名字只出现一次时不加上一级文件夹名
            guard names.count(where: { $0 == name }) > 1 else {
                return name
            }

            return name + " — " + url.deletingLastPathComponent().lastPathComponent
        }
    }

    /// File › Open Recent 每次展开时按最近打开时间列出打开过的仓库，失效的仍可选择重试；末尾是清空列表的 Clear Menu。
    ///
    /// 列表为空时只剩一项不可用的 Clear Menu。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let locations = bookmarks.recentlyOpened.compactMap(\.location)
        let titles = Self.recentTitles(for: locations)

        // 每个仓库一项，悬停提示写完整位置，失效的写 Unavailable
        for (location, title) in zip(locations, titles) {
            let item = NSMenuItem(title: title, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = location
            item.toolTip = bookmarks.isMissing(location)
                ? AppLocalization.text("repositories.unavailable")
                : location.displayPath
            menu.addItem(item)
        }

        // 列表为空时不画分隔线，只留一项 Clear Menu，由 `validateMenuItem(_:)` 置为不可用
        if !locations.isEmpty {
            menu.addItem(.separator())
        }

        let clear = NSMenuItem(
            title: AppLocalization.text("menu.clearRecent"),
            action: #selector(clearRecentRepositories),
            keyEquivalent: ""
        )
        clear.target = self
        menu.addItem(clear)
    }

    /// Clear Menu：清空最近打开列表，书签都保留。
    @objc
    func clearRecentRepositories() {
        bookmarks.clearRecentlyOpened()
    }

    /// 最近菜单直接走窗口复用与版本检查流程。
    @objc
    private func openRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? RepositoryLocation else {
            return
        }

        openRepository(at: path, from: activeWindow, inNewWindow: false)
    }
}
