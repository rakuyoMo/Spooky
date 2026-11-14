import AppKit
import SpookyKit

// MARK: - Search

extension RepositoryWindowController {
    /// 历史搜索框范围菜单的顺序，菜单项的 tag 是这里的序号。
    private static let historyScopes: [HistorySearchCondition.Kind] = [
        .message,
        .author,
        .committer,
        .file,
        .hash,
        .sinceDate,
        .untilDate,
    ]

    /// 工具栏搜索框：输入即时写入会话，由当前主视图过滤自己的列表。
    func makeSearchItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: identifier)
        item.label = AppLocalization.text("action.search")
        item.visibilityPriority = .high
        item.searchField.target = self
        item.searchField.action = #selector(searchChanged(_:))
        configureSearchItem(item)
        return item
    }

    /// 按当前视图设置搜索框：文字、范围菜单、占位文字与补全；仓库管理与不支持过滤的视图中禁用。
    func configureSearchItem(_ item: NSSearchToolbarItem) {
        item.searchField.stringValue = session.searchText
        item.searchField.isEnabled = !showsManager && session.activeView.supportsSearch

        // 先清掉上一个视图的范围菜单、占位文字与补全
        item.searchField.searchMenuTemplate = nil
        item.searchField.placeholderString = nil
        item.searchField.delegate = nil
        contributorCompletion.close()

        guard !showsManager else {
            return
        }

        // 历史的搜索框带范围菜单，写入第一个文字条件
        if session.activeView == .history {
            item.searchField.stringValue = session.history.primarySearchText
            configureHistorySearch(item.searchField)
        }

        // 工作区的搜索框按文件过滤，输入时列出匹配的文件
        if session.activeView == .workingCopy {
            configureWorkingCopySearch(item.searchField)
        }

        // 文件历史的搜索框带范围菜单
        if session.activeView == .fileHistory {
            configureFileHistorySearch(item.searchField)
        }

        // 储藏视图按说明过滤，占位文字写明搜索的内容
        if session.activeView == .stashes {
            item.searchField.placeholderString = AppLocalization.text("stash.search")
        }

        // Reflog 按记录的说明搜索
        if session.activeView == .reflog {
            item.searchField.placeholderString = AppLocalization.text("reflog.search")
        }
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

// MARK: - Suggestions

extension RepositoryWindowController {
    /// 工作区搜索的建议：Files 一组，先列按顺序包含输入字符的文件，最后一行按包含输入过滤。
    ///
    /// - Parameters:
    ///   - query: 搜索框的输入。
    ///   - paths: 工作区列表里的路径。
    static func workingCopySuggestions(for query: String, in paths: [String]) -> [ContributorSuggestion] {
        let files = HistorySearchSuggestions.fileMatches(query, in: paths).map { path in
            ContributorSuggestion(text: path, name: path, email: nil, showsAvatar: false, group: .files)
        }

        return files + [ContributorSuggestion.contains(query, group: .files)].compactMap { $0 }
    }

    /// 历史按说明搜索时的建议：说明、作者、提交人与文件四组，各一行按包含输入搜索对应的范围。
    static func messageScopeSuggestions(for query: String) -> [ContributorSuggestion] {
        let groups: [ContributorSuggestion.Group] = [.messages, .authors, .committers, .files]
        return groups.compactMap { ContributorSuggestion.contains(query, group: $0) }
    }
}

// MARK: - Private

extension RepositoryWindowController {
    /// 工具栏里的搜索框；工具栏还没建立时为 nil。
    private var searchField: NSSearchField? {
        let item = window?.toolbar?.items.first { $0.itemIdentifier.rawValue == "search" }
        return (item as? NSSearchToolbarItem)?.searchField
    }

    /// 建议的分组对应的历史搜索范围。
    private static func historyScope(of group: ContributorSuggestion.Group) -> HistorySearchCondition.Kind {
        switch group {
        case .messages: .message
        case .authors: .author
        case .committers: .committer
        case .files: .file
        }
    }

    /// 历史的搜索框：范围菜单与占位文字，按作者、提交人或文件搜索时弹出补全；输入像日期时最前面是 Since Dates 建议。
    private func configureHistorySearch(_ field: NSSearchField) {
        configureHistorySearchMenu(field)

        let history = session.history

        // 接受补全后与键入一样写入搜索条件；日期建议换成从那一天起的日期条件
        contributorCompletion.attach(
            to: field,
            suggestions: { [weak history] query in
                guard let history else {
                    return []
                }

                let since = HistorySearchSuggestions.sinceSuggestion(for: query).map { [$0] } ?? []

                guard history.primarySearchKind != .message else {
                    return since + Self.messageScopeSuggestions(for: query)
                }

                guard let runner = history.runner, let head = history.branch?.oid else {
                    return since
                }

                let others = await history.suggestions.suggestions(
                    for: history.primarySearchKind,
                    matching: query,
                    runner: runner,
                    head: head
                )

                return since + others
            },
            apply: { [weak self] suggestion in
                if let date = suggestion.sinceDate {
                    self?.session.searchText = ""
                    self?.session.history.searchSince(date)
                    return
                }

                // 分组的建议换到对应的范围
                if let kind = suggestion.group.map(Self.historyScope(of:)) {
                    self?.session.history.setSearchScope(kind)
                }

                self?.session.searchText = suggestion.text
                self?.session.history.setSearchText(suggestion.text)
            }
        )
    }

    /// 工作区的搜索框：范围菜单只有 File 一项；输入时列出按顺序包含输入字符的文件，最后一行按包含输入过滤。
    ///
    /// 选一个文件后搜索框写它的完整路径，列表按这个路径过滤，文件不被选中。
    private func configureWorkingCopySearch(_ field: NSSearchField) {
        let menu = NSMenu()
        let file = NSMenuItem(title: AppLocalization.text("history.search.file"), action: nil, keyEquivalent: "")

        file.state = .on
        menu.addItem(.sectionHeader(title: AppLocalization.text("workspace.title")))
        menu.addItem(file)

        field.searchMenuTemplate = menu
        field.placeholderString = AppLocalization.text("history.search.forFile")

        contributorCompletion.attach(
            to: field,
            suggestions: { [weak session] query in
                Self.workingCopySuggestions(for: query, in: session?.status?.entries.map(\.path) ?? [])
            },
            apply: { [weak session] in session?.searchText = $0.text }
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
