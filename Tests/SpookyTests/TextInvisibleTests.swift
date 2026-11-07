import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

/// 不可见字符的显示身份、真实行尾与复制源保持独立。
@MainActor
struct TextInvisibleTests {
    /// 空文件、终止 LF、CRLF、行内 CR 与无 LF 末行。
    nonisolated static let endings: [(String, Int, Int)] = [
        ("", 0, 0), ("\n", 1, 0), ("a", 0, 0), ("a\n", 1, 0),
        ("a\n\n", 2, 0), ("a\r", 0, 1), ("a\r\n", 0, 1),
        ("a\rb\n", 1, 1), ("a\r\nb\n\rc", 1, 2),
    ]

    /// 初始化无窗口的 AppKit 字体环境。
    init() { _ = NSApplication.shared }

    /// 原文只有实际 LF 才显示行尾标记，行内 CR 不抑制它；CRLF 只显示 CR。
    @Test("原文的真实 LF 与 CR 归属", arguments: endings, [false, true])
    func endings(sample: (String, Int, Int), enabled: Bool) throws {
        let document = file(sample.0, enabled: enabled)
        let manager = try #require(document.layoutManager as? TextInvisibleLayoutManager)
        manager.ensureLayout(for: try #require(document.textContainer))
        let marks = manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs))
        #expect(marks.filter { $0.text.string == "¬" }.count == (enabled ? sample.1 : 0))
        #expect(document.string.filter { $0 == "␍" }.count == (enabled ? sample.2 : 0))
        #expect(document.string.filter { $0 == "\n" }.count == sample.0.utf16.filter { $0 == 10 }.count)
        #expect(!document.string.contains("\r"))
        #expect(document.copiedText(in: NSRange(location: 0, length: document.string.utf16.count)) == sample.0)
        #expect(FileRevisionContent.displayLines(Data(sample.0.utf8)).count == sample.0.utf8.split(
            separator: 10,
            omittingEmptySubsequences: false
        ).count - (sample.0.utf16.last == 10 || sample.0.isEmpty ? 1 : 0))
    }

    /// 标记色与语法色独立；只标源空格，不标 Tab 补位或 NBSP。
    @Test("共享标记身份、颜色与行内高亮")
    func markers() throws {
        let theme = TextTheme.builtin[0]
        let style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true)
        let text = "\t \u{A0}x"
        let spans = [SyntaxSpan(length: text.utf16.count, style: .keyword)]
        let rendered = TextLineRenderer.rendered(text, spans: spans, highlights: [0 ..< 2], highlightColor: .red, style: style)
        let content = rendered.appKit(attributes: DiffTextContent.attributes(style: style))
        #expect(content.string == "     \u{A0}x")
        #expect(rendered.markers == [0: "»", 4: "·"])
        #expect(content.attribute(.backgroundColor, at: 0, effectiveRange: nil) != nil)
        #expect(content.attribute(.backgroundColor, at: 4, effectiveRange: nil) != nil)
        for index in [0, 4] {
            let color = try #require(content.attribute(
                TextInvisibleLayoutManager.color,
                at: index,
                effectiveRange: nil
            ) as? NSColor)
            #expect(color == theme.colors["invisible"]?.calibratedNSColor)
        }
        #expect(
            content.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor == theme.colors["keyword"]?
                .calibratedNSColor
        )
    }

    /// 原生复制入口恢复完整 blob，显示替换的 Unicode 分隔符和源文件已有的标记都保持。
    @Test("原文复制不使用显示替换串", arguments: [false, true])
    func copying(enabled: Bool) throws {
        let source = "a\t b\r\n👍»·¬␍\u{85}\u{2028}\u{2029}\nlast\r"
        let document = file(source, enabled: enabled)
        let full = NSRange(location: 0, length: document.string.utf16.count)
        #expect(document.copiedText(in: full) == source)
        #expect(document.copiedText(in: NSRange(location: 2, length: 1)) == "\t")
        let emoji = NSRange(try #require(document.string.range(of: "👍")), in: document.string)
        #expect(document.copiedText(in: emoji) == "👍")
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.declareTypes([.string], owner: nil)
        document.setSelectedRange(full)
        #expect(document.writeSelection(to: pasteboard, type: .string))
        #expect(pasteboard.string(forType: .string) == source)
    }

    /// Diff 无换行正文与提示各自补 LF，但不改变补丁行数或真实文件标记。
    @Test("Diff 提示和无换行末行都有显示 LF")
    func diffNotice() throws {
        let hunk = try DiffTextLayoutTests.hunk("@@ -0,0 +1 @@\n+last\n\\ No newline at end of file\n")
        let view = DiffHunkTextContainer()
        let style = TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: true)
        view.show(hunk: hunk, style: style, syntax: nil, highlights: [:])
        #expect(view.measure(width: 500) == 55)
        let manager = try #require(view.document.layoutManager as? TextInvisibleLayoutManager)
        let marks = manager.markers(in: NSRange(location: 0, length: manager.numberOfGlyphs))
        #expect(marks.filter { $0.text.string == "¬" }.count == 2)
        #expect(marks.contains { $0.characterIndex == 5 && $0.text.string == "·" })
        #expect(hunk.lines.count == 1 && hunk.lines[0].noNewline)
        #expect(view.content?.rows.count == 2)
    }

    /// 用完整源串和字节切出的显示行构造生产正文。
    func file(_ source: String, enabled: Bool, theme: TextTheme = TextTheme.builtin[0]) -> FileTextDocumentView {
        let document = FileTextDocumentView.make()
        document.show(
            FileRevisionContent.displayLines(Data(source.utf8)),
            source: source,
            style: FileTextStyle(theme: theme),
            rendering: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: enabled),
            spans: nil
        )
        return document
    }
}
