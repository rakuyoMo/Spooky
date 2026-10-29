import Foundation
import Observation
import SpookyKit

// MARK: - BranchesReviewFilter

/// 分支整理列表的筛选项，原始值存进偏好。
enum BranchesReviewFilter: Int, CaseIterable {
    /// 不筛选。
    case all = 0

    /// 陈旧的分支。
    case stale = 1

    /// 不陈旧的分支。
    case active = 2

    /// 上游已不存在的分支。
    case trackingError = 3

    /// 能干净并入基准的分支。
    case mergeable = 5

    /// 并入基准会冲突的分支。
    case mergeConflicts = 6

    /// 有打开着的 Pull Request 或 Merge Request 的分支。
    case withPullRequest = 7

    /// 没有打开着的 Pull Request 或 Merge Request 的分支。
    case withoutPullRequest = 8

    /// 菜单项的资源键；按服务叫法变化的两项是 `pr.` 与 `mr.` 两组里的键。
    var titleKey: String {
        switch self {
        case .all: "review.filter.none"
        case .stale: "review.filter.stale"
        case .active: "review.filter.active"
        case .trackingError: "review.filter.trackingError"
        case .mergeable: "review.filter.mergeable"
        case .mergeConflicts: "review.filter.conflicts"
        case .withPullRequest: "filter.with"
        case .withoutPullRequest: "filter.without"
        }
    }

    /// 按请求状态筛选的两项：标题随选中远端的服务叫 Pull Request 或 Merge Request。
    var isPullRequestFilter: Bool {
        self == .withPullRequest || self == .withoutPullRequest
    }
}

// MARK: - BranchesReviewSort

/// 分支整理列表的排序属性，原始值存进偏好。
enum BranchesReviewSort: Int, CaseIterable {
    /// 按分支名。
    case name = 0

    /// 按最后更新时间。
    case date = 1
}

// MARK: - BranchesReviewOrder

/// 列表的筛选项与排序，来自表头的两个菜单。
struct BranchesReviewOrder: Equatable {
    /// 筛选项。
    var filter = BranchesReviewFilter.all

    /// 排序属性。
    var sort = BranchesReviewSort.name

    /// 是否升序。
    var ascending = true
}

// MARK: - BranchesReviewItem

/// 列表的一行：一个本地分支、它与基准的比较和整理状态。
struct BranchesReviewItem: Identifiable, Equatable {
    /// 本地分支。
    let reference: RepositoryReference

    /// 与基准的比较；还在计算时为 nil。
    let comparison: BranchComparison?

    /// 跟踪错误与最后更新时间所在的整理状态。
    let condition: BranchCondition?

    /// 分支在托管服务上最近的请求；没有或不知道时为 nil。
    var pullRequest: PullRequest? = nil

    /// 分支的完整引用名。
    var id: String { reference.id }
}

// MARK: - BranchesReviewState

/// 分支整理视图的状态：基准分支、各分支与基准的比较、筛选排序与详情的比较。
///
/// 基准或分支顶端变化时重新比较；服务器仓库先去抖，新的比较开始时取消上一次。
@MainActor
@Observable
final class BranchesReviewState {
    /// 筛选项的偏好键。
    static let filterKey = "branchesReviewFilter"

    /// 排序属性的偏好键。
    static let sortKey = "branchesReviewSortAttribute"

    /// 升序的偏好键。
    static let ascendingKey = "branchesReviewSortAscending"

    /// 用户没选基准时默认取的分支名，按优先顺序排列。
    private static let defaultBaseNames = ["next", "develop", "dev", "main", "master"]

    /// 用户选的基准分支；为 nil 时按默认规则选。
    var selectedBase: String? = nil

    /// 列表的多选。
    var selectedIDs = Set<String>() {
        didSet {
            if selectedIDs != oldValue { openDetail() }
        }
    }

    /// 以分支的完整引用名为键的比较结果。
    private(set) var comparisons: [String: BranchComparison] = [:]

    /// 比较进行中。
    private(set) var isComparing = false

    /// 比较失败的原因；成功后清空。
    private(set) var failure: AppFailure? = nil

    /// 单选时详情里的提交与改动。
    let comparison = RevisionComparisonState()

    /// 最近一次归档的分支；侧边栏据此说明归档了几个分支并提供撤销，关闭说明后清空。
    var archivedBranches: [String]? = nil

    /// 打开批量归档对话框：参数是否为自动归档的确认，以及建议归档的分支；由窗口呈现 sheet。
    var onArchiveRequest: ((Bool, [RepositoryReference]) -> Void)? = nil

    /// 最近一次比较用的引用快照。
    private var snapshot: ReferenceSnapshot? = nil

    /// 最近一次比较用的执行器。
    private var runner: GitRunner? = nil

    /// 已完成比较的基准顶端与各分支顶端，相同时不重算。
    private var compared: (base: String, tips: [String: String])? = nil

    /// 正在进行的比较。
    private var compareTask: Task<Void, Never>? = nil

    /// 详情的分叉点读取。
    private var detailTask: Task<Void, Never>? = nil

    /// 过期结果不能写回。
    private var generation = 0

    /// 实际使用的基准分支：用户选的仍然存在时用它，否则依次取默认基准名单里第一个存在的分支、当前分支与第一个本地分支。
    var base: RepositoryReference? {
        let locals = snapshot?.references.filter(\.isLocal) ?? []

        if let selectedBase, let chosen = locals.first(where: { $0.id == selectedBase }) {
            return chosen
        }

        let preferred = Self.defaultBaseNames.map { "refs/heads/" + $0 }

        return preferred.lazy.compactMap { name in locals.first { $0.id == name } }.first
            ?? locals.first { $0.name == head }
            ?? locals.first
    }

    /// 当前分支名，用来选默认的基准。
    private var head: String? = nil

    /// 详情显示比较。
    init() {
        comparison.showsChangeset = true
    }

    /// 一行是否满足筛选项；还在比较或无法检查的分支不算已合并、能合并或有冲突，不知道请求状态时两项请求筛选都不满足。
    static func matches(
        _ item: BranchesReviewItem,
        filter: BranchesReviewFilter,
        staleMonths: Int,
        now: Date,
        knowsPullRequests: Bool = false
    ) -> Bool {
        let stale = item.condition?.isStale(months: staleMonths, now: now) ?? false

        switch filter {
        case .all:
            return true

        case .stale:
            return stale

        case .active:
            return !stale

        case .trackingError:
            return item.condition?.hasTrackingError ?? false

        case .mergeable:
            return item.comparison?.merge == .clean

        case .mergeConflicts:
            guard case .conflicts = item.comparison?.merge else { return false }
            return true

        case .withPullRequest:
            return knowsPullRequests && item.pullRequest?.state == .open

        case .withoutPullRequest:
            return knowsPullRequests && item.pullRequest?.state != .open
        }
    }

    /// 引用快照或基准变化后重新比较；结果不变时不重算。
    ///
    /// - Parameters:
    ///   - snapshot: 最新的引用快照。
    ///   - head: 当前分支名。
    ///   - runner: 仓库的执行器。
    func update(snapshot: ReferenceSnapshot?, head: String?, runner: GitRunner?) {
        self.snapshot = snapshot
        self.head = head
        self.runner = runner

        guard let runner, let base, base.objectType == "commit" else {
            cancel()
            comparisons = [:]
            compared = nil
            return
        }

        let tips = Dictionary(
            snapshot?.references
                .filter { $0.isLocal && $0.id != base.id && $0.objectType == "commit" }
                .map { ($0.id, $0.objectID) } ?? []
        ) { first, _ in first }

        if let compared, compared.base == base.objectID, compared.tips == tips {
            return
        }

        compare(tips, base: base.objectID, runner: runner)
    }

    /// 选择基准分支后立即重新比较。
    func selectBase(_ id: String) {
        selectedBase = id
        compared = nil
        comparisons = [:]
        update(snapshot: snapshot, head: head, runner: runner)
        openDetail()
    }

    /// 写入前或关闭仓库时取消比较。
    func cancel() {
        generation += 1
        compareTask?.cancel()
        compareTask = nil
        isComparing = false
    }

    /// 关闭仓库时清空全部状态。
    func close() {
        cancel()
        detailTask?.cancel()
        detailTask = nil
        selectedBase = nil
        selectedIDs = []
        comparisons = [:]
        compared = nil
        failure = nil
        archivedBranches = nil
        snapshot = nil
        runner = nil
        comparison.close()
    }

    /// 按筛选、搜索与排序得到的列表行。
    ///
    /// - Parameters:
    ///   - conditions: 分支的整理状态。
    ///   - search: 工具栏搜索框的文字，按分支名不区分大小写地匹配。
    ///   - order: 筛选项与排序。
    ///   - staleMonths: 陈旧阈值的月数。
    ///   - pullRequests: 源分支名到最近的请求；不知道时为 nil。
    ///   - now: 判断陈旧的时刻。
    func items(
        conditions: [String: BranchCondition],
        search: String,
        order: BranchesReviewOrder,
        staleMonths: Int,
        pullRequests: [String: PullRequest]? = nil,
        now: Date = Date()
    ) -> [BranchesReviewItem] {
        let baseID = base?.id

        let items = (snapshot?.references ?? [])
            .filter { $0.isLocal && $0.id != baseID }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .map { reference in
                BranchesReviewItem(
                    reference: reference,
                    comparison: comparisons[reference.id],
                    condition: conditions[reference.id],
                    pullRequest: pullRequests?[Self.remoteBranchName(of: reference, in: snapshot)]
                )
            }
            .filter {
                Self.matches($0, filter: order.filter, staleMonths: staleMonths, now: now, knowsPullRequests: pullRequests != nil)
            }

        return Self.sorted(items, by: order)
    }

}

// MARK: - Private

extension BranchesReviewState {
    /// 分支在远端上的名字：有上游时取上游去掉远端名的部分，否则用本地分支名。
    static func remoteBranchName(of reference: RepositoryReference, in snapshot: ReferenceSnapshot?) -> String {
        guard let upstream = reference.upstream, upstream.hasPrefix("refs/remotes/") else {
            return reference.name
        }

        let remote = snapshot?.remotes
            .filter { upstream.hasPrefix("refs/remotes/" + $0.name + "/") }
            .max { $0.name.count < $1.name.count }

        return remote.map { String(upstream.dropFirst(("refs/remotes/" + $0.name + "/").count)) } ?? reference.name
    }

    /// 按排序属性与方向排列；同名或同时间时按引用名排列，结果稳定。
    private static func sorted(
        _ items: [BranchesReviewItem],
        by order: BranchesReviewOrder
    ) -> [BranchesReviewItem] {
        let ascending = order.ascending

        return items.sorted { lhs, rhs in
            switch order.sort {
            case .name:
                let order = lhs.reference.name.localizedStandardCompare(rhs.reference.name)

                guard order != .orderedSame else { return lhs.id < rhs.id }

                return (order == .orderedAscending) == ascending

            case .date:
                let left = lhs.reference.date ?? .distantPast
                let right = rhs.reference.date ?? .distantPast

                guard left != right else { return lhs.id < rhs.id }

                return (left < right) == ascending
            }
        }
    }

    /// 去抖后批量比较；结果只在仍是最新一次比较时写回。
    private func compare(_ tips: [String: String], base: String, runner: GitRunner) {
        cancel()
        generation += 1
        let request = generation
        let remote = runner.location.host != nil
        isComparing = true

        compareTask = Task { [weak self] in
            do {
                // 服务器上的每次比较都要往返，连续切换基准时只做最后一次
                if remote {
                    try await Task.sleep(for: .milliseconds(300))
                }

                let result = try await RepositoryReferences(runner: runner).compare(tips, toBase: base)

                guard let self, generation == request, !Task.isCancelled else { return }

                comparisons = result
                compared = (base, tips)
                failure = nil
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }

                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request else { return }

            isComparing = false
            compareTask = nil
        }
    }

    /// 单选时比较基准与所选分支：从分叉点到分支顶端，多选或没有选择时关闭详情。
    private func openDetail() {
        detailTask?.cancel()

        guard
            selectedIDs.count == 1,
            let runner,
            let base,
            let branch = snapshot?.references.first(where: { selectedIDs.contains($0.id) })
        else {
            comparison.close()
            return
        }

        detailTask = Task { [weak self] in
            // 没有共同历史时直接与基准顶端比较
            let fork = try? await RepositoryReferences(runner: runner)
                .forkPoint(of: branch.objectID, base: base.objectID)

            guard let self, !Task.isCancelled else { return }

            comparison.open(
                base: .init(id: fork ?? base.objectID, title: base.name),
                target: .init(id: branch.objectID, title: branch.name),
                runner: runner
            )
        }
    }
}
