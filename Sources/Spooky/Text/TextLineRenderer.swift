import SwiftUI

// MARK: - TextStyle

/// 文本区的显示样式：主题的字体与颜色、Tab 宽度和是否标出不可见字符，Diff 与文件文本共用。
struct TextStyle {
    /// 当前外观的主题。
    let theme: TextTheme

    /// 一个制表符占的空格数。
    let tabWidth: Int

    /// 用主题的不可见字符色标出制表符、空格与回车。
    let showsInvisibles: Bool

    /// 主题字体。
    var font: Font { .custom(theme.fontName, size: theme.fontSize) }

    /// 主题正文色。
    var textColor: Color { color("text") }

    /// Diff 行号的文字色：正文色各分量加减 0.2，正文是深色时加、浅色时减，透明度与正文相同。
    var lineNumberColor: Color {
        guard let text = theme.colors["text"] else {
            return .secondary
        }

        return text.offset(by: text.isDark ? 0.2 : -0.2).color
    }

    /// 按语义键取主题色，主题缺少的键按正文色处理。
    func color(_ key: String) -> Color {
        (theme.colors[key] ?? theme.colors["text"])?.color ?? .primary
    }
}

// MARK: - TextLineRenderer

/// 把一行文本排成带颜色的富文本：按 Tab 宽度展开制表符、按需标出空白，并套用语法片段的颜色。
enum TextLineRenderer {
    /// 制表符的标记，其后用空格补齐到下一个 Tab 位置。
    static let tabMarker = "→"

    /// 空格的标记。
    static let spaceMarker = "·"

    /// 行内回车（CRLF 的 CR）的标记。
    static let returnMarker = "␍"

    /// 生成一行的显示内容。
    ///
    /// - Parameters:
    ///   - line: 不含换行符的一行文本。
    ///   - spans: 依次覆盖整行的语法片段，长度按 UTF-16 计；为空时整行按正文显示。
    ///   - highlights: 行内高亮的范围，偏移按 UTF-16 计，升序且互不重叠；超出行尾的部分忽略。
    ///   - highlightColor: 行内高亮的底色，与语法片段的文字色同时生效。
    ///   - style: 主题、Tab 宽度与不可见字符设置。
    static func attributed(
        _ line: String,
        spans: [SyntaxSpan]?,
        highlights: [Range<Int>] = [],
        highlightColor: Color = .clear,
        style: TextStyle
    ) -> AttributedString {
        var builder = Builder(style: style, highlightColor: highlightColor)
        let units = Array(line.utf16)
        var pieces: [(range: Range<Int>, color: Color?)] = []
        var offset = 0

        // 片段与行的长度不一致时（如忽略空白的上下文行取自另一侧），剩余部分按正文显示
        for span in spans ?? [] where offset < units.count {
            let end = min(units.count, offset + span.length)

            pieces.append((offset ..< end, span.style.map { style.color($0.rawValue) }))
            offset = end
        }

        if offset < units.count {
            pieces.append((offset ..< units.count, nil))
        }

        // 同色的片段再按高亮范围的边界切开，文字色与底色各自生效
        for piece in pieces {
            for part in split(piece.range, by: highlights) {
                builder.append(
                    String(decoding: units[part.range], as: UTF16.self),
                    color: piece.color,
                    highlighted: part.highlighted
                )
            }
        }

        builder.flush()
        return builder.result
    }

    /// 把一段范围按高亮范围的边界切开，标出每一部分是否落在高亮里。
    private static func split(
        _ range: Range<Int>,
        by highlights: [Range<Int>]
    ) -> [(range: Range<Int>, highlighted: Bool)] {
        var parts: [(range: Range<Int>, highlighted: Bool)] = []
        var start = range.lowerBound

        for highlight in highlights where highlight.overlaps(range) {
            let lower = max(highlight.lowerBound, start)
            let upper = min(highlight.upperBound, range.upperBound)

            if start < lower {
                parts.append((start ..< lower, false))
            }

            if lower < upper {
                parts.append((lower ..< upper, true))
            }

            start = max(start, upper)
        }

        if start < range.upperBound {
            parts.append((start ..< range.upperBound, false))
        }

        return parts
    }
}

// MARK: - Builder

/// 逐字符累积同色的连续文字，减少富文本片段数量；列号用于计算制表符宽度。
private struct Builder {
    /// 显示设置。
    let style: TextStyle

    /// 行内高亮的底色。
    let highlightColor: Color

    /// 已生成的内容。
    var result = AttributedString()

    /// 当前列，从 0 开始。
    var column = 0

    /// 尚未写入的同色文字。
    var pending = ""

    /// 待写文字的颜色；为空时沿用视图的正文色。
    var pendingColor: Color? = nil

    /// 待写文字落在行内高亮里，写入时铺上高亮底色。
    var pendingHighlighted = false

    /// 追加一段同色、同底色的文字，空白按设置替换成标记。
    mutating func append(_ text: String, color: Color?, highlighted: Bool) {
        if color != pendingColor || highlighted != pendingHighlighted {
            flush()
            pendingColor = color
            pendingHighlighted = highlighted
        }

        for character in text {
            switch character {
            case "\t":
                // 补齐到下一个 Tab 位置，标记占第一格
                let width = style.tabWidth - column % style.tabWidth
                column += width

                guard style.showsInvisibles else {
                    pending += String(repeating: " ", count: width)
                    continue
                }

                mark(TextLineRenderer.tabMarker)
                pending += String(repeating: " ", count: width - 1)

            case " " where style.showsInvisibles:
                column += 1
                mark(TextLineRenderer.spaceMarker)

            case "\r":
                // 不标出时直接省略，避免回车在文本视图里另起一行
                if style.showsInvisibles {
                    mark(TextLineRenderer.returnMarker)
                }

            default:
                column += 1
                pending.append(character)
            }
        }
    }

    /// 写入待写文字。
    mutating func flush() {
        guard !pending.isEmpty else {
            return
        }

        var piece = AttributedString(pending)

        if let pendingColor {
            piece.foregroundColor = pendingColor
        }

        if pendingHighlighted {
            piece.backgroundColor = highlightColor
        }

        result += piece
        pending = ""
    }

    /// 写入一个使用不可见字符色的标记；落在行内高亮里时同样铺上高亮底色。
    private mutating func mark(_ marker: String) {
        flush()

        var piece = AttributedString(marker)
        piece.foregroundColor = style.color("invisible")

        if pendingHighlighted {
            piece.backgroundColor = highlightColor
        }

        result += piece
    }
}
