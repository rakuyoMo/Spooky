import AppKit
import SpookyKit

// MARK: - DiffGutterView

/// 行号栏独立处理逻辑行的鼠标、键盘与辅助功能选择。
final class DiffGutterView: NSView {
    /// 提供逐行布局的块容器。
    weak var owner: DiffHunkTextContainer?

    /// 由块宿主提供的独立选择模型。
    private(set) var selection = DiffLineSelection()

    /// 当前逻辑行选区，只读栏始终为空。
    var selected: Set<Int> { readOnly ? [] : selection.selected }

    /// 当前键盘焦点所在的逻辑行。
    private(set) var focusedID: Int?

    /// 当前所有可操作的逻辑行。
    private(set) var selectable: [Int] = []

    /// 写入和重新加载期间不允许选择。
    private(set) var enabled = false

    /// 只读栏不参与键盘与辅助功能动作。
    private(set) var readOnly = true

    /// 指针所在的单个显示行，提示不与正文联动悬停。
    private(set) var hoveredIndex: Int?

    /// 已创建辅助功能元素的块。
    private var hunk: DiffHunk?

    /// 每个可操作逻辑行只暴露一个按钮。
    private var elements: [DiffGutterElement] = []

    /// 行号与正文使用相同的向下坐标。
    override var isFlipped: Bool { true }

    /// 一次 Tab 进入整条行号栏，再用方向键移动。
    override var acceptsFirstResponder: Bool { !readOnly && enabled && !selectable.isEmpty }

    /// 键盘焦点变化时重画焦点环。
    override func becomeFirstResponder() -> Bool {
        if focusedID == nil { focusedID = selectable.first }
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    /// 离开行号栏不清空逻辑行选区。
    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    /// 内容改变时重建逻辑行按钮，模型复用时只重新绑定绘制。
    func configure(hunk: DiffHunk, enabled: Bool, readOnly: Bool, selection: DiffLineSelection) {
        let readOnly = readOnly || hunk.combinedRanges != nil
        if self.hunk != hunk || self.selection !== selection { selection.bind(hunk) }
        self.selection = selection

        if self.hunk != hunk || self.readOnly != readOnly {
            self.hunk = hunk
            selectable = readOnly ? [] : hunk.lines.filter(\.isChange).map(\.id)
            elements = (readOnly ? [] : hunk.lines.filter(\.isChange)).map {
                DiffGutterElement(owner: self, line: $0)
            }
            if let focusedID, !selectable.contains(focusedID) { self.focusedID = nil }
        }

        self.enabled = enabled
        self.readOnly = readOnly
        if !enabled || readOnly {
            hoveredIndex = nil
            selection.cancelDrag()
        }
        selectionChanged()
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    /// Space 与 VoiceOver 按下是完整动作，计数立即发布。
    @discardableResult
    func select(_ id: Int, extending: Bool = false) -> Bool {
        guard enabled, !readOnly, selectable.contains(id), let index = selection.rows.firstIndex(of: id) else {
            return false
        }

        selection.activate(at: index, extending: extending)
        focus(id)
        selectionChanged()
        return true
    }

    /// 键盘和 VoiceOver 共用聚焦入口，焦点本身不改变选区。
    func focus(_ id: Int) {
        guard selectable.contains(id) else { return }

        if let focusedID { setNeedsDisplay(frame(for: focusedID)) }
        focusedID = id
        let rect = frame(for: id)
        if !rect.isNull { scrollToVisible(rect) }
        setNeedsDisplay(rect)
    }

    /// 在可操作逻辑行间移动，跳过上下文与重复的无换行提示。
    func moveFocus(by offset: Int) {
        guard enabled, !readOnly, !selectable.isEmpty else { return }

        let current = focusedID.flatMap { selectable.firstIndex(of: $0) }
        let next = current.map { min(max($0 + offset, 0), selectable.count - 1) }
            ?? (offset < 0 ? selectable.count - 1 : 0)
        focus(selectable[next])
    }

    /// 只有未选中的可选显示行有悬停态，正文与行号共用整块坐标。
    func hover(at point: CGPoint?) {
        var next: Int?
        if
            enabled, !readOnly, let point, let owner, owner.bounds.contains(point),
            let row = owner.textLayout?.row(at: point), selection.rows.indices.contains(row.index),
            let id = selection.rows[row.index], !selected.contains(id)
        {
            next = row.index
        }
        guard next != hoveredIndex else { return }

        for row in owner?.textLayout?.rows ?? [] where row.index == hoveredIndex || row.index == next {
            setNeedsDisplay(CGRect(x: 0, y: row.rect.minY, width: bounds.width, height: row.rect.height))
        }
        hoveredIndex = next
    }

    /// 即时重画受影响的正文，行号和辅助功能值同时读取同一模型。
    func selectionChanged() {
        if let hoveredIndex {
            let id = selection.rows.indices.contains(hoveredIndex) ? selection.rows[hoveredIndex] : nil
            if id.map({ selected.contains($0) }) ?? true { self.hoveredIndex = nil }
        }
        let changed = (owner?.paintedSelection ?? []).symmetricDifference(selected)
        owner?.updateLineSelection()
        for id in changed { setNeedsDisplay(frame(for: id)) }
    }

    /// 虚拟按钮作为行号栏的子元素，不复制正文文本的可访问性节点。
    override func accessibilityChildren() -> [Any]? { elements }

    /// 行号栏是可遍历的组。
    override func accessibilityRole() -> NSAccessibility.Role? { .group }

    /// 展示可操作行的辅助功能容器。
    override func isAccessibilityElement() -> Bool { !readOnly }

    /// 从实际折行区域取出逻辑行，不命中末尾空片段。
    func lineID(at point: CGPoint) -> Int? {
        guard let row = owner?.textLayout?.row(at: point) else { return nil }

        return owner?.content?.rows[row.index].line.lineID
    }

    /// 一个逻辑行的全部显示区域，供焦点环与辅助功能共用。
    func frame(for id: Int) -> CGRect {
        guard let content = owner?.content, let layout = owner?.textLayout else { return .zero }

        return layout.rows.filter { content.rows[$0.index].line.lineID == id }
            .reduce(CGRect.null) { $0.union(CGRect(x: 0, y: $1.rect.minY, width: bounds.width, height: $1.rect.height)) }
    }
}
