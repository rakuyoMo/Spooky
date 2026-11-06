import AppKit

/// 在源空白的排版位置绘制标记，不向正文插入额外字符或改变折行。
final class TextInvisibleLayoutManager: NSLayoutManager {
    /// 一枚位于实际行片段上的标记，使用与正文相同的段落与字体排版。
    struct Marker {
        /// 对应源空白的显示字符位置。
        let characterIndex: Int

        /// 标记自己的属性，颜色独立于语法记号。
        let text: NSAttributedString

        /// 原空白的横坐标和所在视觉行的顶边。
        let rect: NSRect
    }

    /// 标记符号附在原空白上，不使用标记字形参与正文排版。
    static let symbol = NSAttributedString.Key("SpookyInvisibleSymbol")

    /// 标记色单独存储，不随正文语法色或选中字色改变。
    static let color = NSAttributedString.Key("SpookyInvisibleColor")

    /// 为真实 LF 附上不可见字符色；紧邻的 CR 已经有标记时不再标 LF。
    static func lineFeed(
        after line: String,
        style: TextStyle,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        var values = attributes
        if style.showsInvisibles, line.utf16.last != 13 {
            values[symbol] = "¬"
            values[color] = style.theme.colors["invisible"]?.calibratedNSColor ?? NSColor.secondaryLabelColor
        }
        return NSAttributedString(string: "\n", attributes: values)
    }

    /// 正文先按原样绘制，再把空白标记叠在对应的视觉行里。
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        for marker in markers(in: glyphsToShow, origin: origin) {
            marker.text.draw(with: marker.rect, options: [.usesLineFragmentOrigin])
        }
    }

    /// 只枚举本次绘制范围内的源空白；空行以段落顶边排版，不采用控制字形的基线。
    func markers(in glyphs: NSRange, origin: NSPoint = .zero) -> [Marker] {
        guard let textStorage, glyphs.length > 0 else { return [] }

        let characters = characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var result: [Marker] = []
        textStorage.enumerateAttribute(Self.symbol, in: characters) { symbol, range, _ in
            guard let symbol = symbol as? String else { return }

            for index in range.location ..< NSMaxRange(range) {
                let glyph = self.glyphIndexForCharacter(at: index)
                let fragment = self.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let position = self.location(forGlyphAt: glyph)
                var attributes = textStorage.attributes(at: index, effectiveRange: nil)
                attributes[.foregroundColor] = attributes[Self.color]
                attributes.removeValue(forKey: .backgroundColor)
                let text = NSAttributedString(string: symbol, attributes: attributes)
                let rect = NSRect(
                    x: origin.x + fragment.minX + position.x,
                    y: origin.y + fragment.minY,
                    width: max(1, text.size().width),
                    height: max(fragment.height, text.size().height)
                )
                result.append(Marker(characterIndex: index, text: text, rect: rect))
            }
        }
        return result
    }
}
