import Foundation

// MARK: - HistorySearchCondition

/// 历史搜索的一个条件：按提交信息、作者、提交人、文件、哈希或日期筛选。
///
/// 同类条件之间是 “或”，不同类条件之间是 “且”；文字条件忽略大小写、按字面匹配，空条件不参与筛选。
public struct HistorySearchCondition: Sendable, Equatable, Identifiable {
    /// 条件的种类。
    public enum Kind: String, Sendable, CaseIterable {
        /// 提交信息的子串。
        case message

        /// 作者的姓名或邮箱的子串。
        case author

        /// 提交人的姓名或邮箱的子串。
        case committer

        /// 仓库内的路径，按字面匹配文件或目录。
        case file

        /// 提交哈希的前缀，至少 4 位十六进制。
        case hash

        /// 提交人日期。
        case date
    }

    /// 日期条件与所选日期的关系，按本地日历的整天比较。
    public enum DateRelation: String, Sendable, CaseIterable {
        /// 所选那一天之后。
        case after

        /// 所选那一天之前。
        case before

        /// 两个日期之间，包含两端的那一天。
        case range
    }

    /// 界面里一行条件的身份，修改内容时保持不变。
    public let id: UUID

    /// 条件的种类。
    public var kind: Kind

    /// 文字条件的内容；日期条件忽略它。
    public var text: String

    /// 日期条件的关系。
    public var relation: DateRelation

    /// 日期条件的日期；区间时是起始日。
    public var date: Date

    /// 区间的结束日。
    public var endDate: Date

    /// 去掉首尾空白后的文字。
    public var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 是否参与筛选：日期条件总是生效，文字条件需要非空内容。
    public var isActive: Bool { kind == .date || !trimmedText.isEmpty }

    /// 创建一个条件；日期默认是今天。
    public init(
        kind: Kind,
        text: String = "",
        relation: DateRelation = .after,
        date: Date = Date(),
        endDate: Date = Date()
    ) {
        id = UUID()
        self.kind = kind
        self.text = text
        self.relation = relation
        self.date = date
        self.endDate = endDate
    }

    /// 日期条件换算成提交人日期的上下限，单位为 Unix 秒，两端都包含在内。
    ///
    /// “之后” 从下一天开始，“之前” 截止到前一天结束，区间从起始日开始、到结束日结束。
    func bounds(in calendar: Calendar) -> (since: Int64?, until: Int64?) {
        #warning("TODO: 日期条件按整天比较，“之后” 与 “之前” 都不含所选那一天；需在参照应用里实测边界是否包含所选日期，影响历史按日期筛选的首尾一天")

        let start = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        switch relation {
        case .after:
            return (Int64(next.timeIntervalSince1970), nil)

        case .before:
            return (nil, Int64(start.timeIntervalSince1970) - 1)

        case .range:
            // 结束日早于起始日时交换两端
            let end = calendar.startOfDay(for: endDate)
            let lower = min(start, end)
            let upper = calendar.date(byAdding: .day, value: 1, to: max(start, end)) ?? max(start, end)

            return (Int64(lower.timeIntervalSince1970), Int64(upper.timeIntervalSince1970) - 1)
        }
    }
}

// MARK: - HistoryQuery

/// 历史列表的查询：搜索条件、排序方式与是否只沿第一父提交。
public struct HistoryQuery: Sendable, Equatable {
    /// 提交的排列方式。
    public enum Order: Sendable, Equatable {
        /// Git 默认的提交人日期倒序，不保证子提交先于父提交。
        case `default`

        /// 子提交总在父提交之前，同一分支上的提交尽量相邻。
        case topological

        /// 子提交总在父提交之前，其余按提交人日期倒序。
        case date
    }

    /// 排列方式。
    public var order: Order

    /// 合并提交只沿第一父提交向前。
    public var firstParentOnly: Bool

    /// 搜索条件，按界面中的顺序。
    public var conditions: [HistorySearchCondition]

    /// 换算日期条件所用的日历。
    public var calendar: Calendar

    /// 是否有生效的搜索条件。
    public var isSearching: Bool { conditions.contains(where: \.isActive) }

    /// log 与 rev-list 共用的筛选参数：第一父、信息、作者、提交人与日期，不含路径。
    var filterArguments: [String] {
        let active = conditions.filter(\.isActive)
        var arguments = firstParentOnly ? ["--first-parent"] : []

        // 文字条件按字面子串匹配并忽略大小写，输入中的正则符号不会被解释
        let patterns = active.compactMap { condition -> String? in
            switch condition.kind {
            case .message: "--grep=" + condition.trimmedText
            case .author: "--author=" + condition.trimmedText
            case .committer: "--committer=" + condition.trimmedText
            case .file, .hash, .date: nil
            }
        }

        if !patterns.isEmpty {
            arguments += ["-i", "-F"] + patterns
        }

        // 多个日期条件取交集：下限取最晚的，上限取最早的
        let bounds = active.filter { $0.kind == .date }.map { $0.bounds(in: calendar) }

        if let since = bounds.compactMap(\.since).max() {
            arguments.append("--since=@\(since)")
        }

        if let until = bounds.compactMap(\.until).min() {
            arguments.append("--until=@\(until)")
        }

        return arguments
    }

    /// 排序参数；两项都要求时 Git 以后出现的 `--date-order` 为准。
    var orderArguments: [String] {
        switch order {
        case .default: []
        case .topological: ["--topo-order"]
        case .date: ["--date-order"]
        }
    }

    /// 文件条件的路径，放在 `--` 之后按字面匹配。
    var paths: [String] {
        conditions.filter { $0.kind == .file && $0.isActive }.map(\.trimmedText)
    }

    /// 哈希条件的前缀，统一为小写；不是十六进制的输入保留原样，查不到任何提交。
    var hashPrefixes: [String] {
        conditions.filter { $0.kind == .hash && $0.isActive }.map { $0.trimmedText.lowercased() }
    }

    /// 创建查询，默认按拓扑序、不筛选。
    public init(
        order: Order = .topological,
        firstParentOnly: Bool = false,
        conditions: [HistorySearchCondition] = [],
        calendar: Calendar = .current
    ) {
        self.order = order
        self.firstParentOnly = firstParentOnly
        self.conditions = conditions
        self.calendar = calendar
    }
}
