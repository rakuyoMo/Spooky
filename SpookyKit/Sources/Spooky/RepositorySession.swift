import Foundation
import Observation
import SpookyKit

/// 当前窗口选中的主视图。
enum RepositoryView: String, CaseIterable {
    /// 工作区状态列表。
    case workingCopy

    /// 分页提交列表与只读提交详情。
    case history
}

/// 文件行的稳定标识，区分 `rm --cached` 后同路径的已跟踪与未跟踪记录。
struct StatusRowID: Hashable {
    /// Git 给出的相对路径。
    let path: String

    /// 同一路径可以同时拥有已跟踪和未跟踪状态。
    let kind: StatusEntry.Kind
}

/// 一个窗口的仓库读取状态，异步刷新失败时保留完整的上一份快照。
@MainActor
@Observable
final class RepositorySession {
    /// 历史和引用与工作区共用一个窗口生命周期。
    let history = RepositoryHistoryState()

    /// 当前工作区身份。
    private(set) var repository: RepositoryLocation?

    /// 最近一次成功读取的状态。
    private(set) var status: WorkingCopyStatus?

    /// 服务器连接状态，本机仓库为 nil。
    private(set) var connectionState: RemoteConnectionState?

    /// 写操作断线后的仓库核对结果。
    private(set) var recovery: RemoteRecoverySnapshot?

    /// 仅连接可用时允许远端写入。
    var canWrite: Bool {
        repository != nil && !isWriting && (repository?.host == nil || connectionState == .connected)
    }

    /// 写操作期间所有写入口共用锁定状态。
    private(set) var isWriting = false

    /// 标题草稿，失败时保留。
    var commitSubject = ""

    /// 正文草稿，失败时保留。
    var commitBody = ""

    /// 显式修补选项。
    var amend = false

    /// ⌥ 快速修补生效前保存的普通草稿。
    private var originalDraft: (String, String)?

    /// Git 返回的身份和进行中操作。
    private(set) var context: WorkingCopyContext?

    /// 当前文件的补丁快照。
    private(set) var diffSnapshot: DiffSnapshot?

    /// 当前显示哪一侧改动。
    var diffSide: DiffSide = .unstaged

    /// 大 Diff 放行只对当前文件有效。
    var showsLargeDiff = false

    /// Diff 加载中仍保留旧内容。
    private(set) var isLoadingDiff = false

    /// Diff 失败显示在详情中，并保留可复制原文。
    private(set) var diffFailure: AppFailure?

    /// 点击勾选框后的临时状态，刷新成功或失败后撤回。
    private(set) var stagingOverrides: [StatusRowID: Bool] = [:]

    /// 列表多选使用的稳定标识。
    var selectedIDs: Set<StatusRowID> = []

    /// 横幅的冲突过滤选项。
    var onlyConflicts = false

    /// 主菜单请求聚焦提交标题。
    var commitFocusRequest = 0

    /// 窗口快捷键只在编辑信息或按住 ⌥ 时提交。
    var isEditingCommitMessage = false

    /// 窗口负责确认并在 sheet 关闭后执行操作。
    var onConfirm: ((String, String, @escaping () -> Void, (() -> Void)?) -> Void)?

    /// 当前窗口的写操作任务。
    private(set) var writeTask: Task<Void, Never>?

    /// 当前文件的读取任务。
    private var diffTask: Task<Void, Never>?

    /// 提交信息与进行中状态的读取任务。
    private var contextTask: Task<Void, Never>?

    /// 本机递归文件监听。
    private var fileMonitor: RepositoryFileMonitor?

    /// 注入状态源的测试不额外访问真实仓库。
    private let loadsRepositoryDetails: Bool

    /// 测试注入隔离配置，生产环境按仓库位置取得共享执行器。
    private let makeRunner: @Sendable (RepositoryLocation) -> GitRunner

    /// 窗口是否活跃，决定状态轮询频率。
    private var isActive = true

    /// 远端状态轮询任务。
    private var pollingTask: Task<Void, Never>?

    /// 连接状态订阅任务。
    private var connectionTask: Task<Void, Never>?

    /// 自动重连任务，重复断线事件共用一次重连。
    private var reconnectTask: Task<Void, Never>?

    /// 当前主视图。
    var activeView = RepositoryView.workingCopy

    /// 当前选中的文件行。
    var selectedID: StatusRowID? {
        didSet {
            guard selectedID != oldValue else { return }
            showsLargeDiff = false
            diffSnapshot = nil
            diffSide = selectedEntry?.hasUnstagedChanges == true ? .unstaged : .staged
            loadDiff()
        }
    }

    /// 当前详情对应的条目，Unicode 等价路径沿用 Swift 的规范等价比较。
    var selectedEntry: StatusEntry? {
        status?.entries.first { $0.path == selectedID?.path && $0.kind == selectedID?.kind }
    }

    /// 批量动作对应当前多选；单选详情也可从菜单操作。
    var selectedEntries: [StatusEntry] {
        status?.entries.filter {
            selectedIDs.contains(StatusRowID(path: $0.path, kind: $0.kind))
                || (selectedIDs.isEmpty && $0.path == selectedID?.path && $0.kind == selectedID?.kind)
        } ?? []
    }

    /// 未解决冲突期间不允许提交或修补。
    var conflictCount: Int { status?.entries.filter { $0.kind == .conflicted }.count ?? 0 }

    /// 有标题、有暂存改动或可修补的 HEAD 时允许提交；合并可产生空树差异。
    var canCommit: Bool {
        canWrite && conflictCount == 0 && !commitSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (amend || context?.operation == .merge || status?.entries.contains(where: \.hasStagedChanges) == true)
    }

    /// 仓库管理中选中的最近记录。
    var selectedRecentLocation: RepositoryLocation?

    /// 是否正在刷新。
    private(set) var isRefreshing = false

    /// 是否正在验证要打开的目录。
    var isOpening = false

    /// 最近一次读取失败，供界面及测试检查。
    private(set) var failure: AppFailure?

    /// 窗口负责呈现错误 sheet。
    var onFailure: ((AppFailure) -> Void)?

    /// 当前刷新任务，关闭仓库时取消。
    private(set) var refreshTask: Task<Void, Never>?

    /// 快照读取边界，测试可控制响应顺序和失败。
    private let loadStatus: @Sendable (RepositoryLocation) async throws -> WorkingCopyStatus

    /// 请求代数，阻止已取消的旧请求覆盖新仓库。
    private var generation = 0

    /// 创建窗口状态；生产环境的所有 Git 读取都经过核心命令层。
    init(
        makeRunner: @escaping @Sendable (RepositoryLocation) -> GitRunner = {
            var runner = GitRunner(location: $0)
            runner.credentialHandler = { await RemoteCallbackPresenter.shared.respond(to: $0) }
            return runner
        },
        loadStatus: (@Sendable (RepositoryLocation) async throws -> WorkingCopyStatus)? = nil
    ) {
        self.makeRunner = makeRunner
        self.loadStatus = loadStatus ?? { try await makeRunner($0).status() }
        loadsRepositoryDetails = loadStatus == nil
    }

    /// 切换工作区；同一仓库保留选区和视图。
    func display(_ repository: RepositoryLocation) {
        guard self.repository != repository else {
            return
        }

        close()
        self.repository = repository

        if repository.host != nil {
            observeConnection(repository)
            startPolling()
        } else if loadsRepositoryDetails {
            fileMonitor = RepositoryFileMonitor(path: repository.path) { [weak self] in self?.refresh() }
        }
    }

    /// 读取一次状态，同一窗口的重复刷新合并到正在执行的任务。
    func refresh() {
        guard let repository, !isRefreshing, !isWriting else {
            return
        }

        isRefreshing = true
        failure = nil
        let request = generation
        let load = loadStatus

        refreshTask = Task { [weak self] in
            do {
                let status = try await load(repository)

                guard let self, self.generation == request, !Task.isCancelled else {
                    return
                }

                // 成功后一次性替换快照；仍存在的文件继续选中。
                self.status = status
                if !status.entries.contains(where: { $0.kind == .conflicted }) { self.onlyConflicts = false }
                self.stagingOverrides = [:]

                // 暂存会把未跟踪项变为已跟踪项；同路径优先延续选择，双记录仍优先匹配类别。
                func retainedID(_ selected: StatusRowID) -> StatusRowID? {
                    let entry = status.entries.first { $0.path == selected.path && $0.kind == selected.kind }
                        ?? status.entries.first { $0.path == selected.path }
                    return entry.map { StatusRowID(path: $0.path, kind: $0.kind) }
                }

                self.selectedIDs = Set(self.selectedIDs.compactMap(retainedID))

                if let selected = self.selectedID {
                    self.selectedID = retainedID(selected)
                }

                if self.loadsRepositoryDetails {
                    self.loadContext()
                    self.loadDiff()
                    self.history.refresh(status: status, runner: self.makeRunner(repository))
                }
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else {
                    return
                }

                // 保留旧快照，错误反馈与数据展示互不覆盖。
                self.stagingOverrides = [:]
                if (error as? GitError)?.isCancelled != true, !(error is CancellationError) {
                    let failure = AppFailure(error: error, opening: false)
                    self.failure = failure
                    if error is RemoteConnectionError {
                        self.reconnect()
                    } else {
                        self.onFailure?(failure)
                    }
                }
            }

            guard let self, self.generation == request else {
                return
            }

            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    /// 结束当前读取并清空仓库，不影响 App 的其它窗口和进程。
    func close() {
        generation += 1
        history.close()
        fileMonitor?.stop()
        fileMonitor = nil
        writeTask?.cancel()
        diffTask?.cancel()
        contextTask?.cancel()
        writeTask = nil
        diffTask = nil
        contextTask = nil
        isWriting = false
        isLoadingDiff = false
        context = nil
        diffSnapshot = nil
        diffFailure = nil
        stagingOverrides = [:]
        selectedIDs = []
        commitSubject = ""
        commitBody = ""
        amend = false
        originalDraft = nil
        onlyConflicts = false
        isEditingCommitMessage = false
        pollingTask?.cancel()
        connectionTask?.cancel()
        reconnectTask?.cancel()
        pollingTask = nil
        connectionTask = nil
        reconnectTask = nil
        connectionState = nil
        recovery = nil
        refreshTask?.cancel()
        refreshTask = nil
        repository = nil
        status = nil
        selectedID = nil
        selectedRecentLocation = nil
        failure = nil
        activeView = .workingCopy
        isRefreshing = false
    }

    /// 窗口重新激活后立即读取；前后台切换重新计算下一次轮询时间。
    func setActive(_ active: Bool) {
        isActive = active
        if active, repository?.host == nil { refresh() }
        guard repository?.host != nil else { return }
        startPolling()

        if active { refresh() }
    }

    /// 重连失败保留最后快照和原始错误，后台定时重试不阻塞 UI。
    func reconnect() {
        guard reconnectTask == nil,
              let repository,
              let remote = GitRunner(location: repository).remote
        else { return }

        let request = generation
        connectionState = .reconnecting
        reconnectTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    _ = try await remote.reconnect()
                    guard let self, self.generation == request, !Task.isCancelled else { return }
                    self.connectionState = .connected
                    self.recovery = await remote.recovery
                    self.failure = nil
                    self.reconnectTask = nil
                    self.refresh()
                    return
                } catch {
                    guard let self, self.generation == request, !Task.isCancelled else { return }
                    self.connectionState = .unavailable
                    self.failure = AppFailure(error: error, opening: false)
                }

                do { try await Task.sleep(for: RemoteConnection.reconnectInterval) }
                catch { return }

                guard let self, self.generation == request else { return }
                self.connectionState = .reconnecting
            }
        }
    }

    /// 勾选框先更新，再执行命令；任何失败都会撤回临时状态。
    func stage(_ entries: [StatusEntry], staged: Bool) {
        guard canWrite, !entries.isEmpty else { return }
        stagingOverrides = Dictionary(uniqueKeysWithValues: entries.map {
            (StatusRowID(path: $0.path, kind: $0.kind), staged)
        })
        performGit { runner, _ in
            try await WorkingCopyOperations(runner: runner).stage(entries, staged: staged)
        }
    }

    /// 全部动作同时供主菜单、工具栏与提交区调用。
    func stageAll(staged: Bool) {
        stage(status?.entries.filter { staged ? $0.hasUnstagedChanges : $0.hasStagedChanges } ?? [], staged: staged)
    }

    /// 丢弃确认点名目标机器，关闭 sheet 后才开始 Git 操作。
    func discard(_ entries: [StatusEntry]) {
        guard canWrite, !entries.isEmpty else { return }
        let request = generation
        let message = AppLocalization.text(
            repository?.host == nil ? "working.discard.message" : "working.discard.remote",
            entries.count,
            repository?.displayPath ?? ""
        )
        onConfirm?(
            AppLocalization.text("working.discard"),
            message,
            { [weak self] in
                guard let self, self.generation == request else { return }
                self.performGit { runner, _ in
                    try await WorkingCopyOperations(runner: runner).discard(entries)
                }
            },
            nil
        )
    }

    /// 暂存与丢弃使用正在显示的快照，确认期间的变化由核心库拒绝。
    func apply(file: Int, hunk: Int, lines: Set<Int>, discard: Bool) {
        guard canWrite, let snapshot = diffSnapshot else { return }
        let request = generation
        let action: () -> Void = { [weak self] in
            guard let self, self.generation == request else { return }
            self.performGit { runner, _ in
                try await WorkingCopyOperations(runner: runner)
                    .apply(
                        snapshot,
                        file: file,
                        hunk: hunk,
                        lines: lines,
                        discard: discard
                    )
            }
        }

        if discard {
            onConfirm?(
                AppLocalization.text("working.discard"),
                AppLocalization.text(
                    repository?.host == nil ? "working.discard.lines" : "working.discard.remoteLines",
                    repository?.displayPath ?? ""
                ),
                action,
                nil
            )
        } else {
            action()
        }
    }

    /// 修补载入最近信息，退出修补时恢复普通提交草稿。
    func setAmend(_ enabled: Bool) {
        guard enabled != amend else { return }

        if enabled {
            guard status?.branch.oid != nil, context?.operation == nil, let context else { return }
            originalDraft = (commitSubject, commitBody)
            setMessage(context.lastMessage)
        } else if let originalDraft {
            commitSubject = originalDraft.0
            commitBody = originalDraft.1
            self.originalDraft = nil
        }

        amend = enabled
    }

    /// 提交失败保留草稿，修补必须先明确确认改写最近提交。
    func commit() {
        guard canCommit else { return }
        let subject = commitSubject
        let body = commitBody
        let amend = amend
        let request = generation
        let action: () -> Void = { [weak self] in
            guard let self, self.generation == request else { return }
            self.performGit({ runner, _ in
                try await WorkingCopyOperations(runner: runner)
                    .commit(subject: subject, body: body, amend: amend)
            }) { [weak self] in
                self?.commitSubject = ""
                self?.commitBody = ""
                self?.amend = false
                self?.originalDraft = nil
            }
        }

        if amend {
            onConfirm?(
                AppLocalization.text("working.amend"),
                AppLocalization.text("working.amend.confirm"),
                action,
                nil
            )
        } else if context?.operation == .merge, status?.entries.contains(where: \.hasStagedChanges) != true {
            onConfirm?(
                AppLocalization.text("working.emptyMerge"),
                AppLocalization.text("working.emptyMerge.message"),
                action,
                { [weak self] in
                    guard let self, self.generation == request else { return }
                    self.finishOperation("abort")
                }
            )
        } else {
            action()
        }
    }

    /// 采用 Git 的 ours / theirs 语义，变基时界面另行说明两侧含义。
    func resolve(_ entries: [StatusEntry], theirs: Bool) {
        performGit { runner, _ in
            try await WorkingCopyOperations(runner: runner).resolve(entries, theirs: theirs)
        }
    }

    /// 横幅仅暴露当前操作的收尾动作。
    func finishOperation(_ action: String) {
        guard let operation = context?.operation else { return }
        performGit { runner, _ in
            try await WorkingCopyOperations(runner: runner).finish(operation, action: action)
        }
    }

    /// 选区或暂存侧变化后取消旧 Diff，较晚完成的旧请求不会覆盖新选择。
    func loadDiff() {
        diffTask?.cancel()
        diffFailure = nil
        guard loadsRepositoryDetails, let repository, let entry = selectedEntry, entry.kind != .conflicted else {
            diffSnapshot = nil
            isLoadingDiff = false
            return
        }

        if diffSide == .staged && !entry.hasStagedChanges { diffSide = .unstaged }
        if diffSide == .unstaged && !entry.hasUnstagedChanges { diffSide = .staged }
        let side = diffSide
        let request = generation
        let showLarge = showsLargeDiff
        let threshold = UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
            ?? WorkingCopyOperations.defaultWarningKilobytes
        let service = WorkingCopyOperations(runner: makeRunner(repository))
        isLoadingDiff = true
        diffTask = Task { [weak self] in
            do {
                let snapshot = try await service.diff(
                    for: entry, side: side, warningKilobytes: threshold, showLarge: showLarge
                )
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.diffSnapshot = snapshot
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.diffSnapshot = nil
                self.diffFailure = AppFailure(error: error, opening: false)
            }

            guard let self, self.generation == request, !Task.isCancelled else { return }
            self.isLoadingDiff = false
        }
    }

    /// 对话框可读取同一执行器，保持本机凭据与测试隔离环境一致。
    var runner: GitRunner? { repository.map(makeRunner) }

    /// 新建、检出、同步和工作区写入共用任务生命周期，取消后仍刷新真实状态。
    func performGit(
        _ action:
            @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String? = nil,
        success: (() -> Void)? = nil
    ) {
        guard canWrite, let repository else { return }
        refreshTask?.cancel()
        contextTask?.cancel()
        contextTask = nil
        diffTask?.cancel()
        history.suspend()
        isRefreshing = false
        isWriting = true
        let request = generation
        let runner = makeRunner(repository)
        let activity = title.map { RepositoryActivity(repository: repository, title: $0) }
        if let activity { RepositoryActivities.shared.items.insert(activity, at: 0) }
        let (outputs, continuation) = AsyncStream<GitOutputEvent>.makeStream()
        writeTask = Task { [weak self] in
            let collector = Task { @MainActor in
                for await output in outputs { activity?.append(output) }
            }

            do {
                try await action(runner) { continuation.yield($0) }
                activity?.state = Task.isCancelled ? "activity.cancelled" : "activity.finished"
                if let self, self.generation == request, !Task.isCancelled { success?() }
            } catch {
                let cancelled =
                    Task.isCancelled || error is CancellationError
                    || (error as? GitError)?.isCancelled == true
                activity?.state = cancelled ? "activity.cancelled" : "activity.failed"

                if let self, self.generation == request {
                    self.stagingOverrides = [:]

                    // 取消未确认仍须报告；普通取消只回到可刷新状态。
                    if !cancelled || (error as? RemoteConnectionError)?.kind == .cancellationUnconfirmed {
                        let failure = AppFailure(error: error, opening: false)
                        self.failure = failure
                        self.onFailure?(failure)
                    }
                    if error is RemoteConnectionError { self.reconnect() }
                }
            }

            continuation.finish()
            await collector.value
            activity?.cancel = nil

            guard let self, self.generation == request else { return }
            self.isWriting = false
            self.writeTask = nil
            self.refresh()
        }
        let task = writeTask
        activity?.cancel = { task?.cancel() }
    }

    /// 身份与状态加载失败仍展示诊断，不能误把未知状态当成普通改动。
    private func loadContext() {
        guard contextTask == nil, let repository else { return }
        let request = generation
        let hasHead = status?.branch.oid != nil
        let service = WorkingCopyOperations(runner: makeRunner(repository))
        contextTask = Task { [weak self] in
            do {
                let context = try await service.context(hasHead: hasHead)
                guard let self, self.generation == request, !Task.isCancelled else { return }
                let previous = self.context?.operation
                self.context = context

                if previous != context.operation, context.operation != nil, self.commitSubject.isEmpty {
                    self.setMessage(context.mergeMessage)
                }
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.failure = AppFailure(error: error, opening: false)
                self.onFailure?(self.failure!)
            }

            guard let self, self.generation == request else { return }
            self.contextTask = nil
        }
    }

    /// 第一行成为标题，正文保留内部换行。
    private func setMessage(_ message: String) {
        let parts = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        commitSubject = parts.first.map(String.init) ?? ""
        commitBody = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .newlines) : ""
    }

    /// 状态事件由主连接检测产生，即使没有手动刷新也能观察断线。
    private func observeConnection(_ repository: RepositoryLocation) {
        guard let remote = GitRunner(location: repository).remote else { return }
        let request = generation

        connectionTask = Task { [weak self] in
            for await state in await remote.states() {
                guard let self, self.generation == request, !Task.isCancelled else { return }
                self.connectionState = state

                if state == .unavailable {
                    if let error = await remote.failure {
                        self.failure = AppFailure(error: error, opening: false)
                    }

                    self.reconnect()
                }
            }
        }
    }

    /// 轮询只读状态，任何失败都不重放写操作。
    private func startPolling() {
        pollingTask?.cancel()
        let interval = isActive
            ? RemoteConnection.foregroundPollInterval
            : RemoteConnection.backgroundPollInterval

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) }
                catch { return }

                guard let self, self.repository?.host != nil else { return }
                if self.connectionState == .connected { self.refresh() }
            }
        }
    }
}
