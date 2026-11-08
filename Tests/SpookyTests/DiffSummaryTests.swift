import Foundation
import SpookyKit
import Testing

@testable import Spooky

/// 文件头与底栏共享实际摘要入口，元数据与各段单复数分别影响最终文案。
struct DiffSummaryTests {
    /// 修改、新建、删除、模式变化、二进制与空文件的摘要按规定顺序显示；多父模式按首次出现去重；统计按逻辑行计数，二进制标记优先于误带的文本块。
    @Test("文件头摘要、组合模式与统计")
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

        // 单项元数据
        let deleted = AppLocalization.text("diff.summary.deleted", executable)
        let added = AppLocalization.text("diff.summary.added", regular)
        let binaryText = AppLocalization.text("diff.summary.binary")
        #expect(DiffSummary.text(for: try self.file("deleted file mode 100755\n")) == deleted)
        #expect(DiffSummary.text(for: try self.file("new file mode 100644\n")) == added)
        #expect(DiffSummary.text(for: try self.file("Binary files a/f and b/f differ\n")) == binaryText)
        #expect(DiffSummary.text(for: try self.file("old mode 100644\n")).isEmpty)
        #expect(DiffSummary.text(for: try self.file("old mode 100644\nnew mode invalid\n")).isEmpty)

        try expectCombinedModes(regular: regular, executable: executable)

        // 组合块按逻辑行统计
        let plain = try self.file("@@ -1 +1,2 @@\n-old\n+new\n+extra\n")
        let combinedPatch = "diff --cc f\n@@@ -1 -1 +1 @@@\n--old\n++new\n"
        let combined = try #require(RepositoryDiff(patch: Data(combinedPatch.utf8)).files.first)

        let expected = AppLocalization.text(
            "working.diffSummary",
            AppLocalization.text("diff.summary.chunks", 2),
            AppLocalization.text("diff.summary.insertions", 3),
            AppLocalization.text("diff.summary.deletions", 2)
        )

        #expect(DiffSummary.statistics(in: [plain, combined]) == expected)

        // 没有文本块时底栏为空
        let binary = try self.file("Binary files a/f and b/f differ\n@@ -1 +1 @@\n-a\n+b\n")
        #expect(DiffSummary.statistics(in: []).isEmpty)
        #expect(DiffSummary.statistics(in: [try self.file("new file mode 100644\n")]).isEmpty)
        #expect(DiffSummary.statistics(in: [binary]).isEmpty)
    }

    /// 多父模式按首次出现去重，不存在的父不显示；删除和新增不附带模式变化。
    private func expectCombinedModes(regular: String, executable: String) throws {
        let summary = { (header: String) in
            DiffSummary.text(for: try file(header))
        }

        let changed = { (old: String, new: String) in
            AppLocalization.text("diff.summary.modeChanged", old, new)
        }

        #expect(try summary("mode 000000,100644..100644\n").isEmpty)
        #expect(try summary("mode 000000,100644..100755\n") == changed(regular, executable))
        #expect(try summary("mode 100755,100644,100755..100644\n") == changed(executable + ", " + regular, regular))

        // 删除与新增
        let deleted = { AppLocalization.text("diff.summary.deleted", $0) }
        #expect(try summary("deleted file mode 100644,100755,100644\n") == deleted(regular + ", " + executable))
        #expect(try summary("deleted file mode 100644,100644\n") == deleted(regular))
        #expect(try summary("new file mode 100644\n") == AppLocalization.text("diff.summary.added", regular))
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
