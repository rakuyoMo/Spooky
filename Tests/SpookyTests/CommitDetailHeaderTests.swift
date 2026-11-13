import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - CommitDetailHeaderTests

/// 提交详情头部的行与日期写法。
@MainActor
struct CommitDetailHeaderTests {
    /// 展开与收起列出不同的行，引用行只在有引用时出现，每个父提交各占一行；日期带时间与时区，不随列表的日期格式变化。
    @Test("详情头部的行与日期")
    func headerRows() throws {
        let locale = Locale(identifier: "en_US")
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let date = Date(timeIntervalSince1970: 1_793_048_400)
        let merge = Self.commit(parents: ["1", "2"].map { String(repeating: $0, count: 40) }, date: date)
        let root = Self.commit(parents: [], date: date)

        let rows = { (commit: HistoryCommit, expanded: Bool, hasReferences: Bool) in
            CommitMetadataView.rows(
                commit,
                expanded: expanded,
                hasReferences: hasReferences,
                locale: locale,
                timeZone: timeZone
            )
        }

        let keys = { (rows: [CommitMetadataView.Row]) in
            rows.map { row in
                switch row {
                case .text(let key, _): key
                case .refs: "refs"
                }
            }
        }

        // 合并提交展开：两个父提交各一行，标签都是 Parent Hash，引用行排在哈希之前
        #expect(keys(rows(merge, true, true)) == [
            "history.author", "history.authorDate", "history.committer", "history.commitDate",
            "refs", "history.hash", "history.parentHash", "history.parentHash", "history.treeHash",
        ])

        // 根提交展开、没有引用：没有父提交行与引用行
        #expect(keys(rows(root, true, false)) == [
            "history.author", "history.authorDate", "history.committer", "history.commitDate",
            "history.hash", "history.treeHash",
        ])

        // 收起：作者、作者日期与引用；没有引用时只剩前两行
        #expect(keys(rows(merge, false, true)) == ["history.author", "history.authorDate", "refs"])
        #expect(keys(rows(merge, false, false)) == ["history.author", "history.authorDate"])

        // 日期是完整日期、时间与时区
        #expect(rows(root, false, false)[1] == .text(
            key: "history.authorDate",
            value: "October 26, 2026 at 5:00:00\u{202F}PM EDT"
        ))
    }
}

// MARK: - Helpers

extension CommitDetailHeaderTests {
    /// 测试用的提交：作者与提交人不同。
    private static func commit(parents: [String], date: Date) -> HistoryCommit {
        HistoryCommit(
            id: String(repeating: "a", count: 40),
            tree: String(repeating: "b", count: 40),
            parents: parents,
            author: "Alice Writer",
            authorEmail: "alice@example.invalid",
            authorDate: date,
            committer: "Test User",
            committerEmail: "test@example.invalid",
            commitDate: date,
            message: "Subject"
        )
    }
}
