import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Timeline

extension FileViewsTests {
    /// 时间线按提交人日期所在的月份分组，跨年的同名月份分开，月末与月初分在两组；
    /// 组名是本地化的 “月份 年份”，按语言大写。
    @Test("文件历史按月分组")
    func fileHistoryMonths() throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        // 2026-10-26、2026-10-01、2026-09-30 与 2025-10-26，均为纽约时间中午
        let commits = [1_793_030_400, 1_790_870_400, 1_790_784_000, 1_761_494_400].map {
            Self.timelineCommit(date: Date(timeIntervalSince1970: TimeInterval($0)))
        }

        let sections = FileHistoryTimelineView.sections(of: commits, calendar: calendar)
        let titles = sections.map {
            FileHistoryTimelineView.monthTitle($0.month, locale: Locale(identifier: "en_US"), calendar: calendar)
        }

        #expect(sections.map(\.commits.count) == [2, 1, 1])
        #expect(titles == ["OCTOBER 2026", "SEPTEMBER 2026", "OCTOBER 2025"])

        let chinese = FileHistoryTimelineView.monthTitle(
            sections[0].month,
            locale: Locale(identifier: "zh-Hans"),
            calendar: calendar
        )

        #expect(chinese == "2026年10月")
    }
}

// MARK: - Helpers

extension FileViewsTests {
    /// 时间线用的提交，只有提交人日期不同。
    fileprivate static func timelineCommit(date: Date) -> HistoryCommit {
        HistoryCommit(
            id: UUID().uuidString,
            tree: String(repeating: "b", count: 40),
            parents: [],
            author: "Alice",
            authorEmail: "alice@example.invalid",
            authorDate: date,
            committer: "Alice",
            committerEmail: "alice@example.invalid",
            commitDate: date,
            message: "Subject"
        )
    }
}
