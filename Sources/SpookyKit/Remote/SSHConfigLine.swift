import Foundation

// MARK: - SSHConfigLine

/// SSH 配置文件里的一条配置：关键字与它的各个参数，按 OpenSSH 读配置的规则拆出。
///
/// 关键字与参数之间是空白，中间可以夹一个等号；参数之间是空格或制表符。
/// 参数可以用单引号或双引号括起来，`\"`、`\'`、`\\` 与引号外的 `\ ` 是转义；引号外以 `#` 开头的参数起，到行尾都是注释。
struct SSHConfigLine {
    /// 一个参数。
    struct Argument {
        /// 去掉引号与转义之后的值。
        let value: String

        /// 参数在这一行里的范围，包括引号。
        let range: Range<String.Index>
    }

    /// 小写的关键字；SSH 的关键字不分大小写。
    let keyword: String

    /// 各个参数，按先后顺序。
    let arguments: [Argument]

    /// 拆出一行里的配置；空行、注释与引号没有闭合的关键字都不是配置。
    ///
    /// - Parameter line: 不带换行符的一行。
    init?(_ line: String) {
        let scalars = line.unicodeScalars

        // 行尾的空白不属于最后一个参数
        var end = scalars.endIndex

        while end > scalars.startIndex, Self.trailing.contains(scalars[scalars.index(before: end)]) {
            end = scalars.index(before: end)
        }

        var index = Self.skip(Self.whitespace, in: scalars, from: scalars.startIndex, to: end)

        guard
            index < end,
            scalars[index] != "#",
            let keyword = Self.keyword(in: scalars, at: &index, to: end)
        else { return nil }

        self.keyword = keyword.lowercased()

        // 关键字之后是空白，中间可以夹一个等号
        index = Self.skip(Self.whitespace, in: scalars, from: index, to: end)

        if index < end, scalars[index] == "=" {
            index = Self.skip(Self.whitespace, in: scalars, from: scalars.index(after: index), to: end)
        }

        var arguments: [Argument] = []

        while let argument = Self.argument(in: scalars, at: &index, to: end) {
            arguments.append(argument)
        }

        self.arguments = arguments
    }
}

// MARK: - Private

extension SSHConfigLine {
    /// 关键字前后的空白。
    private static let whitespace: Set<Unicode.Scalar> = [" ", "\t", "\r", "\n"]

    /// 行尾不算内容的字符：空白与换页符。
    private static let trailing: Set<Unicode.Scalar> = [" ", "\t", "\r", "\n", "\u{0C}"]

    /// 参数之间的分隔。
    private static let separators: Set<Unicode.Scalar> = [" ", "\t"]

    /// 读出关键字并移到它之后：带双引号的到下一个双引号为止，不带的到空白或等号为止；引号没有闭合时为 nil。
    private static func keyword(
        in scalars: String.UnicodeScalarView,
        at index: inout String.Index,
        to end: String.Index
    ) -> String? {
        guard scalars[index] == "\"" else {
            let start = index

            while index < end, !whitespace.contains(scalars[index]), scalars[index] != "=" {
                index = scalars.index(after: index)
            }

            return String(scalars[start ..< index])
        }

        let start = scalars.index(after: index)

        guard let close = scalars[start ..< end].firstIndex(of: "\"") else {
            return nil
        }

        index = scalars.index(after: close)

        return String(scalars[start ..< close])
    }

    /// 读出下一个参数并移到它之后；后面没有参数或是注释时为 nil。
    private static func argument(
        in scalars: String.UnicodeScalarView,
        at index: inout String.Index,
        to end: String.Index
    ) -> Argument? {
        index = skip(separators, in: scalars, from: index, to: end)

        guard index < end, scalars[index] != "#" else {
            return nil
        }

        let start = index
        var value = String.UnicodeScalarView()
        var quote: Unicode.Scalar? = nil

        while index < end {
            let scalar = scalars[index]
            let next = scalars.index(after: index)

            // 转义的字符原样进入值，反斜杠本身不进
            if scalar == "\\", next < end, isEscapable(scalars[next], quoted: quote != nil) {
                value.append(scalars[next])
                index = scalars.index(after: next)
                continue
            }

            if quote == nil, separators.contains(scalar) {
                break
            }

            if scalar == quote {
                quote = nil
            } else if quote == nil, scalar == "\"" || scalar == "'" {
                quote = scalar
            } else {
                value.append(scalar)
            }

            index = next
        }

        return Argument(value: String(value), range: start ..< index)
    }

    /// 反斜杠后面的这个字符是否与它合成一个转义：引号与反斜杠总是，空格只在引号外是。
    private static func isEscapable(_ scalar: Unicode.Scalar, quoted: Bool) -> Bool {
        scalar == "\"" || scalar == "'" || scalar == "\\" || (!quoted && scalar == " ")
    }

    /// 从给定位置起跳过一组字符，返回第一个不在其中的位置。
    private static func skip(
        _ skipped: Set<Unicode.Scalar>,
        in scalars: String.UnicodeScalarView,
        from start: String.Index,
        to end: String.Index
    ) -> String.Index {
        var index = start

        while index < end, skipped.contains(scalars[index]) {
            index = scalars.index(after: index)
        }

        return index
    }
}
