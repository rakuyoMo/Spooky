import Foundation
import Testing

@testable import SpookyKit

/// 文件摘要从真实 Git 扩展头解析；可选字段损坏不能放宽补丁正文的校验。
struct DiffFileMetadataTests {
    /// 由隔离配置、固定身份与日期的 Git 2.54 生成的补丁和重命名原路径。
    struct Fixture: Decodable {
        /// 场景名称。
        let name: String

        /// JSON 中的 Base64 补丁。
        let patch: Data

        /// 特殊路径场景的原始路径。
        let path: String?
    }

    /// 各类普通文件、二进制负载与重命名字段都从真实 Git 补丁中读取。
    @Test("真实 Git 文件摘要元数据")
    func fixtures() throws {
        let fixtures = try loadFixtures()
        #expect(fixtures.count == 27)
        let files = try Dictionary(uniqueKeysWithValues: fixtures.map {
            ($0.name, try #require(RepositoryDiff(patch: $0.patch).files.first))
        })
        #expect(files["modified"]?.metadata.oldModes.map(\.value) == ["100644"])
        #expect(files["modified"]?.metadata.newMode?.value == "100644")
        #expect(files["added"]?.metadata.isAdded ?? false)
        #expect(files["added"]?.metadata.oldModes.isEmpty ?? false)
        #expect(files["deleted"]?.metadata.isDeleted ?? false)
        #expect(files["deleted-executable"]?.metadata.oldModes.first?.kind == .executable)
        #expect(files["deleted-executable"]?.metadata.newMode == nil)
        #expect(files["mode-only"]?.hunks.isEmpty ?? false)
        #expect(files["mode-only"]?.metadata.oldModes.first?.kind == .regular)
        #expect(files["mode-only"]?.metadata.newMode?.kind == .executable)
        #expect(files["empty-added"]?.hunks.isEmpty ?? false)
        #expect(files["empty-added"]?.metadata.isAdded ?? false)
        #expect(files["symlink"]?.metadata.newMode?.kind == .symbolicLink)
        #expect(files["submodule"]?.metadata.newMode?.kind == .submodule)
        #expect(files["binary"]?.isBinary ?? false)
        #expect(files["binary-patch"]?.isBinary ?? false)
        #expect(files["rename-edited"]?.metadata.rename?.similarity == 98)

        for fixture in fixtures where fixture.path != nil {
            let path = try #require(fixture.path)
            let rename = try #require(files[fixture.name]?.metadata.rename)
            #expect(Data(rename.oldPath.utf8) == Data(path.utf8))
            #expect(Data(rename.newPath.utf8) == Data(("new-" + path).utf8))
            #expect(rename.similarity == 100)
        }
    }

    /// 原模式列表保留父顺序、重复项与不存在的父，显示去重属于 App。
    @Test("组合 Diff 摘要保留逐父模式")
    func combined() throws {
        let fixtures = try loadFixtures()
        let expected = [
            "combined-missing-same": ["000000", "100644"],
            "combined-missing-changed": ["000000", "100644"],
            "combined-mixed": ["100644", "100755"],
            "combined-repeated": ["100755", "100644", "100755"],
            "combined-deleted-mixed": ["100644", "100755"],
            "combined-deleted-same": ["100644", "100644"],
            "combined-all-absent": [],
        ]

        for fixture in fixtures where fixture.name.hasPrefix("combined-") {
            let file = try #require(RepositoryDiff(patch: fixture.patch).files.first)
            #expect(file.metadata.oldModes.map(\.value) == expected[fixture.name])
            #expect(file.metadata.isDeleted == fixture.name.contains("deleted"))
            #expect(file.metadata.isAdded == fixture.name.contains("all-absent"))
        }
    }

    /// 类别只按六位八进制模式解释，未知但合法的值不冒充普通文件。
    @Test("文件模式的类别与合法性")
    func modes() {
        for (value, kind) in [
            ("100644", DiffFileMode.Kind.regular), ("100755", .executable), ("120000", .symbolicLink),
            ("040000", .directory), ("160000", .submodule), ("000000", .unspecified), ("100600", .unspecified),
        ] {
            #expect(DiffFileMode(value)?.kind == kind)
            #expect(DiffFileMode(value)?.value == value)
            #expect(DiffFileMode(value)?.exists == (value != "000000"))
        }

        for value in ["100644,100755", "100648", "644", "-00644", " 100644", "100644 ", "Regular"] {
            #expect(DiffFileMode(value) == nil)
        }
    }

    /// 非法路径、越界百分比和缺字段只省略重命名项，不丢掉其它合法摘要。
    @Test("可选摘要字段损坏", arguments: [
        ["rename from old", "rename to new"],
        ["rename from old", "similarity index 100%"],
        ["rename from old", "rename to new", "similarity index 101%"],
        ["rename from old", "rename to new", "similarity index -1%"],
        ["rename from old", "rename to new", "similarity index 1.5%"],
        ["rename from old", "rename to new", "similarity index 1 %"],
        ["rename from \"old", "rename to new", "similarity index 100%"],
        ["rename from \"old\"suffix", "rename to new", "similarity index 100%"],
        ["rename from \"old\"\t", "rename to new", "similarity index 100%"],
        ["rename from \"\"", "rename to new", "similarity index 100%"],
        ["rename from \"\\777\"", "rename to new", "similarity index 100%"],
        ["rename from old", "rename to \"\\q\"", "similarity index 100%"],
    ])
    func malformedOptional(headers: [String]) throws {
        let patch = (["diff --git a/f b/f", "old mode 100644", "new mode 100755"] + headers).joined(separator: "\n") + "\n"
        let file = try #require(RepositoryDiff(patch: Data(patch.utf8)).files.first)
        #expect(file.metadata.rename == nil)
        #expect(file.metadata.newMode?.kind == .executable)
        #expect(file.metadata.oldModes.first?.kind == .regular)
    }

    /// 摘要解析不把损坏的正文当作无块文件成功返回。
    @Test("摘要不放宽补丁严格校验")
    func malformedBody() {
        for body in ["@@ -1 +1 @@\n-old\n", "@@ invalid @@\n", "@@ -1 +1 @@\n-old\n+new"] {
            #expect(throws: WorkingCopyError.malformedDiff) {
                try RepositoryDiff(patch: Data(("diff --git a/f b/f\nnew file mode broken\n" + body).utf8))
            }
        }
    }

    /// 每份固定夹具同时保留原补丁与路径，用字节比较避免 Unicode 规范等价掩盖变化。
    private func loadFixtures() throws -> [Fixture] {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/diff-metadata.json")
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }
}
