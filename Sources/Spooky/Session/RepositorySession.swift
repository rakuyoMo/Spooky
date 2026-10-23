import Foundation
import Observation
import os
import SpookyKit

// MARK: - RepositoryView

/// 当前窗口选中的主视图。
enum RepositoryView: String, CaseIterable {
    /// 工作区状态列表。
    case workingCopy

    /// 分页提交列表与只读提交详情。
    case history
}

// MARK: - StatusRowID

/// 文件行的稳定标识，区分 `rm --cached` 后同路径的已跟踪与未跟踪记录。
struct StatusRowID: Hashable {
    /// Git 给出的相对路径。
    let path: String

    /// 同一路径可以同时拥有已跟踪和未跟踪状态。
    let kind: StatusEntry.Kind
}

// MARK: - InterruptedWrite

/// 因断线而结果未知的写操作；重连核对后据此告诉用户 HEAD 是否变化。
struct InterruptedWrite {
    /// 已本地化的操作名称。
    let title: String

    /// 写入前状态快照中的分支与 HEAD。
    let branch: BranchStatus?

    /// 中断发生的时间，只采用在此之后完成的核对结果。
    let time: Date
}

// MARK: - RepositorySession

/// 一个窗口的仓库读取状态，异步刷新失败时保留完整的上一份快照。
@MainActor
@Observable
final class RepositorySession {
    /// 写操作、刷新失败与重连核对的日志；只记操作名与错误类别，不记路径和 Git 输出。
    private nonisolated static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "RepositorySession")

    /// 历史和引用与工作区共用一个窗口生命周期。
    let history = RepositoryHistoryState()

    /// 当前工作区身份。
    private(set) var repository: RepositoryLocation? = nil

    /// 最近一次成功读取的状态。
    private(set) var status: WorkingCopyStatus? = nil

    /// 服务器连接状态，本机仓库为 nil。
    private(set) var connectionState: RemoteConnectionState? = nil

    /// 写操作断线后的仓库核对结果。
    private(set) var recovery: RemoteRecoverySnapshot? = nil

    /// 断线中断、等待重连核对的写操作。
    private(set) var interruptedWrite: InterruptedWrite? = nil

    /// 写操作期间所有写入口共用锁定状态。
    private(set) var isWriting = false

    /// 标题草稿，失败时保留。
    var commitSubject = ""

    /// 正文草稿，失败时保留。
    var commitBody = ""

    /// 显式修补选项。
    var amend = false

    /// Git 返回的身份和进行中操作。
    private(set) var context: WorkingCopyContext? = nil

    /// 当前文件的补丁快照。
    private(set) var diffSnapshot: DiffSnapshot? = nil

    /// 当前显示哪一侧改动。
    var diffSide = DiffSide.unstaged

    /// 大 Diff 放行只对当前文件有效。
    var showsLargeDiff = false

    /// Diff 加载中仍保留旧内容。
    private(set) var isLoadingDiff = false

    /// Diff 失败显示在详情中，并保留可复制原文。
    private(set) var diffFailure: AppFailure? = nil

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
    var onConfirm: ((String, String, @escaping () -> Void, (() -> Void)?) -> Void)? = nil

    /// 窗口在重连核对完成后向用户报告中断写入的结果；没有新的核对时表示写入没有开始。
    var onRecovery: ((InterruptedWrite, RemoteRecoverySnapshot?) -> Void)? = nil

    /// 写操作结束后通知应用刷新显示同一仓库的其它窗口。
    var onWriteFinished: ((RepositoryLocation) -> Void)? = nil

    /// 恢复的视图状态失效、回到 Working Copy 时，窗口据此重建主视图。
    var onViewReset: (() -> Void)? = nil

    /// 当前窗口的写操作任务。
    private(set) var writeTask: Task<Void, Never>? = nil

    /// 当前主视图。
    var activeView = RepositoryView.workingCopy

    /// 仓库管理中选中的最近记录。
    var selectedRecentLocation: RepositoryLocation? = nil

    /// 是否正在刷新。
    private(set) var isRefreshing = false

    /// 是否正在验证要打开的目录。
    var isOpening = false

    /// 最近一次读取失败，供界面及测试检查。
    private(set) var failure: AppFailure? = nil

    /// 窗口负责呈现错误 sheet。
    var onFailure: ((AppFailure) -> Void)? = nil

    /// 当前刷新任务，关闭仓库时取消。
    private(set) var refreshTask: Task<Void, Never>? = nil

    /// ⌥ 快速修补生效前保存的普通草稿。
    private var originalDraft: (subject: String, body: String)? = nil

    /// 当前文件的读取任务。
    private var diffTask: Task<Void, Never>? = nil

    /// 提交信息与进行中状态的读取任务。
    private var contextTask: Task<Void, Never>? = nil

    /// 本机递归文件监听。
    private var fileMonitor: RepositoryFileMonitor? = nil

    /// 注入状态源的测试不额外访问真实仓库。
    private let loadsRepositoryDetails: Bool

    /// 测试注入隔离配置，生产环境按仓库位置取得共享执行器。
    private let makeRunner: @Sendable (RepositoryLocation) -> GitRunner

    /// 窗口是否活跃，决定状态轮询频率。
    private var isActive = true

    /// 远端状态轮询任务。
    private var pollingTask: Task<Void, Never>? = nil

    /// 连接状态订阅任务。
    private var connectionTask: Task<Void, Never>? = nil

    /// 自动重连任务，重复断线事件共用一次重连。
    private var reconnectTask: Task<Void, Never>? = nil

    /// 刷新进行中收到的完整刷新请求，本次结束后补做。
    private var pendingFullRefresh = false

    /// 当前刷新的身份；写入取消旧刷新后，迟到的收尾不能清掉新刷新。
    private var refreshID = UUID()

    /// 已显示 Diff 对应的工作区内容哈希，服务器轮询据此判断文件内容是否变化。
    private var contentHash: (id: StatusRowID, hash: String?)? = nil

    /// 本窗口打开过的仓库视图状态，切换回仓库时恢复。
    @ObservationIgnored
    private var viewStates = RepositoryViewStateCache()

    /// 快照读取边界，测试可控制响应顺序和失败。
    private let loadStatus: @Sendable (RepositoryLocation) async throws -> WorkingCopyStatus

    /// 请求代数，阻止已取消的旧请求覆盖新仓库。
    private var generation = 0

    /// 连接可用、本窗口没有写操作，且应用内没有同一仓库的写操作时才允许写入。
    var canWrite: Bool {
        guard let repository, !isWriting, !RepositoryWriteLocks.shared.contains(repository) else {
            return false
        }

        return repository.host == nil || connectionState == .connected
    }

    /// 当前选中的文件行。
    var selectedID: StatusRowID? = nil {
        didSet {
            guard selectedID != oldValue else { return }
            showsLargeDiff = false
            diffSnapshot = nil
            diffSide = (selectedEntry?.hasUnstagedChanges ?? false) ? .unstaged : .staged
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
            && (
                amend
                    || context?.operation == .merge
                    || (status?.entries.contains(where: \.hasStagedChanges) ?? false)
            )
    }

    /// 对话框可读取同一执行器，保持本机凭据与测试隔离环境一致。
    var runner: GitRunner? { repository.map(makeRunner) }

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

        // 恢复的引用已不存在时，回到安全的 Working Copy 视图。
        history.onRestoreFailure = { [weak self] in
            self?.activeView = .workingCopy
            self?.onViewReset?()
        }
    }

    /// 切换工作区；同一仓库保留选区和视图，切回打开过的仓库时恢复它的视图状态。
    func display(_ repository: RepositoryLocation) {
        guard self.repository != repository else {
            return
        }

        close()
        self.repository = repository

        // 正在显示的仓库也计入缓存上限，超出时淘汰最久未使用的仓库。
        let saved = viewStates.state(for: repository)
        viewStates.store(saved ?? RepositoryViewState(), for: repository)

        if let saved {
            restore(saved)
        }

        if repository.host != nil {
            observeConnection(repository)
            startPolling()
        } else if loadsRepositoryDetails {
            fileMonitor = RepositoryFileMonitor(path: repository.path) { [weak self] in self?.refresh() }
        }
    }

    /// 读取状态；本机仓库与完整刷新重读全部视图数据，服务器轮询只在状态或所选文件内容变化时连带读取。
    ///
    /// - Parameter full: 是否重读身份、引用、历史与 Diff；写入完成、重连、重新激活和手动刷新使用完整刷新。
    func refresh(full: Bool = false) {
        guard let repository, !isWriting else {
            return
        }

        // 正在刷新时合并请求；完整刷新不能丢弃，留到本次结束后补做。
        guard !isRefreshing else {
            pendingFullRefresh = pendingFullRefresh || full
            return
        }

        let full = full || repository.host == nil
        isRefreshing = true
        failure = nil
        let request = generation
        let id = UUID()
        refreshID = id
        let load = loadStatus
        let previous = status

        // 轮询时顺带读取所选文件的内容哈希，与状态并发，服务器上只占一次往返的等待时间。
        let probe = full || !loadsRepositoryDetails ? nil : selectedEntry.flatMap { $0.kind == .conflicted ? nil : $0 }
        let service = WorkingCopyOperations(runner: makeRunner(repository))

        refreshTask = Task { [weak self] in
            do {
                async let loaded = load(repository)
                async let probed = Self.contentHash(of: probe, service: service)
                let status = try await loaded
                let hash = await probed

                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                let statusChanged = status != previous
                replaceStatus(status)

                // 状态没有变化的轮询不再重复读取身份、引用和 Diff，减少服务器往返。
                if loadsRepositoryDetails {
                    if full || statusChanged {
                        loadContext()
                        history.refresh(status: status, runner: makeRunner(repository), reload: full)
                    }

                    if full || statusChanged || contentChanged(probe, hash: hash) {
                        loadDiff()
                    }
                }
            } catch {
                guard let self, generation == request, !Task.isCancelled else {
                    return
                }

                reportRefreshFailure(error, in: repository)
            }

            guard let self, generation == request, refreshID == id else {
                return
            }

            finishRefresh()
        }
    }

    /// 结束当前读取并清空仓库，视图状态存入窗口缓存；不影响 App 的其它窗口和进程。
    func close() {
        if let repository {
            viewStates.store(captureViewState(), for: repository)
        }

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
        contentHash = nil
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
        interruptedWrite = nil
        refreshTask?.cancel()
        refreshTask = nil
        pendingFullRefresh = false
        repository = nil
        status = nil
        selectedID = nil
        selectedRecentLocation = nil
        failure = nil
        activeView = .workingCopy
        isRefreshing = false
    }

    /// 退出前取消本窗口的全部任务并等待结束，本机子进程与远端操作随之回收。
    func shutdown() async {
        let tasks = [writeTask, refreshTask, diffTask, contextTask, pollingTask, connectionTask, reconnectTask]
            .compactMap { $0 } + history.activeTasks
        close()

        for task in tasks {
            await task.value
        }
    }
}

// MARK: - Connection

extension RepositorySession {
    /// 窗口重新激活后立即完整刷新一次；前后台切换重新计算下一次轮询时间。
    func setActive(_ active: Bool) {
        let wasActive = isActive
        isActive = active

        guard let repository else {
            return
        }

        if repository.host != nil {
            startPolling()
        }

        // 应用激活与窗口成为主窗口会先后通知，只有从后台回到前台时刷新。
        if active, !wasActive {
            refresh(full: true)
        }
    }

    /// 重连失败保留最后快照和原始错误，后台定时重试不阻塞 UI。
    func reconnect() {
        guard
            reconnectTask == nil,
            let repository,
            let remote = GitRunner(location: repository).remote
        else { return }

        let request = generation
        connectionState = .reconnecting
        reconnectTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    _ = try await remote.reconnect()
                    guard let self, generation == request, !Task.isCancelled else { return }
                    reconnectTask = nil
                    await connectionRestored(remote, request: request)
                    return
                } catch {
                    guard let self, generation == request, !Task.isCancelled else { return }
                    connectionState = .unavailable
                    failure = AppFailure(error: error, opening: false, location: repository)
                }

                do { try await Task.sleep(for: RemoteConnection.reconnectInterval) }
                catch { return }

                guard let self, generation == request else { return }
                connectionState = .reconnecting
            }
        }
    }
}

// MARK: - Working Copy

extension RepositorySession {
    /// 勾选框先更新，再执行命令；任何失败都会撤回临时状态。
    func stage(_ entries: [StatusEntry], staged: Bool) {
        guard canWrite, !entries.isEmpty else { return }
        stagingOverrides = Dictionary(uniqueKeysWithValues: entries.map {
            (StatusRowID(path: $0.path, kind: $0.kind), staged)
        })
        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).stage(entries, staged: staged)
            },
            title: AppLocalization.text(staged ? "working.stage" : "working.unstage"),
            recordsActivity: false
        )
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
                guard let self, generation == request else { return }
                performGit(
                    { runner, _ in
                        try await WorkingCopyOperations(runner: runner).discard(entries)
                    },
                    title: AppLocalization.text("working.discard"),
                    recordsActivity: false
                )
            },
            nil
        )
    }

    /// 暂存与丢弃使用正在显示的快照，确认期间的变化由核心库拒绝。
    func apply(file: Int, hunk: Int, lines: Set<Int>, discard: Bool) {
        guard canWrite, let snapshot = diffSnapshot else { return }
        let request = generation

        // 中断报告沿用块头按钮的动作名称。
        let action = discard ? "discard" : (snapshot.side == .staged ? "unstage" : "stage")
        let title = AppLocalization.text(
            "working." + action + (lines.isEmpty ? "Chunk" : (lines.count == 1 ? "Line" : "Lines"))
        )
        let perform: () -> Void = { [weak self] in
            guard let self, generation == request else { return }
            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .apply(
                            snapshot,
                            file: file,
                            hunk: hunk,
                            lines: lines,
                            discard: discard
                        )
                },
                title: title,
                recordsActivity: false
            )
        }

        if discard {
            onConfirm?(
                AppLocalization.text("working.discard"),
                AppLocalization.text(
                    repository?.host == nil ? "working.discard.lines" : "working.discard.remoteLines",
                    repository?.displayPath ?? ""
                ),
                perform,
                nil
            )
        } else {
            perform()
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
            commitSubject = originalDraft.subject
            commitBody = originalDraft.body
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
            guard let self, generation == request else { return }
            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .commit(subject: subject, body: body, amend: amend)
                },
                title: AppLocalization.text(amend ? "working.amend" : "working.commit"),
                recordsActivity: false
            ) { [weak self] in
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
                    guard let self, generation == request else { return }
                    finishOperation("abort")
                }
            )
        } else {
            action()
        }
    }

    /// 采用 Git 的 ours / theirs 语义，变基时界面另行说明两侧含义。
    func resolve(_ entries: [StatusEntry], theirs: Bool) {
        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).resolve(entries, theirs: theirs)
            },
            title: AppLocalization.text(theirs ? "working.theirs" : "working.ours"),
            recordsActivity: false
        )
    }

    /// 横幅仅暴露当前操作的收尾动作。
    func finishOperation(_ action: String) {
        guard let operation = context?.operation else { return }
        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).finish(operation, action: action)
            },
            title: AppLocalization.text("working." + action),
            recordsActivity: false
        )
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

        if diffSide == .staged, !entry.hasStagedChanges { diffSide = .unstaged }
        if diffSide == .unstaged, !entry.hasUnstagedChanges { diffSide = .staged }
        let side = diffSide
        let request = generation
        let showLarge = showsLargeDiff
        let threshold = UserDefaults.standard.object(forKey: "diffWarningKilobytes") as? Int
            ?? WorkingCopyOperations.defaultWarningKilobytes
        let service = WorkingCopyOperations(runner: makeRunner(repository))
        let remote = repository.host != nil
        isLoadingDiff = true
        diffTask = Task { [weak self] in
            do {
                // 服务器先记下内容哈希再读补丁：之后的修改一定使哈希不同，轮询不会漏掉。
                let hash = remote ? try await service.worktreeHash(of: entry) : nil
                let snapshot = try await service.diff(
                    for: entry, side: side, warningKilobytes: threshold, showLarge: showLarge
                )
                guard let self, generation == request, !Task.isCancelled else { return }
                diffSnapshot = snapshot
                contentHash = (StatusRowID(path: entry.path, kind: entry.kind), hash)
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                diffSnapshot = nil
                diffFailure = AppFailure(error: error, opening: false, location: repository)
            }

            guard let self, generation == request, !Task.isCancelled else { return }
            isLoadingDiff = false
        }
    }
}

// MARK: - Write Operations

extension RepositorySession {
    /// 新建、检出、同步和工作区写入共用任务生命周期，取消后仍刷新真实状态。
    ///
    /// - Parameters:
    ///   - title: 已本地化的操作名称，用于 Activity 与断线后的核对报告。
    ///   - recordsActivity: 网络与引用操作记入 Activity；工作区的高频写入只用于核对报告。
    /// - Returns: 是否已开始执行；仓库不可写时不启动，调用方据此保留未发送的参数。
    @discardableResult
    func performGit(
        _ action:
        @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        recordsActivity: Bool = true,
        success: (() -> Void)? = nil
    ) -> Bool {
        guard canWrite, let repository, RepositoryWriteLocks.shared.acquire(repository) else {
            return false
        }

        refreshTask?.cancel()
        refreshTask = nil
        refreshID = UUID()
        contextTask?.cancel()
        contextTask = nil
        diffTask?.cancel()
        history.suspend()
        isRefreshing = false
        pendingFullRefresh = false
        isWriting = true
        let request = generation
        let runner = makeRunner(repository)
        let branch = status?.branch
        let finished = onWriteFinished
        let activity = recordsActivity ? RepositoryActivity(repository: repository, title: title) : nil
        if let activity { RepositoryActivities.shared.insert(activity) }
        let (outputs, continuation) = AsyncStream<GitOutputEvent>.makeStream()
        Self.logger.info("写操作开始：\(title, privacy: .public)")

        writeTask = Task { [weak self] in
            let collector = Task { @MainActor in
                for await output in outputs { activity?.append(output) }
            }

            do {
                try await action(runner) { continuation.yield($0) }
                activity?.state = Task.isCancelled ? "activity.cancelled" : "activity.finished"
                Self.logger.info("写操作\(Task.isCancelled ? "已取消" : "完成", privacy: .public)：\(title, privacy: .public)")

                if let self, generation == request, !Task.isCancelled { success?() }
            } catch {
                let cancelled =
                    Task.isCancelled || error is CancellationError
                        || ((error as? GitError)?.isCancelled ?? false)
                activity?.state = cancelled ? "activity.cancelled" : "activity.failed"

                // 失败的类别在 reportWriteFailure 归类后记录，这里只记取消
                if cancelled { Self.logger.info("写操作已取消：\(title, privacy: .public)") }

                if let self, generation == request {
                    reportWriteFailure(error, cancelled: cancelled, title: title, branch: branch, in: repository)
                }
            }

            continuation.finish()
            await collector.value
            activity?.cancel = nil
            RepositoryWriteLocks.shared.release(repository)
            finished?(repository)

            guard let self, generation == request else { return }
            isWriting = false
            writeTask = nil
            refresh(full: true)
        }

        let task = writeTask
        activity?.cancel = { task?.cancel() }
        return true
    }
}

// MARK: - Private

extension RepositorySession {
    /// 轮询时的所选文件内容哈希；没有可比较的文件或读取失败时为 nil。
    private static func contentHash(of entry: StatusEntry?, service: WorkingCopyOperations) async -> String? {
        guard let entry else {
            return nil
        }

        return try? await service.worktreeHash(of: entry)
    }

    /// 刷新成功后一次性替换快照；仍存在的文件继续选中。
    private func replaceStatus(_ status: WorkingCopyStatus) {
        self.status = status
        if !status.entries.contains(where: { $0.kind == .conflicted }) { onlyConflicts = false }
        stagingOverrides = [:]

        // 暂存会把未跟踪项变为已跟踪项；同路径优先延续选择，双记录仍优先匹配类别。
        func retainedID(_ selected: StatusRowID) -> StatusRowID? {
            let entry = status.entries.first { $0.path == selected.path && $0.kind == selected.kind }
                ?? status.entries.first { $0.path == selected.path }
            return entry.map { StatusRowID(path: $0.path, kind: $0.kind) }
        }

        selectedIDs = Set(selectedIDs.compactMap(retainedID))

        if let selected = selectedID {
            selectedID = retainedID(selected)
        }
    }

    /// 刷新失败时撤回临时勾选并报告错误：取消不报告，断线交给重连，其余错误交给窗口呈现。
    private func reportRefreshFailure(_ error: Error, in repository: RepositoryLocation) {
        // 保留旧快照，错误反馈与数据展示互不覆盖。
        stagingOverrides = [:]

        guard (error as? GitError)?.isCancelled != true, !(error is CancellationError) else {
            return
        }

        let failure = AppFailure(error: error, opening: false, location: repository)
        self.failure = failure
        Self.logger.error("刷新失败，类别 \(failure.kind.rawValue, privacy: .public)")

        if error is RemoteConnectionError {
            reconnect()
        } else {
            onFailure?(failure)
        }
    }

    /// 本次刷新结束：解除刷新状态，并补做刷新期间收到的完整刷新请求。
    private func finishRefresh() {
        isRefreshing = false
        refreshTask = nil

        if pendingFullRefresh {
            pendingFullRefresh = false
            refresh(full: true)
        }
    }

    /// 写入失败时撤回临时勾选并报告错误；服务器写入断线后结果未知，记下中断的写入等待重连核对。
    ///
    /// - Parameters:
    ///   - title: 已本地化的操作名称，用于断线后的核对报告。
    ///   - branch: 写入前状态快照中的分支与 HEAD。
    private func reportWriteFailure(
        _ error: Error,
        cancelled: Bool,
        title: String,
        branch: BranchStatus?,
        in repository: RepositoryLocation
    ) {
        stagingOverrides = [:]

        let remoteFailure = error as? RemoteConnectionError

        // 取消未确认仍须报告；普通取消只回到可刷新状态。
        if !cancelled || remoteFailure?.kind == .cancellationUnconfirmed {
            let failure = AppFailure(error: error, opening: false, location: repository, writing: true)
            self.failure = failure
            Self.logger.error("写操作失败：\(title, privacy: .public)，类别 \(failure.kind.rawValue, privacy: .public)")
            onFailure?(failure)
        }

        // 结果未知的服务器写入不重试，等待重连核对后再报告。
        if remoteFailure != nil {
            interruptedWrite = InterruptedWrite(title: title, branch: branch, time: Date())
            Self.logger.error("服务器写入在断线中中断，等待重连核对：\(title, privacy: .public)")
            reconnect()
        }
    }

    /// 所选文件与已显示 Diff 的记录一致、但内容哈希不同，说明需要重读 Diff。
    private func contentChanged(_ entry: StatusEntry?, hash: String?) -> Bool {
        guard
            let entry, let contentHash,
            contentHash.id == StatusRowID(path: entry.path, kind: entry.kind)
        else { return false }

        return contentHash.hash != hash
    }

    /// 重连成功后丢弃断线前的推断状态，报告中断写入的核对结果并完整刷新。
    private func connectionRestored(_ remote: RemoteConnection, request: Int) async {
        let recovery = await remote.recovery

        guard generation == request else {
            return
        }

        connectionState = .connected
        failure = nil
        stagingOverrides = [:]
        self.recovery = recovery

        // 只采用中断之后完成的核对；没有新的核对说明写入没有在服务器上开始。
        if let interruptedWrite {
            let checked = recovery.flatMap { $0.checkedAt >= interruptedWrite.time ? $0 : nil }
            self.interruptedWrite = nil
            Self.logger
                .info(
                    "中断的写入已核对：\(interruptedWrite.title, privacy: .public)，\(checked == nil ? "未在服务器上开始" : "取得中断后的核对结果", privacy: .public)"
                )
            onRecovery?(interruptedWrite, checked)
        }

        refresh(full: true)
    }

    /// 身份与状态加载失败仍展示诊断，不能误把未知状态当成普通改动。
    private func loadContext() {
        guard contextTask == nil, let repository else { return }
        let request = generation
        let head = status?.branch.oid
        let service = WorkingCopyOperations(runner: makeRunner(repository))
        contextTask = Task { [weak self] in
            do {
                let context = try await service.context(head: head)
                guard let self, generation == request, !Task.isCancelled else { return }
                let previous = self.context?.operation
                self.context = context

                if previous != context.operation, context.operation != nil, commitSubject.isEmpty {
                    setMessage(context.mergeMessage)
                }
            } catch {
                guard let self, generation == request, !Task.isCancelled else { return }
                let failure = AppFailure(error: error, opening: false, location: repository)
                self.failure = failure

                // 读取中断线由连接横幅和重连接管，不额外弹出 sheet。
                if error is RemoteConnectionError {
                    reconnect()
                } else {
                    onFailure?(failure)
                }
            }

            guard let self, generation == request else { return }
            contextTask = nil
        }
    }

    /// 第一行成为标题，正文保留内部换行。
    private func setMessage(_ message: String) {
        let parts = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        commitSubject = parts.first.map(String.init) ?? ""
        commitBody = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .newlines) : ""
    }

    /// 当前仓库的视图状态，切换仓库时存入窗口缓存。
    private func captureViewState() -> RepositoryViewState {
        RepositoryViewState(
            activeView: activeView,
            selectedID: selectedID,
            selectedIDs: selectedIDs,
            diffSide: diffSide,
            commitSubject: commitSubject,
            commitBody: commitBody,
            amend: amend,
            originalDraft: originalDraft,
            onlyConflicts: onlyConflicts,
            historyReferences: history.selectedReferences,
            historyCommits: history.selectedIDs
        )
    }

    /// 切回仓库时恢复视图状态；数据随后重新读取，失效的选区由刷新结果过滤。
    private func restore(_ state: RepositoryViewState) {
        activeView = state.activeView
        commitSubject = state.commitSubject
        commitBody = state.commitBody
        amend = state.amend
        originalDraft = state.originalDraft
        onlyConflicts = state.onlyConflicts
        selectedIDs = state.selectedIDs

        // 先恢复选中行再恢复暂存侧，选中行的变更回调会重置暂存侧。
        selectedID = state.selectedID
        diffSide = state.diffSide
        history.restore(references: state.historyReferences, commits: state.historyCommits)
    }

    /// 状态事件由主连接检测产生，即使没有手动刷新也能观察断线与其它窗口发起的重连。
    private func observeConnection(_ repository: RepositoryLocation) {
        guard let remote = GitRunner(location: repository).remote else { return }
        let request = generation

        connectionTask = Task { [weak self] in
            for await state in await remote.states() {
                guard let self, generation == request, !Task.isCancelled else { return }
                let previous = connectionState
                connectionState = state

                if state == .unavailable {
                    if let error = await remote.failure {
                        failure = AppFailure(error: error, opening: false, location: repository)
                    }

                    reconnect()
                }

                // 重连由其它窗口完成时同样完整刷新；本窗口的重连任务自行处理。
                if state == .connected, previous != nil, previous != .connected, reconnectTask == nil {
                    await connectionRestored(remote, request: request)
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

                guard let self, repository?.host != nil else { return }
                if connectionState == .connected { refresh() }
            }
        }
    }
}
