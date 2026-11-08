import Foundation
import SpookyKit

// MARK: - BranchArchiving

/// 归档建议与自动归档的规则：哪些分支可以归档、自动归档多久做一次。
enum BranchArchiving {
    /// 记录各仓库上次检查自动归档的时刻，键是仓库的显示路径，值是 Unix 秒。
    static let lastCheckKey = "autoArchiveLastCheck"

    /// 自动归档的间隔：一天一次。
    static let interval: TimeInterval = 24 * 60 * 60

    /// 建议归档的本地分支：请求已在托管服务上合并或陈旧，且不是基准分支、置顶或已归档的分支；当前检出的分支同样可以建议。
    ///
    /// - Parameters:
    ///   - snapshot: 引用快照，提供分支与附加信息。
    ///   - conditions: 分支的整理状态。
    ///   - staleMonths: 陈旧阈值的月数。
    ///   - automatic: 自动归档时还要跳过勾了 “自动归档时跳过” 的分支。
    ///   - mergedOnServer: 请求已在托管服务上合并、此后没有新提交的分支。
    ///   - now: 判断陈旧的时刻。
    /// - Returns: 按引用名排列。
    static func candidates(
        in snapshot: ReferenceSnapshot,
        conditions: [String: BranchCondition],
        staleMonths: Int,
        automatic: Bool,
        mergedOnServer: Set<String> = [],
        now: Date = Date()
    ) -> [RepositoryReference] {
        snapshot.references
            .filter { reference in
                let metadata = snapshot.metadata(for: reference.id)

                guard
                    reference.isLocal,
                    !metadata.isArchived,
                    !metadata.isPinned,
                    !(automatic && metadata.skipsAutoArchive),
                    let condition = conditions[reference.id],
                    !condition.isBase
                else {
                    return false
                }

                return mergedOnServer.contains(reference.id) || condition.isStale(months: staleMonths, now: now)
            }
            .sorted { $0.id < $1.id }
    }

    /// 距上次检查已满一天，该再检查一次自动归档。
    static func isDue(
        for repository: RepositoryLocation,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        let checks = defaults.dictionary(forKey: lastCheckKey) as? [String: Double] ?? [:]

        guard let last = checks[repository.displayPath] else {
            return true
        }

        return now.timeIntervalSince1970 - last >= interval
    }

    /// 记下这次检查的时刻；无论是否归档、用户是否确认，都等一天后再检查。
    static func recordCheck(
        for repository: RepositoryLocation,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        var checks = defaults.dictionary(forKey: lastCheckKey) as? [String: Double] ?? [:]
        checks[repository.displayPath] = now.timeIntervalSince1970
        defaults.set(checks, forKey: lastCheckKey)
    }
}
