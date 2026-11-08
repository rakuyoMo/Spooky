import AppKit
import SpookyKit
import Testing

@testable import Spooky

// MARK: - DiffTextCopyTests

/// 复制沿用字符选区，但内容必须来自原始文本，不含行号、展开空格与不可见字符标记。
@MainActor
struct DiffTextCopyTests {
    /// 整块保留已有的末尾 LF，局部选区不扩成整行；无换行提示属于复制源串但仍对应原始改动行；字面上的标记、Tab、CR 与多码元字符不被反向替换损坏。
    @Test("Diff 字符复制、无换行提示与原文保真")
    func copying() throws {
        let view = try DiffTextLayoutTests.view("@@ -1,1 +1,1 @@\n-alpha\n+beta\n")
        let content = try #require(view.content)
        #expect(content.copiedText(in: NSRange(location: 0, length: 11)) == "alpha\nbeta\n")
        #expect(content.copiedText(in: NSRange(location: 1, length: 3)) == "lph")
        #expect(content.copiedText(in: NSRange(location: 3, length: 5)) == "ha\nbe")
        #expect(content.copiedText(in: NSRange(location: 3, length: 3)) == "ha\n")
        #expect(content.copiedText(in: NSRange(location: 3, length: 0)).isEmpty)

        // 无换行提示独立成行
        let notice = try DiffTextLayoutTests.view("@@ -0,0 +1,1 @@\n+a\n\\ No newline at end of file\n")
        let noticeContent = try #require(notice.content)
        let whole = NSRange(location: 0, length: noticeContent.attributed.length)
        #expect(noticeContent.rows.map(\.line.lineID) == [0, 0])
        #expect(noticeContent.copiedText(in: whole) == "a\n No newline at end of file\n")
        #expect(notice.measure(width: 500) == 55)

        for invisibles in [false, true] {
            try expectFidelity(invisibles: invisibles)
        }
    }

    /// AppKit 转换保留语法色、行内底色与提示行的不可见字符色。
    @Test("Diff AppKit 属性转换保留各类颜色")
    func attributes() throws {
        let style = DiffTextLayoutTests.style
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,1 @@\n+let\n\\ No newline at end of file\n")
        let syntax = DiffSyntax(old: [], new: [[SyntaxSpan(length: 3, style: .keyword)]])
        let content = DiffTextContent(hunk: hunk, style: style, syntax: syntax, highlights: [0: [1 ..< 2]])
        let text = content.attributed

        let keyword = text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(keyword == style.theme.colors["keyword"]?.calibratedNSColor)

        let highlight = text.attribute(.backgroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(highlight == AppPalette.nsColor("diff_inline_added_highlight_color"))
        #expect(text.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)

        let invisible = text.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        #expect(invisible == style.theme.colors["invisible"]?.calibratedNSColor)
    }

    /// 大块仍以逻辑行索引映射首尾，测试不把墙钟耗时当作正确性条件。
    @Test("Diff 五千行完整文本入口")
    func largeContent() throws {
        let count = 5000
        let line = "let value = 1234567890; // line content"
        let body = String(repeating: "+" + line + "\n", count: count)
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,\(count) @@\n" + body)

        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])
        let height = view.measure(width: 700)
        let content = try #require(view.content)
        #expect(height == 95_017)
        #expect(content.rows.count == count)
        #expect(content.rows.first?.line.numbers == ["0", "+1"])
        #expect(content.rows.last?.line.numbers == ["", "+5000"])

        // 末行的复制与命中
        let tail = try #require(content.rows.last)
        #expect(content.copiedText(in: tail.range) == line + "\n")
        #expect(view.textLayout?.rows(intersecting: CGRect(x: 0, y: 94_981, width: 700, height: 19)).count == 1)
    }

    /// 按是否显示不可见字符核对整行、Tab、表情与原生 Copy 的复制结果。
    private func expectFidelity(invisibles: Bool) throws {
        let source = "a\t b\r·→»¬␍👍\r"
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,1 @@\n+\(source)\n")
        let style = TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: invisibles)
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: style, syntax: nil, highlights: [:])

        let content = try #require(view.content)
        #expect(content.copiedText(in: NSRange(location: 0, length: content.attributed.length)) == source + "\n")
        #expect(content.copiedText(in: NSRange(location: 2, length: 1)) == "\t")

        let displayed = content.attributed.string
        let emoji = NSRange(try #require(displayed.range(of: "👍")), in: displayed)
        #expect(content.copiedText(in: emoji) == (invisibles ? "👍" : "👍\r"))

        // 原生 Copy
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        pasteboard.declareTypes([.string], owner: nil)
        view.document.setSelectedRange(NSRange(location: 0, length: content.attributed.length))
        #expect(view.document.writeSelection(to: pasteboard, type: .string))
        #expect(pasteboard.string(forType: .string) == source + "\n")
    }
}
