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

    /// 字体测量先建立 AppKit 应用环境，定向运行不依赖其它套件的初始化顺序。
    init() {
        _ = NSApplication.shared
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

    /// 行号按完整向量去重并带符号；零范围保留锚点，非零范围从首行前一行开始推进；列宽按每块实际最大行号量取。
    @Test("Diff 行号、零范围锚点与列宽")
    func lineNumbers() throws {
        let hunk = try Self.hunk("@@ -9,3 +9,3 @@\n same\n-old\n\\ No newline at end of file\n+new\n last\n")
        let rows = DiffDisplayLine.rows(in: hunk)
        #expect(rows.map(\.numbers) == [["9", "9"], ["-10", ""], ["", ""], ["", "+10"], ["11", "11"]])
        #expect(rows[2].lineID == rows[1].lineID)
        #expect(rows[2].source == " No newline at end of file")
        #expect(rows[2].isNotice)

        // 首行锚点
        let anchors = [
            ("@@ -0,0 +1,1 @@\n+a\n", ["0", "+1"]),
            ("@@ -1,1 +0,0 @@\n-a\n", ["-1", "0"]),
            ("@@ -20,0 +21,1 @@\n+a\n", ["20", "+21"]),
            ("@@ -1,1 +1,2 @@\n+a\n same\n", ["0", "+1"]),
        ]

        for (patch, expected) in anchors {
            #expect(DiffDisplayLine.rows(in: try Self.hunk(patch)).first?.numbers == expected)
        }

        // 同一字体按位数取宽，换大字体后变宽
        let large = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)

        for (number, expected) in [(9, 41.0), (99, 47.0), (999, 54.0), (9999, 61.0)] {
            let rows = DiffDisplayLine.rows(in: try Self.hunk("@@ -\(number),1 +1,1 @@\n-a\n+b\n"))
            #expect(DiffDisplayLine.columnWidth(in: rows, font: Self.style.theme.font) == CGFloat(expected))
            #expect(DiffDisplayLine.columnWidth(in: rows, font: large) > CGFloat(expected))
        }
    }

    /// 短行各 19 pt 且空行基线不跟随 LF 控制字形；长行折行后行号命中区覆盖全部折行；字体与 Tab 改变从当前宽度重新量高，颜色更新保留行矩形。
    @Test("Diff 短行、折行与布局输入")
    func layout() throws {
        let view = try Self.view("@@ -1,3 +1,3 @@\n one\n \n three\n")
        #expect(view.measure(width: 500) == 74)

        let layout = try #require(view.textLayout)
        #expect(layout.rows.map(\.rect.height) == [19, 19, 19])
        #expect(layout.rows[1].baseline - layout.rows[0].baseline == 19)
        #expect(layout.row(at: CGPoint(x: 0, y: 58)) == nil)

        let manager = try #require(view.document.layoutManager)
        let glyph = manager.glyphIndexForCharacter(at: 0)
        #expect(abs(layout.rows[0].baseline - manager.location(forGlyphAt: glyph).y) < 0.01)

        // 一个逻辑行折成多行，放宽后恢复原高度
        let wrapped = try Self.view("@@ -0,0 +1,1 @@\n+\(String(repeating: "abcdefghij ", count: 12))\n")
        let wide = wrapped.measure(width: 1200)
        #expect(wrapped.measure(width: 200) > wide)

        let row = try #require(wrapped.textLayout?.rows.first)
        #expect(wrapped.textLayout?.rows.count == 1)
        #expect(wrapped.gutter.lineID(at: CGPoint(x: 3, y: row.rect.maxY - 1)) == 0)
        #expect(wrapped.gutter.lineID(at: CGPoint(x: 3, y: row.rect.maxY + 1)) == nil)
        #expect(wrapped.measure(width: 1200) == wide)

        try expectLayoutInputs()
    }

    /// 主题只变颜色或行号选区改变时不重设文字选区；键盘和辅助功能共用逻辑行身份，禁用和只读状态不能触发写选择。
    @Test("Diff 文字选择、行号键盘与辅助功能")
    func selection() throws {
        let hunk = try Self.hunk("@@ -1,1 +1,1 @@\n-old\n+new\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: Self.style, syntax: nil, highlights: [:])
        view.document.setSelectedRange(NSRange(location: 1, length: 4))
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)
        #expect(view.gutter.select(0))
        #expect(view.document.selectedRange() == NSRange(location: 1, length: 4))

        // 只换正文颜色
        var theme = Self.style.theme
        theme.colors["text"] = PaletteColor(hex: "#123456", alpha: 1)
        let recolored = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        view.show(hunk: hunk, style: recolored, syntax: nil, highlights: [:])
        #expect(view.document.selectedRange() == NSRange(location: 1, length: 4))
        #expect(view.gutter.selected == [0])

        let selected = view.document.selectedTextAttributes[.backgroundColor] as? NSColor
        #expect(selected == theme.colors["selection"]?.calibratedNSColor)

        try expectAccessibility()
    }
}

// MARK: - Private

extension DiffTextLayoutTests {
    /// 加大字号与 Tab 宽度后重新量高，再只换颜色时行矩形与高度都不变；排版后正文紧贴行号栏并裁剪。
    private func expectLayoutInputs() throws {
        let hunk = try Self.hunk("@@ -0,0 +1,1 @@\n+" + String(repeating: "word\t", count: 12) + "\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: Self.style, syntax: nil, highlights: [:])
        let first = view.measure(width: 250)
        let initialWidth = try #require(view.content?.columnWidth)

        // 字号与 Tab 一起变大
        var theme = Self.style.theme
        theme.fontSize = 20
        let large = TextStyle(theme: theme, tabWidth: 8, showsInvisibles: false)
        view.show(hunk: hunk, style: large, syntax: nil, highlights: [:])
        #expect(view.textLayout == nil)

        let height = view.measure(width: 250)
        #expect(height > first)
        #expect(try #require(view.content?.columnWidth) > initialWidth)

        // 只换颜色
        let frames = view.textLayout?.rows.map(\.rect)
        theme.colors["text"] = PaletteColor(hex: "#ABCDEF", alpha: 1)
        let recolored = TextStyle(theme: theme, tabWidth: 8, showsInvisibles: false)
        view.show(hunk: hunk, style: recolored, syntax: nil, highlights: [:])
        #expect(view.textLayout?.rows.map(\.rect) == frames)
        #expect(view.measure(width: 250) == height)

        // 实际排版
        view.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        view.layoutSubtreeIfNeeded()
        #expect(view.document.frame.minX == view.gutter.frame.maxX)
        #expect(view.gutter.frame.height == height)
        #expect(view.document.textContainerInset == CGSize(width: 4, height: 0))
        #expect(view.document.textContainer?.lineFragmentPadding == 0)
        #expect(view.clipsToBounds && view.document.clipsToBounds && view.gutter.clipsToBounds)
    }

    /// 无换行提示与修改行共用一个辅助功能元素，焦点按逻辑行移动，禁用与只读后不能再选。
    private func expectAccessibility() throws {
        let hunk = try Self.hunk("@@ -1,2 +1,2 @@\n same\n-old\n\\ No newline at end of file\n+new\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: Self.style, syntax: nil, highlights: [:])
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)

        let children = try #require(view.gutter.accessibilityChildren() as? [DiffGutterElement])
        #expect(children.count == 2)
        #expect(children[0].accessibilityLabel() == AppLocalization.text("working.selectLine", 2))

        // 键盘焦点
        view.gutter.moveFocus(by: 1)
        #expect(view.gutter.focusedID == 1)
        view.gutter.moveFocus(by: 1)
        #expect(view.gutter.focusedID == 2)

        // 辅助功能按下
        #expect(children[0].accessibilityPerformPress())
        #expect(view.gutter.selected == [1])
        #expect(children[0].accessibilityValue() as? String == AppLocalization.text("working.selected"))
        #expect(!view.gutter.select(0))

        // 禁用与只读
        view.gutter.configure(hunk: hunk, enabled: false, readOnly: false, selection: view.gutter.selection)
        #expect(!children[0].accessibilityPerformPress())
        #expect(!children[0].isAccessibilityEnabled())

        view.gutter.configure(hunk: hunk, enabled: true, readOnly: true, selection: view.gutter.selection)
        #expect(view.gutter.accessibilityChildren()?.isEmpty ?? false)
        #expect(!view.gutter.select(1))
    }
}
