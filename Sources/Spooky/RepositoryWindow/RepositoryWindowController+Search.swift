import AppKit

// MARK: - Search

extension RepositoryWindowController {
    /// 工具栏搜索框：输入即时写入会话，由当前主视图过滤自己的列表；不支持过滤的视图中禁用。
    func makeSearchItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: identifier)
        item.label = AppLocalization.text("action.search")
        item.visibilityPriority = .high
        item.searchField.stringValue = session.searchText
        item.searchField.isEnabled = session.activeView.supportsSearch
        item.searchField.target = self
        item.searchField.action = #selector(searchChanged(_:))

        // 文件历史的搜索框带范围菜单
        if session.activeView == .fileHistory {
            configureFileHistorySearch(item.searchField)
        }

        // 储藏视图按说明过滤，占位文字写明搜索的内容
        if session.activeView == .stashes {
            item.searchField.placeholderString = AppLocalization.text("stash.search")
        }

        return item
    }

    /// ⌘F 把焦点交给工具栏搜索框，空间不足而收起时先展开。
    @objc
    func focusSearch() {
        let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "search" }
        (item as? NSSearchToolbarItem)?.beginSearchInteraction()
    }

    /// 键入与清除都经搜索框的动作同步到会话。
    @objc
    private func searchChanged(_ sender: NSSearchField) {
        session.searchText = sender.stringValue
    }
}
