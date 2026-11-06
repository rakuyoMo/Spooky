import AppKit
import SpookyKit
import Testing

@testable import Spooky

// MARK: - DiffTextLayoutTests

/// 每块一个 TextKit 栈，行号、文字选择与写补丁身份共用同一份显示映射。
@MainActor
struct DiffTextLayoutTests {
    /// 固定 Menlo 11 的默认显示设置。
    static var style: TextStyle {
        TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false)
    }

    /// 从生产解析器得到一块供显示测试使用的补丁。
    static func hunk(_ body: String) throws -> DiffHunk {
        let patch = "diff --git a/a.txt b/a.txt\n--- a/a.txt\n+++ b/a.txt\n" + body
        return try #require(RepositoryDiff(patch: Data(patch.utf8)).files.first?.hunks.first)
    }

    /// 直接构造生产使用的容器，不挂载窗口。
    static func view(_ body: String) throws -> DiffHunkTextContainer {
        let view = DiffHunkTextContainer()
        view.show(hunk: try hunk(body), style: style, syntax: nil, highlights: [:])
        return view
    }

    /// 上下文、增删与无换行提示的行号按完整向量去重，而不是只格式化可选行号。
    @Test("Diff 行号带符号并按列去重")
    func lineNumbers() throws {
        let hunk = try Self.hunk("@@ -9,3 +9,3 @@\n same\n-old\n\\ No newline at end of file\n+new\n last\n")
        let rows = DiffDisplayLine.rows(in: hunk)
        #expect(rows.map(\.numbers) == [["9", "9"], ["-10", ""], ["", ""], ["", "+10"], ["11", "11"]])
        #expect(rows[2].lineID == rows[1].lineID)
        #expect(rows[2].source == " No newline at end of file")
        #expect(rows[2].isNotice)
    }

    /// 零范围保留锚点；非零范围从首行前一行开始推进。
    @Test("Diff 首行与零范围锚点", arguments: [
        ("@@ -0,0 +1,1 @@\n+a\n", ["0", "+1"]),
        ("@@ -1,1 +0,0 @@\n-a\n", ["-1", "0"]),
        ("@@ -20,0 +21,1 @@\n+a\n", ["20", "+21"]),
        ("@@ -1,1 +1,2 @@\n+a\n same\n", ["0", "+1"]),
    ])
    func anchors(patch: String, expected: [String]) throws {
        let hunk = try Self.hunk(patch)
        #expect(DiffDisplayLine.rows(in: hunk).first?.numbers == expected)
    }

    /// 同一字体按实际最大行号量宽，各块之间不共享宽度。
    @Test("Diff 行号列宽", arguments: [(9, 41.0), (99, 47.0), (999, 54.0), (9999, 61.0)])
    func columnWidths(number: Int, expected: Double) throws {
        let hunk = try Self.hunk("@@ -\(number),1 +1,1 @@\n-a\n+b\n")
        let rows = DiffDisplayLine.rows(in: hunk)
        #expect(DiffDisplayLine.columnWidth(in: rows, font: Self.style.theme.font) == CGFloat(expected))
        #expect(
            DiffDisplayLine
                .columnWidth(in: rows, font: .monospacedSystemFont(ofSize: 20, weight: .regular)) > CGFloat(expected)
        )
    }

    /// 三行各 19 pt，末尾空片段只计算一次；空行行号基线不能跟随 LF 的控制字形。
    @Test("Diff 短行与空行布局")
    func shortLines() throws {
        let view = try Self.view("@@ -1,3 +1,3 @@\n one\n \n three\n")
        #expect(view.measure(width: 500) == 74)
        let layout = try #require(view.textLayout)
        #expect(layout.rows.map(\.rect.height) == [19, 19, 19])
        #expect(layout.rows[1].baseline - layout.rows[0].baseline == 19)
        #expect(layout.row(at: CGPoint(x: 0, y: 58)) == nil)
        let manager = try #require(view.document.layoutManager)
        let glyph = manager.glyphIndexForCharacter(at: 0)
        #expect(abs(layout.rows[0].baseline - manager.location(forGlyphAt: glyph).y) < 0.01)
    }

    /// 一个逻辑行折成多行，行号命中区覆盖全部折行；放宽后恢复原高度。
    @Test("Diff 折行布局与宽度缓存")
    func wrapping() throws {
        let line = String(repeating: "abcdefghij ", count: 12)
        let view = try Self.view("@@ -0,0 +1,1 @@\n+\(line)\n")
        let wide = view.measure(width: 1200)
        let narrow = view.measure(width: 200)
        #expect(narrow > wide)
        let layout = try #require(view.textLayout)
        #expect(layout.rows.count == 1)
        #expect(view.gutter.lineID(at: CGPoint(x: 3, y: layout.rows[0].rect.maxY - 1)) == 0)
        #expect(view.gutter.lineID(at: CGPoint(x: 3, y: layout.rows[0].rect.maxY + 1)) == nil)
        #expect(view.measure(width: 1200) == wide)
    }

    /// 字体与 Tab 宽度改变都从当前宽度重新量高，颜色更新保留同一份行矩形。
    @Test("Diff 字体与 Tab 布局更新")
    func layoutInputs() throws {
        let hunk = try Self.hunk("@@ -0,0 +1,1 @@\n+" + String(repeating: "word\t", count: 12) + "\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: Self.style, syntax: nil, highlights: [:])
        let first = view.measure(width: 250)
        let initialWidth = view.content?.columnWidth
        var theme = Self.style.theme
        theme.fontSize = 20
        let large = TextStyle(theme: theme, tabWidth: 8, showsInvisibles: false)
        view.show(hunk: hunk, style: large, syntax: nil, highlights: [:])
        #expect(view.textLayout == nil)
        let height = view.measure(width: 250)
        #expect(height > first)
        #expect(try #require(view.content?.columnWidth) > #require(initialWidth))
        let frames = view.textLayout?.rows.map(\.rect)
        theme.colors["text"] = PaletteColor(hex: "#ABCDEF", alpha: 1)
        view.show(
            hunk: hunk,
            style: TextStyle(theme: theme, tabWidth: 8, showsInvisibles: false),
            syntax: nil,
            highlights: [:]
        )
        #expect(view.textLayout?.rows.map(\.rect) == frames)
        #expect(view.measure(width: 250) == height)
        view.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        view.layoutSubtreeIfNeeded()
        #expect(view.document.frame.minX == view.gutter.frame.maxX)
        #expect(view.gutter.frame.height == height)
        #expect(view.document.textContainerInset == CGSize(width: 4, height: 0))
        #expect(view.document.textContainer?.lineFragmentPadding == 0)
        #expect(view.clipsToBounds)
        #expect(view.document.clipsToBounds)
        #expect(view.gutter.clipsToBounds)
    }

    /// 行号边线用原始浮点分量，透明度不变，不经十六进制往返。
    @Test("Diff 行号边线颜色")
    func borderColor() {
        var theme = TextTheme.builtin[0]
        theme.colors["background"] = PaletteColor(hex: "#FFFFFF", alpha: 0.47)
        let light = DiffGutterView.borderColor(style: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false))
        #expect(abs(light.redComponent - 0.9) < 0.000_001)
        #expect(abs(light.alphaComponent - 0.47) < 0.000_001)
        theme.colors["background"] = PaletteColor(hex: "#161819", alpha: 0.37)
        let dark = DiffGutterView.borderColor(style: TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false))
        #expect(abs(dark.redComponent - (22.0 / 255 + 0.1)) < 0.000_001)
        #expect(abs(dark.alphaComponent - 0.37) < 0.000_001)
    }

    /// 主题只变颜色或行号选区改变时，文字内容和字符选区不重设。
    @Test("Diff 文字选择独立于行号与颜色")
    func independentSelection() throws {
        let hunk = try Self.hunk("@@ -1,1 +1,1 @@\n-old\n+new\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: Self.style, syntax: nil, highlights: [:])
        view.document.setSelectedRange(NSRange(location: 1, length: 4))
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selected: [])
        #expect(view.gutter.select(0))
        #expect(view.document.selectedRange() == NSRange(location: 1, length: 4))
        var style = Self.style
        var theme = style.theme
        theme.colors["text"] = PaletteColor(hex: "#123456", alpha: 1)
        style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        view.show(hunk: hunk, style: style, syntax: nil, highlights: [:])
        #expect(view.document.selectedRange() == NSRange(location: 1, length: 4))
        #expect(view.gutter.selected == [0])
        #expect(
            view.document.selectedTextAttributes[.backgroundColor] as? NSColor == theme.colors["selection"]?
                .calibratedNSColor
        )
    }

    /// 键盘和辅助功能共用逻辑行身份，禁用和只读状态不能触发写选择。
    @Test("Diff 行号键盘与辅助功能入口")
    func accessibility() throws {
        let hunk = try Self.hunk("@@ -1,2 +1,2 @@\n same\n-old\n\\ No newline at end of file\n+new\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: Self.style, syntax: nil, highlights: [:])
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selected: [])
        let children = try #require(view.gutter.accessibilityChildren() as? [DiffGutterElement])
        #expect(children.count == 2)
        #expect(children[0].accessibilityLabel() == AppLocalization.text("working.selectLine", 2))
        view.gutter.moveFocus(by: 1)
        #expect(view.gutter.focusedID == 1)
        view.gutter.moveFocus(by: 1)
        #expect(view.gutter.focusedID == 2)
        #expect(children[0].accessibilityPerformPress())
        #expect(view.gutter.selected == [1])
        #expect(children[0].accessibilityValue() as? String == AppLocalization.text("working.selected"))
        #expect(!view.gutter.select(0))
        view.gutter.configure(hunk: hunk, enabled: false, readOnly: false, selected: [1])
        #expect(!children[0].accessibilityPerformPress())
        #expect(!children[0].isAccessibilityEnabled())
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: true, selected: [])
        #expect(view.gutter.accessibilityChildren()?.isEmpty ?? false)
        #expect(!view.gutter.select(1))
    }

}
