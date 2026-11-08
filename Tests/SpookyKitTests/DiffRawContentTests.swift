import Foundation
import Testing

@testable import SpookyKit

/// 原始块身份来自 Git 字节，不能由解码后的标题和正文重新拼接。
struct DiffRawContentTests {
    /// 隔离 Git 2.54、固定身份与时间生成的普通 / 多父补丁。
    struct Fixture: Decodable {
        /// 场景与对象格式。
        let name: String

        /// Git 输出的完整补丁。
        let patch: Data

        /// 按文件与块边界截出的原始字节。
        let blocks: [Data]
    }

    /// 普通块保存非法 UTF-8、CRLF、Tab 和末行标记，组合块保存全部父前缀。
    @Test("普通与组合 Diff 保留原始块字节")
    func rawContent() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/diff-raw-hunks.json")
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        #expect(fixtures.count == 4)

        for fixture in fixtures {
            let diff = try RepositoryDiff(patch: fixture.patch)
            #expect(diff.files.flatMap(\.hunks).map(\.rawContent) == fixture.blocks)
            #expect(fixture.blocks.allSatisfy { $0.starts(with: Data("@@".utf8)) && $0.last == 10 })

            // 普通补丁里有非法 UTF-8、CRLF 与末行标记
            if fixture.name.hasPrefix("ordinary") {
                #expect(fixture.blocks.contains { $0.contains(0xFF) })
                #expect(fixture.blocks.contains { $0.contains(13) })
                #expect(fixture.blocks.last?.contains(Data("\\ No newline at end of file\n".utf8)) ?? false)
            }

            // 两份补丁连在一起时，块字节按顺序各出现一次
            let repeated = try RepositoryDiff(patch: fixture.patch + fixture.patch)
            #expect(repeated.files.flatMap(\.hunks).map(\.rawContent) == fixture.blocks + fixture.blocks)
        }
    }
}
