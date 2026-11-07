import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

extension DiffLineSelectionTests {
    /// 开关本身决定选中样式，即使没有语法片段也要使用选中底色；提示文字保持不可见字符色。
    @Test("行选择正文颜色与有效着色开关", arguments: [false, true], ["#101010", "#801010"])
    func colors(syntax: Bool, text: String) throws {
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
        let original = storage.attribute(.foregroundColor, at: content.rows[3].range.location, effectiveRange: nil) as? NSColor
        #expect(view.gutter.select(2))
        #expect(view.gutter.select(1))
        let addition = storage.attribute(.foregroundColor, at: content.rows[3].range.location, effectiveRange: nil) as? NSColor
        let removal = storage.attribute(.foregroundColor, at: content.rows[1].range.location, effectiveRange: nil) as? NSColor
        let notice = storage.attribute(.foregroundColor, at: content.rows[2].range.location, effectiveRange: nil) as? NSColor
        #expect(addition == (syntax ? original : (text == "#101010" ? .black : .white)))
        #expect(removal == (syntax ? original : .labelColor))
        #expect(notice == theme.colors["invisible"]?.calibratedNSColor)
        let added = try #require(theme.colors["added"])
        let expected = syntax ? PaletteColor(hex: added.hex, alpha: min(1, added.alpha + 0.25)).nsColor : added.calibratedNSColor
        #expect(view.backgroundColor(for: content.rows[3].line) == expected)
        #expect(view.backgroundColor(for: content.rows[4].line) == nil)
        #expect(view.document.selectedRange() == NSRange(location: 2, length: 10))
        #expect(view.gutter.select(2))
        #expect(
            storage
                .attribute(.foregroundColor, at: content.rows[3].range.location, effectiveRange: nil) as? NSColor == original
        )
    }

    /// 整块悬停共用实际折行矩形，只亮单个显示行；禁用后不保留临时状态。
    @Test("正文和行号的悬停与禁用")
    func hovering() throws {
        let hunk = try DiffTextLayoutTests.hunk(Self.patch)
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)
        view.frame = NSRect(x: 0, y: 0, width: 500, height: view.measure(width: 500))
        view.layoutSubtreeIfNeeded()
        let rows = try #require(view.textLayout?.rows)
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
        view.gutter.configure(hunk: hunk, enabled: false, readOnly: false, selection: view.gutter.selection)
        #expect(view.gutter.hoveredIndex == nil)
        #expect(!view.gutter.select(2))
        #expect(view.gutter.selected == [1])
    }

    /// 原生鼠标事件只改变逻辑选区，Command 与普通单击等价，计数在 mouseUp 发布。
    @Test("行号鼠标事件与计数发布", arguments: [false, true])
    func events(command: Bool) throws {
        let hunk = try DiffTextLayoutTests.hunk(Self.patch)
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)
        view.frame = NSRect(x: 0, y: 0, width: 500, height: view.measure(width: 500))
        view.layoutSubtreeIfNeeded()
        let rows = try #require(view.textLayout?.rows)
        let gutter = view.gutter
        gutter.mouseDown(with: try event(.leftMouseDown, row: rows[2], gutter: gutter, command: command))
        #expect(gutter.selected == [1] && gutter.selection.publishedCount == 0)
        gutter.mouseDragged(with: try event(.leftMouseDragged, row: rows[4], gutter: gutter, command: command))
        #expect(gutter.selected == [1, 2] && gutter.selection.publishedCount == 0)
        gutter.mouseUp(with: try event(.leftMouseUp, row: rows[4], gutter: gutter, command: command))
        #expect(gutter.selection.publishedCount == 2)
        #expect(view.window == nil)
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
