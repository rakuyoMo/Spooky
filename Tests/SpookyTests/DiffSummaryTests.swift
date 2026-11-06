import Foundation
import SpookyKit
import Testing

@testable import Spooky

/// 文件头与底栏共享实际摘要入口，元数据与各段单复数分别影响最终文案。
struct DiffSummaryTests {
    /// 纯修改、新建、删除、模式变化、二进制与空文件的摘要按规定顺序显示。
    @Test("文件头摘要的实际文本")
    func summary() throws {
        let regular = mode("100644", kind: "regular")
        let executable = mode("100755", kind: "executable")
        let changed = AppLocalization.text("diff.summary.modeChanged", regular, executable)
        let rename = AppLocalization.text("diff.summary.renamed", " old ", "new\nname", 98)
        let file = try file("""
            old mode 100644
            new mode 100755
            similarity index 98%
            rename from " old "
            rename to "new\\nname"
            @@ -1 +1 @@
            -old
            +new

            """)
        let statistics = DiffSummary.statistics(in: [file])
        #expect(DiffSummary.text(for: file) == [changed, rename, statistics].joined(separator: "\n"))
        #expect(DiffSummary.text(for: try self.file("deleted file mode 100755\n")) == AppLocalization.text(
            "diff.summary.deleted", executable
        ))
        #expect(DiffSummary.text(for: try self.file("new file mode 100644\n")) == AppLocalization.text(
            "diff.summary.added", regular
        ))
        #expect(DiffSummary.text(for: try self.file("Binary files a/f and b/f differ\n")) == AppLocalization.text(
            "diff.summary.binary"
        ))
        #expect(DiffSummary.text(for: try self.file("old mode 100644\n")).isEmpty)
        #expect(DiffSummary.text(for: try self.file("old mode 100644\nnew mode invalid\n")).isEmpty)
    }

    /// 多父模式按首次出现去重，不存在的父不显示；删除和新增不附带模式变化。
    @Test("组合模式摘要的存在性和顺序")
    func combinedModes() throws {
        let regular = mode("100644", kind: "regular")
        let executable = mode("100755", kind: "executable")
        #expect(DiffSummary.text(for: try file("mode 000000,100644..100644\n")).isEmpty)
        #expect(DiffSummary.text(for: try file("mode 000000,100644..100755\n")) == AppLocalization.text(
            "diff.summary.modeChanged", regular, executable
        ))
        #expect(DiffSummary.text(for: try file("mode 100755,100644,100755..100644\n")) == AppLocalization.text(
            "diff.summary.modeChanged", executable + ", " + regular, regular
        ))
        #expect(DiffSummary.text(for: try file("deleted file mode 100644,100755,100644\n")) == AppLocalization.text(
            "diff.summary.deleted", regular + ", " + executable
        ))
        #expect(DiffSummary.text(for: try file("deleted file mode 100644,100644\n")) == AppLocalization.text(
            "diff.summary.deleted", regular
        ))
        #expect(DiffSummary.text(for: try file("new file mode 100644\n")) == AppLocalization.text(
            "diff.summary.added", regular
        ))
    }

    /// 统计使用逻辑行而不是父前缀数，二进制标记优先于误带的文本块。
    @Test("摘要统计与空底栏")
    func statistics() throws {
        let plain = try file("@@ -1 +1,2 @@\n-old\n+new\n+extra\n")
        let combined = try #require(RepositoryDiff(patch: Data(
            "diff --cc f\n@@@ -1 -1 +1 @@@\n--old\n++new\n".utf8
        )).files.first)
        #expect(DiffSummary.statistics(in: [plain, combined]) == AppLocalization.text(
            "working.diffSummary",
            AppLocalization.text("diff.summary.chunks", 2),
            AppLocalization.text("diff.summary.insertions", 3),
            AppLocalization.text("diff.summary.deletions", 2)
        ))
        #expect(DiffSummary.statistics(in: []).isEmpty)
        #expect(DiffSummary.statistics(in: [try file("new file mode 100644\n")]).isEmpty)
        #expect(DiffSummary.statistics(in: [try file("Binary files a/f and b/f differ\n@@ -1 +1 @@\n-a\n+b\n")]).isEmpty)

        for kind in ["chunks", "insertions", "deletions"] {
            for count in 0 ... 2 {
                let key = "diff.summary." + kind + (count == 1 ? ".one" : "")
                #expect(DiffSummary.count(count, kind: kind) == AppLocalization.text(key, count))
            }
        }
    }

    /// 八种语言的片段对 0、1、2 正确格式化，整句连接符由模板提供，不出现资源键或多余参数。
    @Test("八语言 Diff 统计与大 Diff 文案", arguments: AppLocalization.languages)
    func translations(language: String) throws {
        let url = try #require(AppLocalization.bundle.url(forResource: language, withExtension: "lproj"))
        let bundle = try #require(Bundle(url: url))
        let expected: [String: [String]] = [
            "en": ["1 chunk", "0 insertions", "2 deletions"],
            "zh-Hans": ["1 个块", "新增 0 行", "删除 2 行"],
            "zh-Hant": ["1 個區塊", "新增 0 行", "刪除 2 行"],
            "ja": ["1 個のブロック", "0 行追加", "2 行削除"],
            "ko": ["블록 1 개", "추가 0 줄", "삭제 2 줄"],
            "de": ["1 Block", "0 Zeilen hinzugefügt", "2 Zeilen gelöscht"],
            "fr": ["1 section", "0 insertions", "2 suppressions"],
            "es": ["1 fragmento", "0 inserciones", "2 eliminaciones"],
        ]
        let parts = zip(["chunks", "insertions", "deletions"], [1, 0, 2]).map { kind, count in
            let key = "diff.summary." + kind + (count == 1 ? ".one" : "")
            return String(format: bundle.localizedString(forKey: key, value: nil, table: nil), count)
        }
        #expect(parts == expected[language])
        let template = bundle.localizedString(forKey: "working.diffSummary", value: nil, table: nil)
        let separator = language.hasPrefix("zh") ? "，" : (language == "ja" ? "、" : ", ")
        #expect(String(format: template, arguments: parts) == parts.joined(separator: separator))
        let warning = bundle.localizedString(forKey: "working.largeDiff", value: nil, table: nil)
        #expect(try LocalizationTests.formatSignature(warning).isEmpty)
        #expect(!warning.contains("kB"))
    }

    /// 使用生产解析入口构造文件摘要，不另建视图专用元数据。
    private func file(_ content: String) throws -> DiffFile {
        try #require(RepositoryDiff(patch: Data(("diff --git a/f b/f\n" + content).utf8)).files.first)
    }

    /// 模式数值和类别分别作为资源参数传入。
    private func mode(_ value: String, kind: String) -> String {
        AppLocalization.text("diff.summary.mode", value, AppLocalization.text("diff.summary.mode." + kind))
    }
}
