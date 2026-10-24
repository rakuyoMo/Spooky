import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

/// Diff 的行号色随主题正文色推出，行内高亮在原文的位置上铺底色、不改变显示的文字。
struct DiffDisplayTests {
    /// 行号色由正文色推出：深色正文各分量加 0.2，浅色正文减 0.2，透明度与正文相同；换主题时行号随之变化。
    @Test("行号色由主题正文色推出")
    func lineNumberColor() throws {
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
    }

    /// 高亮范围按 UTF-16 偏移落在原文上：语法色照常保留，制表符展开后的空格整段铺底色，显示的文字不变。
    @Test("行内高亮与语法色同时生效")
    func highlightedRuns() {
        let style = TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false)
        let keyword = style.color("keyword")
        let spans = [SyntaxSpan(length: 3, style: .keyword)]

        let rendered = TextLineRenderer.attributed(
            "let 名字\t= 👍",
            spans: spans,
            highlights: [1 ..< 2, 4 ..< 7, 9 ..< 11],
            highlightColor: .green,
            style: style
        )

        let runs = rendered.runs.map { run in
            (String(rendered[run.range].characters), run.foregroundColor, run.backgroundColor)
        }

        #expect(String(rendered.characters) == "let 名字  = 👍")
        #expect(runs.map(\.0) == ["l", "e", "t", " ", "名字  ", "= ", "👍"])
        #expect(runs.map(\.1) == [keyword, keyword, keyword, nil, nil, nil, nil])
        #expect(runs.map(\.2) == [nil, .green, nil, nil, .green, nil, .green])
    }

    /// 超出行尾的高亮范围不影响显示，避免补丁更新后旧的范围套到更短的行上时出错。
    @Test("超出行尾的高亮范围")
    func outOfRangeHighlights() {
        let style = TextStyle(theme: TextTheme.builtin[0], tabWidth: 4, showsInvisibles: false)

        let rendered = TextLineRenderer.attributed(
            "ab",
            spans: nil,
            highlights: [1 ..< 5, 8 ..< 9],
            highlightColor: .green,
            style: style
        )

        #expect(String(rendered.characters) == "ab")
        #expect(rendered.runs.map { $0.backgroundColor } == [nil, .green])
    }

    /// 各块的高亮按块元素的身份存放，界面按同一身份取用；身份对不上时整块都不会高亮。
    @Test("补丁各块的高亮按元素身份存放")
    func segmentHighlights() async throws {
        let patch = [
            "diff --git a/a.txt b/a.txt",
            "--- a/a.txt",
            "+++ b/a.txt",
            "@@ -1,2 +1,2 @@",
            " same",
            "-old value",
            "+new value",
            "@@ -20,1 +20,1 @@",
            "-x = 1",
            "+x = 2",
        ]
        .joined(separator: "\n") + "\n"

        let diff = try RepositoryDiff(patch: Data(patch.utf8))
        let highlights = await DiffSegment.highlights(in: diff)

        let hunks = DiffSegment.all(in: diff).filter { segment in
            if case .hunk = segment { true } else { false }
        }

        #expect(hunks.count == 2)
        #expect(highlights[hunks[0].id] == [1: [0 ..< 3], 2: [0 ..< 3]])
        #expect(highlights[hunks[1].id] == [0: [4 ..< 5], 1: [4 ..< 5]])
    }
}
