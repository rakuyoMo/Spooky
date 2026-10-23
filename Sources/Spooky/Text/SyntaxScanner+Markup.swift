import Foundation

// MARK: - Markup

extension SyntaxScanner {
    /// 标记语言的一个记号：注释、CDATA、标签或正文。
    mutating func scanMarkupToken() {
        if has(Array("<!--".utf16), at: index) {
            emit(to: endOfMarker("-->", from: index + 4), .comment)
            return
        }

        if has(Array("<![CDATA[".utf16), at: index) {
            emit(to: endOfMarker("]]>", from: index + 9), .string)
            return
        }

        let next = index + 1 < units.count ? units[index + 1] : 10

        if units[index] == 60, Self.isWordStart(next) || [47, 63, 33].contains(next) {
            scanTag()
            return
        }

        emit(to: index + 1, nil)
    }

    /// 标签：`<`、可选的 `/` `?` `!`、标签名、属性名与引号里的属性值，直到 `>`。
    private mutating func scanTag() {
        var end = index + 1

        if [47, 63, 33].contains(units[end]) {
            end += 1
        }

        emit(to: markupNameEnd(from: end), .xmlTag)

        while index < units.count {
            let unit = units[index]
            let closing = (unit == 47 || unit == 63) && index + 1 < units.count && units[index + 1] == 62

            if unit == 62 || closing {
                emit(to: index + (closing ? 2 : 1), .xmlTag)
                return
            }

            // 没有闭合的标签遇到下一个标签即结束
            if unit == 60 {
                return
            }

            if unit == 34 || unit == 39 {
                emit(to: (find([unit], from: index + 1) ?? units.count) + 1, .attributeValue)
            } else if isMarkupNameUnit(unit) {
                emit(to: markupNameEnd(from: index), .attributeName)
            } else {
                emit(to: index + 1, nil)
            }
        }
    }

    /// 标签名与属性名可以含冒号、连字符与点。
    private func markupNameEnd(from position: Int) -> Int {
        var end = position

        while end < units.count, isMarkupNameUnit(units[end]) {
            end += 1
        }

        return end
    }

    /// 标签名与属性名的码元。
    private func isMarkupNameUnit(_ unit: UInt16) -> Bool {
        Self.isWordStart(unit) || Self.isDigit(unit) || [45, 46, 58].contains(unit)
    }

    /// 结束标记之后的位置；没有结束标记时到全文末尾。
    private func endOfMarker(_ marker: String, from position: Int) -> Int {
        let close = Array(marker.utf16)
        return find(close, from: position).map { $0 + close.count } ?? units.count
    }
}

// MARK: - Style Sheet

extension SyntaxScanner {
    /// 样式表的一个记号：花括号外是选择器，花括号内是属性名与值。
    mutating func scanStyleSheetToken() {
        let unit = units[index]

        if scanComment() || scanString() {
            return
        }

        if unit == 123 || unit == 125 {
            braceDepth = max(0, braceDepth + (unit == 123 ? 1 : -1))
            emit(to: index + 1, nil)
            return
        }

        // @media、@import 等规则
        if unit == 64, index + 1 < units.count, Self.isWordStart(units[index + 1]) {
            emit(to: styleNameEnd(from: index + 1), .keyword)
            return
        }

        guard braceDepth > 0 else {
            scanSelector()
            return
        }

        if Self.isDigit(unit) || (unit == 35 && isWordUnit(at: index + 1)) {
            emit(to: styleNameEnd(from: index + 1), .number)
        } else if Self.isWordStart(unit) || unit == 45 {
            let end = styleNameEnd(from: index)
            emit(to: end, nextNonSpace(from: end) == 58 ? .attributeName : nil)
        } else {
            emit(to: index + 1, nil)
        }
    }

    /// 选择器一直到 `{`、逗号、注释或行尾。
    private mutating func scanSelector() {
        var end = index

        while end < units.count, ![123, 44, 10].contains(units[end]), !has(Array("/*".utf16), at: end) {
            end += 1
        }

        let selector = units[index ..< end].contains { $0 != 32 && $0 != 9 }
        emit(to: end, selector ? .cssSelector : nil)
    }

    /// 属性名、数值与单位可以含连字符、点与百分号。
    private func styleNameEnd(from position: Int) -> Int {
        var end = position

        while end < units.count, isWordUnit(at: end) || [45, 46, 37].contains(units[end]) {
            end += 1
        }

        return max(end, position)
    }
}

// MARK: - Markdown

extension SyntaxScanner {
    /// Markdown 的一个记号：行首的围栏与标题按整行处理，行内处理代码、强调与链接。
    mutating func scanMarkdownToken() {
        if index == 0 || units[index - 1] == 10, scanMarkdownLine() {
            return
        }

        let unit = units[index]
        let line = lineEnd(from: index)

        // 行内代码
        if unit == 96, let close = find([96], from: index + 1), close < line {
            emit(to: close + 1, .codeBlock)
            return
        }

        if scanEmphasis(line: line) || scanLink(line: line) {
            return
        }

        emit(to: index + 1, nil)
    }

    /// 围栏代码块与标题。
    private mutating func scanMarkdownLine() -> Bool {
        let end = lineEnd(from: index)
        var first = index

        while first < end, units[first] == 32 {
            first += 1
        }

        if has(Array("```".utf16), at: first) || has(Array("~~~".utf16), at: first) {
            inFence.toggle()
            emit(to: end, .codeBlock)
            return true
        }

        if inFence || (units.indices.contains(first) && units[first] == 35 && first == index) {
            emit(to: end, inFence ? .codeBlock : .heading)
            return true
        }

        return false
    }

    /// `**粗体**`、`__粗体__`、`*斜体*` 与 `_斜体_`，必须在同一行闭合；词中间的下划线不算。
    private mutating func scanEmphasis(line: Int) -> Bool {
        let unit = units[index]

        guard unit == 42 || unit == 95, !(unit == 95 && isWordUnit(at: index - 1)) else {
            return false
        }

        let strong = index + 1 < line && units[index + 1] == unit
        let marker = strong ? [unit, unit] : [unit]

        guard
            index + marker.count < line,
            units[index + marker.count] != 32,
            let close = find(marker, from: index + marker.count + 1),
            close < line
        else { return false }

        emit(to: close + marker.count, strong ? .stronglyEmphasized : .emphasized)
        return true
    }

    /// `[文字](地址)` 的地址部分，以及裸写的 http / https 地址。
    private mutating func scanLink(line: Int) -> Bool {
        if units[index] == 93, index + 1 < line, units[index + 1] == 40, let close = find([41], from: index + 2), close < line {
            emit(to: index + 1, nil)
            emit(to: close + 1, .url)
            return true
        }

        guard has(Array("http://".utf16), at: index) || has(Array("https://".utf16), at: index) else {
            return false
        }

        var end = index

        while end < line, ![32, 9, 41, 62].contains(units[end]) {
            end += 1
        }

        emit(to: end, .url)
        return true
    }
}
