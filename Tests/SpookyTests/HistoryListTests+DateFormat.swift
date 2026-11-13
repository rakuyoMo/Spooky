import ApplicationServices
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - DateFormat

extension HistoryListTests {
    /// 两种写法都不带时间：绝对写法是按语言与区域的短日期；相对写法对今天、昨天写说法，其余日子（含以后的日子）写完整日期。
    /// 今天、昨天按当地日历的日子算，不按相隔的小时数，跨午夜、换时区与夏令时切换日都以当地的日子为准。
    @Test("提交日期的两种写法")
    func commitDateFormats() throws {
        let newYork = Self.calendar("en_US", timeZone: "America/New_York")
        let now = try Self.time(month: 11, day: 12, hour: 10, in: newYork)

        // 今天、昨天、更早与以后的日子
        #expect(try Self.formats(Self.time(month: 11, day: 12, hour: 8, in: newYork), now: now, in: newYork) == [
            "11/12/26",
            "Today",
        ])

        #expect(try Self.formats(Self.time(month: 11, day: 11, hour: 12, in: newYork), now: now, in: newYork) == [
            "11/11/26",
            "Yesterday",
        ])

        #expect(try Self.formats(Self.time(month: 11, day: 10, hour: 12, in: newYork), now: now, in: newYork) == [
            "11/10/26",
            "November 10, 2026",
        ])

        #expect(try Self.formats(Self.time(month: 11, day: 13, hour: 9, in: newYork), now: now, in: newYork) == [
            "11/13/26",
            "November 13, 2026",
        ])

        // 跨午夜：只差两分钟也是昨天，差近一整天仍是今天，刚过两天的午夜写完整日期
        let justAfterMidnight = try Self.time(month: 11, day: 12, hour: 0, minute: 1, in: newYork)
        let beforeMidnight = try Self.time(month: 11, day: 12, hour: 23, minute: 59, in: newYork)

        #expect(
            try Self.formats(
                Self.time(month: 11, day: 11, hour: 23, minute: 59, in: newYork),
                now: justAfterMidnight,
                in: newYork
            ) == ["11/11/26", "Yesterday"]
        )

        #expect(
            try Self.formats(justAfterMidnight, now: beforeMidnight, in: newYork) == ["11/12/26", "Today"]
        )

        #expect(
            try Self.formats(
                Self.time(month: 11, day: 10, hour: 23, minute: 59, in: newYork),
                now: justAfterMidnight,
                in: newYork
            ) == ["11/10/26", "November 10, 2026"]
        )

        // 时区：同一时刻在纽约是昨天晚上，在东京是今天上午
        let utc = Self.calendar("en_US", timeZone: "UTC")
        let tokyo = Self.calendar("en_US", timeZone: "Asia/Tokyo")
        let instant = try Self.time(month: 11, day: 12, hour: 2, in: utc)
        let later = try Self.time(month: 11, day: 12, hour: 13, in: utc)

        #expect(Self.formats(instant, now: later, in: newYork) == ["11/11/26", "Yesterday"])
        #expect(Self.formats(instant, now: later, in: tokyo) == ["11/12/26", "Today"])

        // 夏令时切换日：3 月 8 日只有 23 小时、11 月 1 日有 25 小时，前一天仍是昨天，再早一天写完整日期
        let afterSpring = try Self.time(month: 3, day: 9, hour: 9, in: newYork)
        let afterFall = try Self.time(month: 11, day: 2, hour: 0, minute: 30, in: newYork)

        #expect(try Self.formats(Self.time(month: 3, day: 8, hour: 12, in: newYork), now: afterSpring, in: newYork) == [
            "3/8/26",
            "Yesterday",
        ])

        #expect(try Self.formats(Self.time(month: 3, day: 7, hour: 12, in: newYork), now: afterSpring, in: newYork) == [
            "3/7/26",
            "March 7, 2026",
        ])

        #expect(
            try Self.formats(
                Self.time(month: 11, day: 1, hour: 0, minute: 10, in: newYork),
                now: afterFall,
                in: newYork
            ) == ["11/1/26", "Yesterday"]
        )

        // 语言与区域跟随日历：简体中文的短日期、说法与完整日期
        let chinese = Self.calendar("zh_Hans_CN", timeZone: "America/New_York")

        #expect(try Self.formats(Self.time(month: 11, day: 12, hour: 8, in: chinese), now: now, in: chinese) == [
            "2026/11/12",
            "今天",
        ])

        #expect(try Self.formats(Self.time(month: 11, day: 11, hour: 8, in: chinese), now: now, in: chinese) == [
            "2026/11/11",
            "昨天",
        ])

        #expect(try Self.formats(Self.time(month: 11, day: 10, hour: 8, in: chinese), now: now, in: chinese) == [
            "2026/11/10",
            "2026年11月10日",
        ])
    }

    /// Reflog 行在日期后带系统的短时间：绝对写法是短日期加短时间；相对写法今天、昨天写说法，更早的日子写完整日期，
    /// 日期与时间之间的连接由系统按语言给出。相对写法按运行时的当天判断，日子与时刻都取日历所在的时区。
    @Test("Reflog 行带时间的两种写法")
    func reflogDateFormats() throws {
        let newYork = Self.calendar("en_US", timeZone: "America/New_York")
        let today = try #require(newYork.date(bySettingHour: 10, minute: 5, second: 0, of: Date()))
        let yesterday = try #require(newYork.date(byAdding: .day, value: -1, to: today))

        let earlier = try #require(newYork.date(from: DateComponents(
            year: 2025,
            month: 3,
            day: 4,
            hour: 15,
            minute: 30
        )))

        // 系统的短时间在 AM / PM 前用窄不换行空格
        let space = "\u{202F}"

        let absolute = { CommitDateFormat.absolute.stringWithTime(from: $0, calendar: newYork) }
        let relative = { CommitDateFormat.relative.stringWithTime(from: $0, calendar: newYork) }

        #expect(absolute(earlier) == "3/4/25, 3:30" + space + "PM")

        #expect(relative(today) == "Today at 10:05" + space + "AM")
        #expect(relative(yesterday) == "Yesterday at 10:05" + space + "AM")
        #expect(relative(earlier) == "March 4, 2025 at 3:30" + space + "PM")
    }

    /// 历史行写出提交人日期：作者日期与提交人日期不在同一天时，行里只出现提交人日期。
    @Test("历史行用提交人日期", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func rowCommitDate() async throws {
        let authored = try Self.date(month: 10, day: 1, calendar: .current)
        let committed = try Self.date(month: 10, day: 20, calendar: .current)

        let commit = HistoryCommit(
            id: String(repeating: "d", count: 40),
            tree: String(repeating: "e", count: 40),
            parents: [],
            author: "Alice",
            authorEmail: "alice@example.invalid",
            authorDate: authored,
            committer: "Bob",
            committerEmail: "bob@example.invalid",
            commitDate: committed,
            message: "Dated"
        )

        let committedText = CommitDateFormat.absolute.string(from: committed)
        let authoredText = CommitDateFormat.absolute.string(from: authored)

        // 行的文字合成一个元素，读到标题时日期也已在里面
        let elements = await AccessibilityProbe.elements(
            until: { elements in
                elements.contains { Self.mentions($0, commit.subject) }
            }
        ) {
            HistoryCommitRow(
                commit: commit,
                graph: nil,
                references: [],
                isHead: false,
                small: true,
                dateFormat: .absolute,
                unpushed: false,
                unpulled: false,
                isParent: false,
                selected: false,
                signatures: CommitSignatureStore(),
                runner: nil
            )
            .frame(height: 24)
        }

        #expect(elements.contains { Self.mentions($0, committedText) })
        #expect(!elements.contains { Self.mentions($0, authoredText) })
    }
}

// MARK: - DateFormat Helpers

extension HistoryListTests {
    /// 一个时刻按绝对、相对两种写法写出的文字，依次排列。
    private static func formats(_ date: Date, now: Date, in calendar: Calendar) -> [String] {
        [
            CommitDateFormat.absolute.string(from: date, now: now, calendar: calendar),
            CommitDateFormat.relative.string(from: date, now: now, calendar: calendar),
        ]
    }

    /// 公历日历，语言区域与时区固定，不受本机设置影响。
    private static func calendar(_ locale: String, timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: locale)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        return calendar
    }

    /// 日历所在时区里 2026 年某天的时刻。
    private static func time(month: Int, day: Int, hour: Int, minute: Int = 0, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    /// 元素的名称或值里含有给定文字。
    private static func mentions(_ element: AccessibilityProbe.Element, _ text: String) -> Bool {
        element.name.contains(text) || element.value.contains(text)
    }
}
