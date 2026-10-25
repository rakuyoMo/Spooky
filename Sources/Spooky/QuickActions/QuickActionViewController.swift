import AppKit

// MARK: - QuickActionViewController

/// 快捷操作面板的内容：动作模式的对象条、30 pt 的输入框、分隔线与 40 pt 行高的结果表。
///
/// 焦点始终留在输入框里：方向键、Tab、↩ 与 Esc 都在输入框的命令里分发给状态控制器，单击结果行只把焦点还给输入框。
@MainActor
final class QuickActionViewController: NSViewController {
    /// 动作模式里对象条的高度；平时为 0。
    private static let headerHeight: CGFloat = 43

    /// 当前面板的状态；换了仓库或窗口时换成新的。
    private(set) var controller: QuickActionController?

    /// 关闭面板之后执行动作。
    private var perform: ((QuickActionObject, QuickAction) -> Void)?

    /// 关闭面板，由窗口控制器提供。
    var close: (() -> Void)?

    /// 对象条：符号、标题与副标题，底部一条分隔线。
    private let header = NSView()

    /// 对象条的符号。
    private let headerIcon = NSImageView()

    /// 对象条的标题。
    private let headerTitle = NSTextField(labelWithString: "")

    /// 对象条的副标题。
    private let headerSubtitle = NSTextField(labelWithString: "")

    /// 对象条的高度约束，进入与退出动作模式时切换。
    private var headerHeightConstraint: NSLayoutConstraint?

    /// 输入框。
    let inputField = NSTextField()

    /// 结果表。
    let tableView = NSTableView()

    /// 搭好对象条、输入框、分隔线与结果表。
    override func loadView() {
        let view = NSView(frame: NSRect(origin: .zero, size: QuickActionWindowController.contentSize))
        self.view = view

        configureHeader()
        configureInputField()
        configureTableView()

        let separator = NSBox()
        separator.boxType = .separator

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        for subview in [header, inputField, separator, scrollView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        activateConstraints(separator: separator, scrollView: scrollView)
    }

    /// 换上新的状态控制器，列表随状态变化刷新。
    ///
    /// - Parameter perform: 关闭面板之后对对象执行动作。
    func attach(_ controller: QuickActionController, perform: @escaping (QuickActionObject, QuickAction) -> Void) {
        self.controller?.onChange = nil
        self.controller = controller
        self.perform = perform

        controller.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    /// 把焦点放进输入框，并选中已有的文字。
    func focusInput() {
        view.window?.makeFirstResponder(inputField)
        inputField.currentEditor()?.selectAll(nil)
    }
}

// MARK: NSTextFieldDelegate

extension QuickActionViewController: NSTextFieldDelegate {
    /// 输入即搜。
    func controlTextDidChange(_: Notification) {
        controller?.setQuery(inputField.stringValue)
    }

    /// ↩、Tab、⇧Tab、→、←、Esc、↑ / ↓ 交给状态控制器，其余按键照常编辑输入。
    func control(_: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard let controller else {
            return false
        }

        let selection = textView.selectedRange()
        let length = textView.string.utf16.count

        let outcome: QuickActionController.Outcome
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): outcome = controller.insertNewline()

        case #selector(NSResponder.insertTab(_:)): outcome = controller.insertTab()

        case #selector(NSResponder.insertBacktab(_:)): outcome = controller.insertBacktab()

        case #selector(NSResponder.cancelOperation(_:)): outcome = controller.cancelOperation()

        case #selector(NSResponder.moveUp(_:)): controller.moveSelection(by: -1)
            outcome = .handled

        case #selector(NSResponder.moveDown(_:)): controller.moveSelection(by: 1)
            outcome = .handled

        case #selector(NSResponder.moveRight(_:)):
            outcome = controller.moveRight(atEnd: selection.length == 0 && selection.location == length)

        case #selector(NSResponder.moveLeft(_:)):
            outcome = controller.moveLeft(atStart: selection.length == 0 && selection.location == 0)

        default: return false
        }

        return handle(outcome)
    }
}

// MARK: NSTableViewDataSource, NSTableViewDelegate

extension QuickActionViewController: NSTableViewDataSource, NSTableViewDelegate {
    /// 没有结果且查询都已结束时只有一行 No Results。
    func numberOfRows(in _: NSTableView) -> Int {
        guard let controller else {
            return 0
        }

        return controller.showsNoResults ? 1 : controller.items.count
    }

    /// 结果行或 No Results 行。
    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let controller, controller.items.indices.contains(row) else {
            return tableView.makeView(withIdentifier: QuickActionEmptyCellView.identifier, owner: self)
                ?? QuickActionEmptyCellView()
        }

        let cell = tableView.makeView(withIdentifier: QuickActionCellView.identifier, owner: self) as? QuickActionCellView
            ?? QuickActionCellView()

        let item = controller.items[row]
        cell.configure(item, hint: hint(for: item))

        return cell
    }

    /// 自绘圆角选中底的行。
    func tableView(_ tableView: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        tableView.makeView(withIdentifier: QuickActionRowView.identifier, owner: self) as? QuickActionRowView
            ?? QuickActionRowView()
    }

    /// No Results 行不可选。
    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        controller?.items.indices.contains(row) ?? false
    }

    /// 鼠标改变的选中行同步给状态控制器。
    func tableViewSelectionDidChange(_: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }

        controller?.select(tableView.selectedRow)
    }
}

// MARK: - Actions

extension QuickActionViewController {
    /// 单击结果行只把焦点还给输入框。
    @objc
    private func clickTable() {
        view.window?.makeFirstResponder(inputField)
    }

    /// 双击执行这一行并关闭面板。
    @objc
    private func doubleClickTable() {
        guard let controller, tableView.clickedRow >= 0 else {
            return
        }

        if !handle(controller.performItem(at: tableView.clickedRow)) {
            view.window?.makeFirstResponder(inputField)
        }
    }

    /// 按命令的结果关闭面板、响铃或执行动作；返回命令是否已被处理。
    @discardableResult
    private func handle(_ outcome: QuickActionController.Outcome) -> Bool {
        switch outcome {
        case .handled:
            return true

        case .ignored:
            return false

        case .beep:
            NSSound.beep()
            return true

        case .close:
            close?()
            return true

        case .perform(let object, let action):
            close?()
            perform?(object, action)
            return true
        }
    }

    /// 输入、对象条与结果表跟上状态；选中行滚动到可见处。
    private func refresh() {
        guard isViewLoaded, let controller else {
            return
        }

        if inputField.stringValue != controller.query {
            inputField.stringValue = controller.query
        }

        updateHeader(controller.activeObject)
        tableView.reloadData()

        if let index = controller.selectedIndex {
            tableView.selectRowIndexes([index], byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        } else {
            tableView.deselectAll(nil)
        }
    }

    /// 对象行的提示是默认动作与 More Actions 两行，动作行只有 ↩︎。
    private func hint(for item: QuickActionItem) -> String {
        guard item.action == nil, let controller else {
            return "↩︎"
        }

        let action = controller.catalog.defaultAction(for: item.object)

        return AppLocalization.text("quickActions.objectHint", action.title(for: item.object.kind))
    }
}

// MARK: - Layout

extension QuickActionViewController {
    /// 对象条：符号距左 20 pt，标题距顶 6 pt，副标题紧贴标题；底部一条分隔线。
    private func configureHeader() {
        header.wantsLayer = true
        header.layer?.masksToBounds = true

        headerIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .large)
        headerTitle.font = .systemFont(ofSize: 13)
        headerTitle.textColor = .controlTextColor
        headerTitle.lineBreakMode = .byTruncatingTail
        headerSubtitle.font = .systemFont(ofSize: 10)
        headerSubtitle.textColor = .secondaryLabelColor
        headerSubtitle.lineBreakMode = .byTruncatingTail

        let separator = NSBox()
        separator.boxType = .separator

        for subview in [headerIcon, headerTitle, headerSubtitle, separator] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            headerIcon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            headerIcon.topAnchor.constraint(equalTo: header.topAnchor, constant: 5),
            headerIcon.widthAnchor.constraint(equalToConstant: 32),
            headerIcon.heightAnchor.constraint(equalToConstant: 30),

            headerTitle.leadingAnchor.constraint(equalTo: headerIcon.trailingAnchor, constant: 8),
            headerTitle.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            headerTitle.topAnchor.constraint(equalTo: header.topAnchor, constant: 6),

            headerSubtitle.leadingAnchor.constraint(equalTo: headerTitle.leadingAnchor),
            headerSubtitle.trailingAnchor.constraint(equalTo: headerTitle.trailingAnchor),
            headerSubtitle.topAnchor.constraint(equalTo: headerTitle.bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),
        ])
    }

    /// 30 pt 系统字体、没有边框与焦点环的输入框。
    private func configureInputField() {
        inputField.font = .systemFont(ofSize: 30)
        inputField.placeholderString = AppLocalization.text("quickActions.placeholder")
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.lineBreakMode = .byClipping
        inputField.usesSingleLineMode = true
        inputField.delegate = self
        inputField.setAccessibilityLabel(AppLocalization.text("quickActions.placeholder"))
    }

    /// 不画背景、行间距为 0、行高 40 pt 的单列表格。
    private func configureTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("QuickActionColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.headerView = nil
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = .zero
        tableView.rowHeight = QuickActionCellView.height
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.focusRingType = .none
        tableView.refusesFirstResponder = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(clickTable)
        tableView.doubleAction = #selector(doubleClickTable)
    }

    /// 输入框左右各 20 pt、距对象条 9 pt、最小宽 190 pt；分隔线在输入框下方 7 pt，结果表铺满其下。
    private func activateConstraints(separator: NSBox, scrollView: NSScrollView) {
        let headerHeight = header.heightAnchor.constraint(equalToConstant: 0)
        headerHeightConstraint = headerHeight

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.topAnchor.constraint(equalTo: view.topAnchor),
            headerHeight,

            inputField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inputField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            inputField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 9),
            inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 190),

            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.topAnchor.constraint(equalTo: inputField.bottomAnchor, constant: 7),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// 动作模式里对象条显示对象，平时收起。
    private func updateHeader(_ object: QuickActionObject?) {
        headerHeightConstraint?.constant = object == nil ? 0 : Self.headerHeight

        guard let object else {
            return
        }

        headerIcon.image = NSImage(systemSymbolName: object.symbol, accessibilityDescription: nil)
        headerTitle.stringValue = object.title
        headerSubtitle.stringValue = object.subtitle
    }
}
