import Foundation
import Testing

@testable import SpookyKit

// MARK: - CombinedDiffTests

/// 固定 Git 2.54 输出验证多父行号；夹具使用隔离配置、固定身份与 2000-01-01 的提交时间。
struct CombinedDiffTests {
    /// 一份真实合并补丁与按父顺序、最后为结果的完整文件字节。
    struct Fixture: Decodable {
        /// 标识哈希格式、组合方式与文件边界场景。
        let name: String

        /// Base64 编码的真实补丁，由 JSONDecoder 解码。
        let patch: Data

        /// 各侧的原始文件；不存在的文件使用空字节。
        let versions: [Data]
    }

    /// 所有父侧的行号都指向同一行原文，不拿第一父侧的行号顶替其它父侧。
    @Test("组合 Diff 完整列号对应真实文件")
    func realFixtures() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/diff-combined.json")
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        #expect(fixtures.count == 22)

        for fixture in fixtures {
            let diff = try RepositoryDiff(patch: fixture.patch)
            let file = try #require(diff.files.first)
            #expect(diff.files.count == 1)
            #expect(!file.hunks.isEmpty)

            try verify(file, fixture: fixture)

            // 各父侧前缀的全部组合都出现
            if fixture.name.contains("subsets") {
                let prefixes = Set(file.hunks.flatMap(\.lines).compactMap(\.combined).map(\.prefixes))
                #expect(prefixes.count == (fixture.versions.count == 3 ? 7 : 15))
            }

            if fixture.name == "multiple-hunks" {
                #expect(file.hunks.count == 2)
            }

            if fixture.name.hasPrefix("nonewline-") {
                #expect(file.hunks.flatMap(\.lines).allSatisfy { !$0.noNewline })
            }

            // 组合 Diff 的块不能生成可写补丁
            for hunk in file.hunks {
                for reverse in [false, true] {
                    #expect(throws: WorkingCopyError.invalidSelection) {
                        try diff.patch(path: "file", file: 0, hunk: hunk.id, selectedLines: [], reverse: reverse)
                    }
                }
            }
        }
    }

    /// 输入中的无换行标记关联上一条逻辑行，不新增行号或补丁行；组合范围和逐行前缀必须一致，
    /// 损坏数据不能作为部分成功返回；忽略空白的匹配不允许在普通与组合行之间拼接可写补丁。
    @Test("手写组合 Diff 的无换行标记、错误边界与行匹配")
    func handwritten() throws {
        let diff = try parse("@@@ -1 -1 +1 @@@\n- a\n\\ No newline at end of file\n -b\n++c\n")
        let lines = try #require(diff.files.first?.hunks.first?.lines)
        #expect(lines.count == 3)
        #expect(lines.map(\.noNewline) == [true, false, false])
        #expect(lines.compactMap(\.combined).map(\.numbers) == [[1, 0, 0], [1, 1, 0], [1, 1, 1]])

        // 非法前缀、范围与标记
        let malformed = [
            "@@@ -1 -1 +1 @@@\n-+a\n",
            "@@@ -1 -1 +1 @@@\n+-a\n",
            "@@@ -1 -1 +1 @@@\n xa\n",
            "@@@ -1 -1 +1 @@@\n a\n",
            "@@@ -1 +1 @@@\n  a\n",
            "@@@@ -1 -1 +1 @@@@\n  a\n",
            "@@@ -1,2 -1,2 +1,2 @@@\n  a\n",
            "@@@ -1 -1 +1 @@@\n  a\n  b\n",
            "@@@ -1,0 -1 +1 @@@\n  a\n",
            "@@@ -1 -1 +1 @@@\n\\ No newline at end of file\n  a\n",
            "@@@ -1 -1 +1 @@@\n  a\n\\ No newline at end of file\n\\ No newline at end of file\n",
            "@@@ -9223372036854775807,2 -1 +1 @@@\n  a\n",
            "@@@ -1 -1 +1 @@@\n  a",
        ]

        for body in malformed {
            #expect(throws: WorkingCopyError.malformedDiff) {
                try parse(body)
            }
        }

        // 普通行与组合行互不匹配，只有普通行之间能匹配
        let combined = try parse("@@@ -1 -1 +1 @@@\n--old\n++new\n")
        let ordinary = try RepositoryDiff(patch: Data("diff --git a/f b/f\n@@ -1 +1 @@\n-old\n+new\n".utf8))
        let combinedLines = try #require(combined.files.first?.hunks.first?.lines)
        let ordinaryLines = try #require(ordinary.files.first?.hunks.first?.lines)

        #expect(combined.matchingChanges(of: ordinaryLines) == nil)
        #expect(ordinary.matchingChanges(of: combinedLines) == nil)
        #expect(combined.matchingChanges(of: combinedLines) == nil)
        #expect(ordinary.matchingChanges(of: ordinaryLines)?.lines == [0, 1])

        // 匹配需要至少一行上下文
        #expect(DiffOptions(contextLines: 0).arguments == ["--unified=1"])
    }

    /// 逐侧用原始文件核对每次推进，锚点与消费数量在每块重新开始。
    private func verify(_ file: DiffFile, fixture: Fixture) throws {
        let versions = fixture.versions.map { data -> [Data] in
            guard !data.isEmpty else { return [] }

            let content: Data = data.last == 10 ? data.dropLast() : data
            return content.split(separator: 10, omittingEmptySubsequences: false).map { Data($0) }
        }

        for hunk in file.hunks {
            let ranges = try #require(hunk.combinedRanges)
            #expect(ranges.count == versions.count)
            var counts = Array(repeating: 0, count: ranges.count)
            var numbers = ranges.map { max(0, $0.start - 1) }

            for line in hunk.lines {
                let combined = try #require(line.combined)
                #expect(combined.prefixes.count == versions.count - 1)
                let removed = combined.prefixes.contains(45)
                let present = combined.prefixes.map { $0 == 45 || (!removed && $0 == 32) } + [!removed]

                for side in present.indices where present[side] {
                    let number = ranges[side].start + counts[side]
                    try #require(versions[side].indices.contains(number - 1))
                    #expect(versions[side][number - 1] == line.content)
                    numbers[side] = number
                    counts[side] += 1
                }

                #expect(combined.numbers == numbers)
                #expect(line.oldNumber == (present[0] && line.prefix != 43 ? numbers[0] : nil))
                #expect(line.newNumber == (removed ? nil : numbers.last))
            }

            #expect(counts == ranges.map(\.count))
        }
    }

    /// 手写输入只用于标记关联与错误边界，真实成功输出由固定夹具覆盖。
    private func parse(_ body: String) throws -> RepositoryDiff {
        try RepositoryDiff(patch: Data(("diff --cc f\n" + body).utf8))
    }
}
