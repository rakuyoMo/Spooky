import Foundation

// MARK: - BranchCondition

/// 一个本地分支的整理状态：最后更新时间、跟踪错误与是否为基准分支。
///
/// 全部来自引用快照：时间取 for-each-ref 的 `creatordate`，跟踪错误取 `%(upstream)` 与快照里是否还有这个引用。
/// 侧边栏的注记与分支整理视图共用它。
public struct BranchCondition: Sendable, Equatable {
    /// 本地分支的完整引用名。
    public let reference: String

    /// 顶端提交的提交时间；读不到时为 nil。
    public let lastUpdated: Date?

    /// 配置了上游、但上游引用已不存在时（Git 记作 gone）为上游的完整引用名，否则为 nil。
    public let missingUpstream: String?

    /// 分支本身是不是基准分支；基准分支不显示陈旧标记。
    public let isBase: Bool

    /// 是否有跟踪错误。
    public var hasTrackingError: Bool { missingUpstream != nil }

    /// 最后更新早于 `months` 个月前即为陈旧；恰好落在阈值上不算，读不到时间的分支与基准分支也不算。
    ///
    /// - Parameters:
    ///   - months: 陈旧阈值的月数，按日历月计算。
    ///   - now: 判断时刻，测试传入固定时间。
    ///   - calendar: 计算月份所用的日历。
    public func isStale(months: Int, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard
            !isBase,
            months > 0,
            let lastUpdated,
            let threshold = calendar.date(byAdding: .month, value: -months, to: now)
        else {
            return false
        }

        return lastUpdated < threshold
    }
}

// MARK: - RepositoryReferences

extension RepositoryReferences {
    /// 按名称认作基准分支的本地分支名，按优先顺序排列。
    public static let standardBaseBranchNames = ["main", "master", "develop", "dev", "next"]

    /// 快照里的基准分支：存在的标准名本地分支在前，再加上各分支设置的、仍然存在的父分支，按引用名排序。
    public static func baseBranches(in snapshot: ReferenceSnapshot) -> [String] {
        let existing = Set(snapshot.references.map(\.id))
        let standard = standardBaseBranchNames.map { "refs/heads/" + $0 }.filter(existing.contains)
        let parents = Set(snapshot.metadata.values.compactMap(\.parent))
            .filter { existing.contains($0) && !standard.contains($0) }
            .sorted()

        return standard + parents
    }

    /// 由快照得出每个本地分支的整理状态。
    ///
    /// - Parameter bases: 基准分支的完整引用名；省略时取 `baseBranches(in:)`。
    /// - Returns: 以本地分支的完整引用名为键。
    public static func conditions(
        in snapshot: ReferenceSnapshot,
        bases: [String]? = nil
    ) -> [String: BranchCondition] {
        let baseSet = Set(bases ?? baseBranches(in: snapshot))
        let existing = Set(snapshot.references.map(\.id))
        var result: [String: BranchCondition] = [:]

        // 只看本地分支；配置了上游、但上游引用已不在快照里即为跟踪错误
        for reference in snapshot.references where reference.isLocal {
            result[reference.id] = BranchCondition(
                reference: reference.id,
                lastUpdated: reference.date,
                missingUpstream: reference.upstream.flatMap { existing.contains($0) ? nil : $0 },
                isBase: baseSet.contains(reference.id)
            )
        }

        return result
    }
}
