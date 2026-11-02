import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - PullRequestConversationTests

/// 讨论的时间线：提交按本机日历日分组，组与评论按时间排列；提交从仓库里读完才列出。
@MainActor
struct PullRequestConversationTests {
    /// 组的时间比组里最早的提交早 2 秒，所以组排在当天的提交与同一时刻的评论之前；午夜前后的提交分在两天。
    @Test("提交按日历日分组，与评论按时间排列")
    func timeline() throws {
        let calendar = try Self.calendar()

        let lateNight = try Self.date(day: 1, hour: 23, minute: 59, calendar: calendar)
        let afterMidnight = try Self.date(day: 2, hour: 0, minute: 1, calendar: calendar)
        let morning = try Self.date(day: 2, hour: 9, minute: 0, calendar: calendar)

        // 读到的提交按拓扑序从新到旧
        let commits = [
            Self.commit("c", date: morning),
            Self.commit("b", date: afterMidnight),
            Self.commit("a", date: lateNight),
        ]

        // 一条评论落在两组之间，一条与第二组最早的提交同一时刻
        let comments = [
            PullRequestComment(
                id: 1,
                author: HostingUser(username: "bob", name: nil),
                body: "same instant",
                createdAt: afterMidnight
            ),
            PullRequestComment(
                id: 2,
                author: HostingUser(username: "alice", name: nil),
                body: "between",
                createdAt: try Self.date(day: 2, hour: 0, minute: 0, calendar: calendar)
            ),
        ]

        let timeline = PullRequestConversationItem.timeline(comments: comments, commits: commits, calendar: calendar)

        #expect(
            timeline.map(\.key) == [
                .group(calendar.startOfDay(for: lateNight)),
                .comment(2),
                .group(calendar.startOfDay(for: afterMidnight)),
                .comment(1),
            ]
        )

        // 组里的提交按提交者时间从早到晚，组的时间早 2 秒
        let groups = timeline.compactMap { item -> PullRequestCommitGroup? in
            guard case .group(let group) = item else { return nil }
            return group
        }

        #expect(groups.map { $0.commits.map(\.subject) } == [["a"], ["b", "c"]])
        #expect(groups.map(\.date) == [lateNight.addingTimeInterval(-2), afterMidnight.addingTimeInterval(-2)])
    }

    /// 需要获取或比较还没读完时没有提交，讨论里只有评论。
    @Test("没有提交时没有提交组")
    func timelineWithoutCommits() {
        let comment = PullRequestComment(
            id: 7,
            author: HostingUser(username: "bob", name: nil),
            body: "hi",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        #expect(PullRequestConversationItem.timeline(comments: [comment], commits: []).map(\.key) == [.comment(7)])
    }

    /// 1 个提交用单数写法；日期跟随 Settings → General 的日期格式。
    @Test("提交组的标题")
    func groupTitle() throws {
        let calendar = try Self.calendar()
        let date = try Self.date(day: 3, hour: 12, minute: 0, calendar: calendar)

        let single = try #require(
            PullRequestCommitGroup.groups(of: [Self.commit("a", date: date)], calendar: calendar).first
        )

        let double = try #require(
            PullRequestCommitGroup.groups(
                of: [Self.commit("b", date: date), Self.commit("a", date: date)],
                calendar: calendar
            )
            .first
        )

        #expect(
            single.title(format: .absolute)
                == AppLocalization.text("pullRequests.commitGroup.one", CommitDateFormat.absolute.string(from: single.date))
        )

        #expect(
            double.title(format: .absolute)
                == AppLocalization.text("pullRequests.commitGroup", 2, CommitDateFormat.absolute.string(from: double.date))
        )

        #expect(
            double.title(format: .relative)
                == AppLocalization.text("pullRequests.commitGroup", 2, CommitDateFormat.relative.string(from: double.date))
        )
    }

    /// 比较范围里的提交与参与者读完才列出，提交按拓扑序从新到旧；关闭后不再列出。
    @Test("讨论读出比较范围里的全部提交与参与者")
    func loadCommits() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-conversation-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))

        // 基准之上三个提交
        var heads: [String] = []

        for subject in ["base", "one", "two", "three"] {
            _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", subject])

            let head = try await runner.run(["rev-parse", "HEAD"])
            heads.append(String(decoding: head, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let conversation = PullRequestConversationState()
        conversation.load(base: heads[0], target: heads[3], runner: runner)

        try await FileViewsTests.wait { conversation.commits != nil }
        #expect(conversation.commits?.map(\.subject) == ["three", "two", "one"])

        // 基准的提交不算，三个提交都是同一位作者
        #expect(conversation.contributors?.map(\.commitCount) == [3])

        conversation.close()
        #expect(conversation.commits == nil && conversation.contributors == nil)
    }

    /// 作者、提交数、目标分支与源分支按参数位置插入并加粗，分支名里的 Markdown 符号原样显示；提交数未知时省掉这一段。
    @Test("讨论头部的合并说明")
    func headerInfo() {
        let request = Self.request(source: "feat/*bold*_x_", target: "main_**")

        // 加粗的几段
        let emphasized: (AttributedString) -> Set<String> = { info in
            Set(info.runs.filter { $0.font != nil }.map { String(info[$0.range].characters) })
        }

        let commits = AppLocalization.text("pullRequests.header.commits", 3)
        let counted = PullRequestConversationHeader.info(of: request, commitCount: 3)

        #expect(
            String(counted.characters)
                == AppLocalization.text("pullRequests.header.info", "alice", commits, "main_**", "feat/*bold*_x_")
        )

        #expect(emphasized(counted) == ["alice", commits, "main_**", "feat/*bold*_x_"])

        // 1 个提交用单数写法
        let single = PullRequestConversationHeader.info(of: request, commitCount: 1)
        #expect(emphasized(single).contains(AppLocalization.text("pullRequests.header.commits.one")))

        // 还没读完提交时不写提交数
        let unknown = PullRequestConversationHeader.info(of: request, commitCount: nil)

        #expect(
            String(unknown.characters)
                == AppLocalization.text("pullRequests.header.direction", "alice", "main_**", "feat/*bold*_x_")
        )

        #expect(emphasized(unknown) == ["alice", "main_**", "feat/*bold*_x_"])
    }
}

// MARK: - Helpers

extension PullRequestConversationTests {
    /// 固定在东八区的公历，午夜的位置不随运行测试的机器变化。
    static func calendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        return calendar
    }

    /// 2026 年 10 月某天的时刻。
    static func date(day: Int, hour: Int, minute: Int, calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
    }

    /// alice 发起的打开着的请求，源分支与目标分支在同一个项目里。
    static func request(source: String, target: String) -> PullRequest {
        PullRequest(
            id: PullRequestID(instance: .github, project: "o/r", number: 7),
            title: "t",
            body: "",
            state: .open,
            isDraft: false,
            author: HostingUser(username: "alice", name: nil),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: PullRequestBranch(project: "o/r", branch: source, sha: ""),
            target: PullRequestBranch(project: "o/r", branch: target, sha: "")
        )
    }

    /// 只用于排列的提交；哈希由标题重复而成。
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
}
