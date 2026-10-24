import Foundation
import Observation
import SpookyKit

// MARK: - RepositoryReflogState

/// Reflog 视图的状态：所看的引用、分页读取的记录、按说明的搜索与选择，以及右栏复用的提交详情。
@MainActor
@Observable
final class RepositoryReflogState {
    /// 所看的引用：`HEAD` 或本地分支的完整引用名。
    private(set) var reference = "HEAD"

    /// 已读到的记录，从新到旧。
    private(set) var entries: [ReflogEntry] = []

    /// 是否还有下一页。
    private(set) var hasMore = false

    /// 正在读取一页。
    private(set) var isLoading = false

    /// 第一页是否已经读到，区分读取中与没有记录。
    private(set) var isLoaded = false

    /// 读取失败的可复制诊断。
    private(set) var failure: AppFailure? = nil

    /// 选中的记录在查询结果中的位置。
    var selectedID: Int? = nil {
        didSet {
            if selectedID != oldValue { showSelection() }
        }
    }

    /// 右栏的提交详情，与历史视图的详情共用同一套视图。
    let detail = RepositoryHistoryState()

    /// 正在生效的搜索文字。
    private(set) var query = ""

    /// 当前仓库的执行器；没有打开仓库时为 nil。
    private var runner: GitRunner? = nil

    /// 当前仓库的位置，换仓库时据此清空。
    private var location: RepositoryLocation? = nil

    /// 读取一页的任务。
    private var pageTask: Task<Void, Never>? = nil

    /// 请求代数，换引用、搜索或重读后迟到的旧结果不会覆盖新结果。
    private var generation = 0

    /// 选中的记录；没有选中或它已不在列表里时为 nil。
    var selectedEntry: ReflogEntry? {
        entries.first { $0.id == selectedID }
    }

    /// 正在运行的读取任务，退出前等待它们结束。
    var activeTasks: [Task<Void, Never>] {
        [pageTask].compactMap { $0 } + detail.activeTasks
    }

    /// 打开仓库的 Reflog：换了仓库时先清空并回到 HEAD，再读第一页。
    func load(runner: GitRunner, location: RepositoryLocation) {
        if self.location != location {
            close()
            self.location = location
        }

        self.runner = runner
        reload()
    }

    /// 换看另一个引用的记录，从第一页重新读取。
    func show(reference: String) {
        guard reference != self.reference else { return }

        self.reference = reference
        selectedID = nil
        reload()
    }

    /// 搜索框的文字变化后按说明重新读取第一页。
    func search(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != query else { return }

        query = text
        reload()
    }

    /// 重读第一页；仍在列表里的选中记录保持选中。
    func reload() {
        guard runner != nil else { return }

        let selected = selectedEntry
        load(offset: 0) { [weak self] page in
            guard let self else { return }

            entries = page.entries
            hasMore = page.hasMore
            isLoaded = true

            // 同一提交可以出现多次，按时间、说明与提交一起找回原来的那条
            let kept = selected.flatMap { old in
                page.entries.first { $0.commit.id == old.commit.id && $0.date == old.date && $0.message == old.message }
            }

            if let kept, kept.id == selectedID {
                showSelection()
            } else {
                selectedID = kept?.id
            }
        }
    }

    /// 滚到列表底部时续读下一页。
    func loadNextPage() {
        guard hasMore, !isLoading else { return }

        load(offset: entries.count) { [weak self] page in
            self?.entries += page.entries
            self?.hasMore = page.hasMore
        }
    }

    /// 关闭仓库时清空记录、选择与详情，回到 HEAD。
    func close() {
        generation += 1
        pageTask?.cancel()
        pageTask = nil
        runner = nil
        location = nil
        entries = []
        hasMore = false
        isLoading = false
        isLoaded = false
        failure = nil
        query = ""
        selectedID = nil
        reference = "HEAD"
        detail.close()
    }
}

// MARK: - Private

extension RepositoryReflogState {
    /// 读取一页；同一时刻只有一个读取任务，后发起的读取取消先前的。
    ///
    /// - Parameters:
    ///   - offset: 跳过的记录数，第一页为 0。
    ///   - apply: 读到后在主线程合并结果。
    private func load(offset: Int, apply: @escaping (ReflogPage) -> Void) {
        guard let runner else { return }

        generation += 1
        pageTask?.cancel()

        let request = generation
        let reference = reference
        let query = query
        #warning(
            "TODO: 每页条数沿用历史的 Number of commits in history 设置未核实，Reflog 可能另有没有设置项的条数。核实方式：在记录很多的仓库里比对 Reflog 首屏读到的条数与滚到底后续读的条数；只影响分页大小。"
        )

        let configured = UserDefaults.standard.integer(forKey: "historyPageSize")
        let limit = [100, 200, 500, 1000].contains(configured) ? configured : 100

        isLoading = true
        failure = nil

        pageTask = Task { [weak self] in
            do {
                let page = try await RepositoryReflog(runner: runner)
                    .page(of: reference, matching: query, offset: offset, limit: limit)
                guard let self, generation == request, !Task.isCancelled else { return }

                apply(page)
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }

                failure = AppFailure(error: error, opening: false, location: location)
                isLoaded = true
            }

            guard let self, generation == request else { return }

            isLoading = false
        }
    }

    /// 右栏显示选中记录的提交。
    private func showSelection() {
        guard let runner else { return }

        detail.show(selectedEntry?.commit, runner: runner)
    }
}
