import Foundation

// MARK: - HighlightMarkup

/// 把 highlight.js 输出的 HTML 还原成每行的语法片段，长度按原文的 UTF-16 码元计。
///
/// 输出只有 `<span class="…">`、`</span>`、实体与正文三种成分：原文里的 `&`、`<`、`>`、`"`、`'` 都写成了实体，
/// 每个实体还原成一个码元；跨行的记号（块注释、多行字符串）在各行各得一段。
struct HighlightMarkup {
    /// 一个 span 的有效颜色、嵌入语法与 XML 标签身份，用于子记号的继承。
    private struct Scope {
        /// 此层及未指定颜色的子记号使用的颜色。
        var style: SyntaxStyle? = nil

        /// 此层正在使用的语言规范名。
        var language: String

        /// 此层是否为标签记号，属性值只从直接外层判断。
        var isTag = false
    }

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
    private static let scopePrefix = "hljs-"

    /// 嵌入语言类名的前缀。
    private static let languagePrefix = "language-"

    /// 实体从 `&` 到 `;` 的最大长度，如 `&#x27;`。
    private static let entityLimit = 8

    /// 要解析的 HTML。
    private let units: UnsafeBufferPointer<UInt16>

    /// 下一个要读的码元。
    private var index = 0

    /// 由外向内各层记号的有效颜色与语法，首层表示全文。
    private var scopes: [Scope]

    /// 已完成的各行。
    private var lines: [[SyntaxSpan]] = []

    /// 当前行已完成的片段。
    private var line: [SyntaxSpan] = []

    /// 当前片段的长度。
    private var runLength = 0

    /// 当前片段的颜色。
    private var runStyle: SyntaxStyle? = nil

    /// 准备解析一段 HTML。
    private init(units: UnsafeBufferPointer<UInt16>, language: String) {
        self.units = units
        scopes = [Scope(style: nil, language: language)]
    }

    /// 解析 highlight.js 输出的 HTML。
    ///
    /// - Parameters:
    ///   - units: HTML 的 UTF-16 码元。
    ///   - language: 全文使用的语言规范名，嵌入语法由标签指定。
    /// - Returns: 与原文行一一对应的片段，每行的片段依次覆盖整行。
    static func lines(of units: UnsafeBufferPointer<UInt16>, language: String) -> [[SyntaxSpan]] {
        var markup = Self(units: units, language: language)
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
            _ = scopes.popLast()
            return
        }

        // 类名依次覆盖颜色；没有对应颜色的记号沿用外层颜色与语法
        guard let parent = scopes.last else {
            return
        }

        let classes = classes(in: start ... end)
        var scope = Scope(style: parent.style, language: parent.language)

        for name in classes {
            if name.hasPrefix(Self.languagePrefix) {
                scope.language = String(name.dropFirst(Self.languagePrefix.count))
            }

            let key = name.hasPrefix(Self.scopePrefix) ? String(name.dropFirst(Self.scopePrefix.count)) : name

            if let style = SyntaxStyle.scopes[key] {
                scope.style = style
            }
        }

        scope.isTag = classes.contains("hljs-tag")

        // XML 属性值使用独立颜色；其它语法的标签字符串保持字符串色
        if classes.contains("hljs-string"), parent.isTag, scope.language == "xml" {
            scope.style = .attributeValue
        }

        scopes.append(scope)
    }

    /// 开标签的全部类名，保留分层类别与嵌入语言的名称。
    private func classes(in tag: ClosedRange<Int>) -> [String] {
        guard let open = units[tag].firstIndex(of: Self.quote) else {
            return []
        }

        let classes = units[(open + 1) ... tag.upperBound].prefix { $0 != Self.quote }
        return classes.split(separator: Self.space).map { String(decoding: $0, as: UTF16.self) }
    }

    /// 跳过一个实体；`&` 之后不远处没有 `;` 时只跳过 `&` 本身。
    private mutating func skipEntity() {
        let limit = min(units.count, index + Self.entityLimit)
        let end = units[index ..< limit].firstIndex(of: Self.semicolon) ?? index
        index = end + 1
    }

    /// 当前颜色的正文增加一个码元，颜色变化时另起一段。
    private mutating func appendUnit() {
        let style = scopes.last?.style

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
