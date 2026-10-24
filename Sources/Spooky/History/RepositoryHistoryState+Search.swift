import Foundation
import SpookyKit

// MARK: - Search

extension RepositoryHistoryState {
    /// 搜索条件变化到重读之间的等待，输入期间只重读一次。
    static let searchDelay = Duration.milliseconds(300)

    /// 工具栏搜索框对应的条件：第一个文字条件；没有时为 nil。
    var primarySearchIndex: Int? {
        searchConditions.firstIndex { $0.kind != .date }
    }

    /// 工具栏搜索框显示的文字。
    var primarySearchText: String {
        primarySearchIndex.map { searchConditions[$0].text } ?? ""
    }

    /// 工具栏搜索框的范围：第一个文字条件的种类；没有文字条件时为范围菜单所选的种类。
    var primarySearchKind: HistorySearchCondition.Kind {
        primarySearchIndex.map { searchConditions[$0].kind } ?? searchScope
    }

    /// 工具栏搜索框的输入写进第一个文字条件；清空唯一的条件即结束搜索。
    func setSearchText(_ text: String) {
        if let index = primarySearchIndex {
            if text.isEmpty, searchConditions.count == 1 {
                searchConditions = []
            } else {
                searchConditions[index].text = text
            }
        } else if !text.isEmpty {
            searchConditions.insert(HistorySearchCondition(kind: searchScope, text: text), at: 0)
        } else {
            return
        }

        scheduleSearch()
    }

    /// 范围菜单切换种类，第一个文字条件随之改变。
    func setSearchScope(_ kind: HistorySearchCondition.Kind) {
        searchScope = kind

        guard let index = primarySearchIndex, searchConditions[index].kind != kind else {
            return
        }

        searchConditions[index].kind = kind
        scheduleSearch()
    }

    /// 在某个条件之后加一个空的提交信息条件；不指定位置时加在最后。返回新条件的身份，界面据此把焦点交给它。
    @discardableResult
    func addSearchCondition(after id: UUID? = nil) -> UUID {
        let index = id.flatMap { id in searchConditions.firstIndex { $0.id == id } }
        let condition = HistorySearchCondition(kind: .message)

        if let index {
            searchConditions.insert(condition, at: index + 1)
        } else {
            searchConditions.append(condition)
        }

        scheduleSearch()
        return condition.id
    }

    /// 移除一个条件；移除最后一个即结束搜索。
    func removeSearchCondition(_ id: UUID) {
        searchConditions.removeAll { $0.id == id }
        scheduleSearch()
    }

    /// 过滤面板里改动一个条件的种类、文字或日期。
    func updateSearchCondition(_ condition: HistorySearchCondition) {
        guard let index = searchConditions.firstIndex(where: { $0.id == condition.id }) else {
            return
        }

        searchConditions[index] = condition
        scheduleSearch()
    }

    /// 结束搜索并立即重读完整历史；离开历史视图或关闭搜索时使用。
    func clearSearch() {
        guard !searchConditions.isEmpty else {
            return
        }

        searchConditions = []
        searchTask?.cancel()
        searchTask = nil
        reloadCommits()
    }

    /// 视图设置改变后：读出的提交变了就重读，只换了分组方式就重排已加载的行。
    func applyViewSettings() {
        let settings = HistoryViewSettings(defaults: preferences)

        guard settings.query(conditions: searchConditions).hasSameResults(as: query) else {
            reloadCommits()
            return
        }

        if settings.grouping != grouping {
            grouping = settings.grouping
            updateComparisonRows()
        }
    }

    /// 表格某一行对应的提交；标题行与越界时为 nil。
    func commit(atRow row: Int) -> HistoryCommit? {
        rows.indices.contains(row) ? rows[row].commit : nil
    }

    /// 提交在表格中的行号；不在已加载的分页里时为 nil。
    func row(of id: String) -> Int? {
        rows.firstIndex { $0.commit?.id == id }
    }

    /// 回到历史时查找要选中的提交：已加载就滚动到它，还有下一页就按 1000 条续载，否则说明找不到的原因。
    func continueLookup() {
        guard let lookup, !isLoading, snapshot != nil else {
            return
        }

        if commits.contains(where: { $0.id == lookup }) {
            self.lookup = nil
            scrollTarget = lookup
            return
        }

        if hasMore, !reachedLimit {
            loadNextPage(pageSize: 1000)
            return
        }

        self.lookup = nil

        let hash = String(lookup.prefix(8))
        lookupFailure =
            reachedLimit
                ? AppLocalization.text("history.reveal.beyondLimit", hash, Self.maximumLoadedCommits)
                : AppLocalization.text("history.reveal.notFound", hash)
    }
}

// MARK: - Private

extension RepositoryHistoryState {
    /// 等输入停顿后重读；读出的提交与当前列表相同时不重读。
    private func scheduleSearch() {
        searchTask?.cancel()

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)

            guard let self, !Task.isCancelled else { return }

            searchTask = nil

            let settings = HistoryViewSettings(defaults: preferences)

            guard !settings.query(conditions: searchConditions).hasSameResults(as: query) else {
                return
            }

            reloadCommits()
        }
    }
}
