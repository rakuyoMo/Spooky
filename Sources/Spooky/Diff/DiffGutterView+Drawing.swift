import AppKit

extension DiffGutterView {
    /// 原始 sRGB 分量直接加减 0.1，不经八位颜色的取整，透明度保持不变。
    static func borderColor(style: TextStyle) -> NSColor {
        guard let background = style.theme.colors["background"] else { return .separatorColor }

        let color = background.nsColor
        let amount = background.isDark ? 0.1 : -0.1
        return NSColor(
            srgbRed: max(0, color.redComponent + amount),
            green: max(0, color.greenComponent + amount),
            blue: max(0, color.blueComponent + amount),
            alpha: color.alphaComponent
        )
    }

    /// 绘制可见行号与选区，每列右边线覆盖块的全部高度。
    override func draw(_ dirtyRect: NSRect) {
        guard let owner, let content = owner.content, let layout = owner.textLayout, let style = owner.style else {
            return
        }

        (style.theme.colors["background"]?.calibratedNSColor ?? .textBackgroundColor).setFill()
        dirtyRect.fill()
        let width = content.columnWidth
        let count = content.rows.first?.line.numbers.count ?? 2
        let color = NSColor(style.lineNumberColor)
        let font = style.theme.font
        let baseAttributes = DiffTextContent.attributes(style: style)

        for item in layout.rows(intersecting: dirtyRect) {
            let line = content.rows[item.index].line
            let isSelected = selected.contains(line.lineID)

            for (column, number) in line.numbers.enumerated() {
                let x = CGFloat(column) * width

                if isSelected {
                    NSColor.controlAccentColor.setFill()
                    CGRect(x: x, y: item.rect.minY, width: width - 1, height: item.rect.height).fill()
                }

                var attributes = baseAttributes
                attributes[.foregroundColor] = isSelected ? NSColor.alternateSelectedControlTextColor : color
                let paragraph = NSMutableParagraphStyle()
                paragraph.setParagraphStyle(baseAttributes[.paragraphStyle] as? NSParagraphStyle ?? .default)
                paragraph.alignment = .right
                attributes[.paragraphStyle] = paragraph
                let text = NSAttributedString(string: number, attributes: attributes)
                let manager = owner.document.layoutManager
                let baseline = (manager?.defaultBaselineOffset(for: font) ?? 0)
                    + max(0, paragraph.minimumLineHeight - (manager?.defaultLineHeight(for: font) ?? 0))
                text.draw(in: CGRect(
                    x: x + 8,
                    y: item.baseline - baseline,
                    width: width - 17,
                    height: item.rect.height
                ))
            }
        }

        Self.borderColor(style: style).setFill()

        for column in 1 ... count {
            CGRect(x: CGFloat(column) * width - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
        }

        if window?.firstResponder === self, let focusedID {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            NSBezierPath(rect: frame(for: focusedID).insetBy(dx: 1, dy: 1)).stroke()
        }
    }

}
