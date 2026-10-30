import AppKit
import SwiftUI

// MARK: - ThemeTokenList

/// Themes 页的记号类别列表：每行一种语法颜色，名称用正在编辑的主题的字体与这一行的颜色书写。
///
/// 选中的行决定 Font Color 色块编辑哪种颜色；列表底色与选中行的底色取自主题的 `background` 与 `selection`。
struct ThemeTokenList: NSViewRepresentable {
    /// 列表的行：25 pt 高，名称垂直居中，底边 1 pt 是分隔线。
    ///
    /// 选中的行整格填主题的选区色，它上下的两条分隔线都不画；名称颜色不随选中改变。
    final class RowView: NSTableRowView {
        /// 选中时的底色，取自主题的 `selection`。
        var selectionColor = NSColor.clear {
            didSet { needsDisplay = true }
        }

        /// 名称在选中时保持原来的颜色，不换成系统选中样式的文字色。
        override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }

        /// 只画底边的分隔线，底色由表格按主题画；这一行或下一行被选中时不画。
        override func drawBackground(in _: NSRect) {
            guard !isSelected, !isNextRowSelected else {
                return
            }

            NSColor.separatorColor.setFill()

            // 分隔线是半透明的系统色，叠在主题的底色上画。
            NSRect(
                x: 0,
                y: isFlipped ? bounds.maxY - 1 : bounds.minY,
                width: bounds.width,
                height: 1
            )
            .fill(using: .sourceOver)
        }

        /// 整格填选区色，列表在不在键盘焦点上都一样。
        override func drawSelection(in _: NSRect) {
            selectionColor.setFill()
            bounds.fill(using: .sourceOver)
        }
    }

    /// 20 行的颜色键，从上到下；加上色块行的四种颜色，就是主题文件的全部颜色。
    nonisolated static let keys = [
        "text",
        "invisible",
        "keyword",
        "identifier",
        "function",
        "number",
        "string",
        "symbol",
        "comment",
        "preprocessor",
        "xmlTag",
        "attributeName",
        "attributeValue",
        "cssSelector",
        "heading",
        "codeBlock",
        "delimiter",
        "emphasized",
        "stronglyEmphasized",
        "url",
    ]

    /// 正在编辑的主题；字体或颜色变化时重画各行。
    let theme: TextTheme

    /// 选中行的颜色键。
    @Binding
    var selection: String

    /// 建立表格委托。
    func makeCoordinator() -> ThemeTokenListCoordinator { ThemeTokenListCoordinator(self) }

    /// 单列、无表头、不允许空选的表格，每格 25 pt。
    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = NSTableView()
        table.addTableColumn(NSTableColumn(identifier: .init("token")))
        table.headerView = nil
        table.style = .plain

        // 每格 25 pt，行与行之间不留间隙，分隔线由行自己画在底边。
        table.rowSizeStyle = .custom
        table.rowHeight = 25
        table.intercellSpacing = .zero

        table.allowsEmptySelection = false
        table.allowsMultipleSelection = false
        table.dataSource = coordinator
        table.delegate = coordinator

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true

        coordinator.table = table
        coordinator.update(self)
        return scroll
    }

    /// 同步主题与选中行。
    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }
}

// MARK: - ThemeTokenListCoordinator

/// 记号类别列表的数据源与委托：按主题绘制各行，把用户选中的行写回绑定。
@MainActor
final class ThemeTokenListCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    /// 单元格的复用标识。
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("token")

    /// 当前 SwiftUI 输入。
    private var parent: ThemeTokenList

    /// 原生表格。
    weak var table: NSTableView?

    /// 已经画上的主题，决定是否重画。
    private var displayed: TextTheme?

    /// 程序同步选区时忽略表格的选择通知，避免在视图更新中写回绑定。
    private var isUpdating = false

    /// 建立与 SwiftUI 输入的绑定。
    init(_ parent: ThemeTokenList) {
        self.parent = parent
    }

    /// 主题变化时换底色、选区色并重画各行的名称，再把选区移到绑定的颜色键。
    func update(_ parent: ThemeTokenList) {
        self.parent = parent

        guard let table else {
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        if parent.theme != displayed {
            displayed = parent.theme
            redraw(table)
        }

        guard
            let row = ThemeTokenList.keys.firstIndex(of: parent.selection),
            table.selectedRow != row
        else { return }

        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    /// 行数固定为 20。
    func numberOfRows(in _: NSTableView) -> Int { ThemeTokenList.keys.count }

    /// 画选区色与分隔线的行。
    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        let rowView = ThemeTokenList.RowView()
        rowView.selectionColor = color("selection", fallback: .selectedContentBackgroundColor)
        return rowView
    }

    /// 一行的名称：主题的字体，这一行的颜色，含透明度。
    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.cellIdentifier, owner: nil) as? NSTableCellView
            ?? makeCell()

        let key = ThemeTokenList.keys[row]
        cell.textField?.stringValue = AppLocalization.text("themes.token." + key)
        cell.textField?.font = parent.theme.font

        // 主题缺少的颜色按正文色画，与文本区的取色规则相同。
        cell.textField?.textColor = color(key, fallback: color("text", fallback: .textColor))

        return cell
    }

    /// 用户选中另一行：写回绑定，Font Color 色块随之编辑这一行的颜色。
    func tableViewSelectionDidChange(_: Notification) {
        guard
            !isUpdating,
            let table,
            ThemeTokenList.keys.indices.contains(table.selectedRow)
        else { return }

        parent.selection = ThemeTokenList.keys[table.selectedRow]
    }

    /// 换上主题的底色与选区色，重画全部行的名称；滚动位置与选区不变。
    private func redraw(_ table: NSTableView) {
        let background = color("background", fallback: .textBackgroundColor)
        table.backgroundColor = background
        table.enclosingScrollView?.backgroundColor = background

        let selection = color("selection", fallback: .selectedContentBackgroundColor)

        table.enumerateAvailableRowViews { rowView, _ in
            (rowView as? ThemeTokenList.RowView)?.selectionColor = selection
        }

        table.reloadData(
            forRowIndexes: IndexSet(integersIn: ThemeTokenList.keys.indices),
            columnIndexes: IndexSet(integer: 0)
        )
    }

    /// 名称距左 12 pt，在行里垂直居中。
    private func makeCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = Self.cellIdentifier

        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(field)
        cell.textField = field

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            field.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -12),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }

    /// 取主题里的颜色，缺少时用给定的颜色。
    private func color(_ key: String, fallback: NSColor) -> NSColor {
        parent.theme.colors[key]?.nsColor ?? fallback
    }
}
