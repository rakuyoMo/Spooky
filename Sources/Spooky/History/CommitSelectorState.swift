import Foundation
import Observation
import SpookyKit

// MARK: - CommitSelectorState

/// 整页提交详情版本选择器的读取状态：从 HEAD 起按页列出提交，可按提交说明搜索。
///
/// 过期的读取不能覆盖新的结果；视图只管布局。
@MainActor
@Observable
final class CommitSelectorState {
    /// 第一页与每次续载的条数。
    static let pageSize = 50

    /// 搜索框输入停顿这么久之后才重新读取。
    private static let searchDelay = Duration.milliseconds(300)

    /// 已读到的提交，按历史的默认顺序。
    private(set) var commits: [HistoryCommit] = []

    /// 上一次读到的是满页，滚到最后一行时续载。
    private(set) var hasMore = false

    /// 是否正在读取。
    private(set) var isLoading = false

    /// 读取失败的可复制诊断。
    private(set) var failure: AppFailure? = nil

    /// 高亮的提交；读完第一页后它不在列表里时改为第一行。
    var highlightedID: String? = nil

    /// 当前仓库的执行器。
    @ObservationIgnored
    private var runner: GitRunner? = nil

    /// 列表的起点，即 HEAD 指向的提交；仓库还没有提交时为 nil。
    @ObservationIgnored
    private var head: String? = nil

    /// 停顿后生效的搜索内容。
    @ObservationIgnored
    private var searchText = ""

    /// 重读或关闭时变更代数，阻止旧结果回写。
    @ObservationIgnored
    private var generation = 0

    /// 第一页或续载的读取任务。
    @ObservationIgnored
    private var pageTask: Task<Void, Never>? = nil

    /// 搜索框输入的延迟任务。
    @ObservationIgnored
    private var searchTask: Task<Void, Never>? = nil

    /// 从 HEAD 开始列出仓库的提交，搜索与高亮都重置。
    func open(runner: GitRunner?, head: String?) {
        close()
        self.runner = runner
        self.head = head
        reload()
    }

    /// 搜索框内容变化，停顿片刻后按提交说明重读第一页。
    func search(_ text: String) {
        searchTask?.cancel()

        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard text != searchText else {
            searchTask = nil
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)

            // 停顿期间又有输入时，只按最后一次的内容重读
            guard let self, !Task.isCancelled else {
                return
            }

            searchText = text
            searchTask = nil
            reload()
        }
    }

    /// 按当前搜索内容从第一页重读。
    func reload() {
        cancelTask()
        commits = []
        hasMore = false
        failure = nil
        isLoading = false

        load(offset: 0)
    }

    /// 列表显示到最后一行时续载下一页，读到不满一页为止。
    func loadNextPage() {
        guard !isLoading, hasMore, failure == nil else {
            return
        }

        load(offset: commits.count)
    }

    /// ↑ ↓ 把高亮移到上一行或下一行，到第一行或最后一行时停住。
    func moveHighlight(by offset: Int) {
        guard let index = commits.firstIndex(where: { $0.id == highlightedID }) else {
            return
        }

        let target = min(max(index + offset, 0), commits.count - 1)
        highlightedID = commits[target].id
    }

    /// 弹出框关闭时停止读取并清除全部结果。
    func close() {
        cancelTask()
        searchTask?.cancel()
        searchTask = nil
        runner = nil
        head = nil
        searchText = ""
        commits = []
        hasMore = false
        isLoading = false
        failure = nil
        highlightedID = nil
    }
}

// MARK: - Private

extension CommitSelectorState {
    /// 从 HEAD 起按当前搜索内容读取一页，接在已读到的提交之后。
    private func load(offset: Int) {
        guard let runner, let head else {
            return
        }

        let request = generation

        // 搜索框的内容只作为提交说明的条件，按基本正则匹配、忽略大小写
        let query = HistoryQuery(
            conditions: searchText.isEmpty ? [] : [HistorySearchCondition(kind: .message, text: searchText)]
        )

        isLoading = true

        pageTask = Task { [weak self] in
            do {
                let page = try await RepositoryHistory(runner: runner).page(
                    roots: [head],
                    query: query,
                    offset: offset,
                    limit: Self.pageSize
                )

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                apply(page, offset: offset)
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

    /// 写入读到的一页；第一页读完后，原来高亮的提交仍在列表里就保留，否则高亮第一行。
    private func apply(_ page: HistoryPage, offset: Int) {
        commits += page.commits
        hasMore = page.hasMore

        guard offset == 0 else {
            return
        }

        if !commits.contains(where: { $0.id == highlightedID }) {
            highlightedID = commits.first?.id
        }
    }

    /// 取消进行中的读取，并让它的结果失效。
    private func cancelTask() {
        generation += 1
        pageTask?.cancel()
        pageTask = nil
    }
}
