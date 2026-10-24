import Foundation
import SpookyKit

// MARK: - BranchArchiving

/// 归档建议与自动归档的规则：哪些分支可以归档、自动归档多久做一次。
enum BranchArchiving {
    /// 记录各仓库上次检查自动归档的时刻，键是仓库的显示路径，值是 Unix 秒。
    static let lastCheckKey = "autoArchiveLastCheck"

    /// 自动归档的间隔：一天一次。
    static let interval: TimeInterval = 24 * 60 * 60

    #warning(
        "TODO: 置顶分支与当前 HEAD 分支不在归档建议里是推断的；核实方式：让一个置顶分支和当前分支都满足完全合并或陈旧，打开批量归档对话框看它们是否出现；影响归档建议、底栏的可归档数量与自动归档"
    )

    /// 建议归档的本地分支：已完全并入基准分支或陈旧，且不是基准分支、当前分支、置顶或已归档的分支。
    ///
    /// - Parameters:
    ///   - snapshot: 引用快照，提供分支与附加信息。
    ///   - conditions: 分支的整理状态。
    ///   - head: 当前分支名；分离或未出生时为 nil。
    ///   - staleMonths: 陈旧阈值的月数。
    ///   - automatic: 自动归档时还要跳过勾了 “自动归档时跳过” 的分支。
    ///   - now: 判断陈旧的时刻。
    /// - Returns: 按引用名排列。
    static func candidates(
        in snapshot: ReferenceSnapshot,
        conditions: [String: BranchCondition],
        head: String?,
        staleMonths: Int,
        automatic: Bool,
        now: Date = Date()
    ) -> [RepositoryReference] {
        snapshot.references
            .filter { reference in
                let metadata = snapshot.metadata(for: reference.id)

                guard
                    reference.isLocal,
                    reference.name != head,
                    !metadata.isArchived,
                    !metadata.isPinned,
                    !(automatic && metadata.skipsAutoArchive),
                    let condition = conditions[reference.id],
                    !condition.isBase
                else {
                    return false
                }

                return condition.isFullyMerged || condition.isStale(months: staleMonths, now: now)
            }
            .sorted { $0.id < $1.id }
    }

    /// 距上次检查已满一天，该再检查一次自动归档。
    static func isDue(for repository: RepositoryLocation, defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        let checks = defaults.dictionary(forKey: lastCheckKey) as? [String: Double] ?? [:]

        guard let last = checks[repository.displayPath] else {
            return true
        }

        return now.timeIntervalSince1970 - last >= interval
    }

    /// 记下这次检查的时刻；无论是否归档、用户是否确认，都等一天后再检查。
    static func recordCheck(for repository: RepositoryLocation, defaults: UserDefaults = .standard, now: Date = Date()) {
        var checks = defaults.dictionary(forKey: lastCheckKey) as? [String: Double] ?? [:]
        checks[repository.displayPath] = now.timeIntervalSince1970
        defaults.set(checks, forKey: lastCheckKey)
    }
}
