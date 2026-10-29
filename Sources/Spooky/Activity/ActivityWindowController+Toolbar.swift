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

    /// 换页：点分段时取选中的段，从 » 菜单选子项时取它的 tag，两者都是页在 `ActivityKind.allCases` 里的序号；换页后分段选中同一页。
    @objc
    func selectKind(_ sender: Any?) {
        let kinds = ActivityKind.allCases

        let index = (sender as? NSSegmentedControl)?.selectedSegment
            ?? (sender as? NSValidatedUserInterfaceItem)?.tag

        guard let index, kinds.indices.contains(index) else {
            return
        }

        state.kind = kinds[index]

        // » 菜单换页时分段不在工具栏上，同样改它的选中，拉宽窗口后显示的是当前页
        let group = window?.toolbar?.items.first { $0.itemIdentifier == ActivityToolbar.kinds }
        (group?.view as? NSSegmentedControl)?.selectedSegment = index
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

    /// Remote | Repository | Service：自建的单选分段，每段宽度随文字；窗口窄时整组移进 » 菜单，菜单里是三个子项。
    private func makeKindsItem() -> NSToolbarItem {
        let kinds = ActivityKind.allCases

        let control = NSSegmentedControl()
        control.segmentCount = kinds.count
        control.trackingMode = .selectOne
        control.segmentStyle = .texturedRounded
        control.segmentDistribution = .fit
        control.target = self
        control.action = #selector(selectKind(_:))

        let group = NSToolbarItemGroup(itemIdentifier: ActivityToolbar.kinds)
        group.paletteLabel = AppLocalization.text("activity.title")
        group.subitems = kinds.map(makeKindItem(_:))

        // 每段的标题与提示取自同序号的子项
        for (index, item) in group.subitems.enumerated() {
            control.setLabel(item.label, forSegment: index)
            control.setToolTip(item.toolTip, forSegment: index)
        }

        control.selectedSegment = kinds.firstIndex(of: state.kind) ?? 0
        group.view = control

        return group
    }

    /// 一页的子项：» 菜单里显示它的标签，tag 是页的序号，提示供分段的同一段使用。
    private func makeKindItem(_ kind: ActivityKind) -> NSToolbarItem {
        let key = ActivityToolbar.titleKey(of: kind)

        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(key))
        item.label = AppLocalization.text(key)
        item.toolTip = AppLocalization.text(key + ".help")
        item.tag = ActivityKind.allCases.firstIndex(of: kind) ?? 0
        item.target = self
        item.action = #selector(selectKind(_:))

        return item
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
