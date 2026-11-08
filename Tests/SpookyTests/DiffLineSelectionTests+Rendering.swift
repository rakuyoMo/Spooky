import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffLineSelectionTests {
    /// 开关本身决定选中样式，即使没有语法片段也要使用选中底色；提示文字保持不可见字符色；深浅正文各取对比色。
    @Test("行选择正文颜色与有效着色开关")
    func colors() throws {
        for (syntax, text) in [(false, "#101010"), (false, "#801010"), (true, "#101010")] {
            try expectColors(syntax: syntax, text: text)
        }
    }

    /// 整块悬停共用实际折行矩形，只亮单个显示行，禁用后不保留临时状态；原生鼠标事件只改变逻辑选区，Command 与普通单击等价，计数在 mouseUp 发布。
    @Test("行号的悬停、禁用与鼠标事件")
    func mouse() throws {
        let hunk = try DiffTextLayoutTests.hunk(Self.patch)
        let view = try layoutView(hunk)
        let rows = try #require(view.textLayout?.rows)

        // 悬停正文与行号都落在同一显示行，选中后清除悬停
        view.gutter.hover(at: CGPoint(x: 200, y: rows[2].rect.midY))
        #expect(view.gutter.hoveredIndex == 2)
        view.gutter.hover(at: CGPoint(x: 10, y: rows[1].rect.midY))
        #expect(view.gutter.hoveredIndex == 1)
        #expect(view.gutter.select(1))
        #expect(view.gutter.hoveredIndex == nil)
        view.gutter.hover(at: CGPoint(x: 200, y: rows[0].rect.midY))
        #expect(view.gutter.hoveredIndex == nil)
        view.gutter.hover(at: CGPoint(x: 200, y: rows[3].rect.midY))
        #expect(view.gutter.hoveredIndex == 3)

        // 禁用后不保留悬停，也不能再选
        view.gutter.configure(hunk: hunk, enabled: false, readOnly: false, selection: view.gutter.selection)
        #expect(view.gutter.hoveredIndex == nil)
        #expect(!view.gutter.select(2))
        #expect(view.gutter.selected == [1])

        // 普通与 Command 单击后拖动
        for command in [false, true] {
            let target = try layoutView(hunk)
            let gutter = target.gutter
            gutter.mouseDown(with: try event(.leftMouseDown, row: rows[2], gutter: gutter, command: command))
            #expect(gutter.selected == [1] && gutter.selection.publishedCount == 0)
            gutter.mouseDragged(with: try event(.leftMouseDragged, row: rows[4], gutter: gutter, command: command))
            #expect(gutter.selected == [1, 2] && gutter.selection.publishedCount == 0)
            gutter.mouseUp(with: try event(.leftMouseUp, row: rows[4], gutter: gutter, command: command))
            #expect(gutter.selection.publishedCount == 2)
            #expect(target.window == nil)
        }
    }

    /// 选中再取消新增行，核对正文前景色、行底色与字符选区。
    private func expectColors(syntax: Bool, text: String) throws {
        let hunk = try DiffTextLayoutTests.hunk(Self.patch)
        var theme = TextTheme.builtin[0]
        theme.colors["text"] = PaletteColor(hex: text, alpha: 1)
        let style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)

        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: style, syntax: nil, highlights: [:], colorsSyntax: syntax)
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)
        view.document.setSelectedRange(NSRange(location: 2, length: 10))

        let content = try #require(view.content)
        let storage = try #require(view.document.textStorage)

        let color = { (row: Int) in
            storage.attribute(.foregroundColor, at: content.rows[row].range.location, effectiveRange: nil) as? NSColor
        }

        let original = color(3)
        #expect(view.gutter.select(2))
        #expect(view.gutter.select(1))
        #expect(color(3) == (syntax ? original : (text == "#101010" ? .black : .white)))
        #expect(color(1) == (syntax ? original : .labelColor))
        #expect(color(2) == theme.colors["invisible"]?.calibratedNSColor)

        let added = try #require(theme.colors["added"])
        let emphasized = PaletteColor(hex: added.hex, alpha: min(1, added.alpha + 0.25)).nsColor
        let expected = syntax ? emphasized : added.calibratedNSColor
        #expect(view.backgroundColor(for: content.rows[3].line) == expected)
        #expect(view.backgroundColor(for: content.rows[4].line) == nil)
        #expect(view.document.selectedRange() == NSRange(location: 2, length: 10))

        // 取消选择后恢复原来的前景色
        #expect(view.gutter.select(2))
        #expect(color(3) == original)
    }

    /// 按 500 点宽排好版、行号栏可选的文本区。
    private func layoutView(_ hunk: DiffHunk) throws -> DiffHunkTextContainer {
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)
        view.frame = NSRect(x: 0, y: 0, width: 500, height: view.measure(width: 500))
        view.layoutSubtreeIfNeeded()
        return view
    }

    /// 构造交给原生视图入口的局部事件，不发送系统输入。
    private func event(
        _ type: NSEvent.EventType,
        row: DiffTextLayout.Row,
        gutter: DiffGutterView,
        command: Bool
    ) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type,
            location: gutter.convert(CGPoint(x: 5, y: row.rect.midY), to: nil),
            modifierFlags: command ? .command : [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
    }
}
