import AppKit

// MARK: - ActivityToolbar

/// Activity 窗口工具栏的标识与排布：左边清除，中间分页，右边搜索。
enum ActivityToolbar {
    /// 工具栏标识。
    static let identifier = NSToolbar.Identifier("Spooky.ActivityToolbar")

    /// 清掉当前页已结束的记录。
    static let clearAll = NSToolbarItem.Identifier("clearAll")

    /// Remote | Repository | Service 三页的分段。
    static let kinds = NSToolbarItem.Identifier("activityKinds")

    /// 过滤当前页的搜索框。
    static let search = NSToolbarItem.Identifier("search")

    /// 唯一的排布，不允许自定义。
    static let defaultItems: [NSToolbarItem.Identifier] = [
        clearAll,
        .flexibleSpace,
        kinds,
        .space,
        .flexibleSpace,
        search,
    ]

    /// 各页标题的资源键；提示文字的键是它加上 `.help`。
    static func titleKey(of kind: ActivityKind) -> String {
        switch kind {
        case .remote: "activity.remote"
        case .repository: "activity.repository"
        case .service: "activity.service"
        }
    }
}

// MARK: - Toolbar

extension ActivityWindowController {
    /// 装上工具栏：只显示控件，不允许自定义。
    func configureToolbar() {
        let toolbar = NSToolbar(identifier: ActivityToolbar.identifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    /// 默认排布。
    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        ActivityToolbar.defaultItems
    }

    /// 可用的项与默认排布相同。
    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        ActivityToolbar.defaultItems
    }

    /// 按标识创建工具栏项。
    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        switch identifier {
        case ActivityToolbar.clearAll:
            makeClearAllItem()

        case ActivityToolbar.kinds:
            makeKindsItem()

        case ActivityToolbar.search:
            makeSearchItem()

        default:
            nil
        }
    }

    /// Clear All：清掉当前页已结束的记录，进行中的保留。
    @objc
    func clearAll(_: Any?) {
        activities.clearEnded(state.kind)
    }

    /// 分段换页；每段的 tag 是它在 `ActivityKind.allCases` 里的序号。
    @objc
    func selectKind(_ sender: NSToolbarItem) {
        let kinds = ActivityKind.allCases

        guard kinds.indices.contains(sender.tag) else {
            return
        }

        state.kind = kinds[sender.tag]
    }

    /// 搜索框的文字即时写入窗口状态，列表随之过滤。
    @objc
    func searchChanged(_ sender: NSSearchField) {
        state.query = sender.stringValue
    }
}

// MARK: - Private

extension ActivityWindowController {
    /// Clear All：只显示文字的按钮，标签、面板标签与提示都是按钮文字。
    private func makeClearAllItem() -> NSToolbarItem {
        let title = AppLocalization.text("activity.clear")

        let item = NSToolbarItem(itemIdentifier: ActivityToolbar.clearAll)
        item.label = title
        item.paletteLabel = title
        item.toolTip = title
        item.target = self
        item.action = #selector(clearAll(_:))

        let button = NSButton(title: title, target: self, action: #selector(clearAll(_:)))
        button.bezelStyle = .toolbar
        item.view = button

        return item
    }

    /// Remote | Repository | Service：单选的文字分段，选中当前页。
    private func makeKindsItem() -> NSToolbarItem {
        let kinds = ActivityKind.allCases
        let titles = kinds.map { AppLocalization.text(ActivityToolbar.titleKey(of: $0)) }

        let group = NSToolbarItemGroup(
            itemIdentifier: ActivityToolbar.kinds,
            titles: titles,
            selectionMode: .selectOne,
            labels: titles,
            target: self,
            action: nil
        )
        group.paletteLabel = AppLocalization.text("activity.title")

        // 每段带上自己的序号与提示，换页时据序号取页
        for (index, segment) in group.subitems.enumerated() {
            segment.tag = index
            segment.target = self
            segment.action = #selector(selectKind(_:))
            segment.toolTip = AppLocalization.text(ActivityToolbar.titleKey(of: kinds[index]) + ".help")
        }

        group.selectedIndex = kinds.firstIndex(of: state.kind) ?? 0

        return group
    }

    /// 搜索框：按仓库名与日志内容过滤当前页，提示与标签相同。
    private func makeSearchItem() -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: ActivityToolbar.search)
        item.label = AppLocalization.text("action.search")
        item.toolTip = item.label
        item.searchField.placeholderString = AppLocalization.text("activity.search")
        item.searchField.target = self
        item.searchField.action = #selector(searchChanged(_:))

        return item
    }
}
