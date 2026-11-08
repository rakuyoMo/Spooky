import AppKit
import SpookyKit
import Testing

@testable import Spooky

// MARK: - CombinedDiffDisplayTests

/// 组合 Diff 直接使用核心提供的完整向量，布局与复制仍由共享文本区负责。
@MainActor
struct CombinedDiffDisplayTests {
    /// 两父与三父的有效前缀按各自列去重，提示行不推进任何一列；空侧以起点减一为锚点。
    @Test("组合 Diff 的多父行号、符号与零范围锚点")
    func numbers() throws {
        // 两父：提示行沿用上一行的身份，不推进任何一列
        let hunk = try hunk("""
            @@@ -1,4 -1,4 +1,4 @@@
            ++kept-0
             +kept-1
            - removed-1
            + kept-2
             -removed-2
              kept-3
            --removed-3
            \\ No newline at end of file

            """)

        let rows = DiffDisplayLine.rows(in: hunk)

        #expect(rows.map(\.numbers) == [
            ["0", "0", "+1"],
            ["1", "", "+2"],
            ["-2", "", ""],
            ["", "1", "+3"],
            ["", "-2", ""],
            ["3", "3", "4"],
            ["-4", "-4", ""],
            ["", "", ""],
        ])

        #expect(rows.last?.lineID == rows[rows.count - 2].lineID)
        #expect(rows.last?.isNotice ?? false)

        // 三父：符号不固定落在第一父列或第二列，结果列始终在最后
        let three = try self.hunk("@@@@ -1,2 -1,2 -1,4 +1,3 @@@@\n  -a\n- -b\n --c\n++ d\n+ +e\n ++f\n")

        #expect(DiffDisplayLine.rows(in: three).map(\.numbers) == [
            ["0", "0", "-1", "0"],
            ["-1", "", "-2", ""],
            ["", "-1", "-3", ""],
            ["", "", "4", "+1"],
            ["", "2", "", "+2"],
            ["2", "", "", "+3"],
        ])

        // 零范围：每块独立显示全部首行列号
        for body in ["@@@ -2,0 -2,0 +2,1 @@@\n++new\n", "@@@ -1,0 -1,0 +2,1 @@@\n++new\n"] {
            let hunk = try self.hunk(body)
            let expected = hunk.oldStart == 2 ? "1" : "0"
            #expect(DiffDisplayLine.rows(in: hunk).map(\.numbers) == [[expected, expected, "+2"]])
        }
    }

    /// 第二或第三父列的最大值决定所有列的宽度，三列与四列共用真实只读文本布局；长行只生成一组行号，折行后保持原文映射。
    @Test("组合 Diff 的全列宽度、只读文本区与长行折行")
    func layout() throws {
        for parents in [2, 3] {
            try expectColumns(parents: parents)
        }

        // 长行折行
        let source = String(repeating: "long word\t", count: 20)
        let hunk = try hunk("@@@ -1,0 -1,0 +1 @@@\n++\(source)\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])

        let wide = view.measure(width: 1400)
        let narrow = view.measure(width: 300)
        #expect(narrow > wide)
        #expect(view.textLayout?.rows.count == 1)
        #expect(view.content?.rows.first?.line.numbers == ["0", "0", "+1"])

        let content = try #require(view.content)
        #expect(content.copiedText(in: NSRange(location: 0, length: content.attributed.length)) == source + "\n")
    }

    /// 一个父数下的列宽、文字区位置与只读行号栏。
    private func expectColumns(parents: Int) throws {
        let ranges = parents == 2 ? "-1 -1000 +1" : "-1 -2 -1000 +1"
        let body = String(repeating: "@", count: parents + 1)
        let hunk = try hunk("\(body) \(ranges) \(body)\n" + String(repeating: " ", count: parents) + "text\t名\r\n")
        let view = DiffHunkTextContainer()
        view.show(hunk: hunk, style: DiffTextLayoutTests.style, syntax: nil, highlights: [:])

        let height = view.measure(width: 600)
        view.frame = CGRect(x: 0, y: 0, width: 600, height: height)
        view.layoutSubtreeIfNeeded()
        #expect(view.content?.columnWidth == 61)
        #expect(view.gutter.frame.width == CGFloat(parents + 1) * 61)
        #expect(view.document.frame.minX == view.gutter.frame.maxX)
        #expect(view.document.textContainerInset == CGSize(width: 4, height: 0))
        #expect(height == 36)

        let content = try #require(view.content)
        #expect(content.copiedText(in: NSRange(location: 0, length: content.attributed.length)) == "text\t名\r\n")

        // 组合补丁的行号栏不可选
        view.gutter.configure(hunk: hunk, enabled: true, readOnly: false, selection: view.gutter.selection)
        #expect(view.gutter.selected.isEmpty)
        #expect(!view.gutter.acceptsFirstResponder)
        #expect(view.gutter.accessibilityChildren()?.isEmpty ?? false)
        #expect(!view.gutter.select(0))
        #expect(view.document.isSelectable)
        #expect(!view.document.isEditable)
    }

    /// 显示测试从实际组合解析入口得到模型，不在 App 中重新计算多父推进。
    private func hunk(_ body: String) throws -> DiffHunk {
        try #require(RepositoryDiff(patch: Data(("diff --cc file\n" + body).utf8)).files.first?.hunks.first)
    }
}
