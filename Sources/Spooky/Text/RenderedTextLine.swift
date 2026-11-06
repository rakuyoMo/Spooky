import AppKit
import SwiftUI

// MARK: - RenderedTextLine

/// 一行的显示属性与原文偏移映射；复制只读取原文，不反向替换可见标记。
struct RenderedTextLine {
    /// 带语法色与行内底色的显示内容。
    let attributed: AttributedString

    /// 显示字符与源字符的 UTF-16 对应关系。
    let mapping: TextSourceMap

    /// 转成 TextKit 使用的属性，保留正文、语法色与行内高亮底色。
    func appKit(attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for run in attributed.runs {
            var values = attributes

            if let color = run.foregroundColor {
                values[.foregroundColor] = NSColor(color)
            }

            if let color = run.backgroundColor {
                values[.backgroundColor] = NSColor(color)
            }

            result.append(NSAttributedString(
                string: String(attributed[run.range].characters),
                attributes: values
            ))
        }

        return result
    }
}

// MARK: - TextSourceMap

/// 合并连续的一对一字符映射，制表符展开和隐藏的回车单独记录。
struct TextSourceMap {
    /// 一段显示范围与它对应的原文范围。
    struct Segment {
        /// 显示串内的 UTF-16 范围，隐藏字符的长度为零。
        var display: NSRange

        /// 原文内的 UTF-16 范围。
        var source: NSRange
    }

    /// 已按原文顺序排好的片段。
    private(set) var segments: [Segment] = []

    /// 原文的累计 UTF-16 长度。
    private(set) var sourceLength = 0

    /// 显示串的累计 UTF-16 长度。
    private(set) var displayLength = 0

    /// 记录一个字符的显示长度；普通连续字符合并，避免长文件逐字符保存对象。
    mutating func append(source: Int, display: Int) {
        if
            source == display,
            let last = segments.last,
            last.source.length == last.display.length
        {
            segments[segments.count - 1].source.length += source
            segments[segments.count - 1].display.length += display
        } else {
            segments.append(Segment(
                display: NSRange(location: displayLength, length: display),
                source: NSRange(location: sourceLength, length: source)
            ))
        }

        sourceLength += source
        displayLength += display
    }

    /// 将非空的显示选区还原为源范围；选中部分 Tab 也只复制一个原始 Tab。
    func sourceRange(for range: NSRange) -> NSRange {
        guard range.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let lower = max(0, range.location)
        let upper = min(displayLength, NSMaxRange(range))
        var start: Int?
        var end = 0

        for segment in segments {
            let left = segment.display.location
            let right = NSMaxRange(segment.display)
            let hidden = segment.display.length == 0

            guard hidden ? (left >= lower && left <= upper) : (right > lower && left < upper) else {
                continue
            }

            let identity = segment.source.length == segment.display.length
            let sourceStart = segment.source.location + (identity ? max(0, lower - left) : 0)
            let sourceEnd = NSMaxRange(segment.source) - (identity ? max(0, right - upper) : 0)
            start = min(start ?? sourceStart, sourceStart)
            end = max(end, sourceEnd)
        }

        return NSRange(location: start ?? 0, length: end - (start ?? 0))
    }
}
