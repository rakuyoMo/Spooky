import AppKit
import Testing

@testable import Spooky

extension TextInvisibleTests {
    /// 标记不参加折行，Tab 与空格在等宽与比例字体里都保持原来的推进距离；同一容器改变字号和 Tab 宽度后，标记位置与复制范围同步重建。
    @Test("不可见字符开关不改变 LF 折行与 Tab 占宽")
    func layout() throws {
        for font in ["Menlo", "Helvetica"] {
            try expectLayout(font: font)
        }
    }

    /// 原生字形与空行 LF 标记绘制到离屏图像，比较它们相对各自行顶的非透明像素行。
    @Test("空行 LF 标记与正文实际绘制基线一致")
    func baseline() throws {
        for (font, size) in [("Menlo", 11.0), ("Courier", 17)] {
            let (first, empty) = try inkRows(font: font, size: size)
            #expect(!first.isEmpty)
            #expect(first == empty)
        }
    }

    /// 按字体比较关闭与打开标记的两份排版，再在打开标记的容器上换字号与 Tab 宽度。
    private func expectLayout(font: String) throws {
        var theme = TextTheme.builtin[0]
        theme.fontName = font
        theme.fontSize = 17
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,2 @@\n+xxxxxxxxxx\n+\t x\tword word word word\n")

        let plain = DiffHunkTextContainer()
        let marked = DiffHunkTextContainer()
        let plainStyle = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        let markedStyle = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true)
        plain.show(hunk: hunk, style: plainStyle, syntax: nil, highlights: [:])
        marked.show(hunk: hunk, style: markedStyle, syntax: nil, highlights: [:])
        let plainManager = try #require(plain.document.layoutManager)
        let markedManager = try #require(marked.document.layoutManager as? TextInvisibleLayoutManager)

        // 含恰好放下十个字符的宽度
        let tenCharacters = NSAttributedString(string: "xxxxxxxxxx", attributes: [.font: theme.font]).size().width
        let exactWidth = try #require(plain.content?.columnWidth) * 2 + 8 + tenCharacters

        for width in [180.0, 500.0, 230.0, exactWidth] {
            #expect(plain.measure(width: width) == marked.measure(width: width))
            #expect(plain.document.string == marked.document.string)
            #expect(plain.textLayout?.rows.map(\.rect) == marked.textLayout?.rows.map(\.rect))

            for index in 0 ..< plainManager.numberOfGlyphs {
                #expect(plainManager.location(forGlyphAt: index) == markedManager.location(forGlyphAt: index))
            }

            // 末行的 LF 标记落在末行之内
            let marks = markedManager.markers(in: NSRange(location: 0, length: markedManager.numberOfGlyphs))
            #expect(marks.filter { $0.text.string == "¬" }.count == 2)

            let last = try #require(marks.last { $0.text.string == "¬" })
            let lastRow = try #require(marked.textLayout?.rows.last)
            #expect(last.rect.minY >= lastRow.rect.minY)
            #expect(last.rect.minY < lastRow.rect.maxY)
        }

        // 同一容器改变字号和 Tab 宽度
        theme.fontSize += 3
        let larger = TextStyle(theme: theme, tabWidth: 8, showsInvisibles: true)
        marked.show(hunk: hunk, style: larger, syntax: nil, highlights: [:])
        _ = marked.measure(width: 500)

        let content = try #require(marked.content)
        let copied = content.copiedText(in: NSRange(location: 0, length: content.attributed.length))
        #expect(copied == "xxxxxxxxxx\n\t x\tword word word word\n")

        let marks = markedManager.markers(in: NSRange(location: 0, length: markedManager.numberOfGlyphs))
        let size = CGFloat(theme.fontSize)
        #expect(marks.filter { $0.text.string == "»" }.count == 2)
        #expect(marks.allSatisfy { mark in
            (mark.text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == size
        })
    }

    /// 绘制 “¬” 与一个空行，返回两行各自相对行顶有墨迹的像素行。
    private func inkRows(font: String, size: Double) throws -> (first: [Int], empty: [Int]) {
        let view = DiffHunkTextContainer()
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,2 @@\n+¬\n+\n")
        var theme = TextTheme.builtin[0]
        theme.colors["invisible"] = theme.colors["text"]
        theme.fontName = font
        theme.fontSize = size
        let style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true)
        view.show(hunk: hunk, style: style, syntax: nil, highlights: [:])
        _ = view.measure(width: 500)

        // 离屏绘制
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

        let inked = { (y: Int) in
            (0 ..< width).contains { (bitmap.colorAt(x: $0, y: y)?.alphaComponent ?? 0) > 0.2 }
        }

        let first = (0 ..< top).filter { inked($0) }
        let empty = (0 ..< top).filter { inked($0 + top) }
        return (first, empty)
    }
}
