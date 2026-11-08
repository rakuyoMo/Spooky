import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// Diff 放进懒加载栈时，文件段的开头与各块排在同一层，身份互不相同，块头与行才不会被当成重复的元素漏掉。
struct DiffSegmentTests {
    /// 第一个文件段有两个块，第二个文件段是类型变化后新增的符号链接；元素按补丁顺序排列，各块的高亮按元素身份存放。
    @Test("补丁拆成同一层的文件头与块，高亮按块的身份存放")
    func segments() async throws {
        let patch = [
            "diff --git a/a.swift b/a.swift",
            "--- a/a.swift",
            "+++ b/a.swift",
            "@@ -1,2 +1,2 @@",
            " same",
            "-old value",
            "+new value",
            "@@ -20,1 +20,1 @@",
            "-x = 1",
            "+x = 2",
            "diff --git a/a.swift b/a.swift",
            "new file mode 120000",
            "--- /dev/null",
            "+++ b/a.swift",
            "@@ -0,0 +1 @@",
            "+target",
            "\\ No newline at end of file",
        ]
        .joined(separator: "\n") + "\n"

        let diff = try RepositoryDiff(patch: Data(patch.utf8))
        let segments = DiffSegment.all(in: diff)

        let order = segments.map { segment in
            switch segment {
            case .file(let file): "file \(file.id)"
            case .hunk(let file, let hunk): "hunk \(file.id).\(hunk.id)"
            }
        }

        #expect(order == ["file 0", "hunk 0.0", "hunk 0.1", "file 1", "hunk 1.0"])
        #expect(Set(segments.map(\.id)).count == segments.count)

        // 界面按同一身份取用高亮；身份对不上时整块都不会高亮
        let highlights = await DiffSegment.highlights(in: diff)
        #expect(highlights[segments[1].id] == [1: [0 ..< 3], 2: [0 ..< 3]])
        #expect(highlights[segments[2].id] == [0: [4 ..< 5], 1: [4 ..< 5]])
    }
}
