import AppKit
import SpookyKit

// MARK: - DiffGutterView

/// 行号栏独立处理逻辑行的鼠标、键盘与辅助功能选择。
final class DiffGutterView: NSView {
    /// 提供逐行布局的块容器。
    weak var owner: DiffHunkTextContainer?

    /// 行号选区变更后通知 SwiftUI，正文字符选区不受影响。
    var onSelectionChange: (Set<Int>) -> Void = { _ in }

    /// 当前逻辑行选区。
    private(set) var selected: Set<Int> = []

    /// 当前键盘焦点所在的逻辑行。
    private(set) var focusedID: Int?

    /// 当前所有可操作的逻辑行。
    private(set) var selectable: [Int] = []

    /// 写入和重新加载期间不允许选择。
    private(set) var enabled = false

    /// 只读栏不参与键盘与辅助功能动作。
    private var readOnly = true

    /// 已创建辅助功能元素的块。
    private var hunk: DiffHunk?

    /// 每个可操作逻辑行只暴露一个按钮。
    private var elements: [DiffGutterElement] = []

    /// ⇧ 范围选择的锚点。
    private var anchor: Int?

    /// 拖选的起始逻辑行。
    private var dragStart: Int?

    /// 拖选期间固定执行选中或取消。
    private var dragSelecting = false

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

    /// 内容改变时重建逻辑行按钮，单纯选区变化只刷新值与绘制。
    func configure(hunk: DiffHunk, enabled: Bool, readOnly: Bool, selected: Set<Int>) {
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
        self.selected = selected
        needsDisplay = true
    }

    /// 按逻辑行切换，⇧ 沿用锚点到目标的范围选择。
    @discardableResult
    func select(_ id: Int, extending: Bool = false) -> Bool {
        guard enabled, !readOnly, selectable.contains(id) else { return false }

        if extending, let anchor {
            selected.formUnion(selectable.filter { (min(anchor, id) ... max(anchor, id)).contains($0) })
        } else if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }

        anchor = id
        focus(id)
        onSelectionChange(selected)
        needsDisplay = true
        return true
    }

    /// 键盘和 VoiceOver 共用聚焦入口，焦点本身不改变选区。
    func focus(_ id: Int) {
        guard selectable.contains(id) else { return }

        focusedID = id
        scrollToVisible(id)
        needsDisplay = true
    }

    /// 在可操作逻辑行间移动，跳过上下文与重复的无换行提示。
    func moveFocus(by offset: Int) {
        guard enabled, !selectable.isEmpty else { return }

        let current = focusedID.flatMap { selectable.firstIndex(of: $0) }
        let next = current.map { min(max($0 + offset, 0), selectable.count - 1) }
            ?? (offset < 0 ? selectable.count - 1 : 0)
        focus(selectable[next])
    }

    /// 单击先决定本次拖选方向，再通过同一入口选择。
    override func mouseDown(with event: NSEvent) {
        guard
            enabled, !readOnly,
            let id = lineID(at: convert(event.locationInWindow, from: nil)),
            selectable.contains(id)
        else { return }

        window?.makeFirstResponder(self)
        dragStart = id
        dragSelecting = !selected.contains(id)
        select(id, extending: event.modifierFlags.contains(.shift))
    }

    /// 拖过的逻辑行一起选中或取消，折行命中仍映射到原始补丁行。
    override func mouseDragged(with event: NSEvent) {
        guard
            enabled, let start = dragStart,
            let end = lineID(at: convert(event.locationInWindow, from: nil))
        else { return }

        let range = min(start, end) ... max(start, end)

        for id in selectable where range.contains(id) {
            if dragSelecting { selected.insert(id) } else { selected.remove(id) }
        }

        onSelectionChange(selected)
        needsDisplay = true
    }

    /// 结束本次拖选，不影响已选行。
    override func mouseUp(with _: NSEvent) { dragStart = nil }

    /// Tab 按原生焦点链离开，方向键与 Space 在行号栏内操作。
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: moveFocus(by: 1)

        case 126: moveFocus(by: -1)

        case 49:
            if let focusedID { select(focusedID) }

        case 48:
            if event.modifierFlags.contains(.shift) {
                window?.selectPreviousKeyView(self)
            } else {
                window?.selectNextKeyView(self)
            }

        default: super.keyDown(with: event)
        }
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

    /// 焦点行滚到外层 ScrollView 的可见区域。
    private func scrollToVisible(_ id: Int) {
        let rect = frame(for: id)
        guard !rect.isNull else { return }

        scrollToVisible(rect)
    }
}
