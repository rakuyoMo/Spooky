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
    /// 搜索框输入停顿这么久之后才重新读取。
    private static let searchDelay = Duration.milliseconds(300)

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

    /// 时间线读取失败的可复制诊断。
    private(set) var failure: AppFailure? = nil

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
    private(set) var diff: CommitDiff? = nil

    /// 所选版本的文件原文。
    private(set) var content: FileRevisionContent? = nil

    /// 详情是否正在读取。
    private(set) var isLoadingDetail = false

    /// 详情读取失败的可复制诊断，不覆盖时间线。
    private(set) var detailFailure: AppFailure? = nil

    /// 停顿后生效的搜索框内容。
    private var searchText = ""

    /// 当前仓库的执行器。
    private var runner: GitRunner? = nil

    /// 时间线固定的起点；HEAD 移动后才重读。
    private var head: String? = nil

    /// 打开文件后是否已按 HEAD 确定了树中存储的路径形式。
    private var resolvedPath = false

    /// 关闭、重读或换文件时变更代数，阻止旧结果回写。
    private var generation = 0

    /// 第一页与计数的读取任务。
    private var pageTask: Task<Void, Never>? = nil

    /// 详情的读取任务。
    private var detailTask: Task<Void, Never>? = nil

    /// 搜索框输入的延迟任务。
    private var searchTask: Task<Void, Never>? = nil

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

    /// 搜索框内容变化，停顿片刻后按新条件重读。
    func search(_ text: String) {
        searchTask?.cancel()

        guard text != searchText else {
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.searchDelay)
            } catch {
                return
            }

            self?.searchText = text
            self?.reload()
        }
    }

    /// 刷新后的 HEAD 与时间线的起点不同时重读，轮询不打断翻页或选择。
    func update(head: String?) {
        guard path != nil, head != self.head else {
            return
        }

        self.head = head
        reload()
    }

    /// 按当前条件读取第一页与总数，仍在结果中的提交保持选中。
    func reload() {
        cancelTasks()
        failure = nil
        commits = []
        totalCount = nil
        hasMore = false
        isLoading = false

        guard let path, let runner else {
            return
        }

        // 仓库还没有提交时没有历史
        guard let head else {
            totalCount = 0
            selectedID = nil
            return
        }

        let request = generation
        let filter = filter
        let resolve = !resolvedPath
        isLoading = true

        pageTask = Task { [weak self] in
            do {
                let views = RepositoryFileViews(runner: runner)
                let entry = resolve ? try await views.storedEntry(for: path, in: head) : nil
                let path = entry?.path ?? path
                let root = try await Self.root(for: filter, head: head, runner: runner)
                let result = try await Self.firstPage(of: path, from: root, filter: filter, views: views)

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                apply(result, path: path, submodule: entry?.isSubmodule)
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
        isLoading = true

        pageTask = Task { [weak self] in
            do {
                let page = try await RepositoryFileViews(runner: runner)
                    .page(of: path, from: head, filter: filter, offset: offset, limit: Self.pageSize)

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

    /// 读取所选提交的补丁或原文；放行大 Diff 只作用于这一次读取。
    func loadDetail(showLarge: Bool = false) {
        detailTask?.cancel()
        diff = nil
        content = nil
        detailFailure = nil
        isLoadingDetail = false

        guard let commit = selectedCommit, let path, let runner else {
            return
        }

        let request = generation
        let mode = detailMode
        let threshold = UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
            ?? WorkingCopyOperations.defaultWarningKilobytes

        // 与工作区和提交详情使用同样的上下文行数与忽略空白偏好
        let options = DiffPreferences.options()
        isLoadingDetail = true

        detailTask = Task { [weak self] in
            do {
                let views = RepositoryFileViews(runner: runner)

                // 原文与补丁分别读取，切换显示方式时才读另一种
                let diff = mode == .diff
                    ? try await views.diff(
                        of: path,
                        in: commit.id,
                        options: options,
                        warningKilobytes: threshold,
                        showLarge: showLarge
                    )
                    : nil
                let content = mode == .raw
                    ? try await FileRevisionContent.load(path, at: commit.id, views: views)
                    : nil

                guard let self, generation == request, selectedID == commit.id, !Task.isCancelled else {
                    return
                }

                self.diff = diff
                self.content = content
            } catch {
                guard let self, generation == request, selectedID == commit.id, !Task.isCancelled else {
                    return
                }

                detailFailure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, selectedID == commit.id, !Task.isCancelled else {
                return
            }

            isLoadingDetail = false
        }
    }

    /// 关闭文件历史，清除全部结果与条件。
    func close() {
        cancelTasks()
        searchTask?.cancel()
        searchTask = nil
        detailTask?.cancel()
        detailTask = nil
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
    private static func firstPage(
        of path: String,
        from root: String?,
        filter: FileHistoryFilter,
        views: RepositoryFileViews
    ) async throws -> FirstPage {
        guard let root else {
            return FirstPage(commits: [], hasMore: false, count: 0)
        }

        if filter.scope == .revision, !filter.trimmedText.isEmpty {
            let page = try await views.page(of: path, from: root, filter: filter, limit: 1)
            return FirstPage(commits: page.commits, hasMore: false, count: page.commits.count)
        }

        // 第一页与计数互不依赖，服务器上只占一次往返的等待时间
        async let page = views.page(of: path, from: root, filter: filter, limit: pageSize)
        async let count = views.count(of: path, from: root, filter: filter)

        let (first, total) = try await (page, count)

        return FirstPage(commits: first.commits, hasMore: first.hasMore, count: total)
    }

    /// 写入第一页的结果；仍在结果中的提交保持选中，否则清除选择。
    private func apply(_ result: FirstPage, path: String, submodule: Bool?) {
        self.path = path
        resolvedPath = true

        if let submodule {
            isSubmodule = submodule
        }

        commits = result.commits
        hasMore = result.hasMore
        totalCount = result.count

        if let selectedID, !commits.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        } else {
            loadDetail()
        }
    }

    /// 取消时间线的读取，并让进行中的旧请求失效。
    private func cancelTasks() {
        generation += 1
        pageTask?.cancel()
        pageTask = nil
    }
}
