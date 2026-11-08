import AppKit
import Testing

@testable import Spooky

// MARK: - PullRequestMarkdownTests

/// 评论与描述的正文按完整的 Markdown 显示：各种块与行内格式的字体、颜色、框与间距。
struct PullRequestMarkdownTests {
    /// 不带空行的几行在原文里是同一段，显示时仍按行断开，行与行之间不留段落间距。
    /// HTML 块整块不显示，行内 HTML 只去掉标签，分隔线不显示。
    @Test("换行、HTML 与分隔线")
    func lineBreaks() throws {
        let string = PullRequestMarkdown.convert("one\ntwo  \nthree\n\nnext")

        #expect(string.string == "one\ntwo\nthree\nnext")
        #expect(try Self.style(of: "one", in: string).paragraphSpacing == 0)
        #expect(try Self.style(of: "two", in: string).paragraphSpacing == 0)
        #expect(try Self.style(of: "three", in: string).paragraphSpacing == 12)
        #expect(try Self.style(of: "next", in: string).paragraphSpacing == 12)

        // HTML 块与分隔线不显示，行内 HTML 只去掉标签
        let html = PullRequestMarkdown.convert(
            "before\n\n<div>\nblock\n</div>\n\ntext <b>bold</b> <!-- note --> end\n\n---\n\nafter"
        )

        #expect(html.string == "before\ntext bold  end\nafter")
    }

    /// H1–H3 是 24 / 18 / 14 pt 常规字，H4–H6 是 13 pt 粗体，H6 用次一级的文字色；
    /// 斜体与粗体加在正文字体上，行内代码是等宽 12 pt，删除线是单线；链接与图片的地址照原样保留，不按协议过滤。
    @Test("标题、行内格式与链接")
    func inlineFormats() throws {
        let headers = PullRequestMarkdown.convert("# T1\n## T2\n### T3\n#### T4\n##### T5\n###### T6")
        let sizes: [CGFloat] = [24, 18, 14, 13, 13, 13]
        let family = NSFont.userFont(ofSize: 13)?.familyName

        for level in 1 ... 6 {
            let font = try #require(Self.attribute(.font, of: "T\(level)", in: headers) as? NSFont)
            let color = Self.attribute(.foregroundColor, of: "T\(level)", in: headers) as? NSColor

            #expect(font.pointSize == sizes[level - 1], "H\(level)")
            #expect(font.familyName == family, "H\(level)")
            #expect(font.fontDescriptor.symbolicTraits.contains(.bold) == (level >= 4), "H\(level)")
            #expect(color == (level == 6 ? .secondaryLabelColor : .labelColor), "H\(level)")
            #expect(try Self.style(of: "T\(level)", in: headers).paragraphSpacing == 12)
        }

        // 行内格式
        let string = PullRequestMarkdown.convert("*soft* **loud** `tick` ~~gone~~ plain")

        let italic = try #require(Self.attribute(.font, of: "soft", in: string) as? NSFont)
        let bold = try #require(Self.attribute(.font, of: "loud", in: string) as? NSFont)
        let code = try #require(Self.attribute(.font, of: "tick", in: string) as? NSFont)
        let plain = try #require(Self.attribute(.font, of: "plain", in: string) as? NSFont)

        #expect(italic.fontDescriptor.symbolicTraits.contains(.italic))
        #expect(bold.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(code.isFixedPitch && code.pointSize == 12)
        #expect(plain == .systemFont(ofSize: 13))

        #expect(Self.attribute(.strikethroughStyle, of: "gone", in: string) as? Int == NSUnderlineStyle.single.rawValue)
        #expect(Self.attribute(.strikethroughStyle, of: "plain", in: string) == nil)

        // 链接与图片的地址照原样保留，图片显示替代文字
        let links = PullRequestMarkdown.convert(
            [
                "[site](https://example.com/a)",
                "[notes](file:///tmp/notes.txt)",
                "<mailto:me@example.com>",
                "![logo](https://example.com/logo.png)",
            ]
            .joined(separator: " ")
        )

        #expect(Self.attribute(.link, of: "site", in: links) as? URL == URL(string: "https://example.com/a"))
        #expect(Self.attribute(.link, of: "notes", in: links) as? URL == URL(string: "file:///tmp/notes.txt"))
        #expect(Self.attribute(.link, of: "mailto:me", in: links) as? URL == URL(string: "mailto:me@example.com"))
        #expect(Self.attribute(.link, of: "logo", in: links) as? URL == URL(string: "https://example.com/logo.png"))
    }

    /// 代码块的各行共用一个框：四边 1 pt 边框、内边距 8、宽度占满，没有段后间距，之后空一行。
    /// 引用块的几段共用一个框：四边 4 pt 边框只有左边有颜色，左右内边距 8，文字用停用控件的文字色。
    /// 代码块的底色、文字与边框，以及引用块的竖条，按画的时候的外观取值。
    @Test("代码块与引用块的框、字体与颜色")
    func blocks() throws {
        let string = PullRequestMarkdown.convert("```swift\nlet a = 1\nlet b = 2\n```\n\nafter")

        #expect(string.string == "let a = 1\nlet b = 2\n\nafter")

        let first = try #require(Self.style(of: "let a", in: string).textBlocks.last)
        let second = try #require(Self.style(of: "let b", in: string).textBlocks.last)
        #expect(first === second)

        for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
            #expect(first.width(for: .border, edge: edge) == 1)
            #expect(first.width(for: .padding, edge: edge) == 8)
        }

        #expect(first.contentWidth == 100 && first.contentWidthValueType == .percentageValueType)
        #expect(try Self.style(of: "let a", in: string).paragraphSpacing == 0)
        #expect(try Self.style(of: "let b", in: string).paragraphSpacing == 0)
        #expect(try Self.style(of: "after", in: string).textBlocks.isEmpty)

        let font = try #require(Self.attribute(.font, of: "let b", in: string) as? NSFont)
        #expect(font.isFixedPitch && font.pointSize == 12)

        // 引用块
        let quoted = PullRequestMarkdown.convert("> first\n>\n> second\n\nafter")

        #expect(quoted.string == "first\nsecond\nafter")

        let quote = try #require(Self.style(of: "first", in: quoted).textBlocks.first)
        let next = try #require(Self.style(of: "second", in: quoted).textBlocks.first)
        #expect(quote === next)

        for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
            #expect(quote.width(for: .border, edge: edge) == 4)
        }

        #expect(quote.borderColor(for: .minX) != nil)
        #expect(quote.borderColor(for: .maxX) == nil)
        #expect(quote.width(for: .padding, edge: .minX) == 8 && quote.width(for: .padding, edge: .maxX) == 8)
        #expect(quote.width(for: .padding, edge: .minY) == 0 && quote.width(for: .padding, edge: .maxY) == 0)
        #expect(quote.backgroundColor == nil)

        #expect(Self.attribute(.foregroundColor, of: "second", in: quoted) as? NSColor == .disabledControlTextColor)
        #expect(try Self.style(of: "second", in: quoted).paragraphSpacing == 12)

        // 两种外观下的颜色
        try Self.expectBlockColors()
    }

    /// 有序列表从原文的起始序号数，嵌在列表里的无序列表用空心圆点；每层缩进 8，最外层的列表结束时空一行。
    /// 表格的各单元格共用一个表格：格线都是 1 pt，表头粗体，按列对齐，空的单元格补齐，表格之后空一行。
    @Test("列表与表格")
    func listsAndTable() throws {
        let list = PullRequestMarkdown.convert("3. three\n4. four\n   - nested\n\nafter\n\n- a\n- b")

        #expect(list.string == "3. three\n4. four\n◦ nested\n\nafter\n• a\n• b")

        let three = try Self.style(of: "three", in: list)
        let four = try Self.style(of: "four", in: list)
        let nested = try Self.style(of: "nested", in: list)

        #expect(three.textLists.count == 1 && three.textLists.first === four.textLists.first)
        #expect(nested.textLists.count == 2)
        #expect(three.headIndent == 8 && three.firstLineHeadIndent == 8)
        #expect(nested.headIndent == 16 && nested.firstLineHeadIndent == 16)
        #expect(three.paragraphSpacing == 0 && nested.paragraphSpacing == 0)
        #expect(three.textLists.first?.markerFormat == .decimal)
        #expect(nested.textLists.last?.markerFormat == .circle)
        #expect(try Self.style(of: "after", in: list).textLists.isEmpty)

        // 表格
        let string = PullRequestMarkdown.convert("| Name | Size |\n|:--|--:|\n| one | |\n| two | 2 |\n\nafter")

        #expect(string.string == "Name\nSize\none\n\ntwo\n2\n\nafter")

        let cells = try ["Name", "Size", "one", "two", "2"].map { name in
            try #require(Self.style(of: name, in: string).textBlocks.last as? NSTextTableBlock)
        }

        #expect(cells.allSatisfy { $0.table === cells[0].table })
        #expect(cells[0].table.numberOfColumns == 2)
        #expect(cells.map(\.startingRow) == [0, 0, 1, 2, 2])
        #expect(cells.map(\.startingColumn) == [0, 1, 0, 0, 1])
        #expect(
            cells.allSatisfy {
                $0.width(for: .padding, edge: .minX) == 4
                    && $0.width(for: .padding, edge: .maxY) == 4
            }
        )

        // 相邻单元格之间只有一条 1 pt 的线：每格画右边与下边，第一列另画左边，表头一行另画上边
        let edges: [NSRectEdge] = [.minX, .minY, .maxX, .maxY]
        #expect(edges.map { cells[0].width(for: .border, edge: $0) } == [1, 1, 1, 1])
        #expect(edges.map { cells[1].width(for: .border, edge: $0) } == [0, 1, 1, 1])
        #expect(edges.map { cells[2].width(for: .border, edge: $0) } == [1, 0, 1, 1])
        #expect(edges.map { cells[4].width(for: .border, edge: $0) } == [0, 0, 1, 1])

        // 第二行的第二格没有文字，仍是一个单元格
        let location = "Name\nSize\none\n".utf16.count
        let empty = try #require(Self.style(at: location, in: string).textBlocks.last as? NSTextTableBlock)
        #expect(empty.startingRow == 1 && empty.startingColumn == 1)

        #expect(try Self.style(of: "Name", in: string).alignment == .left)
        #expect(try Self.style(of: "Size", in: string).alignment == .right)

        let header = try #require(Self.attribute(.font, of: "Name", in: string) as? NSFont)
        let body = try #require(Self.attribute(.font, of: "one", in: string) as? NSFont)
        #expect(header.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(!body.fontDescriptor.symbolicTraits.contains(.bold))
    }

    /// 文字区的高度按宽度折行量出，宽度变窄时变高，正文末尾不留空行；同一段正文只转换一次，列宽变化时重用转换结果。
    @Test("按宽度量出高度，转换结果按正文缓存")
    @MainActor
    func height() {
        let words = Array(repeating: "word", count: 40).joined(separator: " ")
        let string = PullRequestMarkdown.convert(words)

        let line = PullRequestMarkdown.height(of: PullRequestMarkdown.convert("word"), width: 400)
        let wide = PullRequestMarkdown.height(of: string, width: 2000)
        let narrow = PullRequestMarkdown.height(of: string, width: 200)

        #expect(line == wide)
        #expect(narrow > wide * 3)
        #expect(PullRequestMarkdown.height(of: PullRequestMarkdown.convert("- a\n- b"), width: 400) == line * 2)

        // 同一段正文只转换一次
        let first = PullRequestMarkdown.attributedString("cached **body**")
        let second = PullRequestMarkdown.attributedString("cached **body**")
        #expect(first === second)
    }
}

// MARK: - Helpers

extension PullRequestMarkdownTests {
    /// 文字第一次出现处的属性。
    private static func attribute(
        _ key: NSAttributedString.Key,
        of text: String,
        in string: NSAttributedString
    ) -> Any? {
        guard let range = string.string.range(of: text) else {
            return nil
        }

        let location = NSRange(range, in: string.string).location
        return string.attribute(key, at: location, effectiveRange: nil)
    }

    /// 文字第一次出现处的段落样式。
    private static func style(of text: String, in string: NSAttributedString) throws -> NSParagraphStyle {
        try #require(attribute(.paragraphStyle, of: text, in: string) as? NSParagraphStyle)
    }

    /// 给定位置的段落样式。
    private static func style(at location: Int, in string: NSAttributedString) throws -> NSParagraphStyle {
        try #require(string.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)
    }

    /// 核对代码块的底色、文字与边框，以及引用块的竖条，在浅色与深色外观下各取对应的值。
    private static func expectBlockColors() throws {
        let string = PullRequestMarkdown.convert("```\ncode\n```\n\n> quote")

        let code = try #require(style(of: "code", in: string).textBlocks.last)
        let quote = try #require(style(of: "quote", in: string).textBlocks.first)
        let text = try #require(attribute(.foregroundColor, of: "code", in: string) as? NSColor)

        let expected: [(NSAppearance.Name, [PaletteColor])] = [
            (.aqua, [
                PaletteColor(hex: "#F4F4F4", alpha: 1),
                PaletteColor(hex: "#000000", alpha: 0.8),
                PaletteColor(hex: "#C9C9C9", alpha: 1),
                PaletteColor(hex: "#C9C9C9", alpha: 1),
            ]),
            (.darkAqua, [
                PaletteColor(hex: "#46484B", alpha: 1),
                PaletteColor(hex: "#FFFFFF", alpha: 0.85),
                PaletteColor(hex: "#5F5F5F", alpha: 1),
                PaletteColor(hex: "#5F5F5F", alpha: 1),
            ]),
        ]

        for (name, colors) in expected {
            let appearance = try #require(NSAppearance(named: name))
            var resolved: [PaletteColor?] = []

            appearance.performAsCurrentDrawingAppearance {
                resolved = [
                    code.backgroundColor.flatMap(PaletteColor.init(nsColor:)),
                    PaletteColor(nsColor: text),
                    code.borderColor(for: .minY).flatMap(PaletteColor.init(nsColor:)),
                    quote.borderColor(for: .minX).flatMap(PaletteColor.init(nsColor:)),
                ]
            }

            #expect(resolved.compactMap { $0 } == colors, "\(name.rawValue)")
        }
    }
}
