import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// Diff 放进懒加载栈时，文件段的开头与各块排在同一层，身份互不相同，块头与行才不会被当成重复的元素漏掉。
struct DiffSegmentTests {
    /// 第一个文件段有两个块，第二个文件段是类型变化后新增的符号链接；元素按补丁顺序排列。
    @Test("补丁拆成同一层的文件头与块")
    func segments() throws {
        let patch = [
            "diff --git a/a.swift b/a.swift",
            "--- a/a.swift",
            "+++ b/a.swift",
            "@@ -1,2 +1,3 @@",
            "+import Foundation",
            " one",
            " two",
            "@@ -20,2 +21,2 @@",
            "-old",
            "+new",
            " end",
            "diff --git a/a.swift b/a.swift",
            "new file mode 120000",
            "--- /dev/null",
            "+++ b/a.swift",
            "@@ -0,0 +1 @@",
            "+target",
            "\\ No newline at end of file",
        ]
        .joined(separator: "\n") + "\n"

        let segments = DiffSegment.all(in: try RepositoryDiff(patch: Data(patch.utf8)))

        let order = segments.map { segment in
            switch segment {
            case .file(let file): "file \(file.id)"
            case .hunk(let file, let hunk): "hunk \(file.id).\(hunk.id)"
            }
        }

        #expect(order == ["file 0", "hunk 0.0", "hunk 0.1", "file 1", "hunk 1.0"])
        #expect(Set(segments.map(\.id)).count == segments.count)
    }
}
