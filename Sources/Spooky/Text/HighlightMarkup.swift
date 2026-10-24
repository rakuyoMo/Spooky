import Foundation

// MARK: - HighlightMarkup

/// 把 highlight.js 输出的 HTML 还原成每行的语法片段，长度按原文的 UTF-16 码元计。
///
/// 输出只有 `<span class="…">`、`</span>`、实体与正文三种成分：原文里的 `&`、`<`、`>`、`"`、`'` 都写成了实体，
/// 每个实体还原成一个码元；跨行的记号（块注释、多行字符串）在各行各得一段。
struct HighlightMarkup {
    /// `<`
    private static let lessThan = UInt16(UInt8(ascii: "<"))

    /// `>`
    private static let greaterThan = UInt16(UInt8(ascii: ">"))

    /// `/`
    private static let slash = UInt16(UInt8(ascii: "/"))

    /// `&`
    private static let ampersand = UInt16(UInt8(ascii: "&"))

    /// `;`
    private static let semicolon = UInt16(UInt8(ascii: ";"))

    /// `"`
    private static let quote = UInt16(UInt8(ascii: "\""))

    /// 空格。
    private static let space = UInt16(UInt8(ascii: " "))

    /// 换行。
    private static let newline = UInt16(UInt8(ascii: "\n"))

    /// 记号类名的前缀。
    private static let scopePrefix = Array("hljs-".utf16)

    /// 实体从 `&` 到 `;` 的最大长度，如 `&#x27;`。
    private static let entityLimit = 8

    /// 要解析的 HTML。
    private let units: UnsafeBufferPointer<UInt16>

    /// 下一个要读的码元。
    private var index = 0

    /// 由外向内各层记号的颜色。
    private var styles: [SyntaxStyle?] = []

    /// 已完成的各行。
    private var lines: [[SyntaxSpan]] = []

    /// 当前行已完成的片段。
    private var line: [SyntaxSpan] = []

    /// 当前片段的长度。
    private var runLength = 0

    /// 当前片段的颜色。
    private var runStyle: SyntaxStyle? = nil

    /// 准备解析一段 HTML。
    private init(units: UnsafeBufferPointer<UInt16>) {
        self.units = units
    }

    /// 解析 highlight.js 输出的 HTML。
    ///
    /// - Parameter units: HTML 的 UTF-16 码元。
    /// - Returns: 与原文行一一对应的片段，每行的片段依次覆盖整行。
    static func lines(of units: UnsafeBufferPointer<UInt16>) -> [[SyntaxSpan]] {
        var markup = Self(units: units)
        return markup.parse()
    }

    /// 依次读完全部码元。
    private mutating func parse() -> [[SyntaxSpan]] {
        while index < units.count {
            switch units[index] {
            case Self.lessThan:
                readTag()

            case Self.ampersand:
                skipEntity()
                appendUnit()

            case Self.newline:
                index += 1
                endLine()

            default:
                index += 1
                appendUnit()
            }
        }

        endLine()
        return lines
    }

    /// 读一个标签：开标签压入它的颜色，闭标签弹出最内层。
    private mutating func readTag() {
        let start = index
        let end = units[start...].firstIndex(of: Self.greaterThan) ?? units.count - 1
        index = end + 1

        if start + 1 < units.count, units[start + 1] == Self.slash {
            _ = styles.popLast()
            return
        }

        // 类名里没有对应颜色的记号沿用外层颜色
        let style = scope(in: start ... end).flatMap { SyntaxStyle.scopes[$0] } ?? styles.last ?? nil
        styles.append(style)
    }

    /// 开标签第一个类名中 `hljs-` 之后的部分；第一个类名不以它开头（如嵌入语言的 `language-xml`）时为空。
    private func scope(in tag: ClosedRange<Int>) -> String? {
        guard let open = units[tag].firstIndex(of: Self.quote) else {
            return nil
        }

        let classes = units[(open + 1) ... tag.upperBound]
        let name = classes.prefix { $0 != Self.space && $0 != Self.quote }

        guard name.starts(with: Self.scopePrefix) else {
            return nil
        }

        return String(decoding: name.dropFirst(Self.scopePrefix.count), as: UTF16.self)
    }

    /// 跳过一个实体；`&` 之后不远处没有 `;` 时只跳过 `&` 本身。
    private mutating func skipEntity() {
        let limit = min(units.count, index + Self.entityLimit)
        let end = units[index ..< limit].firstIndex(of: Self.semicolon) ?? index
        index = end + 1
    }

    /// 当前颜色的正文增加一个码元，颜色变化时另起一段。
    private mutating func appendUnit() {
        let style = styles.last ?? nil

        if style != runStyle {
            flushRun()
            runStyle = style
        }

        runLength += 1
    }

    /// 结束当前行，跨行的记号在下一行继续使用同样的颜色。
    private mutating func endLine() {
        flushRun()
        lines.append(line)
        line = []
    }

    /// 把当前片段加入当前行。
    private mutating func flushRun() {
        guard runLength > 0 else {
            return
        }

        line.append(SyntaxSpan(length: runLength, style: runStyle))
        runLength = 0
    }
}
