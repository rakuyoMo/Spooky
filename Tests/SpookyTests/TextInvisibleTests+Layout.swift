import AppKit
import Testing

@testable import Spooky

extension TextInvisibleTests {
    /// 标记不参加折行，Tab 与空格在比例字体里也保持原来的推进距离。
    @Test("不可见字符开关不改变 LF 折行与 Tab 占宽", arguments: ["Menlo", "Helvetica", "Courier"])
    func layout(font: String) throws {
        var theme = TextTheme.builtin[0]
        theme.fontName = font
        theme.fontSize = 17
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,2 @@\n+xxxxxxxxxx\n+\t x\tword word word word\n")
        let plain = DiffHunkTextContainer()
        let marked = DiffHunkTextContainer()
        plain.show(hunk: hunk, style: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false), syntax: nil, highlights: [:])
        marked.show(hunk: hunk, style: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true), syntax: nil, highlights: [:])
        let plainManager = try #require(plain.document.layoutManager)
        let markedManager = try #require(marked.document.layoutManager as? TextInvisibleLayoutManager)

        let tenCharacters = NSAttributedString(string: "xxxxxxxxxx", attributes: [.font: theme.font]).size().width
        let exactWidth = try #require(plain.content?.columnWidth) * 2 + 8 + tenCharacters
        for width in [180.0, 500.0, 230.0, exactWidth] {
            #expect(plain.measure(width: width) == marked.measure(width: width))
            #expect(plain.document.string == marked.document.string)
            #expect(plain.textLayout?.rows.map(\.rect) == marked.textLayout?.rows.map(\.rect))
            for index in 0 ..< plainManager.numberOfGlyphs {
                #expect(plainManager.location(forGlyphAt: index) == markedManager.location(forGlyphAt: index))
            }
            let marks = markedManager.markers(in: NSRange(location: 0, length: markedManager.numberOfGlyphs))
            #expect(marks.filter { $0.text.string == "¬" }.count == 2)
            let last = try #require(marks.last { $0.text.string == "¬" })
            let lastRow = try #require(marked.textLayout?.rows.last)
            #expect(last.rect.minY >= lastRow.rect.minY)
            #expect(last.rect.minY < lastRow.rect.maxY)
        }

        // 同一容器改变字号和 Tab 宽度后，标记位置与复制范围同步重建。
        theme.fontSize += 3
        let style = TextStyle(theme: theme, tabWidth: 8, showsInvisibles: true)
        marked.show(hunk: hunk, style: style, syntax: nil, highlights: [:])
        _ = marked.measure(width: 500)
        let content = try #require(marked.content)
        #expect(
            content
                .copiedText(in: NSRange(location: 0, length: content.attributed.length)) ==
                "xxxxxxxxxx\n\t x\tword word word word\n"
        )
        let marks = markedManager.markers(in: NSRange(location: 0, length: markedManager.numberOfGlyphs))
        #expect(marks.filter { $0.text.string == "»" }.count == 2)
        #expect(
            marks
                .allSatisfy {
                    ($0.text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == CGFloat(theme.fontSize)
                }
        )
    }

    /// 原生字形与空行 LF 标记绘制到离屏图像，比较它们相对各自行顶的非透明像素行。
    @Test("空行 LF 标记与正文实际绘制基线一致", arguments: ["Menlo", "Courier"], [11.0, 17.0])
    func baseline(font: String, size: Double) throws {
        let view = DiffHunkTextContainer()
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,2 @@\n+¬\n+\n")
        var theme = TextTheme.builtin[0]
        theme.colors["invisible"] = theme.colors["text"]
        theme.fontName = font
        theme.fontSize = size
        let style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true)
        view.show(hunk: hunk, style: style, syntax: nil, highlights: [:])
        _ = view.measure(width: 500)
        let manager = try #require(view.document.layoutManager as? TextInvisibleLayoutManager)
        let range = NSRange(location: 0, length: manager.numberOfGlyphs)
        let image = NSImage(size: NSSize(width: 100, height: 80), flipped: true) { _ in
            manager.drawGlyphs(forGlyphRange: range, at: .zero)
            return true
        }
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let rows = try #require(view.textLayout?.rows)
        let top = Int(rows[1].rect.minY)
        let width = Int(NSAttributedString(string: "¬", attributes: [.font: theme.font]).size().width.rounded(.down))
        var first: [Int] = []
        var empty: [Int] = []
        for y in 0 ..< top {
            if (0 ..< width).contains(where: { (bitmap.colorAt(x: $0, y: y)?.alphaComponent ?? 0) > 0.2 }) { first.append(y) }
            if
                (0 ..< width)
                    .contains(where: { (bitmap.colorAt(x: $0, y: y + top)?.alphaComponent ?? 0) > 0.2 }) { empty.append(y) }
        }
        #expect(!first.isEmpty)
        #expect(first == empty)
    }
}
