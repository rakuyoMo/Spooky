import Foundation
import Testing

@testable import SpookyKit

// MARK: - Autosquash Detection

extension RepositoryRewriteTests {
    /// 标记提交要在更早的提交里找到目标：标题相同、标题以引用开头或哈希以引用开头；找不到目标的标记不算。
    @Test("判断有没有可以自动压缩的提交")
    func autosquashDetection() {
        // 从新到旧排列的提交，哈希按位置取不同的字符
        let history = { (subjects: [String]) in
            subjects.enumerated().map { index, subject in
                HistoryCommit(
                    id: String(repeating: String(index), count: 40),
                    tree: String(repeating: "f", count: 40),
                    parents: [],
                    author: "A",
                    authorEmail: "a@example.invalid",
                    authorDate: Date(),
                    committer: "A",
                    committerEmail: "a@example.invalid",
                    commitDate: Date(),
                    message: subject
                )
            }
        }

        #expect(RepositoryRewrite.hasAutosquashCommits(in: history(["fixup! 功能", "其它", "功能"])))
        #expect(RepositoryRewrite.hasAutosquashCommits(in: history(["squash! amend! 功能 一", "功能 一：说明"])))
        #expect(RepositoryRewrite.hasAutosquashCommits(in: history(["fixup! 2222222", "其它", "目标"])))
        #expect(!RepositoryRewrite.hasAutosquashCommits(in: history(["fixup! 不存在", "功能"])))
        #expect(!RepositoryRewrite.hasAutosquashCommits(in: history(["功能", "fixup! 功能"])))
    }
}
