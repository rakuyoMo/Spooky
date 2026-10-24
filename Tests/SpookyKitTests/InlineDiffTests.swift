import Foundation
import Testing

@testable import SpookyKit

// MARK: - InlineDiffTests

/// 行内高亮只标出一对修改行里真正改动的单词；范围按 UTF-16 计，界面据此在原文上铺底色，偏移错一位就会盖到相邻的字。
struct InlineDiffTests {
    /// 一对修改行只高亮换掉的单词，两侧各自标在自己的行上，相同的部分不高亮。
    @Test("成对的修改行只高亮改动的单词")
    func pairedLines() throws {
        let hunk = try Self.hunk([
            " func total() {",
            "-    return price * count",
            "+    return price * quantity",
            " }",
        ])

        let ranges = InlineDiff.ranges(in: hunk)

        #expect(ranges == [1: [19 ..< 24], 2: [19 ..< 27]])
        #expect(Self.text(hunk.lines[1], ranges[1]) == ["count"])
        #expect(Self.text(hunk.lines[2], ranges[2]) == ["quantity"])
    }

    /// 被上下文行隔开的两组各自配对；一组里删除行与新增行数目不同时无法确定对应关系，整组不高亮。
    @Test("按组配对，数目不同的组不高亮")
    func groups() throws {
        let hunk = try Self.hunk([
            "-let a = 1",
            "-let b = 2",
            "+let a = 10",
            "+let b = 20",
            " let c = 3",
            "-let d = 4",
            "+let d = 40",
            "+let e = 5",
        ])

        let ranges = InlineDiff.ranges(in: hunk)

        // 第一组按顺序配对：第 1 个删除行对第 1 个新增行
        #expect(Self.text(hunk.lines[0], ranges[0]) == ["1"])
        #expect(Self.text(hunk.lines[2], ranges[2]) == ["10"])
        #expect(Self.text(hunk.lines[1], ranges[1]) == ["2"])
        #expect(Self.text(hunk.lines[3], ranges[3]) == ["20"])

        // 第二组一删两增，不高亮
        #expect(ranges[5] == nil && ranges[6] == nil && ranges[7] == nil)
    }

    /// 只有新增或只有删除的块没有可比较的另一行，不产生高亮。
    @Test("只有新增或只有删除的块")
    func oneSided() throws {
        let added = try Self.hunk(["+first", "+second"])
        let deleted = try Self.hunk([" keep", "-gone", " keep"])

        #expect(InlineDiff.ranges(in: added).isEmpty)
        #expect(InlineDiff.ranges(in: deleted).isEmpty)
    }

    /// 任一行超过 1000 个字符就不比较，恰好 1000 个字符仍然比较；按字符数而不是字节数判断。
    @Test("超过 1000 个字符不比较")
    func lengthLimit() {
        let prefix = String(repeating: "字", count: 995)

        // 995 个汉字连成一个单词，加上空格与 4 个字符的单词正好 1000 个字符
        let accepted = InlineDiff.compare(deleted: prefix + " abcd", added: prefix + " wxyz")
        #expect(accepted?.deleted == [996 ..< 1000])
        #expect(accepted?.added == [996 ..< 1000])

        // 新增行多一个字符就超过上限，整对都不比较
        #expect(InlineDiff.compare(deleted: prefix + " abcd", added: prefix + " wxyz!") == nil)
        #expect(InlineDiff.compare(deleted: prefix + " abcde", added: prefix + " wxyz") == nil)
    }

    /// 任一行超过 75% 的字符都变了，高亮会盖满整行，这一对不高亮；恰好 75% 仍然高亮。
    @Test("超过 75% 的字符改动不高亮")
    func changedRatio() {
        // 删除行 10 个字符里 9 个改了
        #expect(InlineDiff.compare(deleted: "alpha beta", added: "gamma delta") == nil)

        // 删除行 5 个字符里只改了 2 个，新增行 15 个字符里改了 12 个，任一行超过就不高亮
        #expect(InlineDiff.compare(deleted: "ab cd", added: "ab xyzxyzxyzxyz") == nil)

        // 删除行 8 个字符里 6 个改了，正好 75%；新增行 5 个字符里 3 个改了
        let boundary = InlineDiff.compare(deleted: "abcdef g", added: "xyz g")
        #expect(boundary?.deleted == [0 ..< 6])
        #expect(boundary?.added == [0 ..< 3])
    }

    /// 中文与 emoji 的偏移按 UTF-16 计：汉字各占 1、emoji 占 2，组合 emoji 不从中间切开。
    @Test("多字节字符的 UTF-16 偏移")
    func multibyte() throws {
        let hunk = try Self.hunk([
            "-let 名字 = \"张三\" 👍",
            "+let 名字 = \"李四\" 👨‍👩‍👧",
        ])

        let ranges = InlineDiff.ranges(in: hunk)

        #expect(ranges[0] == [10 ..< 12, 14 ..< 16])
        #expect(ranges[1] == [10 ..< 12, 14 ..< 22])
        #expect(Self.text(hunk.lines[0], ranges[0]) == ["张三", "👍"])
        #expect(Self.text(hunk.lines[1], ranges[1]) == ["李四", "👨‍👩‍👧"])
    }

    /// 字母、数字与下划线连成单词，标点各自成段，空白连成一段；各段首尾相接覆盖整行。
    @Test("切分单词、空白与标点")
    func tokens() {
        let tokens = InlineDiff.tokens(of: "foo_bar(1,  2)")

        #expect(tokens.map(\.text) == ["foo_bar", "(", "1", ",", "  ", "2", ")"])
        #expect(tokens.map(\.range.lowerBound) == [0, 7, 8, 9, 10, 12, 13])
        #expect(tokens.last?.range.upperBound == 14)
    }
}

// MARK: - Helpers

extension InlineDiffTests {
    /// 把带前缀的行拼成只有一块的补丁并解析，块头的行数按前缀计算。
    private static func hunk(_ lines: [String]) throws -> DiffHunk {
        let old = lines.filter { !$0.hasPrefix("+") }.count
        let new = lines.filter { !$0.hasPrefix("-") }.count

        let patch = [
            "diff --git a/file.swift b/file.swift",
            "--- a/file.swift",
            "+++ b/file.swift",
            "@@ -1,\(old) +1,\(new) @@",
        ] + lines

        let diff = try RepositoryDiff(patch: Data((patch.joined(separator: "\n") + "\n").utf8))
        return try #require(diff.files.first?.hunks.first)
    }

    /// 按 UTF-16 范围从一行里取出高亮的文字，核对偏移落在预期的字上。
    private static func text(_ line: DiffLine, _ ranges: [Range<Int>]?) -> [String] {
        let units = Array(String(decoding: line.content, as: UTF8.self).utf16)

        return (ranges ?? []).map { range in
            String(decoding: units[range], as: UTF16.self)
        }
    }
}
