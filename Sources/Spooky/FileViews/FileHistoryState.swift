import Foundation
import Observation
import SpookyKit

// MARK: - FileHistoryDetailMode

/// 文件历史详情显示所选提交里这个文件的补丁，还是该版本的原文。
enum FileHistoryDetailMode: Hashable {
    /// 与第一父提交比较的只读补丁。
    case diff

    /// 该版本的文件原文。
    case raw
}

// MARK: - FileHistoryState

/// 一个文件的提交时间线、筛选条件与所选提交的详情，过期请求不能覆盖新的结果。
@MainActor
@Observable
final class FileHistoryState {
    /// 当前查看的文件，使用树中存储的形式；没有打开文件时为 nil。
    private(set) var path: String? = nil

    /// 文件在 HEAD 中是子模块时不显示历史。
    private(set) var isSubmodule = false

    /// 已加载的提交，按 Git 输出的顺序排列。
    private(set) var commits: [HistoryCommit] = []

    /// 符合条件的提交总数，读取完成前为 nil。
    private(set) var totalCount: Int? = nil

    /// 还有下一页时滚动到底自动读取。
    private(set) var hasMore = false

    /// 时间线是否正在读取。
    private(set) var isLoading = false

    /// 进行中的读取是 HEAD 移动引起的时间线重读；它在后台进行，不显示读取进度。
    private(set) var isRefreshingCommits = false

    /// 时间线读取失败的可复制诊断。
    var failure: AppFailure? = nil

    /// 搜索框的匹配范围。
    var scope = FileHistoryFilter.Scope.author {
        didSet {
            if scope != oldValue { reload() }
        }
    }

    /// 时间线中选中的提交。
    var selectedID: String? = nil {
        didSet {
            if selectedID != oldValue { loadDetail() }
        }
    }

    /// 详情显示补丁还是原文。
    var detailMode = FileHistoryDetailMode.diff {
        didSet {
            if detailMode != oldValue { loadDetail() }
        }
    }

    /// 所选提交中这个文件的补丁。
    var diff: CommitDiff? = nil

    /// 所选版本的文件原文。
    var content: FileRevisionContent? = nil

    /// 详情是否正在读取。
    var isLoadingDetail = false

    /// 详情读取失败的可复制诊断，不覆盖时间线。
    var detailFailure: AppFailure? = nil

    /// 停顿后生效的搜索框内容。
    var searchText = ""

    /// 当前仓库的执行器。
    private(set) var runner: GitRunner? = nil

    /// 时间线固定的起点；HEAD 移动后才重读。
    private(set) var head: String? = nil

    /// 打开文件后是否已按 HEAD 确定了树中存储的路径形式。
    private var resolvedPath = false

    /// 关闭、重读或换文件时变更代数，阻止旧结果回写。
    var generation = 0

    /// 第一页与计数的读取任务。
    private var pageTask: Task<Void, Never>? = nil

    /// 详情的读取任务。
    var detailTask: Task<Void, Never>? = nil

    /// 搜索框输入的延迟任务。
    var searchTask: Task<Void, Never>? = nil

    /// 搜索框补全用的整个仓库的作者：按仓库与 HEAD 读取一次，换文件时沿用。
    var authorsLoad: (
        location: RepositoryLocation,
        head: String,
        task: Task<[FileContributor], any Error>
    )? = nil

    /// 时间线与详情的读取记进的 Activity 列表，由会话设成它自己的列表。
    @ObservationIgnored
    var activities = RepositoryActivities.shared

    /// 当前目录详情的逐文件结果，与单文件详情互斥。
    let directory = FileHistoryDirectoryState()

    /// 当前目标路径下按提交哈希缓存的不可变对象能力。
    var targets: [String: FileHistoryTarget] = [:]

    /// 时间线可见行的类型读取任务。
    var targetTasks: [String: Task<Void, Never>] = [:]

    /// 目录比较的准备任务，换目标或关闭时取消。
    var comparisonTask: Task<Void, Never>? = nil

    /// 当前详情请求身份，隔离同一提交的重试。
    var detailRequest = UUID()

    /// 自动刷新衍生的读取不触发交互。
    var recordsReads = true

    /// 当前选中的提交记录。
    var selectedCommit: HistoryCommit? {
        commits.first { $0.id == selectedID }
    }

    /// 读取时使用的条件：搜索框的范围与停顿后生效的内容。
    var filter: FileHistoryFilter {
        FileHistoryFilter(scope: scope, text: searchText)
    }

    /// 所选提交里这个文件的只读补丁来源，供语法着色与图片对照读取内容；没有选中提交时为空。
    var detailSource: CommitFileDiffSource? {
        guard let commit = selectedCommit, let path, let runner else {
            return nil
        }

        return CommitFileDiffSource(runner: runner, commit: commit.id, file: RepositoryFileViews.change(of: path))
    }

    /// 打开一个文件的历史，从当前 HEAD 开始读取；条件与选择都重置。
    func open(_ path: String, head: String?, runner: GitRunner) {
        close()
        self.runner = runner
        self.head = head
        self.path = path
        reload()
    }

    /// 刷新后的 HEAD 与时间线的起点不同时重读，轮询不打断翻页或选择。
    ///
    /// - Parameter records: 重读的时间线与详情是否记进 Activity，与引起它的刷新相同。
    func update(head: String?, records: Bool = true) {
        guard path != nil, head != self.head else {
            return
        }

        self.head = head
        resolvedPath = false
        isSubmodule = false
        reload(records: records, refreshing: true)
    }

    /// 按当前条件读取第一页与总数，仍在结果中的提交保持选中。
    ///
    /// - Parameters:
    ///   - records: 第一页、总数与随后重读的详情是否记进 Activity；自动刷新引起的重读不记。
    ///   - refreshing: HEAD 移动引起的重读：已显示的时间线与详情保留到新的读完，至少读回已加载的条数；读取在后台进行，不显示进度。
    func reload(records: Bool = true, refreshing: Bool = false) {
        // 刷新时只取消时间线的读取，已显示的时间线、详情与各行的对象能力都保留
        if refreshing {
            pageTask?.cancel()
            pageTask = nil
        } else {
            cancelTasks()
            commits = []
            totalCount = nil
            hasMore = false
        }

        recordsReads = records
        failure = nil
        isLoading = false
        isRefreshingCommits = false

        guard let path, let runner else {
            return
        }

        // 仓库还没有提交时没有历史
        guard let head else {
            commits = []
            totalCount = 0
            selectedID = nil
            return
        }

        let request = generation
        let filter = filter
        let resolve = !resolvedPath
        let activities = activities
        let limit = max(Self.pageSize, refreshing ? commits.count : 0)
        isLoading = true
        isRefreshingCommits = refreshing

        pageTask = Task { [weak self] in
            do {
                let views = RepositoryFileViews(runner: runner)
                let (path, entry) = try await FileHistoryTarget.resolvePath(path, head: head, views: views, resolve: resolve)
                let root = try await Self.root(for: filter, head: head, runner: runner)
                let result = try await Self.firstPage(
                    of: path,
                    from: root,
                    filter: filter,
                    limit: limit,
                    views: views,
                    activity: (activities, records)
                )

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                apply(result, path: path, submodule: entry?.isSubmodule, records: records)
            } catch {
                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, !Task.isCancelled else {
                return
            }

            isLoading = false
            isRefreshingCommits = false
        }
    }

    /// 列表请求最后一行时续载下一页；按版本范围筛选时只有一条。
    func loadNextPage() {
        guard
            !isLoading, hasMore,
            let path, let runner, let head,
            scope != .revision || filter.trimmedText.isEmpty
        else { return }

        let request = generation
        let filter = filter
        let offset = commits.count
        let activities = activities
        isLoading = true

        pageTask = Task { [weak self] in
            do {
                let page = try await Self.recordPage(
                    in: runner.location,
                    activities: activities,
                    records: true
                ) {
                    try await RepositoryFileViews(runner: runner).page(
                        of: path,
                        from: head,
                        filter: filter,
                        offset: offset,
                        limit: Self.pageSize
                    )
                }

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                commits += page.commits
                hasMore = page.hasMore
            } catch {
                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, !Task.isCancelled else {
                return
            }

            isLoading = false
        }
    }

    /// 关闭文件历史，清除全部结果与条件。
    func close() {
        cancelTasks()
        searchTask?.cancel()
        searchTask = nil
        detailTask?.cancel()
        detailTask = nil
        targets = [:]
        comparisonTask?.cancel()
        comparisonTask = nil
        path = nil
        runner = nil
        head = nil
        resolvedPath = false
        isSubmodule = false
        commits = []
        totalCount = nil
        hasMore = false
        isLoading = false
        failure = nil
        searchText = ""
        scope = .author
        selectedID = nil
        detailMode = .diff
        diff = nil
        content = nil
        isLoadingDetail = false
        detailFailure = nil
    }
}

// MARK: - Private

extension FileHistoryState {
    /// 第一页与总数一起读取的结果。
    private struct FirstPage {
        /// 第一页的提交。
        let commits: [HistoryCommit]

        /// 是否还有下一页。
        let hasMore: Bool

        /// 符合条件的提交总数。
        let count: Int
    }

    /// 每页条数沿用历史的设置。
    private static var pageSize: Int {
        let configured = UserDefaults.standard.integer(forKey: "historyPageSize")
        return [100, 200, 500, 1000].contains(configured) ? configured : 100
    }

    /// 时间线的起点：按版本范围筛选时是该版本，版本不存在时没有起点，其余情况是 HEAD。
    private static func root(
        for filter: FileHistoryFilter,
        head: String,
        runner: GitRunner
    ) async throws -> String? {
        guard filter.scope == .revision, !filter.trimmedText.isEmpty else {
            return head
        }

        do {
            return try await RepositoryReferences(runner: runner).resolve(filter.trimmedText)
        } catch let error as GitError where !error.isCancelled {
            // 输入的不是一个提交时显示为没有结果，而不是读取失败
            return nil
        }
    }

    /// 读取第一页与总数；按版本范围筛选时只取该版本上最近一次修改这个文件的提交。
    ///
    /// - Parameters:
    ///   - limit: 第一页读的条数，超过一页时接着往下读。
    ///   - activity: 读取记进的 Activity 列表与是否记录；第一页记为 Load Commits，总数记为 Load Commit Count。
    private static func firstPage(
        of path: String,
        from root: String?,
        filter: FileHistoryFilter,
        limit: Int,
        views: RepositoryFileViews,
        activity: (store: RepositoryActivities, records: Bool)
    ) async throws -> FirstPage {
        let (activities, records) = activity

        guard let root else {
            return FirstPage(commits: [], hasMore: false, count: 0)
        }

        // 按版本范围筛选时只读一页，不读总数
        if filter.scope == .revision, !filter.trimmedText.isEmpty {
            let latest = try await recordPage(
                in: views.runner.location,
                activities: activities,
                records: records
            ) {
                try await views.page(of: path, from: root, filter: filter, limit: 1)
            }

            return FirstPage(commits: latest.commits, hasMore: false, count: latest.commits.count)
        }

        // 第一页与计数互不依赖，服务器上只占一次往返的等待时间
        async let page = recordPage(
            in: views.runner.location,
            activities: activities,
            records: records
        ) {
            try await HistoryPage.reading(limit: limit) {
                try await views.page(of: path, from: root, filter: filter, offset: $0, limit: $1)
            }
        }

        async let count = activities.recordRead(
            [AppLocalization.text("activity.read.commitCount")],
            in: views.runner.location,
            records: records
        ) {
            try await views.count(of: path, from: root, filter: filter)
        }

        let (first, total) = try await (page, count)

        return FirstPage(commits: first.commits, hasMore: first.hasMore, count: total)
    }

    /// 把读取修改过这个文件的一页提交记为 Load Commits，一行结果写出读到的提交数。
    ///
    /// - Parameters:
    ///   - location: 读取所属的仓库。
    ///   - activities: 读取记进的 Activity 列表。
    ///   - records: 是否记进 Activity。
    ///   - read: 读取这一页。
    /// - Returns: 读到的一页。
    private static func recordPage(
        in location: RepositoryLocation,
        activities: RepositoryActivities,
        records: Bool,
        _ read: () async throws -> HistoryPage
    ) async throws -> HistoryPage {
        try await activities.recordRead(
            [AppLocalization.text("activity.read.commits")],
            in: location,
            records: records,
            results: { [AppLocalization.text("activity.result.commits", $0.commits.count)] },
            read
        )
    }

    /// 写入第一页的结果：时间线没变时不替换；仍在结果中的提交保持选中，否则清除选择。
    ///
    /// - Parameter records: 重读的详情是否记进 Activity，与第一页相同。
    private func apply(_ result: FirstPage, path: String, submodule: Bool?, records: Bool) {
        let samePath = self.path?.utf8.elementsEqual(path.utf8) ?? false

        // 换了路径时各行的对象能力作废，还在读的一并取消
        if !samePath {
            targets = [:]

            for task in targetTasks.values { task.cancel() }
            targetTasks = [:]
        }

        self.path = path
        resolvedPath = true

        isSubmodule = submodule ?? isSubmodule

        if commits != result.commits {
            commits = result.commits
        }

        hasMore = result.hasMore
        totalCount = result.count

        // 刷新时路径没变，所选提交的详情在后台重读，不先清空
        if let selectedID, !commits.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        } else {
            loadDetail(records: records, refreshing: isRefreshingCommits && samePath)
        }
    }

    /// 取消时间线的读取，并让进行中的旧请求失效。
    private func cancelTasks() {
        generation += 1
        pageTask?.cancel()
        pageTask = nil
        detailTask?.cancel()
        detailTask = nil
        detailRequest = UUID()
        directory.close()
        diff = nil
        content = nil

        for task in targetTasks.values { task.cancel() }
        targetTasks = [:]
    }
}
