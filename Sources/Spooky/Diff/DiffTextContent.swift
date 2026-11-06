import AppKit
import SpookyKit

// MARK: - DiffTextContent

/// 整块正文的显示串、源串与逐显示行范围；末尾 LF 属于源串。
struct DiffTextContent {
    /// 一个显示行在整块中的范围，以及行内显示字符到原文的映射。
    struct Row {
        /// 逻辑行、提示种类与行号。
        let line: DiffDisplayLine

        /// 含末尾 LF 的显示范围。
        let range: NSRange

        /// 含末尾 LF 的原文范围。
        let sourceRange: NSRange

        /// 行内字符映射，包含末尾 LF。
        let mapping: TextSourceMap
    }

    /// 不含 Git 前缀与行号的整块原文。
    let source: [UInt16]

    /// TextKit 使用的显示内容。
    let attributed: NSAttributedString

    /// 按显示顺序排列的行映射。
    let rows: [Row]

    /// 一列行号的宽度，包含右侧边线。
    let columnWidth: CGFloat

    /// 通过共用行渲染器构造整块正文，同时保留语法色和行内高亮底色。
    init(
        hunk: DiffHunk,
        style: TextStyle,
        syntax: DiffSyntax?,
        highlights: [Int: [Range<Int>]]
    ) {
        let display = DiffDisplayLine.rows(in: hunk)
        let attributes = Self.attributes(style: style)
        let content = NSMutableAttributedString()
        let original = NSMutableString()
        var mapped: [Row] = []
        let lines = Dictionary(uniqueKeysWithValues: hunk.lines.map { ($0.id, $0) })

        for row in display {
            let line = lines[row.lineID]
            let rendered = TextLineRenderer.rendered(
                row.source,
                spans: row.isNotice ? nil : line.flatMap { syntax?.spans(for: $0) },
                highlights: row.isNotice ? [] : (highlights[row.lineID] ?? []),
                highlightColor: AppPalette.color(
                    row.prefix == 43 ? "diff_inline_added_highlight_color" : "diff_inline_deleted_highlight_color"
                ),
                style: style
            )
            var values = attributes

            if row.isNotice {
                values[.foregroundColor] = style.theme.colors["invisible"]?.calibratedNSColor
            }

            let start = content.length
            let sourceStart = original.length
            var mapping = rendered.mapping
            mapping.append(source: 1, display: 1)
            content.append(rendered.appKit(attributes: values))
            content.append(NSAttributedString(string: "\n", attributes: values))
            original.append(row.source + "\n")
            mapped.append(Row(
                line: row,
                range: NSRange(location: start, length: content.length - start),
                sourceRange: NSRange(location: sourceStart, length: original.length - sourceStart),
                mapping: mapping
            ))
        }

        source = Array((original as String).utf16)
        attributed = content
        rows = mapped
        columnWidth = DiffDisplayLine.columnWidth(in: display, font: style.theme.font)
    }

    /// 正文与行号使用相同的最小行高，不限制字体回退所需的高度。
    static func attributes(style: TextStyle) -> [NSAttributedString.Key: Any] {
        let font = style.theme.font
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = (font.ascender - font.descender + 4).rounded()
        paragraph.lineSpacing = 2
        return [
            .font: font,
            .foregroundColor: style.theme.colors["text"]?.calibratedNSColor ?? NSColor.textColor,
            .paragraphStyle: paragraph,
        ]
    }

    /// 只复制实际选中的原文字符；跨行选择自然包含源串中已有的 LF。
    func copiedText(in range: NSRange) -> String {
        guard range.length > 0 else { return "" }

        var result = ""

        for row in rows {
            let intersection = NSIntersectionRange(range, row.range)
            guard intersection.length > 0 else { continue }

            let local = NSRange(location: intersection.location - row.range.location, length: intersection.length)
            let mapped = row.mapping.sourceRange(for: local)
            let start = row.sourceRange.location + mapped.location
            result += String(decoding: source[start ..< start + mapped.length], as: UTF16.self)
        }

        return result
    }

}
