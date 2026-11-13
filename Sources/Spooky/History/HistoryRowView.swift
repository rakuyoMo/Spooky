import AppKit

// MARK: - HistoryRowView

/// 历史列表的行视图：提交行在底边画一条系统分隔线，从头像（中号）或短哈希（小号）的左缘画到单元格的右缘；
/// 选中底的形状沿用系统的 inset 样式，颜色随焦点与窗口状态变化，变化方式与侧边栏的选中行相同。
final class HistoryRowView: NSTableRowView {
    /// 复用行视图的标识。
    static let identifier = NSUserInterfaceItemIdentifier("history-row")

    /// 分隔线起点距单元格左缘的距离；nil 时不画分隔线。
    var separatorInset: CGFloat? {
        didSet {
            separator.isHidden = separatorInset == nil
            needsLayout = true
        }
    }

    /// 分隔线；叠在单元格之上，未拉取提交的弱化底色不会盖住它。
    let separator = HistoryRowSeparator()

    /// 建立不画分隔线的行视图。
    ///
    /// - Parameter frame: 行视图的初始位置与尺寸。
    override init(frame: NSRect) {
        super.init(frame: frame)

        identifier = Self.identifier
        separator.isHidden = true
        addSubview(separator)
    }

    /// 行视图只由代码创建。
    required init?(coder _: NSCoder) { nil }

    /// 选中底的颜色。
    ///
    /// - Parameters:
    ///   - emphasized: 列表是第一响应者。
    ///   - key: 窗口是 key window。
    ///   - background: 列表的底色，窗口不是 key window 时与未强调的选中色各取一半。
    static func selectionColor(emphasized: Bool, key: Bool, background: NSColor) -> NSColor {
        let unemphasized = NSColor.unemphasizedSelectedContentBackgroundColor

        guard key else {
            return unemphasized.blended(withFraction: 0.5, of: background) ?? unemphasized
        }

        return emphasized ? .controlAccentColor : unemphasized
    }

    /// 窗口成为或不再是 key window 时，选中底的颜色随之变化，需要重画。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

        guard let window else {
            return
        }

        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyStateChanged),
                name: name,
                object: window
            )
        }
    }

    /// 先让系统按 inset 样式画出选中底，再在同一透明层里把它整片换成 `selectionColor` 的颜色；边距、圆角与相邻选中行的连接都保持系统的画法。
    override func drawSelection(in dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let table = superview as? NSTableView

        let color = Self.selectionColor(
            emphasized: isEmphasized,
            key: window?.isKeyWindow ?? false,
            background: table?.backgroundColor ?? .controlBackgroundColor
        )

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        super.drawSelection(in: dirtyRect)

        // 只在系统画过的地方上色
        color.setFill()
        bounds.fill(using: .sourceIn)

        context.endTransparencyLayer()
    }

    /// 单元格之后才加进来，每加一个子视图都把分隔线重新放回最上面，并按新单元格重新排布。
    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)

        guard subview !== separator else {
            return
        }

        addSubview(separator, positioned: .above, relativeTo: nil)
        needsLayout = true
    }

    /// 分隔线贴着行的底边，横向从单元格左缘加上 `separatorInset` 起，到单元格右缘止。
    override func layout() {
        super.layout()

        // 单元格的位置随列表样式缩进，没有单元格时按整行算
        let cell = (view(atColumn: 0) as? NSView)?.frame ?? bounds
        let inset = separatorInset ?? 0

        #warning(
            "TODO: 分隔线贴着行的底边；中号行的头像在行内上下居中，分隔线离头像底 6 pt，小号行离短哈希底约 5 pt，比要求的 7 pt、6 pt 各少 1 pt，是否把行内的头像与文字上移 1 pt 未定。核实方式：深浅色 2× 截图量出头像、短哈希到分隔线的距离；只影响提交行内容的纵向位置。"
        )

        separator.frame = NSRect(
            x: cell.minX + inset,
            y: isFlipped ? bounds.maxY - 1 : bounds.minY,
            width: max(0, cell.width - inset),
            height: 1
        )
    }

    /// 选中的行按新的窗口状态重画选中底。
    @objc
    private func keyStateChanged() {
        if isSelected {
            needsDisplay = true
        }
    }
}

// MARK: - HistoryCommitTable.Coordinator

extension HistoryCommitTable.Coordinator {
    /// 每一行都用历史列表的行视图；提交行画分隔线，下一行是日期分组的标题时不画，其它种类的行也不画。
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView =
            tableView.makeView(withIdentifier: HistoryRowView.identifier, owner: nil) as? HistoryRowView
                ?? HistoryRowView()

        let rows = parent.session.history.rows
        let next = rows.indices.contains(row + 1) ? rows[row + 1] : nil

        guard rows.indices.contains(row), let commit = rows[row].commit else {
            rowView.separatorInset = nil
            return rowView
        }

        if case .group? = next {
            rowView.separatorInset = nil
            return rowView
        }

        // 起点与单元格里头像或短哈希的左缘对齐，显示提交图时在图的右侧
        let graph = parent.showGraph ? parent.session.history.graphRows[commit.id] : nil
        rowView.separatorInset = HistoryCommitRow.contentLeading(graph: graph)

        return rowView
    }
}

// MARK: - HistoryRowSeparator

/// 1 pt 高的系统分隔线，颜色随外观变化，不参与鼠标命中。
final class HistoryRowSeparator: NSView {
    /// 不抢占提交行的点按、右键与拖动。
    override func hitTest(_: NSPoint) -> NSView? { nil }

    /// 用系统分隔线颜色填满自身。
    override func draw(_: NSRect) {
        NSColor.separatorColor.setFill()
        bounds.fill()
    }
}
