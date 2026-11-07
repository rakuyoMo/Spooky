import AppKit

extension DiffGutterView {
    /// 上下文也记录按下位置，以便拖动经过可选行时确定方向。
    override func mouseDown(with event: NSEvent) {
        guard enabled, !readOnly, let row = owner?.textLayout?.row(at: convert(event.locationInWindow, from: nil)) else {
            return
        }

        window?.makeFirstResponder(self)
        selection.begin(at: row.index, extending: event.modifierFlags.contains(.shift))
        if let id = selection.rows[row.index] { focus(id) }
        selectionChanged()
    }

    /// 拖动只在本块实际行矩形内处理，不跨到相邻块或末尾空片段。
    override func mouseDragged(with event: NSEvent) {
        guard enabled, !readOnly, let row = owner?.textLayout?.row(at: convert(event.locationInWindow, from: nil)) else {
            return
        }

        selection.drag(to: row.index)
        selectionChanged()
    }

    /// 鼠标松开才发布按钮计数。
    override func mouseUp(with _: NSEvent) {
        guard enabled, !readOnly else { return }

        selection.end()
        selectionChanged()
    }

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

    /// 手形只覆盖可操作行号格，折行与提示复用真实行矩形。
    override func resetCursorRects() {
        guard enabled, !readOnly, let layout = owner?.textLayout else { return }

        for row in layout.rows where selection.rows.indices.contains(row.index) && selection.rows[row.index] != nil {
            addCursorRect(
                CGRect(x: 0, y: row.rect.minY, width: bounds.width, height: row.rect.height),
                cursor: .pointingHand
            )
        }
    }
}
