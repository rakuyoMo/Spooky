import Foundation

// MARK: - InlineDiff

/// 块内修改行的单词级比较：删除行与新增行成对比较，找出两行中改动的部分，供 Diff 给它们铺上高亮底色。
///
/// 一行先切成单词、连续空白与其它单个字符，再按最短编辑脚本比较两行的切分结果。
public enum InlineDiff {
    /// 参与比较的一行最多的字符数，任一行超过时这一对不比较。
    static let maximumLength = 1000

    /// 一行中改动的字符超过这个比例时，这一对不高亮：几乎整行重写时，高亮只会盖满整行。
    static let maximumChangedRatio = 0.75

    /// 一个块中各修改行需要高亮的范围。
    ///
    /// 被上下文行隔开的每段连续改动是一组：组内删除行与新增行数目相同时按顺序一一配对比较，数目不同的组不高亮。
    ///
    /// - Parameter hunk: 已解析的块。
    /// - Returns: 键是块内行序号，值是升序、互不重叠的范围，偏移按 UTF-16 计；没有高亮的行不在其中。
    public static func ranges(in hunk: DiffHunk) -> [Int: [Range<Int>]] {
        var result: [Int: [Range<Int>]] = [:]
        var deleted: [DiffLine] = []
        var added: [DiffLine] = []

        for line in hunk.lines {
            switch line.prefix {
            case 45:
                deleted.append(line)

            case 43:
                added.append(line)

            default:
                // 上下文行结束当前一组
                compare(deleted, added, into: &result)
                deleted.removeAll()
                added.removeAll()
            }
        }

        compare(deleted, added, into: &result)
        return result
    }

    /// 比较一对删除行与新增行。
    ///
    /// - Parameters:
    ///   - deleted: 删除行的文字，不含 Diff 前缀。
    ///   - added: 新增行的文字。
    /// - Returns: 两行各自改动的部分，偏移按 UTF-16 计；任一行超过长度上限或改动比例上限时为空。
    static func compare(
        deleted: String,
        added: String
    ) -> (deleted: [Range<Int>], added: [Range<Int>])? {
        let oldLength = deleted.count
        let newLength = added.count

        guard oldLength <= maximumLength, newLength <= maximumLength else {
            return nil
        }

        let old = tokens(of: deleted)
        let new = tokens(of: added)
        var removed: [Int] = []
        var inserted: [Int] = []

        // 删除行里被移除的段与新增行里插入的段，各自记下在本行中的序号
        for change in new.map(\.text).difference(from: old.map(\.text)) {
            switch change {
            case .remove(let offset, _, _):
                removed.append(offset)

            case .insert(let offset, _, _):
                inserted.append(offset)
            }
        }

        // 合并相邻的段要求按行内顺序排列
        removed.sort()
        inserted.sort()

        // 任一行改动的字符太多时，整对都不高亮
        guard
            changedRatio(removed, in: old, length: oldLength) <= maximumChangedRatio,
            changedRatio(inserted, in: new, length: newLength) <= maximumChangedRatio
        else { return nil }

        return (merged(removed, in: old), merged(inserted, in: new))
    }

    /// 把一行切成单词、连续空白与其它单个字符。
    ///
    /// 单词由字母、数字、组合标记与连接标点连成，中文等没有空格分隔的文字连成一个单词；
    /// emoji 与标点按字素簇各自成段，不会从中间切开。
    ///
    /// - Parameter line: 不含换行符的一行文字。
    /// - Returns: 依次覆盖整行的各段。
    static func tokens(of line: String) -> [Token] {
        #warning("TODO: 只改一行的缩进或词间空格，核实空白处是否应当高亮；目前连续空白作为一段参与比较，只影响空白改动的行内高亮")

        var tokens: [Token] = []
        var start = line.startIndex
        var offset = 0
        var length = 0
        var kind: TokenKind? = nil

        // 写入从 start 到 end 的一段，下一段从 end 开始
        func append(upTo end: String.Index) {
            let text = line[start ..< end]
            let units = text.utf16.count

            tokens.append(Token(text: text, range: offset ..< offset + units, length: length))
            offset += units
        }

        for index in line.indices {
            let next = TokenKind(line[index])

            // 单词与空白延续到类别改变为止，其它字符各自成段
            if let kind, next == kind, kind != .other {
                length += 1
                continue
            }

            if kind != nil {
                append(upTo: index)
            }

            start = index
            length = 1
            kind = next
        }

        if kind != nil {
            append(upTo: line.endIndex)
        }

        return tokens
    }
}

// MARK: InlineDiff.Token

extension InlineDiff {
    /// 切分出的一段文字与它在行中的位置。
    struct Token {
        /// 这一段的文字，比较时按 Unicode 标准等价判断相同。
        let text: Substring

        /// 在行中的范围，按 UTF-16 计。
        let range: Range<Int>

        /// 字素簇个数，用于计算改动比例。
        let length: Int
    }
}

// MARK: - Private

extension InlineDiff {
    /// 一组连续改动里删除行与新增行数目相同时，按顺序配对比较，把结果写进各行。
    private static func compare(
        _ deleted: [DiffLine],
        _ added: [DiffLine],
        into result: inout [Int: [Range<Int>]]
    ) {
        guard !deleted.isEmpty, deleted.count == added.count else {
            return
        }

        for (old, new) in zip(deleted, added) {
            guard
                let changes = compare(
                    deleted: String(decoding: old.content, as: UTF8.self),
                    added: String(decoding: new.content, as: UTF8.self)
                )
            else { continue }

            if !changes.deleted.isEmpty {
                result[old.id] = changes.deleted
            }

            if !changes.added.isEmpty {
                result[new.id] = changes.added
            }
        }
    }

    /// 改动的段占整行字素簇的比例；空行没有可改动的字符，按 0 计。
    private static func changedRatio(_ indices: [Int], in tokens: [Token], length: Int) -> Double {
        guard length > 0 else {
            return 0
        }

        let changed = indices.reduce(0) { $0 + tokens[$1].length }
        return Double(changed) / Double(length)
    }

    /// 把相邻的改动段合并成一个范围，减少绘制的片段数。
    private static func merged(_ indices: [Int], in tokens: [Token]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []

        for index in indices {
            let range = tokens[index].range

            if let last = ranges.last, last.upperBound == range.lowerBound {
                ranges[ranges.count - 1] = last.lowerBound ..< range.upperBound
            } else {
                ranges.append(range)
            }
        }

        return ranges
    }
}

// MARK: - TokenKind

/// 切分一行时字符的类别，按字素簇的第一个码位判断。
private enum TokenKind {
    /// 字母、数字、组合标记、连接标点与零宽连接符。
    case word

    /// 空格、制表符、回车等空白。
    case whitespace

    /// 标点、符号与 emoji 等其它字符。
    case other

    /// 判断一个字素簇的类别。
    init(_ character: Character) {
        guard let scalar = character.unicodeScalars.first else {
            self = .other
            return
        }

        let properties = scalar.properties

        if properties.isWhitespace {
            self = .whitespace
            return
        }

        switch properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .connectorPunctuation:
            self = .word

        default:
            // U+200C、U+200D 是零宽不连字与零宽连字，属于单词的一部分
            let joiner = scalar.value == 0x200C || scalar.value == 0x200D
            self = properties.isAlphabetic || joiner ? .word : .other
        }
    }
}
