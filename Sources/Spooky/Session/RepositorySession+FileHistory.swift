import SpookyKit

// MARK: - File History Actions

extension RepositorySession {
    /// 未解析的目标与目录都不能读取为原文、Blame 或导出文件。
    func canReadFileHistory(_ target: FileHistoryTarget?) -> Bool {
        target?.allowsContent ?? false
    }

    /// 详情头部固定提供 Blame、Show Commit 与 Diff Tool。
    func fileHistoryHeaderActions(_ commit: HistoryCommit) -> [FileViewAction] {
        let path = fileHistory.path ?? ""

        return [
            FileViewAction(
                title: AppLocalization.text("blame.title"),
                enabled: canReadFileHistory(fileHistory.targets[commit.id])
            ) { [weak self] in
                self?.showHistoryFile(path, commit: commit, mode: .blame)
            },
            FileViewAction(title: AppLocalization.text("fileHistory.showCommit")) { [weak self] in
                self?.showCommit(commit)
            },
            FileViewAction(title: AppLocalization.text("externalTool.action.diffTool")) { [weak self] in
                self?.compareFileHistory(commit)
            },
        ]
    }

    /// 时间线右键以所指提交为目标，不依赖详情当前选择。
    func fileHistoryMenuActions(_ commit: HistoryCommit) -> [FileViewAction] {
        let path = fileHistory.path ?? ""
        let name = Self.fileName(path)
        let contentEnabled = canReadFileHistory(fileHistory.targets[commit.id])

        return [
            FileViewAction(
                title: AppLocalization.text("fileHistory.showAt", name, commit.shortID), enabled: contentEnabled
            ) { [weak self] in
                self?.showHistoryFile(path, commit: commit, mode: .raw)
            },
            FileViewAction(
                title: AppLocalization.text("fileHistory.blameAt", name, commit.shortID), enabled: contentEnabled
            ) { [weak self] in
                self?.showHistoryFile(path, commit: commit, mode: .blame)
            },
            FileViewAction(title: AppLocalization.text("fileHistory.showCommitFor", commit.shortID)) { [weak self] in
                self?.showCommit(commit)
            },
            FileViewAction(title: AppLocalization.text("externalTool.openDiffAt", name, commit.shortID)) { [weak self] in
                self?.compareFileHistory(commit)
            },
            FileViewAction(
                title: AppLocalization.text("fileHistory.restoreAt", name, commit.shortID), enabled: canWrite
            ) { [weak self] in
                self?.restoreFile(path, at: commit.id)
            },
            FileViewAction(
                title: AppLocalization.text("fileHistory.exportAt", name, commit.shortID), enabled: contentEnabled
            ) { [weak self] in
                guard let self, fileHistory.path == path, canReadFileHistory(fileHistory.targets[commit.id]) else { return }
                exportFile(path, at: commit.id)
            },
        ]
    }

    /// 准备真实比较文件；根提交的空侧和第一父提交由共用工具入口处理。
    func compareFileHistory(_ commit: HistoryCommit) {
        guard let path = fileHistory.path, let runner else { return }
        let request = generation
        fileHistory.comparisonTask?.cancel()

        fileHistory.comparisonTask = Task { [weak self] in
            do {
                guard let self else { return }
                let files = try await fileHistoryComparisonFiles(commit, path: path)

                guard
                    generation == request, fileHistory.path == path,
                    !Task.isCancelled, !files.isEmpty
                else { return }

                openDiffTool(for: commit, files: files)
            } catch {
                guard let self, generation == request, fileHistory.path == path, !Task.isCancelled else { return }
                fileHistory.failure = AppFailure(error: error, opening: false, location: runner.location)
            }
        }
    }

    /// 由菜单目标准备比较文件，返回完整新旧路径而不是当前详情的选中结果。
    func fileHistoryComparisonFiles(_ commit: HistoryCommit, path: String) async throws -> [ComparedFile] {
        guard let runner else { throw RepositoryReadError.invalidQuery }

        return try await activities.recordRead(
            [AppLocalization.text("activity.read.commitDiffs")], in: runner.location
        ) {
            let target = try await FileHistoryTarget.load(path: path, commit: commit, runner: runner)

            if target.needsDirectoryDiff {
                let changes = try await FileHistoryTarget.changes(path: path, commit: commit, runner: runner)
                return Self.comparedFiles(changes)
            }

            return [ComparedFile(path: path)]
        }
    }

    /// 入口执行时再次检查目标能力，不能绕过菜单禁用把目录交给内容读取。
    private func showHistoryFile(_ path: String, commit: HistoryCommit, mode: FileContentMode) {
        guard fileHistory.path == path, canReadFileHistory(fileHistory.targets[commit.id]) else { return }
        showFile(path, at: commit.id, mode: mode)
    }
}
