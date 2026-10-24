import Foundation

// MARK: - BranchCondition

/// 一个本地分支的整理状态：是否已完全并入基准分支、最后更新时间与跟踪错误。
///
/// 全部来自结构化的 Git 结果：时间取 for-each-ref 的 `creatordate`，跟踪错误取 `%(upstream)` 与快照里是否还有这个引用，
/// 完全合并取 `for-each-ref --merged` 列出的引用名。侧边栏的徽标与分支整理视图共用它。
public struct BranchCondition: Sendable, Equatable {
    /// 本地分支的完整引用名。
    public let reference: String

    /// 顶端提交的提交时间；读不到时为 nil。
    public let lastUpdated: Date?

    /// 配置了上游、但上游引用已不存在时（Git 记作 gone）为上游的完整引用名，否则为 nil。
    public let missingUpstream: String?

    /// 包含这个分支顶端提交的第一个基准分支；分支本身是基准分支，或没有并入任何基准分支时为 nil。
    public let mergedInto: String?

    /// 分支本身是不是判断完全合并的基准分支；基准分支不显示已合并与陈旧标记。
    public let isBase: Bool

    /// 是否已完全并入某个基准分支。
    public var isFullyMerged: Bool { mergedInto != nil }

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
    #warning(
        "TODO: 基准分支名单（main、master、develop、dev、next）与 “没有新提交的分支也算完全合并” 尚未核实；核实方式：分别建这些名字的分支和一个没有新提交的分支，比对 Merged 徽标；影响 Merged 徽标、名称变灰与陈旧注记"
    )
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

    /// 解析 `%(refname)%00` 格式的输出：Git 在每条记录后补一个换行，下一条记录开头的换行要去掉。
    static func parseReferenceNames(_ data: Data) throws -> Set<String> {
        var names = Set<String>()

        for record in data.split(separator: 0) {
            var name = String(decoding: record, as: UTF8.self)

            if name.hasPrefix("\n") {
                name.removeFirst()
            }

            // 最后一条记录之后只剩那个换行
            if name.isEmpty {
                continue
            }

            guard name.hasPrefix("refs/heads/") else {
                throw RepositoryReadError.malformedOutput("for-each-ref")
            }

            names.insert(name)
        }

        return names
    }

    /// 读取快照里每个本地分支的整理状态。
    ///
    /// 每个基准分支一条 `for-each-ref --merged=<哈希> refs/heads`，各基准并发；哈希取自快照，刷新途中分支移动时下一次刷新更正。
    ///
    /// - Parameter bases: 判断完全合并的基准分支的完整引用名，按优先顺序；省略时取 `baseBranches(in:)`，
    ///   分支整理视图传入用户选择的基准分支。快照里不存在或不指向提交的基准被忽略。
    /// - Returns: 以本地分支的完整引用名为键。
    public func conditions(
        in snapshot: ReferenceSnapshot,
        bases: [String]? = nil
    ) async throws -> [String: BranchCondition] {
        let bases = bases ?? Self.baseBranches(in: snapshot)
        let references = Dictionary(snapshot.references.map { ($0.id, $0) }) { first, _ in first }
        let tips = bases.compactMap { base in
            references[base].flatMap { $0.objectType == "commit" ? (base, $0.objectID) : nil }
        }

        // 并发度由仓库队列的主机槽统一限制，服务器上不会超出会话上限。
        let merged = try await withThrowingTaskGroup(of: (String, Set<String>).self) { group in
            for (base, tip) in tips {
                group.addTask {
                    (base, try await mergedBranches(into: tip))
                }
            }

            var result: [String: Set<String>] = [:]

            for try await (base, branches) in group {
                result[base] = branches
            }

            return result
        }

        let baseSet = Set(bases)
        var result: [String: BranchCondition] = [:]

        for reference in snapshot.references where reference.isLocal {
            let isBase = baseSet.contains(reference.id)

            // 基准分支本身不算完全合并；按优先顺序取第一个包含它的基准
            let mergedInto =
                isBase
                    ? nil
                    : tips.first { merged[$0.0, default: []].contains(reference.id) }?.0

            result[reference.id] = BranchCondition(
                reference: reference.id,
                lastUpdated: reference.date,
                missingUpstream: reference.upstream.flatMap { references[$0] == nil ? $0 : nil },
                mergedInto: mergedInto,
                isBase: isBase
            )
        }

        return result
    }

    /// 顶端可从指定提交到达的本地分支。
    private func mergedBranches(into tip: String) async throws -> Set<String> {
        guard GitObjectID.isValid(tip) else {
            throw RepositoryReadError.invalidQuery
        }

        let output = try await runner.run([
            "for-each-ref", "--format=%(refname)%00", "--merged=" + tip, "refs/heads",
        ])

        return try Self.parseReferenceNames(output)
    }
}
