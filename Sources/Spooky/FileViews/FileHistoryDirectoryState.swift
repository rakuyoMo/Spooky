import Foundation
import Observation
import SpookyKit

// MARK: - FileHistoryDirectoryState

/// 一次目录历史详情的逐文件读取状态，每项独立失败、重试与放行大 Diff。
@MainActor
@Observable
final class FileHistoryDirectoryState {
    /// 换提交或关闭时改变，隔离旧视图的可见性回调。
    private(set) var identity = UUID()

    /// 当前提交，目录变更固定与第一父提交比较。
    private(set) var commit: HistoryCommit? = nil

    /// 按 Git 顺序保留的新旧路径和状态。
    private(set) var files: [CommitFileChange] = []

    /// 每个真实文件的补丁。
    private(set) var diffs: [String: CommitDiff] = [:]

    /// 每个真实文件的对象能力。
    private(set) var targets: [String: FileHistoryTarget] = [:]

    /// 失败只替换对应文件的内容。
    private(set) var failures: [String: AppFailure] = [:]

    /// 每文件当前读取的身份，同时用于重建语法着色和图片任务。
    private(set) var requests: [String: UUID] = [:]

    /// 正在读取的文件。
    private(set) var loadingPaths: Set<String> = []

    /// 出现在视口里的文件，偏好变化时重新读取。
    private var visiblePaths: Set<String> = []

    /// 本次详情所属的执行器。
    private var runner: GitRunner? = nil

    /// 延后可见读取是否记入 Activity，与发起目录读取的刷新一致。
    private var records = true

    /// 会话所属的 Activity 存储。
    private var activities = RepositoryActivities.shared

    /// 逐文件任务，替换时必须先取消旧任务。
    private var tasks: [String: Task<Void, Never>] = [:]

    /// 每次读取取当前阈值，测试可提供隔离的偏好来源。
    @ObservationIgnored
    private let warningKilobytes: () -> Int

    /// 创建目录状态，阈值与工作区使用同一偏好。
    init(warningKilobytes: @escaping () -> Int = { RepositorySession.diffWarningBytes / 1000 }) {
        self.warningKilobytes = warningKilobytes
    }

    /// 接收已经核实的目录列表，不在视图里另建长期状态。
    func open(
        commit: HistoryCommit,
        files: [CommitFileChange],
        runner: GitRunner,
        activities: RepositoryActivities,
        records: Bool
    ) {
        close()
        self.commit = commit
        self.files = files
        self.runner = runner
        self.activities = activities
        self.records = records
    }

    /// 旧视图的迟到回调不能改变新提交的可见集合。
    func setVisible(_ path: String, visible: Bool, identity: UUID) {
        guard identity == self.identity else { return }

        if visible {
            visiblePaths.insert(path)
            load(path, records: records)
        } else {
            visiblePaths.remove(path)
        }
    }

    /// 每项使用自己的真实新旧路径，图片与语法着色不会读到相邻文件。
    func source(for file: CommitFileChange) -> CommitFileDiffSource? {
        guard let runner, let commit else { return nil }
        return CommitFileDiffSource(runner: runner, commit: commit.id, file: file)
    }

    /// 偏好变化只重读当前可见补丁，保留变更列表与已知对象能力。
    func reloadDiffs() {
        cancelReads()
        diffs = [:]
        failures = [:]

        for path in visiblePaths { load(path, records: records) }
    }

    /// 显式重试或 Show Diff 仅替换这一文件的读取。
    func load(_ path: String, showLarge: Bool = false, records: Bool = true, retry: Bool = false) {
        guard let runner, let commit, let file = files.first(where: { $0.path == path }) else { return }
        guard retry || showLarge || (diffs[path] == nil && tasks[path] == nil && failures[path] == nil) else { return }

        tasks[path]?.cancel()
        let request = UUID()
        requests[path] = request
        loadingPaths.insert(path)
        failures[path] = nil
        let options = DiffPreferences.options()
        let threshold = warningKilobytes()
        let activities = activities

        tasks[path] = Task { [weak self] in
            do {
                let result = try await RemoteCallbackRequest.$allowsInteraction.withValue(records) {
                    try await Self.read(
                        file, commit: commit, runner: runner,
                        activity: (activities, records), display: (options, threshold, showLarge)
                    )
                }

                guard let self, requests[path] == request, !Task.isCancelled else { return }
                targets[path] = result.0
                diffs[path] = result.1
            } catch {
                guard let self, requests[path] == request, !Task.isCancelled else { return }
                failures[path] = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, requests[path] == request, !Task.isCancelled else { return }
            loadingPaths.remove(path)
            tasks[path] = nil
        }
    }

    /// 换目标、提交或仓库时取消全部任务并丢弃可见登记。
    func close() {
        identity = UUID()
        cancelReads()
        commit = nil
        files = []
        diffs = [:]
        targets = [:]
        failures = [:]
        visiblePaths = []
        runner = nil
    }

    /// 清理请求身份，旧任务即使迟到也无法清除新任务。
    private func cancelReads() {
        for task in tasks.values { task.cancel() }
        tasks = [:]
        requests = [:]
        loadingPaths = []
    }
}

// MARK: - Private

extension FileHistoryDirectoryState {
    /// 类型解析与补丁属于同一文件读取，Activity 保留失败与取消状态。
    private static func read(
        _ file: CommitFileChange,
        commit: HistoryCommit,
        runner: GitRunner,
        activity: (store: RepositoryActivities, records: Bool),
        display: (options: DiffOptions, threshold: Int, showLarge: Bool)
    ) async throws -> (FileHistoryTarget, CommitDiff) {
        try await activity.store.recordRead(
            [AppLocalization.text("activity.read.commitDiffs")], in: runner.location, records: activity.records
        ) {
            let target = try await FileHistoryTarget.load(
                path: file.path, originalPath: file.originalPath, commit: commit, runner: runner
            )
            let diff = try await RepositoryHistory(runner: runner).diff(
                in: commit.id, file: file, options: display.options,
                warningKilobytes: display.threshold, showLarge: display.showLarge
            )
            return (target, diff)
        }
    }
}
