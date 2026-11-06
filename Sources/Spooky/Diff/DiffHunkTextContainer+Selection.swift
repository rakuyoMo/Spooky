import AppKit

extension DiffHunkTextContainer {
    /// 只覆盖选区变化行的字色，源串、字形与原生字符选区均保持。
    func updateLineSelection() {
        guard let content, let style, let storage = document.textStorage else { return }

        let selected = gutter.selected
        let changed = paintedSelection.symmetricDifference(selected)
        guard !changed.isEmpty else { return }

        storage.beginEditing()
        for row in content.rows where changed.contains(row.line.lineID) {
            content.attributed.enumerateAttribute(.foregroundColor, in: row.range) { value, range, _ in
                if let value { storage.addAttribute(.foregroundColor, value: value, range: range) }
            }

            if selected.contains(row.line.lineID), !colorsSyntax, let color = selectedTextColor(for: row.line, style: style) {
                storage.addAttribute(.foregroundColor, value: color, range: row.range)
            }
        }
        storage.endEditing()
        paintedSelection = selected

        for row in textLayout?.rows ?? [] where changed.contains(content.rows[row.index].line.lineID) {
            document.setNeedsDisplay(CGRect(x: 0, y: row.rect.minY, width: document.bounds.width, height: row.rect.height))
        }
    }

    /// 行底色由有效着色选项与逻辑选区决定，提示行始终没有增删底色。
    func backgroundColor(for row: DiffDisplayLine) -> NSColor? {
        let key = row.prefix == 43 ? "added" : (row.prefix == 45 ? "deleted" : "")
        guard let color = style?.theme.colors[key] else { return nil }

        if colorsSyntax, gutter.selected.contains(row.lineID) {
            return PaletteColor(hex: color.hex, alpha: min(1, color.alpha + 0.25)).nsColor
        }
        return color.calibratedNSColor
    }

    /// 整块跟踪只负责悬停，不抢正文的原生文字拖选。
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        ))
    }

    /// 指针进入时立即定位当前显示行。
    override func mouseEntered(with event: NSEvent) {
        gutter.hover(at: convert(event.locationInWindow, from: nil))
    }

    /// 正文与行号区域使用同一显示行命中。
    override func mouseMoved(with event: NSEvent) {
        gutter.hover(at: convert(event.locationInWindow, from: nil))
    }

    /// 离开整块后不保留悬停。
    override func mouseExited(with _: NSEvent) { gutter.hover(at: nil) }

    /// 关闭着色时新增行按主题正文亮度取黑白，删除行取系统文字色。
    private func selectedTextColor(for row: DiffDisplayLine, style: TextStyle) -> NSColor? {
        switch row.prefix {
        case 43: (style.theme.colors["text"]?.isDark ?? false) ? .black : .white
        case 45: .labelColor
        default: nil
        }
    }
}
