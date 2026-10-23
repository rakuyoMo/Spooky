import AppKit
import SwiftUI

// MARK: - ThemeListView

/// 主题列表：不允许空选，选中的主题即当前外观使用的主题。
///
/// 用户主题可以在行内改名；行拖到 Finder 导出成主题文件，主题文件拖进列表即导入。
struct ThemeListView: NSViewRepresentable {
    /// 回车键开始改名；其它按键交给系统列表。
    final class ThemeTableView: NSTableView {
        /// 开始改名所选主题。
        var beginRename: (() -> Void)?

        /// 回车与小键盘 Enter 是行内改名的键盘入口。
        override func keyDown(with event: NSEvent) {
            let isReturn = [36, 76].contains(event.keyCode)
            let plain = event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift])

            guard isReturn, plain, let beginRename else {
                super.keyDown(with: event)

                return
            }

            beginRename()
        }
    }

    /// 主题存储。
    let store: ThemeStore

    /// 列表内容，取自存储；名称或顺序变化时重载表格。
    let themes: [TextTheme]

    /// 当前外观的所选主题。
    let selectedID: String

    /// 是否为深色外观：选中的行写入这一外观的主题选择。
    let dark: Bool

    /// 建立表格委托。
    func makeCoordinator() -> ThemeListCoordinator { ThemeListCoordinator(self) }

    /// 单列、无表头的表格，接受文件拖入，可向其它 App 拖出。
    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = ThemeTableView()
        table.addTableColumn(NSTableColumn(identifier: .init("name")))
        table.headerView = nil
        table.style = .fullWidth
        table.allowsEmptySelection = false
        table.allowsMultipleSelection = false
        table.dataSource = coordinator
        table.delegate = coordinator
        table.registerForDraggedTypes([.fileURL])
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        table.setAccessibilityLabel(AppLocalization.text("settings.themes"))
        table.beginRename = { [weak coordinator] in coordinator?.beginRename() }

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        coordinator.table = table
        coordinator.update(self)
        return scroll
    }

    /// 同步列表内容与所选行。
    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }
}

// MARK: - ThemeListCoordinator

/// 主题列表的数据源与委托：选择、改名、拖出导出与拖入导入。
@MainActor
final class ThemeListCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    /// 当前 SwiftUI 输入。
    private var parent: ThemeListView

    /// 原生表格。
    weak var table: NSTableView?

    /// 已显示的主题标识与名称，决定是否重载。
    private var displayed: [[String]] = []

    /// 程序同步选区时忽略表格的选择通知，避免写回外观选择。
    private var isUpdating = false

    /// 建立与 SwiftUI 输入的绑定。
    init(_ parent: ThemeListView) {
        self.parent = parent
    }

    /// 名称或顺序变化时重载，再把选区移到当前外观的所选主题。
    func update(_ parent: ThemeListView) {
        self.parent = parent

        guard let table else {
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        let rows = parent.themes.map { [$0.id, $0.name] }

        if rows != displayed {
            displayed = rows
            table.reloadData()
        }

        guard
            let row = parent.themes.firstIndex(where: { $0.id == parent.selectedID }),
            table.selectedRow != row
        else { return }

        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    /// 开始改名所选的用户主题；内置主题不能改名。
    func beginRename() {
        guard
            let table,
            parent.themes.indices.contains(table.selectedRow),
            !parent.themes[table.selectedRow].isBuiltin
        else { return }

        table.editColumn(0, row: table.selectedRow, with: nil, select: true)
    }

    /// 行数即主题数。
    func numberOfRows(in _: NSTableView) -> Int { parent.themes.count }

    /// 每行一个名称文本框，只有用户主题可编辑。
    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard parent.themes.indices.contains(row) else {
            return nil
        }

        let theme = parent.themes[row]
        let identifier = NSUserInterfaceItemIdentifier("theme-name")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
            ?? Self.makeCell(identifier)

        cell.textField?.stringValue = theme.name
        cell.textField?.isEditable = !theme.isBuiltin
        cell.textField?.delegate = self
        return cell
    }

    /// 用户点选的行设为当前外观的主题。
    func tableViewSelectionDidChange(_: Notification) {
        guard
            !isUpdating,
            let table,
            parent.themes.indices.contains(table.selectedRow)
        else { return }

        parent.store.select(parent.themes[table.selectedRow].id, dark: parent.dark)
    }

    /// 结束行内编辑时改名；名称为空、未变或被占用时恢复原名，被占用另行提示。
    func controlTextDidEndEditing(_ notification: Notification) {
        guard
            let field = notification.object as? NSTextField,
            let table,
            parent.themes.indices.contains(table.row(for: field))
        else { return }

        let identifier = parent.themes[table.row(for: field)].id

        do {
            try parent.store.rename(identifier, to: field.stringValue)
        } catch {
            let window = table.window
            Task { await ThemeTransfer.report(error, titleKey: "themes.error.rename", file: nil, window: window) }
        }

        // 文本框显示存储里的实际名称，改名没有生效时回到原名。
        field.stringValue = parent.store.themes.first { $0.id == identifier }?.name ?? field.stringValue
    }

    /// 行拖出时提供文件承诺，放到 Finder 后写出主题文件。
    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        guard parent.themes.indices.contains(row) else {
            return nil
        }

        let provider = NSFilePromiseProvider(fileType: TextTheme.fileType.identifier, delegate: self)
        provider.userInfo = parent.themes[row]
        return provider
    }

    /// 只接受主题文件，落点是整张列表。
    func tableView(
        _ tableView: NSTableView,
        validateDrop info: any NSDraggingInfo,
        proposedRow _: Int,
        proposedDropOperation _: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard !Self.themeFiles(in: info).isEmpty else {
            return []
        }

        tableView.setDropRow(-1, dropOperation: .on)
        return .copy
    }

    /// 拖放结束后再逐个导入，覆盖确认不阻塞拖放会话。
    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: any NSDraggingInfo,
        row _: Int,
        dropOperation _: NSTableView.DropOperation
    ) -> Bool {
        let urls = Self.themeFiles(in: info)

        guard !urls.isEmpty else {
            return false
        }

        let store = parent.store
        let window = tableView.window
        Task { await ThemeTransfer.importThemes(urls, into: store, window: window) }
        return true
    }
}

// MARK: NSFilePromiseProviderDelegate

extension ThemeListCoordinator: NSFilePromiseProviderDelegate {
    /// 导出的文件名取主题名称。
    nonisolated func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType _: String) -> String {
        (provider.userInfo as? TextTheme).map { TextTheme.fileName(for: $0.name) } ?? ""
    }

    /// 在主队列写出文件，目标已有同名文件时可以弹出覆盖确认。
    nonisolated func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue { .main }

    /// 写出拖出的主题；不覆盖已有文件时以用户取消结束。
    nonisolated func filePromiseProvider(
        _ provider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let theme = provider.userInfo as? TextTheme else {
            completionHandler(CocoaError(.fileWriteUnknown))
            return
        }

        // 文件承诺的操作队列是主队列，可以直接调用界面代码。
        let error = MainActor.assumeIsolated { ThemeTransfer.writePromise(theme, to: url) }
        completionHandler(error)
    }
}

// MARK: - Helpers

extension ThemeListCoordinator {
    /// 拖动信息里的主题文件，按扩展名识别。
    private static func themeFiles(in info: any NSDraggingInfo) -> [URL] {
        let items = info.draggingPasteboard.pasteboardItems ?? []

        return items
            .compactMap { $0.string(forType: .fileURL).flatMap { URL(string: $0) } }
            .filter { $0.isFileURL && $0.pathExtension.lowercased() == TextTheme.fileExtension }
    }

    /// 单元格：一行可编辑的名称，过长时截断末尾。
    private static func makeCell(_ identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false

        let cell = NSTableCellView()
        cell.identifier = identifier
        cell.textField = field
        cell.addSubview(field)

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}
