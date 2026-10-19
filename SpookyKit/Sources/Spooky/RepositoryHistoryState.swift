import Foundation
import Observation
import SpookyKit

/// 一个仓库窗口的引用、历史与只读提交详情，过期请求不能倒灌。
@MainActor
@Observable
final class RepositoryHistoryState {
    /// 最新成功的引用快照，读取失败时仍保留。
    private(set) var snapshot: ReferenceSnapshot?

    /// 与引用快照一起使用的 HEAD 状态。
    private(set) var branch: BranchStatus?

    /// 分支相对上游的结构化计数。
    private(set) var divergence: [String: ReferenceDivergence] = [:]

    /// 侧边栏可同时选择多个分支，空集合表示全部历史。
    var selectedReferences = Set<String>() {
        didSet {
            if selectedReferences != oldValue { reloadCommits() }
        }
    }

    /// 单个引用入口与多选状态共用同一选择，HEAD 表示分离或未出生分支。
    var selectedReference: String? {
        get { selectedReferences.count == 1 ? selectedReferences.first : nil }
        set { selectedReferences = newValue.map { [$0] } ?? [] }
    }

    /// 已加载的有界分页结果。
    private(set) var commits: [HistoryCommit] = []

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

    /// 当前提交变更的文件列表。
    private(set) var changes: [CommitFileChange] = []

    /// 变更集读取状态。
    private(set) var isLoadingChanges = false

    /// 变更集失败不能显示成没有变更。
    private(set) var changesFailure: AppFailure?

    /// 展开的文件共享一个滚动区域。
    var expandedPaths = Set<String>()

    /// 整页详情选中的文件。
    var selectedPath: String? {
        didSet {
            if selectedPath != oldValue, let selectedPath { loadDiff(selectedPath) }
        }
    }

    /// 单文件已加载的补丁，切换提交时失效。
    private(set) var diffs: [String: CommitDiff] = [:]

    /// 单文件失败独立显示，不覆盖其它文件的补丁。
    private(set) var diffFailures: [String: AppFailure] = [:]

    /// 当前正在读取补丁的文件。
    private(set) var loadingPaths = Set<String>()

    /// 历史读取失败的可复制诊断。
    private(set) var failure: AppFailure?

    /// 窗口错误入口用于引用刷新失败。
    var onFailure: ((Error) -> Void)?

    /// 当前窗口的执行器，测试可以注入隔离环境。
    private var runner: GitRunner?

    /// 引用读取任务，轮询期间合并重复请求。
    private var referenceTask: Task<Void, Never>?

    /// 分页任务可由用户或视图切换取消。
    private var pageTask: Task<Void, Never>?

    /// 选中提交变化时取消旧变更集。
    private var changeTask: Task<Void, Never>?

    /// 各文件独立取消，不重复加载同一路径。
    private var diffTasks: [String: Task<Void, Never>] = [:]

    /// 关闭或重载时变更代数，阻止旧引用快照回写。
    private var generation = 0

    /// 历史刷新时固定的起点，翻页期间不追逐变化的分支。
    private var roots: [String] = []

    /// 递增图状态沿分页延续。
    private var graph = CommitGraph()

    /// 跟踪关系使用与分页根相同的不可变哈希。
    private var trackingRoots: (local: String, upstream: String)?

    /// 写入取消读取后，即使引用未改变也需要恢复分页和详情。
    private var needsReload = false

    /// 当前单选提交，多选时详情显示空状态。
    var selectedCommit: HistoryCommit? {
        guard selectedIDs.count == 1 else { return nil }
        return commits.first { selectedIDs.contains($0.id) }
    }

    /// 只展示真实分支，远端 HEAD 用于默认分支标记。
    var branches: [RepositoryReference] {
        snapshot?.references.filter { $0.isLocal || ($0.isRemote && $0.symbolicTarget == nil) } ?? []
    }

    /// 历史表头当前引用，没有选择时展示全部引用语义。
    var title: String {
        if selectedReferences.count > 1 {
            return snapshot?.references.filter { selectedReferences.contains($0.id) }.map(\.name)
                .joined(separator: ", ") ?? ""
        }
        return snapshot?.references.first { $0.id == selectedReference }?.name
            ?? (selectedReference == "HEAD" ? (branch?.head ?? "HEAD") : AppLocalization.text("history.all"))
    }

    /// 刷新引用后只在根变化时重载列表，轮询不打断翻页或选择。
    func refresh(status: WorkingCopyStatus, runner: GitRunner) {
        guard referenceTask == nil else { return }
        self.runner = runner
        let request = generation
        referenceTask = Task { [weak self] in
            do {
                let service = RepositoryReferences(runner: runner)
                let snapshot = try await service.snapshot()
                var counts: [String: ReferenceDivergence] = [:]

                // 上游计数只查询存在的引用，已删除的上游仍保留跟踪名称。
                for ref in snapshot.references where ref.isLocal {
                    guard let upstream = snapshot.references.first(where: { $0.id == ref.upstream }) else {
                        continue
                    }
                    counts[ref.id] = try await service.divergence(
                        local: ref.objectID,
                        upstream: upstream.objectID
                    )
                }

                guard let self, self.generation == request, !Task.isCancelled else { return }
                let changed = self.snapshot != snapshot || self.branch?.oid != status.branch.oid
                self.snapshot = snapshot
                self.branch = status.branch
                self.divergence = counts
                if changed || self.needsReload {
                    self.needsReload = false
                    self.reloadCommits()
                }
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.failure = AppFailure(error: error, opening: false)
                self.onFailure?(error)
            }

            guard let self, self.generation == request else { return }
            self.referenceTask = nil
        }
    }

    /// 固定当前引用哈希，清空图状态后读取第一页。
    func reloadCommits() {
        cancelPage()
        failure = nil
        let references = snapshot?.references ?? []
        trackingRoots = nil

        if selectedReferences.count > 1 {
            roots = references.filter { selectedReferences.contains($0.id) && $0.objectType == "commit" }
                .map(\.objectID)
        } else if let selectedReference, selectedReference != "HEAD" {
            roots = references.filter { $0.id == selectedReference && $0.objectType == "commit" }
                .map(\.objectID)
            if let local = references.first(where: { $0.id == selectedReference && $0.isLocal }),
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
            roots = Array(
                Set(
                    references.filter { $0.objectType == "commit" }.map(\.objectID)
                        + (branch?.oid.map { [$0] } ?? [])
                )
            )
            .sorted()
        }
        graph = CommitGraph()
        hasMore = !roots.isEmpty

        if roots.isEmpty {
            commits = []
            graphRows = [:]
            unpushed = []
            unpulled = []
            selectedIDs = []
            return
        }
        loadNextPage(replacing: true)
    }

    /// 表格请求最后一行时续载，单次最多使用设置中规定的 1000 条。
    func loadNextPage(replacing: Bool = false) {
        guard !isLoading, hasMore, let runner else { return }
        let request = generation
        let roots = roots
        let offset = replacing ? 0 : commits.count
        let configured = UserDefaults.standard.integer(forKey: "historyPageSize")
        let limit = [100, 200, 500, 1000].contains(configured) ? configured : 100
        isLoading = true
        pageTask = Task { [weak self] in
            do {
                let page = try await RepositoryHistory(runner: runner)
                    .page(roots: roots, offset: offset, limit: limit)
                guard let self, self.generation == request, !Task.isCancelled else { return }

                if replacing {
                    self.commits = []
                    self.graphRows = [:]
                }
                for commit in page.commits { self.graphRows[commit.id] = self.graph.append(commit) }
                self.commits += page.commits
                self.updateTrackingMarkers()
                self.hasMore = page.hasMore
                if replacing {
                    let selected = self.selectedIDs.intersection(Set(self.commits.map(\.id)))
                    if selected == self.selectedIDs {
                        self.loadChanges()
                    } else {
                        self.selectedIDs = selected
                    }
                }
                self.failure = nil
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.failure = AppFailure(error: error, opening: false)
            }

            guard let self, self.generation == request, !Task.isCancelled else { return }
            self.isLoading = false
            self.pageTask = nil
        }
    }

    /// 用户取消分页后保留已有结果，可以继续滚动重试。
    func cancelPage() {
        pageTask?.cancel()
        pageTask = nil
        isLoading = false
    }

    /// 展开时才取文件补丁，放行大 Diff 只影响当前提交的当前文件。
    func loadDiff(_ path: String, showLarge: Bool = false) {
        guard !loadingPaths.contains(path), showLarge || diffs[path] == nil,
            let runner, let commit = selectedCommit, let file = changes.first(where: { $0.path == path })
        else { return }
        let request = generation
        loadingPaths.insert(path)
        diffFailures[path] = nil
        let threshold =
            UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
            ?? WorkingCopyOperations.defaultWarningKilobytes
        diffTasks[path] = Task { [weak self] in
            do {
                let diff = try await RepositoryHistory(runner: runner)
                    .diff(
                        in: commit.id,
                        file: file,
                        warningKilobytes: threshold,
                        showLarge: showLarge
                    )
                guard let self, self.generation == request, self.selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                self.diffs[path] = diff
            } catch {
                guard let self, self.generation == request, self.selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                self.diffFailures[path] = AppFailure(error: error, opening: false)
            }

            guard let self, self.generation == request, self.selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }
            self.loadingPaths.remove(path)
            self.diffTasks[path] = nil
        }
    }

    /// 全部展开 / 收起与快捷键共用状态，补丁仍逐文件按需读取。
    func expandAll(_ expanded: Bool) {
        expandedPaths = expanded ? Set(changes.map(\.path)) : []
        if expanded { for file in changes { loadDiff(file.path) } }
    }

    /// 写入前取消读取，避免旧引用或补丁在写入后覆盖新快照。
    func suspend() {
        generation += 1
        needsReload = true
        referenceTask?.cancel()
        referenceTask = nil
        cancelPage()
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
        runner = nil
        snapshot = nil
        branch = nil
        divergence = [:]
        selectedReference = nil
        commits = []
        graphRows = [:]
        unpushed = []
        unpulled = []
        selectedIDs = []
        changes = []
        changesFailure = nil
        diffs = [:]
        diffFailures = [:]
        expandedPaths = []
        selectedPath = nil
        showsCommitPage = false
        failure = nil
        roots = []
        hasMore = false
    }

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
        isLoadingChanges = true
        changeTask = Task { [weak self] in
            do {
                let files = try await RepositoryHistory(runner: runner).changes(in: commit.id)
                guard let self, self.generation == request, self.selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                self.changes = files
                let threshold = UserDefaults.standard.integer(forKey: "historyAutoExpand")
                if threshold > 0, files.count <= threshold { self.expandAll(true) }
            } catch {
                guard let self, self.generation == request, self.selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }
                self.changesFailure = AppFailure(error: error, opening: false)
            }

            guard let self, self.generation == request, self.selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }
            self.isLoadingChanges = false
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
            if fromLocal && !fromUpstream { unpushed.insert(commit.id) }
            if fromUpstream && !fromLocal { unpulled.insert(commit.id) }
        }
    }
}
