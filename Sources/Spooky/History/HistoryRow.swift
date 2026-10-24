import Foundation
import SpookyKit

// MARK: - HistoryRow

/// 历史列表的一行：日期分组的标题、一个提交，或与基准分支比较时的分叉点与 “没有新提交” 行。
///
/// 按日期分组时表格的行号与提交的位置不再相同，选择、右键与拖放都经行取得对应的提交。
enum HistoryRow: Equatable {
    /// 一组的标题行，参数是这一组的起点。
    case group(Date)

    /// 一个提交。
    case commit(HistoryCommit)

    /// 基准分支的分叉点，插在分叉点提交之前；参数是基准分支名。
    case forkPoint(String)

    /// 所选分支没有自己的提交，排在最前；参数是基准分支名。
    case noNewCommits(String)

    /// 表格比较行是否变化时用的身份。
    var id: String {
        switch self {
        case .group(let start): "group-\(start.timeIntervalSince1970)"
        case .commit(let commit): commit.id
        case .forkPoint: "fork-point"
        case .noNewCommits: "no-new-commits"
        }
    }

    /// 提交行对应的提交；标题行为 nil。
    var commit: HistoryCommit? {
        guard case .commit(let commit) = self else {
            return nil
        }

        return commit
    }

    /// 按提交人日期把提交排成行：每当提交落进新的一组，先插入这一组的标题。
    static func rows(
        for commits: [HistoryCommit],
        grouping: HistoryGrouping,
        calendar: Calendar = .current
    ) -> [Self] {
        guard grouping != .ungrouped else {
            return commits.map(Self.commit)
        }

        var rows: [Self] = []
        var current: Date?

        for commit in commits {
            let start = grouping.start(of: commit.commitDate, in: calendar)

            if let start, start != current {
                rows.append(.group(start))
                current = start
            }

            rows.append(.commit(commit))
        }

        return rows
    }
}
