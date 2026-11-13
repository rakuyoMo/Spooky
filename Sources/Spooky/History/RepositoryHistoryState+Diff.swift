import Foundation
import SpookyKit

// MARK: - Diff

extension RepositoryHistoryState {
    /// 当前提交里一个文件的只读补丁来源，供语法着色与图片对照读取内容；没有选中提交或文件不在变更里时为空。
    func diffSource(path: String) -> CommitFileDiffSource? {
        guard
            let runner,
            let commit = selectedCommit,
            let file = changes.first(where: { $0.path == path })
        else { return nil }

        return CommitFileDiffSource(runner: runner, commit: commit.id, file: file, mergeMode: .preferred)
    }

    /// 单选变化后丢弃上一提交的补丁，元信息直接复用列表记录。
    func loadChanges() {
        changeTask?.cancel()
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        changes = []
        loadedChangesID = nil
        changesFailure = nil
        diffs = [:]
        diffFailures = [:]
        loadingPaths = []
        expandedPaths = []
        fileSelection = ChangesetFileSelection()
        selectedPath = nil
        isLoadingChanges = false

        guard let runner, let commit = selectedCommit else { return }

        let request = generation
        let mergeMode = MergeDiffMode.preferred
        isLoadingChanges = true

        changeTask = Task { [weak self] in
            do {
                let files = try await RepositoryHistory(runner: runner).changes(in: commit.id, mergeMode: mergeMode)

                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }

                changes = files
                loadedChangesID = commit.id

                let threshold = preferences.integer(forKey: "historyAutoExpand")
                if threshold > 0, files.count <= threshold { expandAll(true) }
            } catch {
                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }

                changesFailure = AppFailure(error: error, opening: false, location: runner.location)
            }

            guard
                let self, generation == request, selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }

            isLoadingChanges = false
        }
    }

    /// 刷新后重读同一提交的变更集：不清空已显示的内容，读到的与现有的不同才替换；展开与选中的文件随后在后台重读补丁。
    ///
    /// 这个提交的变更集还没有读出时从头读取。
    func reloadChanges() {
        guard let runner, let commit = selectedCommit, loadedChangesID == commit.id else {
            loadChanges()
            return
        }

        changeTask?.cancel()

        let request = generation
        let mergeMode = MergeDiffMode.preferred

        changeTask = Task { [weak self] in
            let files = try? await RepositoryHistory(runner: runner)
                .changes(in: commit.id, mergeMode: mergeMode)

            // 变更集只由提交与比较方式决定，重读失败时已显示的仍然有效，原样保留
            guard
                let files, let self, generation == request, selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }

            mergeChanges(files)
        }
    }

    /// 展开时才取文件补丁，放行大 Diff 只影响当前提交的当前文件。
    ///
    /// - Parameters:
    ///   - path: 文件路径。
    ///   - showLarge: 是否放行超过阈值的大 Diff。
    ///   - refreshing: 刷新后重读已显示的补丁：不显示读取中，读到的与现有的相同时不替换，失败时保留现有的补丁。
    func loadDiff(_ path: String, showLarge: Bool = false, refreshing: Bool = false) {
        guard
            !loadingPaths.contains(path), showLarge || refreshing || diffs[path] == nil,
            let runner, let commit = selectedCommit, let file = changes.first(where: { $0.path == path })
        else { return }

        let request = generation

        // 新的读取取代同一文件还在进行的重读；刷新时的重读不显示读取中
        diffTasks[path]?.cancel()

        if !refreshing {
            loadingPaths.insert(path)
            diffFailures[path] = nil
        }

        let threshold =
            UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
                ?? WorkingCopyOperations.defaultWarningKilobytes

        // 变更集沿用工作区的上下文与忽略空白偏好
        let options = DiffPreferences.options()
        let mergeMode = MergeDiffMode.preferred

        diffTasks[path] = Task { [weak self] in
            do {
                let diff = try await RepositoryHistory(runner: runner)
                    .diff(
                        in: commit.id,
                        file: file,
                        mergeMode: mergeMode,
                        options: options,
                        warningKilobytes: threshold,
                        showLarge: showLarge
                    )

                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }

                store(diff, for: path)
            } catch {
                guard
                    let self, generation == request, selectedCommit?.id == commit.id,
                    !Task.isCancelled
                else { return }

                // 刷新时的重读失败不盖住已显示的补丁
                if !refreshing || diffs[path] == nil {
                    diffFailures[path] = AppFailure(error: error, opening: false, location: runner.location)
                }
            }

            guard
                let self, generation == request, selectedCommit?.id == commit.id,
                !Task.isCancelled
            else { return }

            loadingPaths.remove(path)
            diffTasks[path] = nil
        }
    }

    /// 上下文行数或忽略空白改变后丢弃已读的补丁，重新读取正在显示的文件。
    func reloadDiffs() {
        for task in diffTasks.values { task.cancel() }
        diffTasks = [:]
        loadingPaths = []
        diffs = [:]
        diffFailures = [:]

        for path in expandedPaths.union(selectedPath.map { [$0] } ?? []) {
            loadDiff(path)
        }
    }

    /// 全部展开 / 收起与快捷键共用状态，补丁仍逐文件按需读取。
    func expandAll(_ expanded: Bool) {
        expandedPaths = expanded ? Set(changes.map(\.path)) : []
        if expanded { for file in changes { loadDiff(file.path) } }
    }
}

// MARK: - Private

extension RepositoryHistoryState {
    /// 把重读的变更集并入已显示的：内容不同才替换，行按路径更新；不在新变更集里的文件移出展开、选中、文件行选区与已读的补丁，展开与选中的文件在后台重读补丁。
    private func mergeChanges(_ files: [CommitFileChange]) {
        if files != changes {
            changes = files
        }

        let paths = Set(files.map(\.path))

        if !expandedPaths.isSubset(of: paths) {
            expandedPaths.formIntersection(paths)
        }

        fileSelection = fileSelection.retaining(files.map(\.path))

        if let selectedPath, !paths.contains(selectedPath) {
            self.selectedPath = nil
        }

        if !paths.isSuperset(of: diffs.keys) {
            diffs = diffs.filter { paths.contains($0.key) }
        }

        if !paths.isSuperset(of: diffFailures.keys) {
            diffFailures = diffFailures.filter { paths.contains($0.key) }
        }

        // 已放行显示的大 Diff 重读时照样放行，不退回提示
        for path in expandedPaths.union(selectedPath.map { [$0] } ?? []) {
            loadDiff(path, showLarge: diffs[path]?.diff != nil, refreshing: true)
        }
    }

    /// 写入一个文件读到的补丁：与已有的相同时不替换；读到了，之前的失败就不再显示。
    private func store(_ diff: CommitDiff, for path: String) {
        if diffs[path] != diff {
            diffs[path] = diff
        }

        if diffFailures[path] != nil {
            diffFailures[path] = nil
        }
    }
}
