import Foundation
import Observation
import SpookyKit

// MARK: - RevisionComparisonState

/// 两个版本比较的读取状态：目标独有的提交分页，以及从基准到目标的改动与按需读取的补丁。
///
/// 与界面解耦，历史详情与分支整理的详情都可以持有一份。
@MainActor
@Observable
final class RevisionComparisonState {
    /// 比较的一侧：完整哈希与用户看到的名字。
    struct Side: Equatable {
        /// 提交的完整哈希。
        let id: String

        /// 引用名或短哈希。
        let title: String
    }

    /// 比较的基准。
    private(set) var base: Side? = nil

    /// 比较的目标。
    private(set) var target: Side? = nil

    /// 显示改动；否则显示提交。
    var showsChangeset = false

    /// 已加载的目标独有提交。
    private(set) var commits: [HistoryCommit] = []

    /// 还有下一页提交。
    private(set) var hasMoreCommits = false

    /// 正在读取提交。
    private(set) var isLoadingCommits = false

    /// 从基准到目标改动的文件。
    private(set) var changes: [CommitFileChange] = []

    /// 正在读取改动。
    private(set) var isLoadingChanges = false

    /// 提交或改动的读取失败。
    private(set) var failure: AppFailure? = nil

    /// 展开的文件。
    var expandedPaths = Set<String>()

    /// 已读取的文件补丁。
    private(set) var diffs: [String: CommitDiff] = [:]

    /// 单个文件的读取失败。
    private(set) var diffFailures: [String: AppFailure] = [:]

    /// 当前仓库的执行器。
    @ObservationIgnored
    private var runner: GitRunner? = nil

    /// 提交、改动与补丁的读取任务，关闭比较时取消。
    @ObservationIgnored
    private var tasks: [Task<Void, Never>] = []

    /// 关闭或换一组版本时递增，丢弃迟到的结果。
    @ObservationIgnored
    private var generation = 0

    /// 补丁选项改变时递增，丢弃按旧选项读取的补丁。
    @ObservationIgnored
    private var diffGeneration = 0

    /// 正在比较两个版本。
    var isActive: Bool { base != nil && target != nil }

    /// 比较两个已解析的提交，读取第一页提交与全部改动。
    func open(base: Side, target: Side, runner: GitRunner) {
        close()
        self.base = base
        self.target = target
        self.runner = runner
        loadCommits()
        loadChanges()
    }

    /// 结束比较并取消全部读取。
    func close() {
        generation += 1

        for task in tasks {
            task.cancel()
        }

        tasks = []
        base = nil
        target = nil
        runner = nil
        commits = []
        hasMoreCommits = false
        isLoadingCommits = false
        changes = []
        isLoadingChanges = false
        failure = nil
        expandedPaths = []
        diffs = [:]
        diffFailures = [:]
    }

    /// 列表滚到底时读取下一页提交。
    func loadCommits() {
        guard !isLoadingCommits, let comparison else {
            return
        }

        let request = generation
        let offset = commits.count
        isLoadingCommits = true

        track { [weak self] in
            do {
                let page = try await comparison.commits(offset: offset)

                guard let self, generation == request else {
                    return
                }

                commits += page.commits
                hasMoreCommits = page.hasMore
            } catch {
                self?.report(error, request: request)
            }

            guard let self, generation == request else {
                return
            }

            isLoadingCommits = false
        }
    }

    /// 展开文件时才读取它的补丁；放行大 Diff 只影响这个文件。
    func loadDiff(_ path: String, showLarge: Bool = false) {
        guard
            showLarge || diffs[path] == nil,
            let comparison,
            let file = changes.first(where: { $0.path == path })
        else { return }

        let request = (generation, diffGeneration)
        let options = DiffPreferences.options()
        let threshold = RepositorySession.diffWarningBytes / 1000
        diffFailures[path] = nil

        track { [weak self] in
            do {
                let diff = try await comparison.diff(
                    of: file,
                    options: options,
                    warningKilobytes: threshold,
                    showLarge: showLarge
                )

                guard let self, (generation, diffGeneration) == request else {
                    return
                }

                diffs[path] = diff
            } catch {
                guard let self, (generation, diffGeneration) == request, !Task.isCancelled else {
                    return
                }

                diffFailures[path] = AppFailure(error: error, opening: false, location: runner?.location)
            }
        }
    }

    /// 上下文行数或忽略空白改变后丢弃已读的补丁，重新读取展开的文件。
    func reloadDiffs() {
        diffGeneration += 1
        diffs = [:]
        diffFailures = [:]

        for path in expandedPaths {
            loadDiff(path)
        }
    }

    /// 全部展开时逐个读取补丁，全部收起不丢弃已读的补丁。
    func expandAll(_ expanded: Bool) {
        expandedPaths = expanded ? Set(changes.map(\.path)) : []

        if expanded {
            for file in changes {
                loadDiff(file.path)
            }
        }
    }

    /// 一个文件的补丁来源，供语法着色与图片对照读取两侧内容。
    func diffSource(path: String) -> CommitFileDiffSource? {
        guard
            let runner, let base, let target,
            let file = changes.first(where: { $0.path == path })
        else { return nil }

        return CommitFileDiffSource(runner: runner, commit: target.id, file: file, base: base.id)
    }
}

// MARK: - Private

extension RevisionComparisonState {
    /// 当前两侧对应的比较服务。
    private var comparison: RevisionComparison? {
        guard let runner, let base, let target else {
            return nil
        }

        return RevisionComparison(runner: runner, base: base.id, target: target.id)
    }

    /// 读取全部改动；文件数不超过自动展开阈值时全部展开。
    private func loadChanges() {
        guard let comparison else {
            return
        }

        let request = generation
        isLoadingChanges = true

        track { [weak self] in
            do {
                let files = try await comparison.changes()

                guard let self, generation == request else {
                    return
                }

                changes = files

                let threshold = UserDefaults.standard.integer(forKey: "historyAutoExpand")

                if threshold > 0, files.count <= threshold {
                    expandAll(true)
                }
            } catch {
                self?.report(error, request: request)
            }

            guard let self, generation == request else {
                return
            }

            isLoadingChanges = false
        }
    }

    /// 登记读取任务，关闭比较时一起取消。
    private func track(_ operation: @escaping @MainActor () async -> Void) {
        tasks.append(Task { await operation() })
    }

    /// 读取失败保留可复制的诊断；被取消或已过期的请求不报告。
    private func report(_ error: Error, request: Int) {
        guard generation == request, !Task.isCancelled else {
            return
        }

        failure = AppFailure(error: error, opening: false, location: runner?.location)
    }
}
