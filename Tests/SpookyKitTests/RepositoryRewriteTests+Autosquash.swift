import Foundation
import Testing

@testable import SpookyKit

// MARK: - Autosquash Detection

extension RepositoryRewriteTests {
    /// 标记可以连续出现，没有标记或只剩标记时不是 Autosquash 提交；
    /// 标记提交要在更早的提交里找到目标：标题相同、标题以引用开头或哈希以引用开头；找不到目标的标记不算。
    @Test("Autosquash 标记与可以自动压缩的提交数")
    func autosquashDetection() {
        // 标记的写法
        #expect(RepositoryRewrite.autosquashReference(of: "fixup! fixup! 标题") == "标题")
        #expect(RepositoryRewrite.autosquashReference(of: "amend! abc1234") == "abc1234")
        #expect(RepositoryRewrite.autosquashReference(of: "squash! ") == nil)
        #expect(RepositoryRewrite.autosquashReference(of: "普通提交") == nil)

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

        let count = { RepositoryRewrite.autosquashCommitCount(in: history($0)) }

        #expect(count(["fixup! 功能", "其它", "功能"]) == 1)
        #expect(count(["squash! amend! 功能 一", "功能 一：说明"]) == 1)
        #expect(count(["fixup! 2222222", "其它", "目标"]) == 1)
        #expect(count(["fixup! 不存在", "功能"]) == 0)
        #expect(count(["功能", "fixup! 功能"]) == 0)

        // 每个找到目标的标记提交各算一个，找不到目标的不算
        #expect(count(["fixup! 功能", "squash! 其它", "fixup! 不存在", "其它", "功能"]) == 2)
    }
}
