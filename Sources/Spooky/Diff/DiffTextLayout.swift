import AppKit

// MARK: - DiffTextLayout

/// 同一 TextKit 文本栈量出的逻辑行矩形与基线，绘制和命中测试共用。
struct DiffTextLayout {
    /// 一个逻辑显示行的全部折行区域。
    struct Row {
        /// 显示行在内容数组中的位置。
        let index: Int

        /// 相对正文的区域，包含全部视觉折行。
        let rect: CGRect

        /// 第一视觉行的正文基线，相对正文顶边。
        let baseline: CGFloat
    }

    /// 按纵坐标递增排列的逻辑行。
    let rows: [Row]

    /// 含最后一个空片段的正文高度。
    let height: CGFloat

    /// 从实际布局管理器读取字符范围的全部折行；空 LF 使用正常字体基线。
    init(content: DiffTextContent, document: NSTextView, style: TextStyle) {
        guard let manager = document.layoutManager, let container = document.textContainer else {
            rows = []
            height = 0
            return
        }

        manager.ensureLayout(for: container)
        let font = style.theme.font
        let minimum = (font.ascender - font.descender + 4).rounded()
        let baselineOffset = manager.defaultBaselineOffset(for: font)
            + max(0, minimum - manager.defaultLineHeight(for: font))
        rows = content.rows.enumerated().map { index, row in
            let glyphs = manager.glyphRange(forCharacterRange: row.range, actualCharacterRange: nil)
            let first = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            let last = manager.lineFragmentRect(forGlyphAt: NSMaxRange(glyphs) - 1, effectiveRange: nil)
            let rect = first.union(last)
            let baseline = row.range.length == 1 ? baselineOffset : manager.location(forGlyphAt: glyphs.location).y
            return Row(index: index, rect: rect, baseline: first.minY + baseline)
        }
        height = ceil(max(manager.usedRect(for: container).maxY, manager.extraLineFragmentRect.maxY))
    }

    /// 用二分定位首个相交行，只遍历需要绘制的可见部分。
    func rows(intersecting rect: CGRect) -> ArraySlice<Row> {
        var lower = 0
        var upper = rows.count

        while lower < upper {
            let middle = (lower + upper) / 2

            if rows[middle].rect.maxY <= rect.minY {
                lower = middle + 1
            } else {
                upper = middle
            }
        }

        let start = lower

        while lower < rows.count, rows[lower].rect.minY < rect.maxY {
            lower += 1
        }

        return rows[start ..< lower]
    }

    /// 末尾空片段不属于任何补丁行。
    func row(at point: CGPoint) -> Row? {
        rows(intersecting: CGRect(x: 0, y: point.y, width: 1, height: 0.001)).first
    }
}
