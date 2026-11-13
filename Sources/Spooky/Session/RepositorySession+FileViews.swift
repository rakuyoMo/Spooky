import AppKit
import SpookyKit

// MARK: - FileViewError

/// 文件视图动作的前置条件不满足，界面负责本地化。
enum FileViewError: Error {
    /// 所选版本中没有这个文件，无法导出。
    case missingAtRevision
}

// MARK: - File Views

extension RepositorySession {
    /// 打开文件历史，从当前 HEAD 开始列出修改过这个文件的提交。
    func showFileHistory(_ path: String) {
        guard let runner else {
            return
        }

        fileHistory.open(path.hasSuffix("/") ? String(path.dropLast()) : path, head: status?.branch.oid, runner: runner)
        activeView = .fileHistory

        // 从文件历史里换文件时搜索框保留内容，新文件沿用同样的筛选
        fileHistory.search(searchText)
        onActiveViewChange?()
    }

    /// 打开某个版本的文件原文或逐行追溯。
    ///
    /// - Parameter revision: 提交的完整哈希；nil 表示跟随当前 HEAD。
    func showFile(_ path: String, at revision: String?, mode: FileContentMode) {
        guard let runner else {
            return
        }

        fileContent.open(path, revision: revision, mode: mode, head: status?.branch.oid, runner: runner)
        activeView = .fileContent
        onActiveViewChange?()
    }

    /// 回到历史，打开这个提交的整页详情；提交不在已加载的分页里也能显示。
    ///
    /// 先核对它在历史里的位置，排得很靠后时询问；取消时视图与历史都不变。
    func showCommit(_ commit: HistoryCommit) {
        history.confirmLookup(commit.id) { [weak self] in
            guard let self else {
                return
            }

            activeView = .history
            history.reveal(commit)
            onActiveViewChange?()
        }
    }

    /// 按哈希回到提交：先读取它的元信息，再打开整页详情。
    func showCommit(id: String) {
        guard let runner, let repository else {
            return
        }

        let request = generation

        Task { [weak self] in
            do {
                // 以这个提交为根的第一条记录就是它自己
                let page = try await RepositoryHistory(runner: runner).page(roots: [id], limit: 1)

                guard let self, generation == request, let commit = page.commits.first else {
                    return
                }

                showCommit(commit)
            } catch {
                guard let self, generation == request else {
                    return
                }

                onFailure?(AppFailure(error: error, opening: false, location: repository))
            }
        }
    }

    /// 把文件的暂存区与工作区恢复到指定版本；确认里写明影响范围，服务器仓库写明在服务器上覆盖，并可以勾选不再提醒。
    func restoreFile(_ path: String, at revision: String) {
        guard canWrite, let repository else {
            return
        }

        let message = AppLocalization.text(
            repository.host == nil ? "fileHistory.restore.message" : "fileHistory.restore.remote",
            path,
            String(revision.prefix(8)),
            repository.displayPath
        )

        confirmRestore([path], at: revision, message: message)
    }

    /// 确认后把文件恢复到指定版本：本机仓库每次确认，服务器仓库的这项确认可以关掉。
    ///
    /// - Parameters:
    ///   - paths: 仓库内的相对路径。
    ///   - revision: 恢复到的版本。
    ///   - message: 写明影响范围的说明。
    func confirmRestore(_ paths: [String], at revision: String, message: String) {
        let request = generation
        let title = AppLocalization.text("fileHistory.restoreTitle")

        let perform = { [weak self] in
            guard let self, generation == request else { return }

            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner).restore(paths, to: revision)
                },
                title: title,
                recordsActivity: false,
                undo: .reversible
            )
        }

        let submitTitle = AppLocalization.text("fileHistory.restore.submit")

        guard repository?.host != nil else {
            onConfirm?(ConfirmationRequest(
                title: title,
                message: message,
                submitTitle: submitTitle,
                action: perform
            ))
            return
        }

        confirmOnServer(
            .restoreFiles,
            title: title,
            submitTitle: submitTitle,
            message: message,
            action: perform
        )
    }

    /// 把某个版本的文件导出到本机：保存面板在本机，内容取自仓库所在机器上的 Git 输出。
    func exportFile(_ path: String, at revision: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = Self.fileName(path)

        let save: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }

            self?.withContents(of: path, at: revision) { data in
                try data.write(to: destination)
            }
        }

        // 从本窗口发起的动作，面板附在本窗口上
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: save)
        } else {
            panel.begin(completionHandler: save)
        }
    }

    /// 把仓库内的路径放进剪贴板，每行一个；完整路径是仓库位置加相对路径，服务器仓库带主机前缀。
    ///
    /// - Parameters:
    ///   - paths: 仓库内的相对路径。
    ///   - relative: 只写相对路径。
    ///   - pasteboard: 放入的剪贴板，测试使用独立的剪贴板。
    func copyPaths(_ paths: [String], relative: Bool, to pasteboard: NSPasteboard = .general) {
        guard let repository else {
            return
        }

        let lines = relative ? paths : paths.map { repository.displayPath + "/" + $0 }

        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    /// 工作区详情动作按对象能力与当前比较侧生成，目录只提供文件历史。
    func workingCopyFileActions(
        _ path: String,
        entry: StatusEntry?,
        isDirectory: Bool
    ) -> [FileViewAction] {
        let comparison: WorkingCopyComparison = diffSide == .staged ? .indexToBase : .workingTreeToIndex
        let entries = entry.map { [$0] } ?? []

        return [
            FileViewAction(title: AppLocalization.text("blame.title"), enabled: !isDirectory) { [weak self] in
                self?.showFile(path, at: nil, mode: .blame)
            },
            FileViewAction(title: AppLocalization.text("fileHistory.title")) { [weak self] in
                self?.showFileHistory(path)
            },
            FileViewAction(
                title: AppLocalization.text("externalTool.action.diffTool"),
                enabled: !isDirectory && canCompare(entries, comparison)
            ) { [weak self] in
                self?.compare(entries, comparison)
            },
        ]
    }

    /// 工作区文件右键菜单的 “查看” 组：原文、Blame 与文件历史，都跟随当前 HEAD；只对单个文件提供。
    func fileViewMenuItems(for entries: [StatusEntry]) -> [NSMenuItem] {
        guard Set(entries.map(\.path)).count == 1, let path = entries.first?.path else {
            return []
        }

        let name = Self.fileName(path)
        let actions = [
            FileViewAction(title: AppLocalization.text("showFile.show", name)) { [weak self] in
                self?.showFile(path, at: nil, mode: .raw)
            },
            FileViewAction(title: AppLocalization.text("blame.show", name)) { [weak self] in
                self?.showFile(path, at: nil, mode: .blame)
            },
            FileViewAction(title: AppLocalization.text("fileHistory.showHistoryOf", name)) { [weak self] in
                self?.showFileHistory(path)
            },
        ]

        return actions.map(FileViewMenuItem.init)
    }
}

// MARK: - Private

extension RepositorySession {
    /// 菜单与文件名使用路径的最后一段。
    static func fileName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// 读取某个版本的文件内容后交给动作；读取或动作失败时在窗口显示错误。
    private func withContents(
        of path: String,
        at revision: String,
        perform action: @escaping @MainActor (Data) throws -> Void
    ) {
        guard let runner, let repository else {
            return
        }

        let request = generation

        Task { [weak self] in
            do {
                let views = RepositoryFileViews(runner: runner)

                // 版本中没有这个文件或是子模块时没有可用的内容
                guard
                    let entry = try await views.storedEntry(for: path, in: revision),
                    entry.type == "blob"
                else { throw FileViewError.missingAtRevision }

                let data = try await views.contents(of: entry)

                guard let self, generation == request else {
                    return
                }

                try action(data)
            } catch {
                guard let self, generation == request else {
                    return
                }

                onFailure?(AppFailure(error: error, opening: false, location: repository))
            }
        }
    }
}
