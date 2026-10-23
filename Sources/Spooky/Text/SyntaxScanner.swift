import Foundation

// MARK: - SyntaxScanner

/// 按语言规则逐个 UTF-16 码元扫描全文，生成每行的语法片段。
///
/// 跨行的块注释、多行字符串与标签按全文状态延续，所以要对整份文件扫描，而不是逐行扫描。
struct SyntaxScanner {
    /// 全文的 UTF-16 码元。
    let units: [UInt16]

    /// 着色规则。
    let language: SyntaxLanguage

    /// 下一个待扫描的位置。
    var index = 0

    /// 已生成的每行片段，换行符本身不计入任何一行。
    var lines: [[SyntaxSpan]] = [[]]

    /// 当前行到目前为止只有空格与制表符。
    var atLineStart = true

    /// 样式表花括号的嵌套深度，大于 0 时位于声明块内。
    var braceDepth = 0

    /// Markdown 正处于围栏代码块中。
    var inFence = false

    /// 行注释标记的码元。
    let lineComments: [[UInt16]]

    /// 块注释起止标记的码元。
    let blockComments: [(open: [UInt16], close: [UInt16])]

    /// 字符串定界符的码元，较长的在前。
    let stringDelimiters: [[UInt16]]

    /// 准备扫描，标记预先转成码元。
    init(units: [UInt16], language: SyntaxLanguage) {
        self.units = units
        self.language = language

        lineComments = language.lineComments.map { Array($0.utf16) }
        blockComments = language.blockComments.compactMap { pair in
            pair.count == 2 ? (Array(pair[0].utf16), Array(pair[1].utf16)) : nil
        }
        stringDelimiters = language.strings
            .map { Array($0.utf16) }
            .sorted { $0.count > $1.count }
    }

    /// 扫描全文。
    mutating func scan() {
        while index < units.count {
            switch language.kind {
            case .code: scanCodeToken()
            case .markup: scanMarkupToken()
            case .css: scanStyleSheetToken()
            case .markdown: scanMarkdownToken()
            }
        }
    }

    /// 程序语言的一个记号：注释、预处理行、字符串、分节、数字、词与带前缀的名字。
    private mutating func scanCodeToken() {
        let unit = units[index]

        if scanComment() || scanPreprocessorLine() || scanString() || scanSection() || scanPrefixed() {
            return
        }

        if Self.isDigit(unit), !isWordUnit(at: index - 1) {
            emit(to: wordEnd(from: index, number: true), .number)
            return
        }

        if Self.isWordStart(unit) {
            scanWord()
            return
        }

        emit(to: index + 1, nil)
    }

    /// 块注释与行注释。
    mutating func scanComment() -> Bool {
        for (open, close) in blockComments where has(open, at: index) {
            let end = find(close, from: index + open.count).map { $0 + close.count } ?? units.count
            emit(to: end, .comment)
            return true
        }

        for marker in lineComments where has(marker, at: index) {
            emit(to: lineEnd(from: index), .comment)
            return true
        }

        return false
    }

    /// 字符串；配置语言中紧跟冒号的字符串是键。
    mutating func scanString() -> Bool {
        guard let delimiter = stringDelimiters.first(where: { has($0, at: index) }) else {
            return false
        }

        var position = index + delimiter.count
        var end = units.count

        while position < units.count {
            if units[position] == 92 {
                position += 2
                continue
            }

            if has(delimiter, at: position) {
                end = position + delimiter.count
                break
            }

            // 单字符定界符的字符串到行尾为止，反引号模板与三引号可以跨行
            if units[position] == 10, delimiter.count == 1, delimiter[0] != 96 {
                end = position
                break
            }

            position += 1
        }

        end = min(end, units.count)
        let key = language.keys == "string" && nextNonSpace(from: end) == 58
        emit(to: end, key ? .attributeName : .string)
        return true
    }

    /// 行首的预处理指令，行尾反斜杠延续到下一行。
    private mutating func scanPreprocessorLine() -> Bool {
        guard atLineStart, let marker = language.preprocessor, has(Array(marker.utf16), at: index) else {
            return false
        }

        var end = lineEnd(from: index)

        while end > index, end < units.count, units[end - 1] == 92 {
            end = lineEnd(from: end + 1)
        }

        emit(to: end, .preprocessor)
        return true
    }

    /// 配置文件行首的 `[分节]`。
    private mutating func scanSection() -> Bool {
        guard language.sections, atLineStart, units[index] == 91 else {
            return false
        }

        emit(to: lineEnd(from: index), .heading)
        return true
    }

    /// 关键字、键、函数调用与类型名。
    private mutating func scanWord() {
        let end = wordEnd(from: index)
        let word = String(decoding: units[index ..< end], as: UTF16.self)
        let next = nextNonSpace(from: end)
        let keyword = language.keywords.contains(language.caseInsensitiveKeywords ? word.lowercased() : word)

        // 配置语言里行首、紧跟冒号或等号的词是键
        let key = atLineStart
            && ((language.keys == "colon" && next == 58) || (language.keys == "equals" && next == 61))

        let style: SyntaxStyle? =
            if keyword {
                .keyword
            } else if key {
                .attributeName
            } else if next == 40 {
                .function
            } else if language.capitalizedTypes, (65 ... 90).contains(units[index]) {
                .identifier
            } else {
                nil
            }

        emit(to: end, style)
    }

    /// 注解（`@MainActor`、`#[derive]`）、以 `@` 开头的关键字与变量（`$HOME`）。
    private mutating func scanPrefixed() -> Bool {
        let unit = units[index]
        let next = index + 1 < units.count ? units[index + 1] : 10

        if let prefix = language.attributePrefix?.utf16.first, unit == prefix {
            if next == 91 {
                let close = (find([93], from: index) ?? units.count) + 1
                emit(to: min(lineEnd(from: index), close), .preprocessor)
                return true
            }

            if Self.isWordStart(next) {
                emit(to: wordEnd(from: index + 1), .preprocessor)
                return true
            }
        }

        // Objective-C 的 @interface 等以 @ 开头的关键字
        if unit == 64, Self.isWordStart(next) {
            let end = wordEnd(from: index + 1)

            if language.keywords.contains("@" + String(decoding: units[index + 1 ..< end], as: UTF16.self)) {
                emit(to: end, .keyword)
                return true
            }
        }

        return scanVariable(unit, next: next)
    }

    /// 变量：`$name`、`${name}` 与 `$?` 这类特殊变量。
    private mutating func scanVariable(_ unit: UInt16, next: UInt16) -> Bool {
        guard let prefix = language.variablePrefix?.utf16.first, unit == prefix else {
            return false
        }

        if next == 123 {
            let close = (find([125], from: index) ?? units.count) + 1
            emit(to: min(lineEnd(from: index), close), .identifier)
        } else if Self.isWordStart(next) || Self.isDigit(next) {
            emit(to: wordEnd(from: index + 1), .identifier)
        } else if "#?@*!$-".utf16.contains(next) {
            emit(to: index + 2, .identifier)
        } else {
            return false
        }

        return true
    }
}

// MARK: - Emitting

extension SyntaxScanner {
    /// 把当前位置到 `end` 的码元记为一种类别，遇到换行另起一行。
    mutating func emit(to end: Int, _ style: SyntaxStyle?) {
        let end = min(max(end, index + 1), units.count)
        var start = index

        while index < end {
            let unit = units[index]
            index += 1

            guard unit == 10 else {
                if unit != 32, unit != 9 {
                    atLineStart = false
                }

                continue
            }

            append(index - 1 - start, style)
            lines.append([])
            atLineStart = true
            start = index
        }

        append(index - start, style)
    }

    /// 追加到当前行，与上一片段同类时合并。
    private mutating func append(_ length: Int, _ style: SyntaxStyle?) {
        guard length > 0 else {
            return
        }

        let last = lines.count - 1

        if let previous = lines[last].last, previous.style == style {
            lines[last][lines[last].count - 1] = SyntaxSpan(length: previous.length + length, style: style)
        } else {
            lines[last].append(SyntaxSpan(length: length, style: style))
        }
    }
}

// MARK: - Helpers

extension SyntaxScanner {
    /// 字母、下划线与非 ASCII 字符都可以开始一个词。
    static func isWordStart(_ unit: UInt16) -> Bool {
        (65 ... 90).contains(unit) || (97 ... 122).contains(unit) || unit == 95 || unit >= 128
    }

    /// ASCII 数字。
    static func isDigit(_ unit: UInt16) -> Bool {
        (48 ... 57).contains(unit)
    }

    /// 指定位置起是否为这串码元。
    func has(_ marker: [UInt16], at position: Int) -> Bool {
        position >= 0
            && position + marker.count <= units.count
            && units[position ..< position + marker.count].elementsEqual(marker)
    }

    /// 从指定位置起第一次出现的位置。
    func find(_ marker: [UInt16], from position: Int) -> Int? {
        var current = position

        while current + marker.count <= units.count {
            if has(marker, at: current) {
                return current
            }

            current += 1
        }

        return nil
    }

    /// 指定位置所在行的行尾，即下一个换行符的位置。
    func lineEnd(from position: Int) -> Int {
        var end = position

        while end < units.count, units[end] != 10 {
            end += 1
        }

        return end
    }

    /// 同一行中指定位置起第一个非空白的码元。
    func nextNonSpace(from position: Int) -> UInt16? {
        var current = position

        while current < units.count, units[current] == 32 || units[current] == 9 {
            current += 1
        }

        return current < units.count && units[current] != 10 ? units[current] : nil
    }

    /// 词的结尾；数字可以带小数点，配置语言的键可以带连字符与点。
    func wordEnd(from position: Int, number: Bool = false) -> Int {
        var end = position

        while end < units.count {
            let unit = units[end]
            let dotted = unit == 46 && end + 1 < units.count && Self.isDigit(units[end + 1])
            let keyPart = language.keys != nil && (unit == 45 || unit == 46)

            guard isWordUnit(at: end) || (number && dotted) || keyPart else {
                break
            }

            end += 1
        }

        return max(end, position + 1)
    }

    /// 指定位置是否为词的一部分；越界时不是。
    func isWordUnit(at position: Int) -> Bool {
        guard units.indices.contains(position) else {
            return false
        }

        let unit = units[position]
        return Self.isWordStart(unit) || Self.isDigit(unit)
    }
}
