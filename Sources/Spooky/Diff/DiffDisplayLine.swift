import AppKit
import SpookyKit

// MARK: - DiffDisplayLine

/// 块内一个显示行；提示行与正文可以指向同一个补丁行。
struct DiffDisplayLine {
    /// 所属的逻辑补丁行，不是显示行序号。
    let lineID: Int

    /// 不带补丁前缀的原文。
    let source: String

    /// 各列已去重并带增删符号的行号。
    let numbers: [String]

    /// 上下文、删除或新增的前缀，提示行为 nil。
    let prefix: UInt8?

    /// 无换行提示不参与行号推进。
    var isNotice: Bool { prefix == nil }

    /// 普通补丁的完整两侧行号先按各自范围推进，再与上一逻辑行去重。
    static func rows(in hunk: DiffHunk) -> [Self] {
        var old = max(0, hunk.oldStart - (hunk.lines.contains { $0.oldNumber != nil } ? 1 : 0))
        var new = max(0, hunk.newStart - (hunk.lines.contains { $0.newNumber != nil } ? 1 : 0))
        var previous: [Int]? = nil
        var result: [Self] = []

        for line in hunk.lines {
            old = line.oldNumber ?? old
            new = line.newNumber ?? new
            let values = [old, new]
            let numbers = values.enumerated().map { column, value in
                guard previous?[column] != value else { return "" }

                let sign = column == 0 && line.prefix == 45 ? "-" : (column == 1 && line.prefix == 43 ? "+" : "")
                return sign + String(value)
            }

            result.append(Self(
                lineID: line.id,
                source: String(decoding: line.content, as: UTF8.self),
                numbers: numbers,
                prefix: line.prefix
            ))
            previous = values

            if line.noNewline {
                result.append(Self(
                    lineID: line.id,
                    source: " No newline at end of file",
                    numbers: ["", ""],
                    prefix: nil
                ))
            }
        }

        return result
    }

    /// 每列按块内最大行号量宽，留出符号、左右间距、额外留宽与边线。
    static func columnWidth(in rows: [Self], font: NSFont) -> CGFloat {
        let maximum = rows.flatMap(\.numbers).compactMap { Int($0) }.map(abs).max() ?? 0
        return ceil(27 + NSAttributedString(string: "+\(maximum)", attributes: [.font: font]).size().width)
    }
}
