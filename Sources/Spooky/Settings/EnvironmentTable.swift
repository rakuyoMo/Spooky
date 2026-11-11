import AppKit
import SwiftUI

// MARK: - EnvironmentTable

/// Environment 页的变量表：变量名一列宽 260 pt，值一列占满其余宽度；行高 24 pt，行间画实线，内容以下的空行也画。
///
/// 只读的表不能选中；可编辑的表可以多选，点按格子编辑，结束编辑时写回。
struct EnvironmentTable: NSViewRepresentable {
    /// 表格里的一个变量。
    struct Variable: Equatable {
        /// 变量名。
        let name: String

        /// 变量的值。
        let value: String
    }

    /// 表格的两列。
    enum Column: String {
        /// 变量名。
        case name

        /// 变量的值。
        case value
    }

    /// 按显示顺序排列的变量。
    let variables: [Variable]

    /// 选中的行；只读的表为 nil。
    var selection: Binding<IndexSet>?

    /// 结束编辑一个格子时写回所在的行、列与文字；只读的表为 nil。
    var commit: ((Int, Column, String) -> Void)?

    /// 要开始编辑变量名的行，开始编辑后清空；只读的表为 nil。
    var editRequest: Binding<Int?>?

    /// 辅助功能读出的表格名称。
    let label: String

    /// 建立表格的数据源与委托。
    func makeCoordinator() -> EnvironmentTableCoordinator { EnvironmentTableCoordinator(self) }

    /// 带表头的两列表格，放在不画边框的滚动区里，边框由页面统一画。
    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = NSTableView()
        table.style = .fullWidth

        // 变量名一列固定 260 pt，表格变宽或变窄时只调整值一列。
        table.addTableColumn(Self.column(.name, width: 260))
        table.addTableColumn(Self.column(.value, width: 260))
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        // 每行 24 pt，行间画实线，列间留 17 pt。
        table.rowSizeStyle = .custom
        table.rowHeight = 24
        table.intercellSpacing = NSSize(width: 17, height: 0)
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.usesAlternatingRowBackgroundColors = false

        table.allowsMultipleSelection = true
        table.dataSource = coordinator
        table.delegate = coordinator
        table.setAccessibilityLabel(label)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder

        coordinator.table = table
        coordinator.update(self)
        return scroll
    }

    /// 同步变量、选区与开始编辑的请求。
    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }
}

// MARK: - Private

extension EnvironmentTable {
    /// 一列：表头是本地化的列名。
    private static func column(_ column: Column, width: CGFloat) -> NSTableColumn {
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
        tableColumn.title = title(column)
        tableColumn.width = width
        tableColumn.minWidth = 40
        return tableColumn
    }

    /// 列名，也是格子的辅助功能名称。
    fileprivate static func title(_ column: Column) -> String {
        switch column {
        case .name: AppLocalization.text("settings.environment.key")
        case .value: AppLocalization.text("settings.environment.value")
        }
    }
}

// MARK: - EnvironmentTableCoordinator

/// 变量表的数据源与委托：显示变量、同步选区、写回编辑。
@MainActor
final class EnvironmentTableCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    /// 当前 SwiftUI 输入。
    private var parent: EnvironmentTable

    /// 原生表格。
    weak var table: NSTableView?

    /// 已显示的变量，决定重载哪些行。
    private var displayed: [EnvironmentTable.Variable] = []

    /// 程序同步选区时忽略表格的选择通知，避免写回选区。
    private var isUpdating = false

    /// 已经接下开始编辑的请求、还没清空它；期间再次同步时不重复处理。
    private var isHandlingEditRequest = false

    /// 建立与 SwiftUI 输入的绑定。
    init(_ parent: EnvironmentTable) {
        self.parent = parent
    }

    /// 变量变化时重载，再同步选区；有开始编辑的请求时选中那一行并编辑变量名。
    func update(_ parent: EnvironmentTable) {
        self.parent = parent

        guard let table else {
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        reload(table, with: parent.variables)

        if
            let selection = parent.selection?.wrappedValue,
            table.selectedRowIndexes != selection
        {
            table.selectRowIndexes(selection, byExtendingSelection: false)
        }

        // 请求在视图更新之外清空并开始编辑，期间再次同步时不重复处理。
        guard
            !isHandlingEditRequest,
            let request = parent.editRequest,
            let row = request.wrappedValue
        else { return }

        isHandlingEditRequest = true

        Task { @MainActor [weak self] in
            request.wrappedValue = nil
            self?.isHandlingEditRequest = false
            self?.beginEditing(row: row)
        }
    }

    /// 行数即变量数。
    func numberOfRows(in _: NSTableView) -> Int { parent.variables.count }

    /// 每个格子一个文本框；可编辑的表里文本框可以直接编辑。
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard
            let tableColumn,
            let column = EnvironmentTable.Column(rawValue: tableColumn.identifier.rawValue),
            parent.variables.indices.contains(row)
        else { return nil }

        let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView
            ?? Self.makeCell(tableColumn.identifier, column: column)

        let variable = parent.variables[row]
        cell.textField?.stringValue = column == .name ? variable.name : variable.value

        // 复用的格子可能来自另一张表，可编辑与委托一起设。
        let editable = parent.commit != nil
        cell.textField?.isEditable = editable
        cell.textField?.isSelectable = editable
        cell.textField?.delegate = self

        return cell
    }

    /// 只读的表不能选中行。
    func tableView(_: NSTableView, shouldSelectRow _: Int) -> Bool {
        parent.selection != nil
    }

    /// 用户改变的选区写回 SwiftUI。
    func tableViewSelectionDidChange(_: Notification) {
        guard !isUpdating, let table, let selection = parent.selection else {
            return
        }

        selection.wrappedValue = table.selectedRowIndexes
    }

    /// 结束编辑一个格子时写回所在的行、列与文字。
    func controlTextDidEndEditing(_ notification: Notification) {
        guard
            let field = notification.object as? NSTextField,
            let table,
            let commit = parent.commit
        else { return }

        let row = table.row(for: field)
        let columnIndex = table.column(for: field)

        guard
            parent.variables.indices.contains(row),
            table.tableColumns.indices.contains(columnIndex),
            let column = EnvironmentTable.Column(rawValue: table.tableColumns[columnIndex].identifier.rawValue)
        else { return }

        commit(row, column, field.stringValue)
    }
}

// MARK: - Helpers

extension EnvironmentTableCoordinator {
    /// 格子：一行系统字体 13 pt 的文字，过长时截断末尾，竖直居中。
    private static func makeCell(
        _ identifier: NSUserInterfaceItemIdentifier,
        column: EnvironmentTable.Column
    ) -> NSTableCellView {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 13)
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setAccessibilityLabel(EnvironmentTable.title(column))

        let cell = NSTableCellView()
        cell.identifier = identifier
        cell.textField = field
        cell.addSubview(field)

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }

    /// 行数变化时整表重载；行数不变时只重载变了的行，不打断其它格子正在进行的编辑。
    private func reload(_ table: NSTableView, with variables: [EnvironmentTable.Variable]) {
        guard variables != displayed else {
            return
        }

        defer { displayed = variables }

        guard variables.count == displayed.count else {
            table.reloadData()
            return
        }

        let changed = IndexSet(variables.indices.filter { variables[$0] != displayed[$0] })
        table.reloadData(forRowIndexes: changed, columnIndexes: IndexSet(table.tableColumns.indices))
    }

    /// 选中一行并开始编辑它的变量名。
    private func beginEditing(row: Int) {
        guard let table, parent.variables.indices.contains(row) else {
            return
        }

        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
        table.editColumn(0, row: row, with: nil, select: true)
    }
}
