import AppKit
import SpookyKit

// MARK: - Search

extension RepositoryWindowController {
    /// 历史搜索框范围菜单的顺序，菜单项的 tag 是这里的序号。
    private static let historyScopes: [HistorySearchCondition.Kind] = [.message, .author, .committer, .file, .hash]

    /// 工具栏搜索框：输入即时写入会话，由当前主视图过滤自己的列表；不支持过滤的视图中禁用。
    func makeSearchItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: identifier)
        item.label = AppLocalization.text("action.search")
        item.visibilityPriority = .high
        item.searchField.stringValue = session.searchText
        item.searchField.isEnabled = session.activeView.supportsSearch
        item.searchField.target = self
        item.searchField.action = #selector(searchChanged(_:))

        // 历史的搜索框带范围菜单，写入第一个文字条件
        if session.activeView == .history {
            item.searchField.stringValue = session.history.primarySearchText
            configureHistorySearch(item.searchField)
        }

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

    /// ⌘F 与 ⌥⌘F 把焦点交给工具栏搜索框，空间不足而收起时先展开。
    @objc
    func focusSearch() {
        let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "search" }
        (item as? NSSearchToolbarItem)?.beginSearchInteraction()
    }

    /// 过滤面板改动第一个文字条件时，工具栏搜索框的文字、范围与占位随之更新。
    func observeHistorySearch() {
        withObservationTracking {
            _ = session.history.primarySearchText
            _ = session.history.primarySearchKind
        } onChange: { [weak self] in
            // 变更通知早于新值写入，下一轮主线程再同步并重新订阅。
            Task { @MainActor in
                self?.syncHistorySearchField()
                self?.observeHistorySearch()
            }
        }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 工具栏里的搜索框；工具栏还没建立时为 nil。
    private var searchField: NSSearchField? {
        let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "search" }
        return (item as? NSSearchToolbarItem)?.searchField
    }

    /// 历史的搜索框：范围菜单与占位文字，按作者、提交人或文件搜索时弹出补全。
    private func configureHistorySearch(_ field: NSSearchField) {
        configureHistorySearchMenu(field)

        let history = session.history

        // 接受补全后与键入一样写入搜索条件
        contributorCompletion.attach(
            to: field,
            suggestions: { [weak history] query in
                guard let history, let runner = history.runner, let head = history.branch?.oid else {
                    return []
                }

                return await history.suggestions.suggestions(
                    for: history.primarySearchKind,
                    matching: query,
                    runner: runner,
                    head: head
                )
            },
            apply: { [weak self] in
                self?.session.searchText = $0
                self?.session.history.setSearchText($0)
            }
        )
    }

    /// 范围菜单：灰色的小标题下列出各范围，当前范围打勾；占位文字写明搜索的内容。
    private func configureHistorySearchMenu(_ field: NSSearchField) {
        let kind = session.history.primarySearchKind
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: AppLocalization.text("history.title"), action: nil, keyEquivalent: ""))

        for (index, candidate) in Self.historyScopes.enumerated() {
            let item = NSMenuItem(
                title: candidate.title,
                action: #selector(selectHistorySearchScope(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.indentationLevel = 1
            item.state = candidate == kind ? .on : .off
            menu.addItem(item)
        }

        field.searchMenuTemplate = menu
        field.placeholderString = kind.placeholder
    }

    /// 过滤面板改动后同步搜索框；只在历史视图里同步，不打断正在显示的补全。
    private func syncHistorySearchField() {
        guard session.activeView == .history, let field = searchField else {
            return
        }

        let text = session.history.primarySearchText

        if field.stringValue != text {
            field.stringValue = text
        }

        configureHistorySearchMenu(field)
    }

    /// 切换历史的搜索范围，第一个文字条件随之改变。
    @objc
    private func selectHistorySearchScope(_ sender: NSMenuItem) {
        guard Self.historyScopes.indices.contains(sender.tag) else {
            return
        }

        session.history.setSearchScope(Self.historyScopes[sender.tag])
    }

    /// 键入与清除都经搜索框的动作同步到会话；历史写入第一个文字条件。
    @objc
    private func searchChanged(_ sender: NSSearchField) {
        session.searchText = sender.stringValue

        if session.activeView == .history {
            session.history.setSearchText(sender.stringValue)
        }
    }
}
