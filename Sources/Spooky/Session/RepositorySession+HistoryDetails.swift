import AppKit
import SpookyKit
import UniformTypeIdentifiers

// MARK: - History Details

extension RepositorySession {
    /// 保存补丁时不带 `a/`、`b/` 前缀的偏好键，对话框与快速保存共用。
    static let omitsPatchPrefixesKey = "savePatchOmitPrefixes"

    /// 历史里选中的两个提交，按列表顺序从新到旧；不是恰好两个时为空。
    var comparedCommits: (newer: HistoryCommit, older: HistoryCommit)? {
        let selected = history.commits.filter { history.selectedIDs.contains($0.id) }

        guard selected.count == 2 else {
            return nil
        }

        return (selected[0], selected[1])
    }

    /// 把文件树或变更集里的多个条目恢复到指定版本；只有一个条目时沿用单个文件的确认文案。
    func restoreItems(_ paths: [String], at revision: String) {
        guard canWrite, let repository, !paths.isEmpty else {
            return
        }

        guard paths.count > 1 else {
            restoreFile(paths[0], at: revision)
            return
        }

        let message = AppLocalization.text(
            repository.host == nil ? "tree.restore.message" : "tree.restore.remote",
            paths.count,
            String(revision.prefix(8)),
            repository.displayPath
        )

        confirmRestore(paths, at: revision, message: message)
    }

    /// 保存补丁：按住 ⌥ 的快速保存不弹选项对话框、不询问保存位置，沿用记住的去前缀选项，直接存进仓库根目录。
    ///
    /// 快速保存的补丁由仓库所在机器上的 Git 写出，服务器仓库的补丁留在服务器上。
    func requestSavePatch(_ commits: [HistoryCommit], quick: Bool) {
        guard !commits.isEmpty else {
            return
        }

        guard quick else {
            onRevisionRequest?(.savePatch(commits))
            return
        }

        let omitsPrefixes = UserDefaults.standard.bool(forKey: Self.omitsPatchPrefixesKey)

        // 列表从新到旧排列，补丁编号从最早的提交开始
        let ids = Array(commits.map(\.id).reversed())

        runExport(AppLocalization.text("patch.title")) { runner in
            _ = try await RevisionExport(runner: runner).savePatchesToRepositoryRoot(ids, omitsPrefixes: omitsPrefixes)
        }
    }

    /// 选择本机目录后，把每个提交存成一个补丁文件；编号按提交从旧到新排列。
    func savePatches(_ commits: [HistoryCommit], omitsPrefixes: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = AppLocalization.text("patch.prompt")

        // 列表从新到旧排列，补丁编号从最早的提交开始
        let ids = commits.map(\.id).reversed()

        present(panel) { [weak self] directory in
            self?.runExport(AppLocalization.text("patch.title")) { runner in
                _ = try await RevisionExport(runner: runner).savePatches(Array(ids), omitsPrefixes: omitsPrefixes, to: directory)
            }
        }
    }

    /// 选择本机位置后导出一个版本：归档存成 zip 文件，否则存成与仓库结构相同的目录。
    ///
    /// - Parameters:
    ///   - revision: 提交的完整哈希。
    ///   - paths: 只导出这些路径；为空时导出整棵树。
    func export(_ revision: String, paths: [String], archive: Bool) {
        guard let repository else {
            return
        }

        let panel = NSSavePanel()
        panel.prompt = AppLocalization.text("export.prompt")
        panel.nameFieldLabel = AppLocalization.text("export.nameLabel")
        panel.canCreateDirectories = true

        let name = paths.count == 1 ? Self.fileName(paths[0]) : repository.name + "-" + revision.prefix(8)

        if archive {
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = name + ".zip"
        } else {
            panel.nameFieldStringValue = name
        }

        present(panel) { [weak self] destination in
            let title = AppLocalization.text(archive ? "export.createArchive" : "export.files")

            self?.runExport(title) { runner in
                let export = RevisionExport(runner: runner)

                if archive {
                    try await export.archive(revision, paths: paths, format: .zip, to: destination)
                } else {
                    try await export.export(revision, paths: paths, to: destination)
                }
            }
        }
    }

    /// 在历史详情里比较两个已解析的提交；从其它视图发起时先回到历史。
    func compare(base: RevisionComparisonState.Side, target: RevisionComparisonState.Side) {
        guard let runner else {
            return
        }

        if activeView != .history || history.showsCommitPage {
            activeView = .history
            history.showsCommitPage = false
            onActiveViewChange?()
        }

        comparison.open(base: base, target: target, runner: runner)
    }

    /// 比较选中的两个提交：默认从较早的到较新的，反向时从较新的到较早的。
    func compareSelectedCommits(reversed: Bool) {
        guard let (newer, older) = comparedCommits else {
            return
        }

        let (base, target) = reversed ? (newer, older) : (older, newer)

        compare(
            base: RevisionComparisonState.Side(id: base.id, title: base.shortID),
            target: RevisionComparisonState.Side(id: target.id, title: target.shortID)
        )
    }
}

// MARK: - Private

extension RepositorySession {
    /// 面板附在当前窗口上；用户选好位置后才执行。
    private func present(_ panel: NSSavePanel, then action: @escaping (URL) -> Void) {
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            action(url)
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    /// 导出与保存补丁不改动 Git 的引用与暂存区，不占用应用内的写锁；记入 Activity 的 Repository 页并提供取消，失败显示错误详情。
    private func runExport(_ title: String, operation: @escaping @Sendable (GitRunner) async throws -> Void) {
        guard let runner, let repository else {
            return
        }

        let activity = RepositoryActivity(kind: .repository, repository: repository, title: title)
        RepositoryActivities.shared.insert(activity)

        let task = Task { [weak self] in
            do {
                try await operation(runner)
                activity.state = Task.isCancelled ? "activity.cancelled" : "activity.finished"
            } catch {
                let cancelled = Task.isCancelled
                    || error is CancellationError
                    || ((error as? GitError)?.isCancelled ?? false)

                activity.state = cancelled ? "activity.cancelled" : "activity.failed"

                if !cancelled {
                    self?.onFailure?(AppFailure(error: error, opening: false, location: repository))
                }
            }

            RepositoryActivities.shared.finish(activity)
        }

        activity.cancel = { task.cancel() }
    }
}
