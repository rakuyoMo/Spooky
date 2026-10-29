import AppKit
import SpookyKit
import UniformTypeIdentifiers

// MARK: - History Details

extension RepositorySession {
    /// 保存补丁时不带 `a/`、`b/` 前缀的偏好键，对话框与快速保存共用。
    static let omitsPatchPrefixesKey = "savePatchOmitPrefixes"

    /// 让 Finder 来到前台并选中这些文件；测试换成不打开 Finder 的。
    static var revealInFinder: ([URL]) -> Void = { NSWorkspace.shared.activateFileViewerSelecting($0) }

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
    /// 快速保存的补丁由仓库所在机器上的 Git 写出，服务器仓库的补丁留在服务器上；本机仓库保存后在 Finder 里选中这些补丁。
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

        runPatchSave { runner, formatting in
            let paths = try await RevisionExport(runner: runner).savePatchesToRepositoryRoot(
                ids,
                omitsPrefixes: omitsPrefixes,
                formatting: formatting
            )

            // 服务器仓库的补丁写在服务器上，本机没有这些文件可以选中
            guard runner.location.localURL != nil else {
                return
            }

            await Self.revealPatches(paths.map { URL(filePath: $0) })
        }
    }

    /// 选择本机目录后，把每个提交存成一个补丁文件；编号按提交从旧到新排列，保存后在 Finder 里选中这些补丁。
    func savePatches(_ commits: [HistoryCommit], omitsPrefixes: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = AppLocalization.text("patch.prompt")

        // 列表从新到旧排列，补丁编号从最早的提交开始
        let ids = commits.map(\.id).reversed()

        present(panel) { [weak self] directory in
            self?.runPatchSave { runner, formatting in
                let files = try await RevisionExport(runner: runner).savePatches(
                    Array(ids),
                    omitsPrefixes: omitsPrefixes,
                    to: directory,
                    formatting: formatting
                )

                await Self.revealPatches(files)
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
    /// 保存补丁成功后让 Finder 来到前台，打开补丁所在的目录并选中写出的全部文件；一个文件都没写或已取消时不打开。
    private static func revealPatches(_ files: [URL]) {
        guard !files.isEmpty, !Task.isCancelled else {
            return
        }

        revealInFinder(files)
    }

    /// 任务已取消，或者错误本身是取消；取消不算失败。
    private static func isCancellation(_ error: (any Error)?) -> Bool {
        Task.isCancelled
            || error is CancellationError
            || ((error as? GitError)?.isCancelled ?? false)
    }

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

    /// 导出不改动 Git 的引用与暂存区，不占用应用内的写锁；整次导出记一条进 Activity 的 Repository 页并提供取消，失败显示错误详情。
    private func runExport(_ title: String, operation: @escaping @Sendable (GitRunner) async throws -> Void) {
        guard let runner, let repository else {
            return
        }

        let activity = RepositoryActivity(kind: .repository, repository: repository, title: title)
        let activities = activities
        activities.insert(activity)

        let task = Task { [weak self] in
            do {
                try await operation(runner)
                activity.state = Task.isCancelled ? "activity.cancelled" : "activity.finished"
            } catch {
                let cancelled = Self.isCancellation(error)
                activity.state = cancelled ? "activity.cancelled" : "activity.failed"

                if !cancelled {
                    self?.onFailure?(AppFailure(error: error, opening: false, location: repository))
                }
            }

            activities.finish(activity)
        }

        activity.cancel = { task.cancel() }
    }

    /// 保存补丁不改动 Git 的引用与暂存区，不占用应用内的写锁；每个提交那一次 `format-patch` 在 Activity 的 Repository 页记一条，
    /// 记录的取消按钮取消整次保存，后面的提交不再执行。失败显示错误详情，取消不提示。
    ///
    /// - Parameter operation: 保存本身；收到的闭包原样交给 `RevisionExport`，由它包住每个提交那一次执行。
    private func runPatchSave(
        _ operation: @escaping @Sendable (GitRunner, RevisionExport.PatchFormatting) async throws -> Void
    ) {
        guard let runner, let repository else {
            return
        }

        let activities = activities
        var task: Task<Void, Never>? = nil

        // 一个提交开始执行时插入进行中的记录
        let start: @MainActor () -> RepositoryActivity = {
            let activity = RepositoryActivity(
                kind: .repository,
                repository: repository,
                title: AppLocalization.text("patch.formatPatch")
            )

            activity.cancel = { task?.cancel() }
            activities.insert(activity)
            return activity
        }

        // 这个提交执行完时写状态并结束记录：成功写 Finished，取消写 Cancelled，失败写 Failed
        let end: @MainActor (RepositoryActivity, (any Error)?) -> Void = { activity, error in
            if Self.isCancellation(error) {
                activity.state = "activity.cancelled"
            } else {
                activity.state = error == nil ? "activity.finished" : "activity.failed"
            }

            activities.finish(activity)
        }

        task = Task { [weak self] in
            do {
                // 每个提交执行前插入记录，执行完按结果结束它；执行抛出的错误照常抛出，后面的提交不再执行
                try await operation(runner) { _, format in
                    let activity = await start()

                    do {
                        try await format()
                        await end(activity, nil)
                    } catch {
                        await end(activity, error)
                        throw error
                    }
                }
            } catch {
                // 取消不提示，失败显示错误详情
                guard !Self.isCancellation(error) else {
                    return
                }

                self?.onFailure?(AppFailure(error: error, opening: false, location: repository))
            }
        }
    }
}
