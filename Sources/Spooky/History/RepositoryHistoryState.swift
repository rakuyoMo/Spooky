import Foundation
import Observation
import SpookyKit

// MARK: - RepositoryHistoryState

/// 一个仓库窗口的引用、历史与只读提交详情，过期请求不能倒灌。
@MainActor
@Observable
final class RepositoryHistoryState {
    /// 窗口副标题的提交数最多数到这里，数到时写 “or more”。
    static let countLimit = 50_000

    /// 回到历史时，要找的提交排在这个数之后就先询问，同意后才续载到它。
    static let slowLookupThreshold = 10_000

    /// 最新成功的引用快照，读取失败时仍保留。
    private(set) var snapshot: ReferenceSnapshot? = nil

    /// 与引用快照一起使用的 HEAD 状态。
    private(set) var branch: BranchStatus? = nil

    /// 分支相对上游的结构化计数。
    private(set) var divergence: [String: ReferenceDivergence] = [:]

    /// 本地分支的最后更新时间、跟踪错误与是否为基准分支，以完整引用名为键；每次读完引用都会写入，随后通知窗口。
    private(set) var conditions: [String: BranchCondition] = [:] {
        didSet { onReferencesLoaded?() }
    }

    /// 侧边栏可同时选择多个分支，空集合表示全部历史。
    var selectedReferences = Set<String>() {
        didSet {
            if selectedReferences != oldValue {
                comparisonBase = nil
                reloadCommits()
            }
        }
    }

    /// 已加载的有界分页结果。
    private(set) var commits: [HistoryCommit] = []

    /// 表格的行：提交与日期分组的标题，随分页与分组方式重排。
    var rows: [HistoryRow] = []

    /// 当前列表使用的日期分组方式。
    var grouping = HistoryGrouping.ungrouped

    /// 当前列表使用的查询；视图设置或搜索条件改变读出的提交时重读。
    var query = HistoryQuery()

    /// 当前查询下的提交数，最多数到计数上限；读到之前为 nil。
    var commitCount: Int? = nil

    /// 搜索条件，按界面中的顺序；工具栏搜索框对应第一个文字条件。
    var searchConditions: [HistorySearchCondition] = []

    /// 工具栏搜索框的范围菜单所选的条件种类。
    var searchScope = HistorySearchCondition.Kind.message

    /// 回到历史时要在列表里选中的提交，找到或放弃后清空。
    var lookup: String? = nil

    /// 列表要滚动到的提交，表格滚动后清空。
    var scrollTarget: String? = nil

    /// 回到的提交在当前历史里找不到的原因。
    var lookupFailure: String? = nil

    /// 这次回到历史不用再询问：提交排在询问的阈值以内，或用户已同意续载；开始新的查找时清掉。
    private var lookupConfirmed = false

    /// 回到提交之前核对它在全部历史里的位置的读取。
    var lookupCheckTask: Task<Void, Never>? = nil

    /// 核对的序号：又要回到别的提交或关闭仓库时加一，之前的询问随之作废。
    var lookupCheckRequest = 0

    /// 刚打开的仓库还没读到引用时要核对的提交与放行后的步骤，读到引用后接着核对。
    var pendingLookupCheck: (id: String, proceed: () -> Void)? = nil

    /// 正在放行的提交，只在执行放行的步骤期间有值；步骤里的 `locate` 见到它就不再核对与询问。
    var releasedLookup: String? = nil

    /// 视图设置所在的偏好域，测试注入临时域。
    var preferences = UserDefaults.standard

    /// 引用、历史分页与提交数的读取记进的 Activity 列表，由会话设成它自己的列表。
    @ObservationIgnored
    var activities = RepositoryActivities.shared

    /// 作者与文件补全的数据，同一 HEAD 只读取一次。
    let suggestions = HistorySearchSuggestions()

    /// 计数任务，查询变化时取消。
    var countTask: Task<Void, Never>? = nil

    /// 搜索条件变化后的延迟重读，输入期间合并为一次。
    var searchTask: Task<Void, Never>? = nil

    /// 每个提交独立的图模型，与分页保持相同次序。
    private(set) var graphRows: [String: CommitGraphRow] = [:]

    /// 当前本地分支独有的已加载提交。
    private(set) var unpushed = Set<String>()

    /// 当前上游独有的已加载提交。
    private(set) var unpulled = Set<String>()

    /// 还有下一页时滚动到底自动读取。
    private(set) var hasMore = false

    /// 列表加载状态。
    private(set) var isLoading = false

    /// 已选提交的完整哈希集合，按列表顺序复制。
    var selectedIDs = Set<String>() {
        didSet {
            if selectedIDs != oldValue { loadChanges() }
        }
    }

    /// 双击进入左文件列表、右补丁的整页提交详情。
    var showsCommitPage = false

    /// 从文件视图回到的提交；不在已加载的分页里时，整页详情仍按它显示。
    private(set) var revealedCommit: HistoryCommit? = nil

    /// 当前提交变更的文件列表。
    private(set) var changes: [CommitFileChange] = []

    /// 变更集读取状态。
    private(set) var isLoadingChanges = false

    /// 变更集失败不能显示成没有变更。
    private(set) var changesFailure: AppFailure? = nil

    /// 展开的文件共享一个滚动区域。
    var expandedPaths = Set<String>()

    /// 单文件已加载的补丁，切换提交时失效。
    private(set) var diffs: [String: CommitDiff] = [:]

    /// 单文件失败独立显示，不覆盖其它文件的补丁。
    private(set) var diffFailures: [String: AppFailure] = [:]

    /// 当前正在读取补丁的文件。
    private(set) var loadingPaths = Set<String>()

    /// 历史读取失败的可复制诊断。
    private(set) var failure: AppFailure? = nil

    /// 窗口错误入口用于引用刷新失败。
    var onFailure: ((Error) -> Void)? = nil

    /// 恢复的引用在新快照中已不存在时通知会话回退视图。
    var onRestoreFailure: (() -> Void)? = nil

    /// 回到的提交排在询问的阈值之后时交给窗口询问；参数是标题兼确认按钮文字、说明与同意后的操作，取消时不回调。
    var onSlowLookup: ((String, String, @escaping () -> Void) -> Void)? = nil

    /// 当前窗口的执行器，测试可以注入隔离环境。
    private(set) var runner: GitRunner? = nil

    /// 引用读取任务，轮询期间合并重复请求。
    private var referenceTask: Task<Void, Never>? = nil

    /// 引用读取进行中时收到的最近一次刷新，读完后补上，读取开始之后的改动不会漏掉。
    private var pendingRefresh: (status: WorkingCopyStatus, runner: GitRunner, reload: Bool, records: Bool)? = nil

    /// 分页与回到历史时核对提交位置的读取，可由用户或视图切换取消。
    private var pageTask: Task<Void, Never>? = nil

    /// 选中提交变化时取消旧变更集。
    private var changeTask: Task<Void, Never>? = nil

    /// 各文件独立取消，不重复加载同一路径。
    private var diffTasks: [String: Task<Void, Never>] = [:]

    /// 关闭或重载时变更代数，阻止旧引用快照回写。
    private var generation = 0

    /// 历史刷新时固定的起点，翻页期间不追逐变化的分支。
    private var roots: [String] = []

    /// 递增图状态沿分页延续。
    private var graph = CommitGraph()

    /// 跟踪关系使用与分页根相同的不可变哈希。
    private var trackingRoots: (local: String, upstream: String)? = nil

    /// 写入取消读取后，即使引用未改变也需要恢复分页和详情。
    private var needsReload = false

    /// 切回仓库时恢复的引用选择，首个引用快照到达后校验一次。
    private var restoredReferences: Set<String>? = nil

    /// 引用快照与分支状态读完后调用，窗口据此检查自动归档。
    var onReferencesLoaded: (() -> Void)? = nil

    /// 打开 Compare Branches 时所选分支与基准分支的比较；没打开或所选不是单个本地分支时为 nil。
    var baseComparison: HistoryBaseComparison? = nil

    /// 所选分支与父分支的比较，供集成父分支改动的按钮使用；没有父分支时为 nil。
    var parentComparison: HistoryBaseComparison? = nil

    /// 用户在 Compare to 里选的基准分支；换了所选分支后清空。
    var comparisonBase: String? = nil

    /// 分叉点及其之下属于基准分支的提交，置灰显示。
    var parentCommits = Set<String>()

    /// 读取分叉点与比较的任务。
    var comparisonTask: Task<Void, Never>? = nil

    /// 单个引用入口与多选状态共用同一选择，HEAD 表示分离或未出生分支。
    var selectedReference: String? {
        get { selectedReferences.count == 1 ? selectedReferences.first : nil }
        set { selectedReferences = newValue.map { [$0] } ?? [] }
    }

    /// 整页详情选中的文件。
    var selectedPath: String? = nil {
        didSet {
            if selectedPath != oldValue, let selectedPath { loadDiff(selectedPath) }
        }
    }

    /// 当前单选提交，多选时详情显示空状态；回到的提交不在已加载的分页里时使用它的记录。
    var selectedCommit: HistoryCommit? {
        guard selectedIDs.count == 1 else { return nil }

        return commits.first { selectedIDs.contains($0.id) }
            ?? revealedCommit.flatMap { selectedIDs.contains($0.id) ? $0 : nil }
    }

    /// 只展示真实分支，远端 HEAD 用于默认分支标记。
    var branches: [RepositoryReference] {
        snapshot?.references.filter { $0.isLocal || ($0.isRemote && $0.symbolicTarget == nil) } ?? []
    }

    /// 全部历史的起点：指向提交的引用与 HEAD 所指的提交，去重后排序。
    var allHistoryRoots: [String] {
        let references = snapshot?.references ?? []

        return Array(
            Set(
                references.filter { $0.objectType == "commit" }.map(\.objectID)
                    + (branch?.oid.map { [$0] } ?? [])
            )
        )
        .sorted()
    }

    /// 历史表头当前引用，没有选择时展示全部引用语义。
    var title: String {
        if selectedReferences.count > 1 {
            return snapshot?.references
                .filter { selectedReferences.contains($0.id) }
                .map(\.name)
                .joined(separator: ", ") ?? ""
        }

        return snapshot?.references.first { $0.id == selectedReference }?.name
            ?? (selectedReference == "HEAD" ? (branch?.head ?? "HEAD") : AppLocalization.text("history.all"))
    }

    /// 正在运行的读取任务，退出前等待它们结束。
    var activeTasks: [Task<Void, Never>] {
        [
            referenceTask,
            pageTask,
            lookupCheckTask,
            changeTask,
            countTask,
            searchTask,
        ]
        .compactMap { $0 } + Array(diffTasks.values)
    }

    /// 刷新引用后只在根变化时重载列表，轮询不打断翻页或选择。
    ///
    /// - Parameters:
    ///   - reload: 完整刷新时即使引用未变也重读第一页，固定根的分页由核心库缓存复用。
    ///   - records: 引用的读取与随之重读的第一页、提交数是否记进 Activity；自动刷新引起的不记。
    func refresh(
        status: WorkingCopyStatus,
        runner: GitRunner,
        reload: Bool = false,
        records: Bool = true
    ) {
        // 读取进行中时只记下最近一次请求，完整刷新与记录的要求随之保留
        guard referenceTask == nil else {
            pendingRefresh = (
                status,
                runner,
                reload || (pendingRefresh?.reload ?? false),
                records || (pendingRefresh?.records ?? false)
            )
            return
        }

        self.runner = runner
        needsReload = needsReload || reload
        let request = generation
        let activities = activities

        referenceTask = Task { [weak self] in
            do {
                let (snapshot, counts) = try await Self.loadReferences(
                    runner: runner,
                    activities: activities,
                    records: records
                )

                guard let self, generation == request, !Task.isCancelled else { return }

                apply(snapshot, divergence: counts, status: status, records: records)
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: false, location: runner.location)
                onFailure?(error)
            }

            guard let self, generation == request else { return }
            referenceTask = nil

            // 读取期间收到的刷新在读完后补上
            if let pending = pendingRefresh {
                pendingRefresh = nil
                refresh(
                    status: pending.status,
                    runner: pending.runner,
                    reload: pending.reload,
                    records: pending.records
                )
            }
        }
    }

    /// 用户取消分页后保留已有结果，可以继续滚动重试。
    func cancelPage() {
        pageTask?.cancel()
        pageTask = nil
        isLoading = false
    }

    /// 切回仓库时恢复分支与提交选择；引用快照到达后再校验引用是否仍存在。
    func restore(references: Set<String>, commits: Set<String>) {
        selectedReferences = references
        selectedIDs = commits
        restoredReferences = references.isEmpty ? nil : references
    }

    /// 写入前取消读取，避免旧引用或补丁在写入后覆盖新快照。
    func suspend() {
        generation += 1
        needsReload = true
        referenceTask?.cancel()
        referenceTask = nil

        // 写入结束后的完整刷新会重读引用，读取期间记下的请求作废
        pendingRefresh = nil

        cancelPage()
        countTask?.cancel()
        countTask = nil
        searchTask?.cancel()
        searchTask = nil
        comparisonTask?.cancel()
        comparisonTask = nil
        changeTask?.cancel()
        changeTask = nil
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        loadingPaths = []
        isLoadingChanges = false
    }

    /// 关闭仓库时清除全部快照和选区。
    func close() {
        suspend()
        cancelLookupCheck()
        runner = nil
        snapshot = nil
        branch = nil
        divergence = [:]
        conditions = [:]
        selectedReference = nil
        commits = []
        rows = []
        commitCount = nil
        searchConditions = []
        lookup = nil
        scrollTarget = nil
        lookupFailure = nil
        graphRows = [:]
        unpushed = []
        unpulled = []
        baseComparison = nil
        parentComparison = nil
        comparisonBase = nil
        parentCommits = []
        selectedIDs = []
        changes = []
        changesFailure = nil
        diffs = [:]
        diffFailures = [:]
        expandedPaths = []
        selectedPath = nil
        showsCommitPage = false
        revealedCommit = nil
        failure = nil
        roots = []
        hasMore = false
        restoredReferences = nil
    }
}

// MARK: - Paging

extension RepositoryHistoryState {
    /// 固定当前引用哈希与视图设置、搜索条件，清空图状态后读取第一页与总数。
    ///
    /// - Parameter records: 第一页与提交数的读取是否记进 Activity；自动刷新引起的重载不记。
    func reloadCommits(records: Bool = true) {
        cancelPage()
        countTask?.cancel()
        countTask = nil
        failure = nil
        lookupFailure = nil
        commitCount = nil

        let settings = HistoryViewSettings(defaults: preferences)
        query = settings.query(conditions: searchConditions)
        grouping = settings.grouping
        loadBaseComparison()

        let references = snapshot?.references ?? []
        trackingRoots = nil

        if selectedReferences.count > 1 {
            roots = references.filter { selectedReferences.contains($0.id) && $0.objectType == "commit" }
                .map(\.objectID)
        } else if let selectedReference, selectedReference != "HEAD" {
            roots = references.filter { $0.id == selectedReference && $0.objectType == "commit" }
                .map(\.objectID)
            if
                let local = references.first(where: { $0.id == selectedReference && $0.isLocal }),
                let upstream = references.first(where: {
                    $0.id == local.upstream && $0.objectType == "commit"
                })
            {
                roots.append(upstream.objectID)
                trackingRoots = (local.objectID, upstream.objectID)
            }
        } else if selectedReference == "HEAD" {
            roots = branch?.oid.map { [$0] } ?? []
        } else {
            roots = allHistoryRoots
        }

        // 搜索结果不连续，图与推拉标记都依赖完整的父链，搜索时不计算
        if query.isSearching {
            trackingRoots = nil
        }

        graph = CommitGraph()
        hasMore = !roots.isEmpty

        if roots.isEmpty {
            commits = []
            rows = []
            graphRows = [:]
            unpushed = []
            unpulled = []
            selectedIDs = []
            commitCount = snapshot == nil ? nil : 0
            continueLookup()
            return
        }

        loadNextPage(replacing: true, records: records)
        loadCount(records: records)
    }

    /// 表格请求最后一行时续载，每页条数取设置，最多 1000 条；Git 返回的一页不满或到了根提交才停。
    ///
    /// - Parameters:
    ///   - pageSize: 回到历史查找提交时按 1000 条扩大加载；nil 时用设置中的条数。
    ///   - records: 是否记进 Activity；自动刷新引起的重载不记。
    func loadNextPage(replacing: Bool = false, pageSize: Int? = nil, records: Bool = true) {
        guard !isLoading, hasMore, let runner else { return }
        let request = generation
        let roots = roots
        let query = query
        let offset = replacing ? 0 : commits.count
        let configured = UserDefaults.standard.integer(forKey: "historyPageSize")
        let limit = pageSize ?? ([100, 200, 500, 1000].contains(configured) ? configured : 100)
        let activities = activities
        isLoading = true
        pageTask = Task { [weak self] in
            do {
                let page = try await activities.recordRead(
                    [AppLocalization.text("activity.read.commits")],
                    in: runner.location,
                    records: records,
                    results: { [AppLocalization.text("activity.result.commits", $0.commits.count)] }
                ) {
                    try await RepositoryHistory(runner: runner)
                        .page(roots: roots, query: query, offset: offset, limit: limit)
                }

                guard let self, generation == request, !Task.isCancelled else { return }

                append(page, replacing: replacing)
                failure = nil
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: false, location: runner.location)
                lookup = nil
            }

            guard let self, generation == request, !Task.isCancelled else { return }
            isLoading = false
            pageTask = nil

            // 回到历史时要选中的提交还没出现在已加载的分页里，继续扩大加载
            continueLookup()
        }
    }

    /// 回到历史时查找要选中的提交：已加载就滚动到它；还有下一页就按 1000 条续载，排在询问的阈值之后先询问；没有下一页时说明找不到。
    func continueLookup() {
        guard let lookup, !isLoading, snapshot != nil else {
            return
        }

        if commits.contains(where: { $0.id == lookup }) {
            self.lookup = nil
            scrollTarget = lookup

            // 选中它时它还不在列表里，当时读不到变更集，找到后补读
            if
                selectedIDs == [lookup],
                changes.isEmpty,
                !isLoadingChanges,
                changesFailure == nil
            {
                loadChanges()
            }

            return
        }

        guard hasMore else {
            reportMissingLookup(lookup)
            return
        }

        // 位置已经核对过或用户已同意，一直续载到找到为止
        if lookupConfirmed {
            loadNextPage(pageSize: 1000)
            return
        }

        checkLookupPosition(lookup)
    }
}

// MARK: - Commit Details

extension RepositoryHistoryState {
    /// 单选变化后丢弃上一提交的补丁，元信息直接复用列表记录。
    func loadChanges() {
        changeTask?.cancel()
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        changes = []
        changesFailure = nil
        diffs = [:]
        diffFailures = [:]
        loadingPaths = []
        expandedPaths = []
        selectedPath = nil
        isLoadingChanges = false
        guard let runner, let commit = selectedCommit else { return }
        let request = generation
        let mergeMode = MergeDiffMode.preferred
        isLoadingChanges = true
        changeTask = Task { [weak self] in
            do {
                let files = try await RepositoryHistory(runner: runner).changes(in: commit.id, mergeMode: mergeMode)
                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                changes = files
                let threshold = UserDefaults.standard.integer(forKey: "historyAutoExpand")
                if threshold > 0, files.count <= threshold { expandAll(true) }
            } catch {
                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                changesFailure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard
                let self, generation == request, selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }
            isLoadingChanges = false
        }
    }

    /// 展开时才取文件补丁，放行大 Diff 只影响当前提交的当前文件。
    func loadDiff(_ path: String, showLarge: Bool = false) {
        guard
            !loadingPaths.contains(path), showLarge || diffs[path] == nil,
            let runner, let commit = selectedCommit, let file = changes.first(where: { $0.path == path })
        else { return }
        let request = generation
        loadingPaths.insert(path)
        diffFailures[path] = nil
        let threshold =
            UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
                ?? WorkingCopyOperations.defaultWarningKilobytes

        // 变更集沿用工作区的上下文与忽略空白偏好
        let options = DiffPreferences.options()
        let mergeMode = MergeDiffMode.preferred

        diffTasks[path] = Task { [weak self] in
            do {
                let diff = try await RepositoryHistory(runner: runner)
                    .diff(
                        in: commit.id,
                        file: file,
                        mergeMode: mergeMode,
                        options: options,
                        warningKilobytes: threshold,
                        showLarge: showLarge
                    )
                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                diffs[path] = diff
            } catch {
                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                diffFailures[path] = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard
                let self, generation == request, selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }
            loadingPaths.remove(path)
            diffTasks[path] = nil
        }
    }

    /// 上下文行数或忽略空白改变后丢弃已读的补丁，重新读取正在显示的文件。
    func reloadDiffs() {
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        loadingPaths = []
        diffs = [:]
        diffFailures = [:]

        for path in expandedPaths.union(selectedPath.map { [$0] } ?? []) {
            loadDiff(path)
        }
    }

    /// 全部展开 / 收起与快捷键共用状态，补丁仍逐文件按需读取。
    func expandAll(_ expanded: Bool) {
        expandedPaths = expanded ? Set(changes.map(\.path)) : []
        if expanded { for file in changes { loadDiff(file.path) } }
    }

    /// 只显示一个给定的提交，不读引用也不分页；Reflog 的右栏用它复用提交详情。
    ///
    /// - Parameters:
    ///   - commit: 要显示的提交；为 nil 时详情回到未选中。
    ///   - runner: 读取变更集与补丁的执行器。
    func show(_ commit: HistoryCommit?, runner: GitRunner) {
        self.runner = runner
        revealedCommit = commit
        selectedIDs = commit.map { [$0.id] } ?? []
    }

    /// 从文件视图回到某个提交：打开它的整页详情，提交不在已加载的分页里也能显示。
    ///
    /// 列表回到全部历史并选中这个提交；它不在已加载的分页里时扩大加载去找，返回列表后滚动到它。
    func reveal(_ commit: HistoryCommit) {
        revealedCommit = commit
        showsCommitPage = true
        locate(commit.id)
    }

    /// 在历史中定位一个提交：列表回到全部历史并选中它；不在已加载的分页里时扩大加载去找，找到后滚动到它。
    func locate(_ id: String) {
        lookup = id
        lookupFailure = nil

        // 放行前已经核对过位置的提交不再核对与询问
        lookupConfirmed = releasedLookup == id

        // 在全部历史里找这个提交，搜索条件不再适用
        let searching = !searchConditions.isEmpty
        searchConditions = []
        searchTask?.cancel()
        searchTask = nil

        if !selectedReferences.isEmpty {
            selectedReferences = []
        } else if searching {
            reloadCommits()
        }

        // 选择没有变化时不会触发重读，这里显式读取变更集
        if selectedIDs == [id] {
            loadChanges()
        } else {
            selectedIDs = [id]
        }

        continueLookup()
    }
}

// MARK: - Private

extension RepositoryHistoryState {
    /// 读取引用快照与各本地分支的领先落后数；记录时按分支、远端、标签各记一条，分支与远端写出与上一次记录相比的增减。
    ///
    /// - Parameters:
    ///   - activities: 读取记进的 Activity 列表。
    ///   - records: 是否记进 Activity。
    /// - Returns: 引用快照与以完整引用名为键的领先落后数。
    private static func loadReferences(
        runner: GitRunner,
        activities: RepositoryActivities,
        records: Bool
    ) async throws -> (ReferenceSnapshot, [String: ReferenceDivergence]) {
        let location = runner.location
        let service = RepositoryReferences(runner: runner)

        return try await activities.recordRead(
            [
                AppLocalization.text("activity.read.branches"),
                AppLocalization.text("activity.read.remotes"),
                AppLocalization.text("activity.read.tags"),
            ],
            in: location,
            records: records,
            results: { snapshot, counts in
                [
                    await activities.changes(
                        of: .branches,
                        items: ActivityInventory.branches(in: snapshot, divergence: counts),
                        in: location
                    ),
                    await activities.changes(
                        of: .remotes,
                        items: ActivityInventory.remotes(in: snapshot),
                        in: location
                    ),
                    nil,
                ]
            }
        ) {
            // 分支的比较值要用到领先落后数，两者算作同一次读取
            let snapshot = try await service.snapshot()

            return (snapshot, try await service.divergences(in: snapshot))
        }
    }

    /// 换上读到的引用快照：引用或 HEAD 变了、或要求重读时重载列表，再接着做等着引用的核对。
    ///
    /// - Parameters:
    ///   - divergence: 各本地分支相对上游的计数。
    ///   - status: 与快照一起使用的工作区状态。
    ///   - records: 重载的第一页与提交数是否记进 Activity。
    private func apply(
        _ snapshot: ReferenceSnapshot,
        divergence: [String: ReferenceDivergence],
        status: WorkingCopyStatus,
        records: Bool
    ) {
        let changed = self.snapshot != snapshot || branch?.oid != status.branch.oid
        self.snapshot = snapshot
        branch = status.branch
        self.divergence = divergence

        // 整理状态由快照直接得出，已删除的上游仍保留跟踪名称
        conditions = RepositoryReferences.conditions(in: snapshot)

        // 恢复的引用已被删除时回到全部历史，并让会话回到 Working Copy。
        checkRestoredReferences(in: snapshot)

        if changed || needsReload {
            needsReload = false
            reloadCommits(records: records)
        }

        // 刚打开仓库时等着引用的核对，读到引用后接着做
        if let pending = pendingLookupCheck {
            pendingLookupCheck = nil
            confirmLookup(pending.id, then: pending.proceed)
        }
    }

    /// 校验切回仓库时恢复的引用选择，只在恢复后的第一个引用快照里校验一次。
    private func checkRestoredReferences(in snapshot: ReferenceSnapshot) {
        guard let restored = restoredReferences else { return }
        restoredReferences = nil
        let known = Set(snapshot.references.map(\.id)).union(["HEAD"])

        if !restored.isSubset(of: known) {
            selectedReferences = []
            onRestoreFailure?()
        }
    }

    /// 核对要找的提交在当前历史里排第几个：在询问的阈值以内就续载；排在之后先询问；不在历史里就说明找不到。
    private func checkLookupPosition(_ id: String) {
        guard let runner else {
            return
        }

        let request = generation
        let roots = roots
        let query = query

        isLoading = true

        pageTask = Task { [weak self] in
            do {
                let position = try await Self.lookupPosition(
                    of: id,
                    roots: roots,
                    query: query,
                    runner: runner
                )

                guard let self, generation == request, !Task.isCancelled else { return }

                isLoading = false
                pageTask = nil
                resolveLookup(
                    id,
                    isWithinThreshold: position.isWithinThreshold,
                    isReachable: position.isReachable
                )
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }

                failure = AppFailure(error: error, opening: false, location: runner.location)
                lookup = nil
                isLoading = false
                pageTask = nil
            }
        }
    }

    /// 按核对的结果继续查找：排在阈值以内就续载；在历史里但排在之后先询问，同意后续载；不在历史里说明找不到。
    private func resolveLookup(_ id: String, isWithinThreshold: Bool, isReachable: Bool) {
        guard isReachable else {
            reportMissingLookup(id)
            return
        }

        if isWithinThreshold {
            lookupConfirmed = true
            continueLookup()
            return
        }

        // 询问期间不再查找；取消时不回调，列表保持原样
        lookup = nil

        let location = runner?.location

        askSlowLookup(id) { [weak self] in
            // 询问期间换了仓库或开始了别的查找时，这次同意不再生效
            guard let self, lookup == nil, runner?.location == location else { return }

            lookup = id
            lookupConfirmed = true
            continueLookup()
        }
    }

    /// 说明要找的提交不在当前历史里，并结束这次查找。
    private func reportMissingLookup(_ id: String) {
        lookup = nil
        lookupFailure = AppLocalization.text("history.reveal.notFound", String(id.prefix(8)))
    }

    /// 读取当前查询下的提交数，供窗口副标题使用；数到计数上限为止。
    ///
    /// - Parameter records: 是否记进 Activity；自动刷新引起的重载不记。
    private func loadCount(records: Bool) {
        countTask?.cancel()
        countTask = nil
        commitCount = nil

        guard let runner, !roots.isEmpty else {
            return
        }

        let request = generation
        let roots = roots
        let query = query
        let activities = activities

        countTask = Task { [weak self] in
            // 计数失败只让副标题不显示数量，不影响列表
            let count = try? await activities.recordRead(
                [AppLocalization.text("activity.read.commitCount")],
                in: runner.location,
                records: records
            ) {
                try await RepositoryHistory(runner: runner)
                    .count(roots: roots, query: query, limit: Self.countLimit)
            }

            guard let self, generation == request, !Task.isCancelled else { return }

            commitCount = count
            countTask = nil
        }
    }

    /// 把一页提交接到列表后面并重排表格行；第一页还要核对原来的选择是否仍在列表里。
    private func append(_ page: HistoryPage, replacing: Bool) {
        if replacing {
            commits = []
            graphRows = [:]
        }

        // 搜索结果不画提交图；只看第一父时不为其余父提交分叉
        if !query.isSearching {
            for commit in page.commits {
                graphRows[commit.id] = graph.append(commit, firstParentOnly: query.firstParentOnly)
            }
        }

        commits += page.commits
        updateTrackingMarkers()
        updateComparisonRows()
        hasMore = page.hasMore

        guard replacing else { return }

        // 回到的提交与正在查找的提交可以不在已加载的分页里，选择仍然保留
        let loaded = Set(commits.map(\.id))
            .union(revealedCommit.map { [$0.id] } ?? [])
            .union(lookup.map { [$0] } ?? [])
        let selected = selectedIDs.intersection(loaded)

        if selected == selectedIDs {
            loadChanges()
        } else {
            selectedIDs = selected
        }
    }

    /// 拓扑序保证孩子先到达，已加载父链即可判定两侧归属，无需逐提交 SSH 查询。
    private func updateTrackingMarkers() {
        unpushed = []
        unpulled = []
        guard let trackingRoots else { return }
        var local = Set([trackingRoots.local])
        var upstream = Set([trackingRoots.upstream])

        for commit in commits {
            let fromLocal = local.contains(commit.id)
            let fromUpstream = upstream.contains(commit.id)
            if fromLocal { local.formUnion(commit.parents) }
            if fromUpstream { upstream.formUnion(commit.parents) }
            if fromLocal, !fromUpstream { unpushed.insert(commit.id) }
            if fromUpstream, !fromLocal { unpulled.insert(commit.id) }
        }
    }
}
