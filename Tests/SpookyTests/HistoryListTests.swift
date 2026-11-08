import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - HistoryListTests

/// 历史列表的搜索、视图设置、日期分组、日期格式、窗口副标题与回到提交。
@MainActor
struct HistoryListTests {
    /// 显示提交图时总按拓扑序；两种排序都勾选时按日期；分组只在按日期排序时生效。
    @Test("视图设置组成历史查询")
    func viewSettings() throws {
        let (defaults, directory) = try Self.temporaryDefaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 没有设置过时显示提交图、按拓扑序、不分组
        var settings = HistoryViewSettings(defaults: defaults)
        #expect(settings.showsGraph)
        #expect(settings.order == .topological)
        #expect(settings.grouping == .ungrouped)

        // 隐藏提交图且两种排序都不勾选时用 Git 默认的顺序；分组的设置不生效
        defaults.set(false, forKey: HistoryViewSettings.showGraphKey)
        defaults.set(HistoryGrouping.week.rawValue, forKey: HistoryViewSettings.groupingKey)
        settings = HistoryViewSettings(defaults: defaults)
        #expect(settings.order == .default)
        #expect(settings.grouping == .ungrouped)

        defaults.set(true, forKey: HistoryViewSettings.topoOrderKey)
        #expect(HistoryViewSettings(defaults: defaults).order == .topological)

        // 两项都勾选时以日期为准，按周分组随之生效
        defaults.set(true, forKey: HistoryViewSettings.dateOrderKey)
        defaults.set(true, forKey: HistoryViewSettings.firstParentKey)
        settings = HistoryViewSettings(defaults: defaults)
        #expect(settings.order == .date)
        #expect(settings.grouping == .week)

        let conditions = [HistorySearchCondition(kind: .author, text: "alice")]
        let query = settings.query(conditions: conditions)
        #expect(query.firstParentOnly)
        #expect(query.isSearching)
        #expect(query.hasSameResults(as: settings.query(conditions: conditions)))
        #expect(!query.hasSameResults(as: settings.query(conditions: [])))
    }

    /// 按天、周、月分组时每组前插入一行标题，表格行号经映射找到提交，标题行不对应提交；
    /// 绝对格式写出日期与时间，相对格式写出相对现在的时间，按天分组的标题跟随格式。
    @Test("日期分组的行、标题与提交日期格式")
    func groupedRows() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

        // 两个提交在 1 月 9 日，一个在 1 月 2 日，一个在 2 月 1 日；按日期倒序排列
        let commits = try [
            Self.commit("d", date: Self.date(month: 2, day: 1, calendar: calendar)),
            Self.commit("c", date: Self.date(month: 1, day: 9, hour: 18, calendar: calendar)),
            Self.commit("b", date: Self.date(month: 1, day: 9, hour: 8, calendar: calendar)),
            Self.commit("a", date: Self.date(month: 1, day: 2, calendar: calendar)),
        ]

        let days = HistoryRow.rows(for: commits, grouping: .day, calendar: calendar)
        #expect(days.map { $0.commit?.subject ?? "-" } == ["-", "d", "-", "c", "b", "-", "a"])

        let months = HistoryRow.rows(for: commits, grouping: .month, calendar: calendar)
        #expect(months.map { $0.commit?.subject ?? "-" } == ["-", "d", "-", "c", "b", "a"])

        let ungrouped = HistoryRow.rows(for: commits, grouping: .ungrouped, calendar: calendar)
        #expect(ungrouped.map(\.id) == commits.map(\.id))

        // 行号映射跳过标题行
        let history = RepositoryHistoryState()
        history.rows = days
        #expect(history.commit(atRow: 0) == nil)
        #expect(history.commit(atRow: 1)?.subject == "d")
        #expect(history.commit(atRow: 4)?.subject == "b")
        #expect(history.commit(atRow: 99) == nil)
        #expect(history.row(of: commits[3].id) == 6)
        #expect(history.row(of: String(repeating: "f", count: 40)) == nil)

        // 提交日期：绝对格式写出日期与时间，相对格式写出相对现在的时间
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let earlier = now.addingTimeInterval(-3 * 3600)
        let absolute = CommitDateFormat.absolute.string(from: earlier, now: now)
        let relative = CommitDateFormat.relative.string(from: earlier, now: now)

        #expect(absolute == earlier.formatted(date: .abbreviated, time: .shortened))
        #expect(relative.contains("3"))
        #expect(relative != absolute)

        // 按天分组的标题跟随日期格式
        let local = Calendar.current
        let today = local.startOfDay(for: now)
        let yesterday = try #require(local.date(byAdding: .day, value: -1, to: today))

        #expect(
            CommitDateFormat.absolute.dayTitle(yesterday, now: now)
                == yesterday.formatted(date: .long, time: .omitted)
        )

        #expect(
            CommitDateFormat.relative.dayTitle(yesterday, now: now)
                != CommitDateFormat.relative.dayTitle(today, now: now)
        )

        // 按周的标题写出全年第几周，按月的标题不随日期格式变化
        let week = HistoryGrouping.week.title(of: yesterday, format: .relative, now: now, calendar: local)
        #expect(week.contains(String(local.component(.weekOfYear, from: yesterday))))

        #expect(
            HistoryGrouping.month.title(of: yesterday, format: .relative, now: now, calendar: local)
                == HistoryGrouping.month.title(of: yesterday, format: .absolute, now: now, calendar: local)
        )
    }

    /// 文件名连续命中的排在前面，其次是文件名按顺序命中、路径命中；不区分大小写。
    @Test("文件补全的匹配与排序")
    func fileSuggestions() {
        let paths = [
            "Sources/History/HistoryListView.swift",
            "docs/hist/notes.md",
            "Sources/HistoryLoader.swift",
            "README.md",
            "目录/历史 说明.md",
        ]

        #expect(HistorySearchSuggestions.fileMatches("history", in: paths) == [
            "Sources/HistoryLoader.swift",
            "Sources/History/HistoryListView.swift",
        ])
        #expect(HistorySearchSuggestions.fileMatches("hlv", in: paths) == ["Sources/History/HistoryListView.swift"])
        #expect(HistorySearchSuggestions.fileMatches("HIST", in: paths).last == "docs/hist/notes.md")
        #expect(HistorySearchSuggestions.fileMatches("历史", in: paths) == ["目录/历史 说明.md"])
        #expect(HistorySearchSuggestions.fileMatches("zzz", in: paths).isEmpty)
    }

    /// 按邮箱读取的头像：读到时显示图片，没有头像或读取失败时记下、之后不再请求；
    /// 托管用户的头像按服务给的地址原样请求，缓存与没有头像的记忆相同。
    @Test("作者头像按邮箱与按地址的读取、缓存与回退")
    func avatars() async throws {
        let store = AvatarStore()
        let image = try #require(
            NSImage(size: NSSize(width: 2, height: 2), flipped: false) { _ in true }.tiffRepresentation
        )

        // 按邮箱读取：只有第一次请求的邮箱有头像
        let requests = RequestCounter()

        store.fetch = { url in
            await requests.record(url)
            let count = await requests.count
            return count == 1 && url.absoluteString.hasSuffix("?s=\(AvatarStore.pixelSize)&d=404") ? image : nil
        }

        // 邮箱按小写与去掉空白后取哈希，同一个人只请求一次
        #expect(await store.image(for: " Alice@Example.invalid ") != nil)
        #expect(await store.image(for: "alice@example.invalid") != nil)
        #expect(await requests.count == 1)

        // 没有头像的邮箱只请求一次，没有邮箱时不请求
        #expect(await store.image(for: "bob@example.invalid") == nil)
        #expect(await store.image(for: "bob@example.invalid") == nil)
        #expect(await store.image(for: nil) == nil)
        #expect(await store.image(for: "  ") == nil)
        #expect(await requests.count == 2)

        // 按地址读取：只有 found 有头像
        let addresses = RequestCounter()
        let found = try #require(URL(string: "https://avatars.githubusercontent.com/u/1?v=4"))
        let absent = try #require(URL(string: "https://git.example.com/uploads/-/system/user/avatar/2/a.png"))

        store.fetch = { url in
            await addresses.record(url)
            return url == found ? image : nil
        }

        // 同一地址只请求一次，没有头像的地址也只请求一次
        #expect(await store.image(at: found) != nil)
        #expect(await store.image(at: found) != nil)
        #expect(await store.image(at: absent) == nil)
        #expect(await store.image(at: absent) == nil)

        // 地址原样请求，不加 Gravatar 的尺寸参数
        #expect(await addresses.urls == [found, absent])
    }
}

// MARK: - RequestCounter

/// 记下头像请求的地址。
private actor RequestCounter {
    /// 请求过的地址。
    private(set) var urls: [URL] = []

    /// 请求次数。
    var count: Int { urls.count }

    /// 记下一次请求。
    func record(_ url: URL) {
        urls.append(url)
    }
}

// MARK: - Helpers

extension HistoryListTests {
    /// 测试专用的偏好域与它所在的临时目录，与应用的偏好隔离；用例结束时删掉目录。
    static func temporaryDefaults() throws -> (defaults: UserDefaults, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-history-tests-" + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }

    /// 构造只用于排列的提交。
    static func commit(_ subject: String, date: Date) -> HistoryCommit {
        HistoryCommit(
            id: String(repeating: subject, count: 40),
            tree: String(repeating: "e", count: 40),
            parents: [],
            author: "Alice",
            authorEmail: "alice@example.invalid",
            authorDate: date,
            committer: "Alice",
            committerEmail: "alice@example.invalid",
            commitDate: date,
            message: subject
        )
    }

    /// 2026 年某天的时刻。
    static func date(month: Int, day: Int, hour: Int = 12, calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)))
    }
}
