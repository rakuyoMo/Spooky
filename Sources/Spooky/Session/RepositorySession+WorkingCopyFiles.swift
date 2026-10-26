import Foundation
import SpookyKit

// MARK: - WorkingCopyFileRequest

/// 需要窗口呈现的工作区文件操作：参数表单，或多按钮的询问。
enum WorkingCopyFileRequest {
    /// 需要填写参数的表单。
    case form(WorkingCopyFileForm)

    /// 要忽略的文件里有已跟踪的文件，询问是否同时停止跟踪。
    case untrackIgnored(IgnoreFile, patterns: [String], tracked: [StatusEntry])
}

// MARK: - WorkingCopyFileForm

/// 工作区文件操作的参数表单。
enum WorkingCopyFileForm {
    /// 把文件恢复到指定版本。
    case revert([StatusEntry])

    /// 移动或重命名一个文件。
    case move(StatusEntry)

    /// 输入自定义的忽略或排除规则，预填所选文件的规则。
    case pattern(IgnoreFile, [StatusEntry])

    /// 输入交给 Git LFS 跟踪的规则，预填第一个所选文件的路径；没有所选文件时为空。
    case lfsPattern([StatusEntry])

    /// 选择本机的补丁文件并应用到工作区。
    case applyPatch
}

// MARK: - Display

extension RepositorySession {
    /// 工作区列表当前的显示选项；被忽略与 assume-unchanged 文件的开关是全局偏好。
    var listing: WorkingCopyListing {
        WorkingCopyListing(
            mode: listMode,
            showsIgnored: UserDefaults.standard.bool(forKey: WorkingCopyPreferences.showIgnored),
            showsAssumeUnchanged: UserDefaults.standard.bool(forKey: WorkingCopyPreferences.showAssumeUnchanged),
            onlyConflicts: onlyConflicts,
            filter: searchText
        )
    }

    /// 当前详情对应的条目，Unicode 等价路径沿用 Swift 的规范等价比较；未改动与被忽略的文件来自补充清单。
    var selectedEntry: StatusEntry? {
        guard let selectedID else { return nil }

        return status?.entries.first { $0.path == selectedID.path && $0.kind == selectedID.kind }
            ?? supplementaryEntry(selectedID)
    }

    /// 批量动作对应当前多选；单选详情也可从菜单操作；未改动与被忽略的文件来自补充清单。
    var selectedEntries: [StatusEntry] {
        let ids = selectedIDs.isEmpty ? Set([selectedID].compactMap { $0 }) : selectedIDs
        let listed = status?.entries.filter { ids.contains(StatusRowID(path: $0.path, kind: $0.kind)) } ?? []

        // 状态里没有的条目才从补充清单里取，同一文件不会出现两次
        let found = Set(listed.map { StatusRowID(path: $0.path, kind: $0.kind) })
        let supplementary = ids.subtracting(found)
            .sorted { $0.path < $1.path }
            .compactMap(supplementaryEntry)

        return listed + supplementary
    }

    /// 切换本窗口的显示模式，需要的补充清单随之读取；记住选择由窗口负责。
    func setListMode(_ mode: WorkingCopyListMode) {
        guard mode != listMode else { return }

        listMode = mode
        loadWorkingTreeFiles()
    }

    /// 补充清单里的条目：未改动或被忽略的文件；清单里已经没有这个路径时为 nil。
    func supplementaryEntry(_ id: StatusRowID) -> StatusEntry? {
        switch id.kind {
        case .unchanged where workingTreeFiles.indexPaths.contains(id.path),
             .ignored where workingTreeFiles.ignoredPaths.contains(id.path):
            StatusEntry(kind: id.kind, path: id.path)

        default:
            nil
        }
    }

    /// 读取当前显示选项需要的补充清单：全部文件与 assume-unchanged 需要暂存区清单，被忽略文件需要忽略清单。
    ///
    /// 只在完整刷新、状态变化与选项变化时调用；服务器轮询的常规读取仍只有 status 与所选文件的哈希。
    func loadWorkingTreeFiles() {
        workingTreeFilesTask?.cancel()

        let options = listing
        let needsIndex = options.mode == .allFiles || options.showsAssumeUnchanged

        guard let repository, let runner, needsIndex || options.showsIgnored else {
            workingTreeFilesTask = nil

            // 不需要补充清单时清空；已经为空就不再写入，避免触发无谓的界面更新
            if workingTreeFiles != WorkingTreeFileListing() {
                workingTreeFiles = WorkingTreeFileListing()
            }

            return
        }

        let request = generation

        workingTreeFilesTask = Task { [weak self] in
            do {
                // 两份清单互不依赖，并发读取
                async let index = needsIndex ? runner.indexFiles() : nil
                async let ignored = options.showsIgnored ? runner.ignoredFiles() : nil
                let listing = try await WorkingTreeFileListing(index: index, ignored: ignored)

                guard let self, generation == request, !Task.isCancelled else { return }
                workingTreeFiles = listing
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                reportFileFailure(error, in: repository)
            }
        }
    }
}

// MARK: - File Operations

extension RepositorySession {
    /// 停止跟踪所选文件：文件留在工作区，下次提交从版本库里移除。
    func untrack(_ entries: [StatusEntry]) {
        let targets = entries.filter(\.isInIndex)
        guard canWrite, !targets.isEmpty else { return }

        let paths = targets.map(\.path)

        performGit(
            { runner, _ in try await WorkingCopyOperations(runner: runner).untrack(paths) },
            title: AppLocalization.text("files.untrack"),
            recordsActivity: false,
            undo: .reversible
        )
    }

    /// 删除所选文件：本机移到废纸篓；服务器没有废纸篓，确认后在服务器上永久删除。
    func delete(_ entries: [StatusEntry]) {
        let targets = entries.filter(\.isDeletable)
        guard canWrite, !targets.isEmpty, let repository else { return }

        let paths = targets.map(\.path)
        let title = AppLocalization.text(repository.host == nil ? "files.trash" : "files.delete")

        // 删除与其它写操作一样经仓库写队列执行
        let perform = { [weak self] in
            _ = self?.performGit(
                { runner, _ in try await WorkingCopyOperations(runner: runner).delete(paths) },
                title: title,
                recordsActivity: false,
                undo: .reversible
            )
        }

        // 本机文件可以从废纸篓放回，不需要确认
        guard repository.host != nil else {
            perform()
            return
        }

        // 确认期间仓库已切换时不执行
        let request = generation

        onConfirm?(
            title,
            AppLocalization.text("files.delete.remote", scopeDescription(targets), repository.displayPath),
            { [weak self] in
                guard let self, generation == request else { return }

                perform()
            },
            nil
        )
    }

    /// 移动一个文件；目标路径已由表单校验，Git 与文件层仍会拒绝覆盖。
    @discardableResult
    func move(_ entry: StatusEntry, to destination: String) -> Bool {
        let tracked = entry.isInIndex

        return performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).move(entry.path, to: destination, tracked: tracked)
            },
            title: AppLocalization.text("files.move"),
            recordsActivity: false,
            undo: .reversible
        )
    }

    /// 把文件恢复到指定版本；表单已写明影响范围，提交表单即确认。
    @discardableResult
    func revert(_ entries: [StatusEntry], to revision: String) -> Bool {
        let paths = entries.flatMap { [$0.path] + ($0.originalPath.map { [$0] } ?? []) }

        return performGit(
            { runner, _ in try await WorkingCopyOperations(runner: runner).restore(paths, to: revision) },
            title: AppLocalization.text("files.revert"),
            recordsActivity: false,
            undo: .reversible
        )
    }

    /// 按所选文件生成规则；所选文件里有已跟踪的文件时先询问是否同时停止跟踪。
    func ignore(_ entries: [StatusEntry], scope: IgnorePatternScope, in file: IgnoreFile) {
        // 类型规则只取第一个文件的扩展名
        let sources = scope == .type ? Array(entries.prefix(1)) : entries
        let patterns = WorkingCopyOperations.ignorePatterns(for: sources.map(\.path), scope: scope)

        addPatterns(patterns, for: entries, in: file)
    }

    /// 写入规则；所选文件里有已跟踪的文件时交给窗口询问，否则直接写入。
    func addPatterns(_ patterns: [String], for entries: [StatusEntry], in file: IgnoreFile) {
        guard canWrite, !patterns.isEmpty else { return }

        let tracked = entries.filter(\.isInIndex)

        guard tracked.isEmpty else {
            onFileRequest?(.untrackIgnored(file, patterns: patterns, tracked: tracked))
            return
        }

        writePatterns(patterns, in: file, untracking: [])
    }

    /// 在同一个写操作里追加规则，并按用户的选择停止跟踪已跟踪的文件。
    func writePatterns(_ patterns: [String], in file: IgnoreFile, untracking entries: [StatusEntry]) {
        let paths = entries.map(\.path)

        performGit(
            { runner, _ in
                let service = WorkingCopyOperations(runner: runner)
                try await service.addIgnorePatterns(patterns, to: file)
                try await service.untrack(paths)
            },
            title: AppLocalization.text(file == .gitignore ? "files.ignore" : "files.exclude"),
            recordsActivity: false,
            undo: file == .gitignore ? .reversible : .irreversible
        )
    }

    /// 设置或清除 assume-unchanged；只处理暂存区里的文件，冲突文件除外。
    func setAssumeUnchanged(_ entries: [StatusEntry], _ assumeUnchanged: Bool) {
        let paths = entries.filter(\.isInIndex).map(\.path)
        guard canWrite, !paths.isEmpty else { return }

        performGit(
            { runner, _ in try await WorkingCopyOperations(runner: runner).setAssumeUnchanged(paths, assumeUnchanged) },
            title: AppLocalization.text(assumeUnchanged ? "files.assumeUnchanged.set" : "files.assumeUnchanged.unset"),
            recordsActivity: false
        )
    }

    /// 补丁内容在本机读出，经标准输入交给工作区所在机器上的 git apply。
    @discardableResult
    func applyPatch(_ patch: Data) -> Bool {
        performGit(
            { runner, _ in try await WorkingCopyOperations(runner: runner).applyPatch(patch) },
            title: AppLocalization.text("files.applyPatch"),
            recordsActivity: false,
            undo: .reversible
        )
    }

    /// 确认框里的影响范围：一个文件点名，多个文件写出数量并列出前几个路径。
    func scopeDescription(_ entries: [StatusEntry]) -> String {
        guard entries.count > 1 else {
            return AppLocalization.text("files.scope.single", entries.first?.path ?? "")
        }

        let listed = entries.prefix(10).map(\.path)
        let names = listed.joined(separator: "\n") + (entries.count > listed.count ? "\n…" : "")

        return AppLocalization.text("files.scope.multiple", entries.count, names)
    }

    /// 补充清单读取失败：断线交给重连，其余错误交给窗口呈现。
    private func reportFileFailure(_ error: Error, in repository: RepositoryLocation) {
        guard !(error is CancellationError), (error as? GitError)?.isCancelled != true else {
            return
        }

        if error is RemoteConnectionError {
            reconnect()
        } else {
            onFailure?(AppFailure(error: error, opening: false, location: repository))
        }
    }
}

// MARK: - Availability

extension RepositorySession {
    /// 停止跟踪需要暂存区里的文件。
    func canUntrack(_ entries: [StatusEntry]) -> Bool {
        canWrite && entries.contains(where: \.isInIndex)
    }

    /// 删除需要工作区里实际存在的文件，冲突文件除外。
    func canDelete(_ entries: [StatusEntry]) -> Bool {
        canWrite && entries.contains(where: \.isDeletable)
    }

    /// 移动一次只处理一个工作区里存在的文件。
    func canMove(_ entries: [StatusEntry]) -> Bool {
        guard canWrite, entries.count == 1, let entry = entries.first else { return false }

        return entry.isDeletable && !entry.path.hasSuffix("/")
    }

    /// 恢复到指定版本作用于已跟踪的文件，冲突文件交给冲突处理。
    func canRevert(_ entries: [StatusEntry]) -> Bool {
        canWrite && !entries.isEmpty && entries.allSatisfy { $0.kind == .tracked || $0.kind == .unchanged }
    }

    /// 忽略与排除作用于还没有被忽略的文件。
    func canIgnore(_ entries: [StatusEntry]) -> Bool {
        canWrite && entries.contains { $0.kind != .ignored }
    }

    /// 设置或清除标记：暂存区清单已读取时按实际标记判断，否则只要求是暂存区里的文件。
    func canMarkAssumeUnchanged(_ entries: [StatusEntry], _ assumeUnchanged: Bool) -> Bool {
        let markable = entries.filter(\.isInIndex)

        guard canWrite, !markable.isEmpty else {
            return false
        }

        guard workingTreeFiles.index != nil else {
            return true
        }

        let marked = workingTreeFiles.assumeUnchanged
        return markable.contains { marked.contains($0.path) != assumeUnchanged }
    }
}

// MARK: - StatusEntry

extension StatusEntry {
    /// 文件在暂存区里：已跟踪且没有被暂存为删除，或是没有改动的已跟踪文件。
    var isInIndex: Bool {
        switch kind {
        case .tracked: staged != .deleted
        case .unchanged: true
        case .conflicted, .untracked, .ignored: false
        }
    }

    /// 右栏显示 Diff 的条目：有改动的已跟踪文件与未跟踪文件；冲突、未改动与被忽略的文件另有视图。
    var hasWorkingCopyDiff: Bool {
        kind == .tracked || kind == .untracked
    }

    /// 文件还在工作区里，可以删除或移动。
    var isDeletable: Bool {
        switch kind {
        case .tracked: unstaged != .deleted && !(staged == .deleted && unstaged == nil)
        case .untracked, .ignored, .unchanged: true
        case .conflicted: false
        }
    }
}
