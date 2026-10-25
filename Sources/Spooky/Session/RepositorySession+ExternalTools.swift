import AppKit
import SpookyKit
import Synchronization

// MARK: - WorkingCopyComparison

/// Working Copy › Compare 与文件右键 Compare ▸ 的比较方式；“A to B” 左侧是 B、右侧是 A。
enum WorkingCopyComparison: CaseIterable {
    /// 工作区对 HEAD。
    case workingTreeToBase

    /// 工作区对暂存区。
    case workingTreeToIndex

    /// 暂存区对 HEAD。
    case indexToBase

    /// 冲突文件：我方对对方。
    case oursToTheirs

    /// 冲突文件：我方对共同祖先。
    case oursToBase

    /// 冲突文件：对方对共同祖先。
    case theirsToBase

    /// 文件右键 Compare ▸ 与主菜单共用的标题键。
    var titleKey: String {
        switch self {
        case .workingTreeToBase: "externalTool.compare.workingTreeToBase"
        case .workingTreeToIndex: "externalTool.compare.workingTreeToIndex"
        case .indexToBase: "externalTool.compare.indexToBase"
        case .oursToTheirs: "externalTool.compare.oursToTheirs"
        case .oursToBase: "externalTool.compare.oursToBase"
        case .theirsToBase: "externalTool.compare.theirsToBase"
        }
    }

    /// 只对单个冲突文件提供的比较。
    var isConflictComparison: Bool {
        [.oursToTheirs, .oursToBase, .theirsToBase].contains(self)
    }

    /// 这个文件的左右两侧；这种比较不适用于这个文件时为 nil。
    func versions(of entry: StatusEntry) -> (left: FileVersion, right: FileVersion)? {
        guard !entry.path.hasSuffix("/") else {
            return nil
        }

        guard isConflictComparison else {
            return Self.workingVersions(self, entry: entry)
        }

        guard let stages = entry.conflict else {
            return nil
        }

        switch self {
        case .oursToTheirs:
            return stages.ours != nil && stages.theirs != nil ? (.blob(stages.theirs), .blob(stages.ours)) : nil

        case .oursToBase:
            return stages.ours != nil && stages.base != nil ? (.blob(stages.base), .blob(stages.ours)) : nil

        default:
            return stages.theirs != nil && stages.base != nil ? (.blob(stages.base), .blob(stages.theirs)) : nil
        }
    }
}

// MARK: - WorkingCopyComparison Private

extension WorkingCopyComparison {
    /// 非冲突文件的三种比较。
    private static func workingVersions(
        _ comparison: Self,
        entry: StatusEntry
    ) -> (left: FileVersion, right: FileVersion)? {
        guard entry.kind != .conflicted else {
            return nil
        }

        switch comparison {
        case .workingTreeToBase: return (.head, .workingTree)
        case .workingTreeToIndex: return (.index, .workingTree)
        case .indexToBase: return (.head, .index)
        default: return nil
        }
    }
}

// MARK: - External Tools

extension RepositorySession {
    /// 本会话所在的仓库窗口；外部程序退出时本程序可能不在前台，不能依赖 key window。
    var presentingWindow: NSWindow? {
        NSApp.windows.first { ($0.windowController as? RepositoryWindowController)?.session === self }
    }

    /// 变更集里的文件转成比较文件。
    static func comparedFiles(_ changes: [CommitFileChange]) -> [ComparedFile] {
        changes.map { ComparedFile(path: $0.path, originalPath: $0.originalPath) }
    }

    /// 所选文件里至少有一个能这样比较；冲突文件的三种比较只对单个文件提供。
    func canCompare(_ entries: [StatusEntry], _ comparison: WorkingCopyComparison) -> Bool {
        guard repository != nil else {
            return false
        }

        if comparison.isConflictComparison {
            return entries.count == 1 && entries.first.flatMap(comparison.versions(of:)) != nil
        }

        return entries.contains { comparison.versions(of: $0) != nil }
    }

    /// 只对单个两侧都是普通文件的冲突提供合并工具；写回结果要求仓库可写。
    func canOpenMergeTool(_ entries: [StatusEntry]) -> Bool {
        guard entries.count == 1, let entry = entries.first else {
            return false
        }

        return canResolve([entry]) && (entry.conflict?.hasRegularFilesOnBothSides ?? false)
    }

    /// 用比较工具比较所选的工作区文件；重命名的文件左侧按原路径读取 HEAD。
    func compare(_ entries: [StatusEntry], _ comparison: WorkingCopyComparison) {
        let pairs = entries.compactMap { entry in comparison.versions(of: entry).map { (entry, $0) } }

        guard let first = pairs.first else {
            return
        }

        // 同一种比较的左右版本对所有文件相同；冲突比较只有一个文件
        let usesOriginal = [.workingTreeToBase, .indexToBase].contains(comparison)
        let files = pairs.map {
            ComparedFile(path: $0.0.path, originalPath: usesOriginal ? $0.0.originalPath : nil)
        }

        openDiffTool(
            files,
            left: first.1.left,
            right: first.1.right,
            names: Self.directoryNames(comparison)
        )
    }

    /// 用比较工具比较提交里的文件与它的第一个父提交；根提交的左侧没有文件。
    ///
    /// 快捷操作 Commit › Open Diff Tool 传入整个变更集。
    ///
    /// - Parameters:
    ///   - commit: 所在的提交。
    ///   - files: 要比较的文件，如变更集里的全部或所选文件。
    func openDiffTool(for commit: HistoryCommit, files: [ComparedFile]) {
        let parent = commit.parents.first
        let parentName = parent.map { String($0.prefix(8)) } ?? AppLocalization.text("externalTool.side.empty")

        openDiffTool(
            files,
            left: parent.map(FileVersion.commit) ?? .blob(nil),
            right: .commit(commit.id),
            names: (parentName, commit.shortID)
        )
    }

    /// 用比较工具比较储藏里的文件与储藏的基准提交；随储藏保存的未跟踪文件在储藏的第三个父提交里。
    ///
    /// - Parameters:
    ///   - stash: 所在的储藏。
    ///   - changes: 要比较的文件。
    func openDiffTool(for stash: StashEntry, changes: [StashFileChange]) {
        let name = String(stash.id.prefix(8))

        // 已跟踪与未跟踪的文件分别在不同的提交里，按所在提交分组启动
        for (commit, group) in Dictionary(grouping: changes, by: \.commit).sorted(by: { $0.key < $1.key }) {
            openDiffTool(
                group.map { ComparedFile(path: $0.file.path, originalPath: $0.file.originalPath) },
                left: .commit(stash.base),
                right: .commit(commit),
                names: (String(stash.base.prefix(8)), name)
            )
        }
    }

    /// 用比较工具比较一组文件的两个版本：多个文件且所选工具支持目录对比时比较两个目录，否则逐个文件启动工具。
    ///
    /// 各版本经 Git 取到会话缓存，在本机启动工具；工具退出后重新读取状态。
    ///
    /// - Parameters:
    ///   - files: 参与比较的文件。
    ///   - left: 左侧版本。
    ///   - right: 右侧版本。
    ///   - names: 目录对比时两侧目录的名字。
    func openDiffTool(
        _ files: [ComparedFile],
        left: FileVersion,
        right: FileVersion,
        names: (left: String, right: String)
    ) {
        guard let fileCache, let repository, !files.isEmpty else {
            return
        }

        let request = generation
        let window = presentingWindow

        Task { [weak self] in
            guard let tool = await ExternalToolPicker.tool(merge: false, in: window) else {
                return
            }

            do {
                try await Self.runDiffTool(
                    tool,
                    files: files,
                    service: ExternalToolFiles(cache: fileCache),
                    versions: (left, right),
                    names: names
                )

                guard let self, generation == request else { return }
                refresh()
            } catch {
                guard let self, generation == request else { return }
                reportOpenFailure(error, in: repository)
            }
        }
    }

    /// 用合并工具解决一个冲突文件：三方版本取到本机，工具退出后有结果就核对并写回工作区、`git add`。
    func openMergeTool(_ entry: StatusEntry) {
        guard canOpenMergeTool([entry]), let fileCache, let repository else {
            return
        }

        let request = generation
        let window = presentingWindow

        Task { [weak self] in
            guard let tool = await ExternalToolPicker.tool(merge: true, in: window) else {
                return
            }

            do {
                let files = try await ExternalToolFiles(cache: fileCache).prepareMerge(entry)
                try await Self.runMergeTool(tool, files: files)

                guard let self, generation == request else { return }
                await finishMerge(files, tool: tool)
            } catch {
                guard let self, generation == request else { return }
                reportOpenFailure(error, in: repository)
            }
        }
    }

    /// 在本会话的窗口上询问是否覆盖已在别处改过的文件。
    ///
    /// - Parameters:
    ///   - path: 文件在仓库内的路径或仓库所在机器上的路径，只显示文件名。
    ///   - overwrite: 用户确认覆盖后的动作。
    func confirmOverwrite(_ path: String, overwrite: @escaping () -> Void) {
        guard let window = presentingWindow, let repository else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppLocalization.text("externalTool.fileChanged")
        alert.informativeText = AppLocalization.text(
            "externalTool.fileChanged.message",
            Self.fileName(path),
            repository.displayPath
        )
        alert.addButton(withTitle: AppLocalization.text("externalTool.overwrite"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { overwrite() }
        }
    }
}

// MARK: - ChangeFlag

/// 写回前核对出的 “文件已在别处改过”，从后台写操作带回主线程。
final class ChangeFlag: Sendable {
    /// 是否核对出了改动。
    private let value = Mutex(false)

    /// 核对出了改动。
    var isSet: Bool { value.withLock { $0 } }

    /// 记下核对出了改动。
    func set() { value.withLock { $0 = true } }
}

// MARK: - Private

extension RepositorySession {
    /// 目录对比时两侧目录的名字。
    private static func directoryNames(_ comparison: WorkingCopyComparison) -> (left: String, right: String) {
        let workingTree = AppLocalization.text("externalTool.side.workingTree")
        let index = AppLocalization.text("externalTool.side.index")
        let base = AppLocalization.text("externalTool.side.base")

        switch comparison {
        case .workingTreeToBase: return ("HEAD", workingTree)

        case .workingTreeToIndex: return (index, workingTree)

        case .indexToBase: return ("HEAD", index)

        case .oursToTheirs: return (
                AppLocalization.text("externalTool.side.theirs"),
                AppLocalization.text("externalTool.side.mine")
            )

        case .oursToBase: return (base, AppLocalization.text("externalTool.side.mine"))

        case .theirsToBase: return (base, AppLocalization.text("externalTool.side.theirs"))
        }
    }

    /// 准备两侧并启动比较工具；逐个文件比较时依次等每一次退出。
    private static func runDiffTool(
        _ tool: ExternalTool,
        files: [ComparedFile],
        service: ExternalToolFiles,
        versions: (left: FileVersion, right: FileVersion),
        names: (left: String, right: String)
    ) async throws {
        let application = try await installedApplication(of: tool)
        let compareDirectories = UserDefaults.standard.object(forKey: ExternalTool.compareDirectoryKey) as? Bool ?? true

        if files.count > 1, tool.supportsDirectoryDiff, compareDirectories {
            let (left, right) = try await service.directories(
                files,
                left: (versions.left, names.left),
                right: (versions.right, names.right)
            )

            try await launch(tool, .diff(left: left, right: right), application: application)
            return
        }

        for file in files {
            let left = try await service.file(file.originalPath ?? file.path, at: versions.left)
            let right = try await service.file(file.path, at: versions.right)

            try await launch(tool, .diff(left: left, right: right), application: application)
        }
    }

    /// 启动合并工具并等它退出。
    private static func runMergeTool(_ tool: ExternalTool, files: MergeToolFiles) async throws {
        let application = try await installedApplication(of: tool)

        try await launch(
            tool,
            .merge(
                local: files.local,
                remote: files.remote,
                base: files.base,
                merged: files.merged,
                hasBase: files.hasBase
            ),
            application: application
        )
    }

    /// 工具的应用位置；没有安装时抛出可复制原因的启动错误。
    @MainActor
    private static func installedApplication(of tool: ExternalTool) throws -> URL {
        guard let application = tool.applicationURL else {
            throw ExternalToolLaunchError(diagnostic: AppLocalization.text("terminal.notInstalled", tool.displayName))
        }

        return application
    }

    /// 按工具的命令行约定启动一次比较或合并。
    private static func launch(
        _ tool: ExternalTool,
        _ request: ExternalToolRequest,
        application: URL
    ) async throws {
        guard let invocation = tool.invocation(request, application: application) else {
            throw ExternalToolLaunchError(diagnostic: tool.displayName)
        }

        try await ExternalToolLauncher.run(invocation)
    }

    /// 合并工具退出后：命令行先于合并窗口退出的工具等用户说明已完成；有结果就写回，没有结果时提示并重新读取状态。
    private func finishMerge(_ files: MergeToolFiles, tool: ExternalTool) async {
        do {
            if tool.exitsBeforeMergeFinishes, try files.result() == nil {
                guard await confirmMergeFinished(files, tool: tool) else {
                    refresh()
                    return
                }
            }

            guard let result = try files.result() else {
                showNotice(
                    AppLocalization.text("externalTool.noResult"),
                    AppLocalization.text("externalTool.noResult.message", Self.fileName(files.path), tool.displayName)
                )
                refresh()
                return
            }

            applyMergeResult(result, files: files, overwrite: false)
        } catch {
            if let repository { reportOpenFailure(error, in: repository) }
        }
    }

    /// 把合并结果写回工作区；文件在合并期间被别处改过时先询问是否覆盖。
    private func applyMergeResult(_ result: Data, files: MergeToolFiles, overwrite: Bool) {
        let keepBackup = UserDefaults.standard.bool(forKey: ExternalTool.keepBackupsKey)
        let changed = ChangeFlag()

        let started = performGit(
            { runner, _ in
                do {
                    try await WorkingCopyOperations(runner: runner)
                        .applyMergeResult(result, for: files, keepBackup: keepBackup, overwrite: overwrite)
                } catch ExternalToolError.fileChanged {
                    changed.set()
                }
            },
            title: AppLocalization.text("externalTool.openMergeTool"),
            recordsActivity: false,
            success: { [weak self] in
                guard changed.isSet else { return }

                self?.confirmOverwrite(files.path) {
                    self?.applyMergeResult(result, files: files, overwrite: true)
                }
            }
        )

        // 仓库正在执行别的写操作或已断线：结果没有写回，说明原因
        if !started {
            showNotice(AppLocalization.text("externalTool.notApplied"), AppLocalization.text("dialog.blocked"))
        }
    }

    /// 命令行先于合并窗口退出时，等用户在合并工具里保存结果后选择 Done。
    private func confirmMergeFinished(_ files: MergeToolFiles, tool: ExternalTool) async -> Bool {
        guard let window = presentingWindow else {
            return false
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = AppLocalization.text("externalTool.finishMerge", tool.displayName)
        alert.informativeText = AppLocalization.text(
            "externalTool.finishMerge.message",
            tool.displayName,
            Self.fileName(files.path)
        )
        alert.addButton(withTitle: AppLocalization.text("externalTool.done"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    /// 在本会话的窗口上显示一条说明。
    private func showNotice(_ title: String, _ message: String) {
        guard let window = presentingWindow else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: AppLocalization.text("action.close"))
        alert.beginSheetModal(for: window)
    }
}
