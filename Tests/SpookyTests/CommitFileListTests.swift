import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - CommitFileListTests

/// 整页提交详情左栏的卡片与工具条。
@MainActor
struct CommitFileListTests {
    /// 作者与提交人按姓名与邮箱整体比较，只差邮箱也写出两人；日期是短日期、不带时间。
    /// 工具条的文件数按真实的变更文件计数，没有变更文件与读取中都不显示。
    @Test("卡片的作者行与工具条的文件数")
    func bylineAndFileCount() throws {
        let locale = Locale(identifier: "en_US")
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let byline = { CommitFileListView.byline($0, locale: locale, timeZone: timeZone) }

        // 姓名与邮箱都相同时只写作者
        let same = Self.commit(committerEmail: "alice@example.invalid")

        #expect(byline(same) == AppLocalization.text("history.committedOn", "Alice", "10/26/26"))

        // 同名不同邮箱也写出提交人
        let otherEmail = Self.commit(committerEmail: "alice@work.invalid")

        #expect(byline(otherEmail) == AppLocalization.text("history.committedWith", "Alice", "Alice", "10/26/26"))

        // 文件数：没有变更文件时不显示，有文件时按数量写，读取中不显示
        let session = RepositorySession()
        defer { session.close() }

        let view = CommitFileListView(session: session, history: session.history)

        #expect(view.fileCount == nil)

        session.history.changes = [
            CommitFileChange(path: "a.txt", originalPath: nil, status: "M", additions: 1, deletions: 1),
        ]

        #expect(view.fileCount == ChangesetSummaryBar.fileCount(1))

        session.history.isLoadingChanges = true

        #expect(view.fileCount == nil)
    }
}

// MARK: - Helpers

extension CommitFileListTests {
    /// 测试用的提交：作者与提交人同名，提交日期是纽约时间 2026-10-26 17:00。
    private static func commit(committerEmail: String) -> HistoryCommit {
        let date = Date(timeIntervalSince1970: 1_793_048_400)

        return HistoryCommit(
            id: String(repeating: "a", count: 40),
            tree: String(repeating: "b", count: 40),
            parents: [],
            author: "Alice",
            authorEmail: "alice@example.invalid",
            authorDate: date,
            committer: "Alice",
            committerEmail: committerEmail,
            commitDate: date,
            message: "Subject"
        )
    }
}
