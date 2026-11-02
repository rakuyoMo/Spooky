import Foundation
import SpookyKit

// MARK: - PullRequestConversationItem

/// 讨论列表的一行：头部、描述、评论、提交组与组里的提交，最后是发表评论。
enum PullRequestConversationItem {
    /// 标题、合并方向与指派。
    case header

    /// 请求的描述。
    case description

    /// 一条评论。
    case comment(PullRequestComment)

    /// 同一天加入的提交，可以折叠。
    case group(PullRequestCommitGroup)

    /// 组里的一个提交。
    case commit(HistoryCommit)

    /// 组末的空白；带组所在那天的零点。
    case spacer(Date)

    /// 发表评论的按钮。
    case addComment

    /// 行的身份：选择与折叠按它记在内存里，重新读取后据此恢复。
    enum Key: Hashable {
        /// 头部。
        case header

        /// 描述。
        case description

        /// 评论，带托管服务上的编号。
        case comment(Int)

        /// 提交组，带组所在那天的零点。
        case group(Date)

        /// 提交，带完整哈希。
        case commit(String)

        /// 组末的空白，带组所在那天的零点。
        case spacer(Date)

        /// 发表评论。
        case addComment
    }

    /// 行的身份。
    var key: Key {
        switch self {
        case .header: .header
        case .description: .description
        case .comment(let comment): .comment(comment.id)
        case .group(let group): .group(group.day)
        case .commit(let commit): .commit(commit.id)
        case .spacer(let day): .spacer(day)
        case .addComment: .addComment
        }
    }

    /// 描述、评论、提交组与提交可以选中；头部、组末的空白与发表评论不能。
    var isSelectable: Bool {
        switch self {
        case .description, .comment, .group, .commit: true
        case .header, .spacer, .addComment: false
        }
    }

    /// 描述之后的时间线：评论与提交组按时间从早到晚排列，时间相同的保持评论在前。
    ///
    /// - Parameters:
    ///   - comments: 请求的评论。
    ///   - commits: 比较范围里的提交，按拓扑序从新到旧。
    ///   - calendar: 分天用的日历，默认是本机的。
    static func timeline(
        comments: [PullRequestComment],
        commits: [HistoryCommit],
        calendar: Calendar = .current
    ) -> [Self] {
        let groups = PullRequestCommitGroup.groups(of: commits, calendar: calendar)

        let entries =
            comments.map { (date: $0.createdAt, item: Self.comment($0)) }
                + groups.map { (date: $0.date, item: Self.group($0)) }

        // 时间相同的按原来的先后排，排序结果不随运行变化
        return entries.enumerated()
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element.item)
    }
}

// MARK: - PullRequestCommitGroup

/// 讨论里同一个本机日历日加入的提交。
struct PullRequestCommitGroup {
    /// 提交者时间所在那天的零点，也是组的身份。
    let day: Date

    /// 组的时间：最早的提交者时间往前 2 秒，组排在当天的提交与同一时刻的评论之前。
    let date: Date

    /// 组里的提交，按提交者时间从早到晚。
    let commits: [HistoryCommit]

    /// 按提交者时间所在的日历日分组，组按时间从早到晚。
    ///
    /// - Parameters:
    ///   - commits: 比较范围里的提交，按拓扑序从新到旧。
    ///   - calendar: 分天用的日历。
    static func groups(of commits: [HistoryCommit], calendar: Calendar) -> [Self] {
        let days = Dictionary(grouping: commits.enumerated()) { calendar.startOfDay(for: $0.element.commitDate) }

        return days
            .compactMap { day, entries in
                // 提交者时间相同的按拓扑序，父提交在前
                let sorted = entries
                    .sorted { left, right in
                        left.element.commitDate == right.element.commitDate
                            ? left.offset > right.offset
                            : left.element.commitDate < right.element.commitDate
                    }
                    .map(\.element)

                guard let first = sorted.first else {
                    return nil
                }

                return Self(day: day, date: first.commitDate.addingTimeInterval(-2), commits: sorted)
            }
            .sorted { $0.date < $1.date }
    }

    /// 组的标题：几个提交在哪天加入，日期按 Settings → General 的日期格式。
    func title(format: CommitDateFormat) -> String {
        let date = format.string(from: date)

        guard commits.count != 1 else {
            return AppLocalization.text("pullRequests.commitGroup.one", date)
        }

        return AppLocalization.text("pullRequests.commitGroup", commits.count, date)
    }
}
