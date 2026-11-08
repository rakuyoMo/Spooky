import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

/// Diff 的行号色与边线色随主题推出，单行在原文的位置上铺语法色与高亮底色、不改变显示的文字。
@MainActor
struct DiffDisplayTests {
    /// 行号色由正文色推出：深色正文各分量加 0.2，浅色正文减 0.2，透明度与正文相同；边线用原始浮点分量与背景透明度。
    @Test("行号色与行号边线色由主题推出")
    func gutterColors() throws {
        let light = try #require(TextTheme.builtin[0].colors["text"])
        let dark = try #require(TextTheme.builtin[1].colors["text"])

        #expect(light.isDark && !dark.isDark)
        #expect(light.offset(by: 0.2) == PaletteColor(hex: "#333333", alpha: light.alpha))
        #expect(dark.offset(by: -0.2) == PaletteColor(hex: "#CCCCCC", alpha: dark.alpha))

        // 分量夹在 0–1 之间，不会因为加减越界变成别的颜色
        #expect(PaletteColor(hex: "#F0F0F0", alpha: 1).offset(by: 0.2).hex == "#FFFFFF")
        #expect(PaletteColor(hex: "#102030", alpha: 1).offset(by: -0.2).hex == "#000000")

        // 只要有一个分量不低于 0.5 就算浅色
        #expect(!PaletteColor(hex: "#801010", alpha: 1).isDark)

        // 行号边线不经十六进制往返，浅色背景压暗、深色背景提亮，透明度不变
        var theme = TextTheme.builtin[0]
        theme.colors["background"] = PaletteColor(hex: "#FFFFFF", alpha: 0.47)
        let lightStyle = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        let lightBorder = DiffGutterView.borderColor(style: lightStyle)
        #expect(abs(lightBorder.redComponent - 0.9) < 0.000_001)
        #expect(abs(lightBorder.alphaComponent - 0.47) < 0.000_001)

        theme.colors["background"] = PaletteColor(hex: "#161819", alpha: 0.37)
        let darkStyle = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        let darkBorder = DiffGutterView.borderColor(style: darkStyle)
        #expect(abs(darkBorder.redComponent - (22.0 / 255 + 0.1)) < 0.000_001)
        #expect(abs(darkBorder.alphaComponent - 0.37) < 0.000_001)
    }

    /// 制表符补齐到下一个 Tab 位置，不可见字符按开关标出；高亮按 UTF-16 偏移落在原文上，与语法色同时生效，超出行尾的范围不影响显示。
    @Test("单行渲染的 Tab、不可见字符、语法色与行内高亮")
    func lineRendering() {
        let theme = TextTheme.builtin[0]
        let plain = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        let marked = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: true)

        // 打开不可见字符时标出制表符、空格与行内回车，关闭时省略回车
        #expect(String(TextLineRenderer.attributed("ab\tc\r", spans: nil, style: plain).characters) == "ab  c")
        #expect(String(TextLineRenderer.attributed("\tx y\r", spans: nil, style: marked).characters) == "»   x·y␍")

        // 片段比行短时剩余部分按正文显示，不丢字
        let short = [SyntaxSpan(length: 1, style: .keyword)]
        #expect(String(TextLineRenderer.attributed("let", spans: short, style: plain).characters) == "let")

        // 制表符展开后的空格整段铺底色，语法色照常保留
        let keyword = plain.color("keyword")

        let rendered = TextLineRenderer.attributed(
            "let 名字\t= 👍",
            spans: [SyntaxSpan(length: 3, style: .keyword)],
            highlights: [1 ..< 2, 4 ..< 7, 9 ..< 11],
            highlightColor: .green,
            style: plain
        )

        let runs = rendered.runs.map { run in
            (String(rendered[run.range].characters), run.foregroundColor, run.backgroundColor)
        }

        #expect(String(rendered.characters) == "let 名字  = 👍")
        #expect(runs.map(\.0) == ["l", "e", "t", " ", "名字  ", "= ", "👍"])
        #expect(runs.map(\.1) == [keyword, keyword, keyword, nil, nil, nil, nil])
        #expect(runs.map(\.2) == [nil, .green, nil, nil, .green, nil, .green])

        // 补丁更新后旧的范围套到更短的行上时，越界部分直接忽略
        let clipped = TextLineRenderer.attributed(
            "ab",
            spans: nil,
            highlights: [1 ..< 5, 8 ..< 9],
            highlightColor: .green,
            style: plain
        )

        #expect(String(clipped.characters) == "ab")
        #expect(clipped.runs.map { $0.backgroundColor } == [nil, .green])
    }
}
