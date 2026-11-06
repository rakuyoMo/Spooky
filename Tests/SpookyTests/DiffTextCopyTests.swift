import AppKit
import SpookyKit
import Testing

@testable import Spooky

// MARK: - DiffTextCopyTests

/// 复制沿用字符选区，但内容必须来自原始文本，不含行号、展开空格与不可见字符标记。
@MainActor
struct DiffTextCopyTests {
    /// 整块保留已有的末尾 LF，局部选区不扩成整行。
    @Test("Diff 整块与局部字符复制")
    func characterRanges() throws {
        let view = try DiffTextLayoutTests.view("@@ -1,1 +1,1 @@\n-alpha\n+beta\n")
        let content = try #require(view.content)
        #expect(content.copiedText(in: NSRange(location: 0, length: 11)) == "alpha\nbeta\n")
        #expect(content.copiedText(in: NSRange(location: 1, length: 3)) == "lph")
        #expect(content.copiedText(in: NSRange(location: 3, length: 5)) == "ha\nbe")
        #expect(content.copiedText(in: NSRange(location: 3, length: 3)) == "ha\n")
        #expect(content.copiedText(in: NSRange(location: 3, length: 0)).isEmpty)
    }

    /// 无换行提示属于显示和复制源串，但仍对应原始改动行。
    @Test("Diff 无换行提示独立成行")
    func noNewline() throws {
        let view = try DiffTextLayoutTests.view("@@ -0,0 +1,1 @@\n+a\n\\ No newline at end of file\n")
        let content = try #require(view.content)
        #expect(content.rows.count == 2)
        #expect(content.rows.map(\.line.lineID) == [0, 0])
        #expect(
            content
                .copiedText(in: NSRange(location: 0, length: content.attributed.length)) == "a\n No newline at end of file\n"
        )
        #expect(view.measure(width: 500) == 55)
    }

    /// 字面上的标记、Tab、CR 与 UTF-16 多码元字符不能通过反向替换损坏。
    @Test("Diff 原文保真", arguments: [false, true])
    func sourceFidelity(invisibles: Bool) throws {
        let source = "a\t b\r·→¬👍\r"
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
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.declareTypes([.string], owner: nil)
        view.document.setSelectedRange(NSRange(location: 0, length: content.attributed.length))
        #expect(view.document.writeSelection(to: pasteboard, type: .string))
        #expect(pasteboard.string(forType: .string) == source + "\n")
    }

    /// AppKit 转换保留语法色、行内底色与提示行的不可见字符色。
    @Test("Diff AppKit 属性转换保留各类颜色")
    func attributes() throws {
        let style = DiffTextLayoutTests.style
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,1 @@\n+let\n\\ No newline at end of file\n")
        let syntax = DiffSyntax(old: [], new: [[SyntaxSpan(length: 3, style: .keyword)]])
        let content = DiffTextContent(hunk: hunk, style: style, syntax: syntax, highlights: [0: [1 ..< 2]])
        #expect(
            content.attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == style.theme
                .colors["keyword"]?.calibratedNSColor
        )
        #expect(
            content.attributed.attribute(.backgroundColor, at: 1, effectiveRange: nil) as? NSColor == AppPalette
                .nsColor("diff_inline_added_highlight_color")
        )
        #expect(content.attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)
        #expect(
            content.attributed.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor == style.theme
                .colors["invisible"]?.calibratedNSColor
        )
    }

    /// 大块仍以逻辑行索引映射首尾，测试不把墙钟耗时当作正确性条件。
    @Test("Diff 五万行完整文本入口")
    func largeContent() throws {
        let count = 50_000
        let line = "let value = 1234567890; // line content"
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1,\(count) @@\n" + String(repeating: "+" + line + "\n", count: count))
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])
        let height = view.measure(width: 700)
        let content = try #require(view.content)
        #expect(height == 950_017)
        #expect(content.rows.count == count)
        #expect(content.rows.first?.line.numbers == ["0", "+1"])
        #expect(content.rows.last?.line.numbers == ["", "+50000"])
        let tail = try #require(content.rows.last)
        #expect(content.copiedText(in: tail.range) == line + "\n")
        #expect(view.textLayout?.rows(intersecting: CGRect(x: 0, y: 949_981, width: 700, height: 19)).count == 1)
    }
}
