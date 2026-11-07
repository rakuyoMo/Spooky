import Foundation
import SpookyKit

// MARK: - File History Detail

extension FileHistoryState {
    /// 可见时间线行只准备对象能力，不预读每个提交的补丁。
    func prepareTarget(_ commit: HistoryCommit) {
        guard targets[commit.id] == nil, targetTasks[commit.id] == nil, let path, let runner else { return }
        let request = generation
        let records = recordsReads

        targetTasks[commit.id] = Task { [weak self] in
            do {
                let target = try await RemoteCallbackRequest.$allowsInteraction.withValue(records) {
                    try await FileHistoryTarget.load(path: path, commit: commit, runner: runner)
                }
                guard let self, generation == request, !Task.isCancelled else { return }
                targets[commit.id] = target
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                failure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, generation == request, !Task.isCancelled else { return }
            targetTasks[commit.id] = nil
        }
    }

    /// 已知目录范围只重读可见补丁；单文件重读当前模式。
    func reloadDiffs() {
        if directory.commit != nil {
            directory.reloadDiffs()
        } else {
            loadDetail()
        }
    }

    /// 读取所选提交的对象能力，再决定单文件内容或完整目录变更。
    func loadDetail(showLarge: Bool = false, records: Bool = true) {
        detailTask?.cancel()
        detailRequest = UUID()
        directory.close()
        diff = nil
        content = nil
        detailFailure = nil
        isLoadingDetail = false

        guard let commit = selectedCommit, let path, let runner else { return }
        let request = detailRequest
        let mode = detailMode
        let options = DiffPreferences.options()
        let threshold = RepositorySession.diffWarningBytes / 1000
        let activities = activities
        isLoadingDetail = true

        detailTask = Task { [weak self] in
            do {
                let result = try await RemoteCallbackRequest.$allowsInteraction.withValue(records) {
                    try await Self.readDetail(
                        path: path, commit: commit, runner: runner, mode: mode,
                        activity: (activities, records), display: (options, threshold, showLarge)
                    )
                }

                guard let self, detailRequest == request, !Task.isCancelled else { return }
                targets[commit.id] = result.target

                if !result.target.allowsContent, detailMode == .raw {
                    detailMode = .diff
                    return
                }

                diff = result.diff
                content = result.content

                if let files = result.files {
                    directory.open(commit: commit, files: files, runner: runner, activities: activities, records: records)
                }
            } catch {
                guard let self, detailRequest == request, !Task.isCancelled else { return }
                detailFailure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard let self, detailRequest == request, !Task.isCancelled else { return }
            isLoadingDetail = false
        }
    }
}

// MARK: - Private

extension FileHistoryState {
    /// 一次详情读取只产生一种内容，目标类型同时供所有动作入口使用。
    private struct DetailResult {
        /// 两侧目标与内容能力。
        let target: FileHistoryTarget

        /// 单文件补丁。
        var diff: CommitDiff? = nil

        /// 当前版本的原文。
        var content: FileRevisionContent? = nil

        /// 目录的全部真实文件变更。
        var files: [CommitFileChange]? = nil
    }

    /// Activity 包含类型解析与实际内容读取，目录不会传给 blob 读取。
    private static func readDetail(
        path: String,
        commit: HistoryCommit,
        runner: GitRunner,
        mode: FileHistoryDetailMode,
        activity: (store: RepositoryActivities, records: Bool),
        display: (options: DiffOptions, threshold: Int, showLarge: Bool)
    ) async throws -> DetailResult {
        let title = AppLocalization.text(mode == .diff ? "activity.read.commitDiffs" : "activity.read.blob")
        return try await activity.store.recordRead([title], in: runner.location, records: activity.records) {
            let target = try await FileHistoryTarget.load(path: path, commit: commit, runner: runner)
            var result = DetailResult(target: target)

            if target.needsDirectoryDiff, mode == .diff || !target.allowsContent {
                result.files = try await FileHistoryTarget.changes(path: path, commit: commit, runner: runner)
            } else if mode == .raw {
                result.content = try await FileRevisionContent.load(
                    path, at: commit.id, views: RepositoryFileViews(runner: runner)
                )
            } else {
                result.diff = try await RepositoryFileViews(runner: runner).diff(
                    of: path, in: commit.id, options: display.options,
                    warningKilobytes: display.threshold, showLarge: display.showLarge
                )
            }

            return result
        }
    }
}
