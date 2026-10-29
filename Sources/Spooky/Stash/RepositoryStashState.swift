import Foundation
import Observation
import SpookyKit

// MARK: - RepositoryStashState

/// 一个仓库窗口的储藏列表、选择与只读储藏详情，过期请求不能倒灌。
@MainActor
@Observable
final class RepositoryStashState {
    /// 最近一次读取的储藏，最新的在前。
    private(set) var entries: [StashEntry] = []

    /// 第一次读取完成前不显示空状态。
    private(set) var isLoaded = false

    /// 列表是否正在读取。
    private(set) var isLoading = false

    /// 最近一次读取列表的失败，显示在列表中。
    private(set) var failure: AppFailure? = nil

    /// 列表中选中的储藏哈希；选择变化后重新读取详情。
    var selectedIDs = Set<String>() {
        didSet {
            if selectedIDs != oldValue { loadChanges() }
        }
    }

    /// 所选储藏的变更文件，已跟踪文件在前、未跟踪文件在后。
    private(set) var changes: [StashFileChange] = []

    /// 变更文件是否正在读取。
    private(set) var isLoadingChanges = false

    /// 读取变更文件的失败。
    private(set) var changesFailure: AppFailure? = nil

    /// 已展开的文件路径。
    var expandedPaths = Set<String>()

    /// 已读取的文件补丁，按路径保存。
    private(set) var diffs: [String: CommitDiff] = [:]

    /// 读取补丁的失败，按路径保存。
    private(set) var diffFailures: [String: AppFailure] = [:]

    /// 正在读取补丁的路径，避免重复请求。
    private var loadingPaths = Set<String>()

    /// 当前仓库的执行器。
    private var runner: GitRunner? = nil

    /// 列表读取任务。
    private var listTask: Task<Void, Never>? = nil

    /// 变更文件读取任务。
    private var changeTask: Task<Void, Never>? = nil

    /// 各文件的补丁读取任务。
    private var diffTasks: [String: Task<Void, Never>] = [:]

    /// 请求代数，写入或关闭后递增，旧请求的结果被丢弃。
    private var generation = 0

    /// 列表的读取记进的 Activity 列表，由会话设成它自己的列表。
    @ObservationIgnored
    var activities = RepositoryActivities.shared

    /// 只有一个储藏被选中时的详情对象。
    var selectedStash: StashEntry? {
        guard selectedIDs.count == 1, let id = selectedIDs.first else {
            return nil
        }

        return entries.first { $0.id == id }
    }

    /// 选中的全部储藏，按列表顺序。
    var selectedStashes: [StashEntry] {
        entries.filter { selectedIDs.contains($0.id) }
    }

    /// 正在运行的读取任务，退出前等待它们结束。
    var activeTasks: [Task<Void, Never>] {
        [listTask, changeTask].compactMap { $0 } + Array(diffTasks.values)
    }

    /// 重新读取储藏列表；仍然存在的选择保留，已删除的储藏从选择中移除。
    ///
    /// - Parameter records: 是否记进 Activity；自动刷新引起的重读不记。
    func refresh(runner: GitRunner, records: Bool = true) {
        guard listTask == nil else { return }
        self.runner = runner
        let request = generation
        let activities = activities
        let location = runner.location
        isLoading = true

        listTask = Task { [weak self] in
            do {
                let stashes = try await activities.recordRead(
                    [AppLocalization.text("activity.read.stashes")],
                    in: location,
                    records: records,
                    results: { stashes in
                        let items = ActivityInventory.stashes(stashes)

                        return [activities.changes(of: .stashes, items: items, in: location)]
                    }
                ) {
                    try await RepositoryStashes(runner: runner).list()
                }

                guard let self, generation == request, !Task.isCancelled else { return }

                entries = stashes
                failure = nil
                selectedIDs.formIntersection(stashes.map(\.id))
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request else { return }
            isLoaded = true
            isLoading = false
            listTask = nil
        }
    }

    /// 按说明过滤列表，大小写与变音符号不敏感；搜索为空时返回全部储藏。
    func filtered(by text: String) -> [StashEntry] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return entries
        }

        return entries.filter { $0.title.localizedStandardContains(query) }
    }

    /// 写入前取消读取，避免旧列表或补丁在写入后覆盖新快照。
    func suspend() {
        generation += 1
        listTask?.cancel()
        listTask = nil
        changeTask?.cancel()
        changeTask = nil
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        loadingPaths = []
        isLoading = false
        isLoadingChanges = false
    }

    /// 关闭仓库时清除全部快照和选区。
    func close() {
        suspend()
        runner = nil
        entries = []
        isLoaded = false
        failure = nil
        selectedIDs = []
        changes = []
        changesFailure = nil
        diffs = [:]
        diffFailures = [:]
        expandedPaths = []
    }
}

// MARK: - Stash Details

extension RepositoryStashState {
    /// 单选变化后丢弃上一储藏的补丁，重新读取变更文件。
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
        isLoadingChanges = false

        guard let runner, let stash = selectedStash else { return }
        let request = generation
        isLoadingChanges = true

        changeTask = Task { [weak self] in
            do {
                let files = try await RepositoryStashes(runner: runner).changes(in: stash)
                guard let self, generation == request, selectedStash?.id == stash.id, !Task.isCancelled else { return }
                changes = files
            } catch {
                guard let self, generation == request, selectedStash?.id == stash.id, !Task.isCancelled else { return }
                changesFailure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, selectedStash?.id == stash.id, !Task.isCancelled else { return }
            isLoadingChanges = false
            changeTask = nil
        }
    }

    /// 展开时才读取文件补丁；放行大 Diff 只影响当前储藏的当前文件。
    func loadDiff(_ path: String, showLarge: Bool = false) {
        guard
            !loadingPaths.contains(path), showLarge || diffs[path] == nil,
            let runner, let stash = selectedStash, let change = changes.first(where: { $0.id == path })
        else { return }

        let request = generation
        loadingPaths.insert(path)
        diffFailures[path] = nil
        let threshold =
            UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
                ?? WorkingCopyOperations.defaultWarningKilobytes

        // 与工作区和提交详情使用同样的上下文行数与忽略空白偏好
        let options = DiffPreferences.options()

        // 已跟踪文件比较储藏提交与基准提交，未跟踪文件读取第三个父提交里的新增
        diffTasks[path] = Task { [weak self] in
            do {
                let diff = try await RepositoryHistory(runner: runner)
                    .diff(
                        in: change.commit,
                        file: change.file,
                        options: options,
                        warningKilobytes: threshold,
                        showLarge: showLarge
                    )
                guard let self, generation == request, selectedStash?.id == stash.id, !Task.isCancelled else { return }
                diffs[path] = diff
            } catch {
                guard let self, generation == request, selectedStash?.id == stash.id, !Task.isCancelled else { return }
                diffFailures[path] = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, selectedStash?.id == stash.id, !Task.isCancelled else { return }
            loadingPaths.remove(path)
            diffTasks[path] = nil
        }
    }

    /// 上下文行数或忽略空白改变后丢弃已读的补丁，重新读取展开的文件。
    func reloadDiffs() {
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        loadingPaths = []
        diffs = [:]
        diffFailures = [:]

        for path in expandedPaths {
            loadDiff(path)
        }
    }

    /// 所选储藏里一个文件的只读补丁来源，供语法着色与图片对照读取内容；没有选中储藏或文件不在变更里时为空。
    func diffSource(path: String) -> CommitFileDiffSource? {
        guard let runner, let change = changes.first(where: { $0.id == path }) else {
            return nil
        }

        return CommitFileDiffSource(runner: runner, commit: change.commit, file: change.file)
    }

    /// 全部展开或收起；补丁仍逐文件按需读取。
    func expandAll(_ expanded: Bool) {
        expandedPaths = expanded ? Set(changes.map(\.id)) : []
        if expanded { for change in changes { loadDiff(change.id) } }
    }
}

// MARK: - StashEntry

extension StashEntry {
    /// 列表与菜单显示的说明：用户写下的说明，没有时用 Git 生成的标题。
    var title: String { message ?? subject }
}
