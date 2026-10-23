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

    /// 储藏列表与只读储藏详情。
    case stashes

    /// 一个文件的提交时间线与所选版本的详情。
    case fileHistory

    /// 某个版本的文件原文与逐行追溯。
    case fileContent

    /// 工具栏搜索框只作用于提供列表过滤的视图，其余视图中禁用。
    var supportsSearch: Bool {
        switch self {
        case .history, .fileContent: false
        case .workingCopy, .stashes, .fileHistory: true
        }
    }
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

    /// 储藏列表、选择与储藏详情。
    let stashes = RepositoryStashState()

    /// 文件历史的时间线、筛选与详情。
    let fileHistory = FileHistoryState()

    /// 文件原文与逐行追溯。
    let fileContent = FileContentState()

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

    /// Diff 底栏的显示整个文件开关，只属于本窗口的工作区视图，不写偏好。
    var diffShowsEntireFile = false

    /// Diff 加载中仍保留旧内容。
    private(set) var isLoadingDiff = false

    /// Diff 失败显示在详情中，并保留可复制原文。
    private(set) var diffFailure: AppFailure? = nil

    /// 点击勾选框后的临时状态，刷新成功或失败后撤回。
    var stagingOverrides: [StatusRowID: Bool] = [:]

    /// 列表多选使用的稳定标识。
    var selectedIDs: Set<StatusRowID> = []

    /// 横幅的冲突过滤选项。
    var onlyConflicts = false

    /// 冲突向导在各仓库生成、尚未清理的备份文件，切换仓库后仍保留，供向导与横幅列出和清理。
    var conflictBackups: [RepositoryLocation: [String]] = [:]

    /// 主菜单请求聚焦提交标题。
    var commitFocusRequest = 0

    /// 窗口快捷键只在编辑信息或按住 ⌥ 时提交。
    var isEditingCommitMessage = false

    /// 提交区使用的身份、签名、注释字符与钩子配置。
    var commitConfiguration: CommitConfiguration? = nil

    /// 读取提交配置的任务。
    var configurationTask: Task<Void, Never>? = nil

    /// 本次提交跳过 pre-commit 与 commit-msg 钩子，只对当前仓库有效。
    var skipHooks = false

    /// 窗口询问注释行的处理方式；参数为去掉注释后信息是否为空，用户取消时不回调。
    var onCommentPrompt: ((Bool, @escaping (CommentHandling) -> Void) -> Void)? = nil

    /// 窗口负责确认并在 sheet 关闭后执行操作。
    var onConfirm: ((String, String, @escaping () -> Void, (() -> Void)?) -> Void)? = nil

    /// 窗口在重连核对完成后向用户报告中断写入的结果；没有新的核对时表示写入没有开始。
    var onRecovery: ((InterruptedWrite, RemoteRecoverySnapshot?) -> Void)? = nil

    /// 写操作结束后通知应用刷新显示同一仓库的其它窗口。
    var onWriteFinished: ((RepositoryLocation) -> Void)? = nil

    /// 恢复的视图状态失效、回到 Working Copy 时，窗口据此重建主视图。
    var onViewReset: (() -> Void)? = nil

    /// 文件视图与提交详情的入口在内容区里切换主视图，窗口据此重建分栏。
    var onActiveViewChange: (() -> Void)? = nil

    /// 当前窗口的写操作任务。
    private(set) var writeTask: Task<Void, Never>? = nil

    /// 当前主视图；切换视图时清空搜索，过滤不会在看不到搜索框内容的视图里生效。
    var activeView = RepositoryView.workingCopy {
        didSet {
            if activeView != oldValue { searchText = "" }
        }
    }

    /// 工具栏搜索框的内容，过滤当前主视图的列表。
    var searchText = ""

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

    /// 窗口负责呈现储藏的对话框。
    var onStashRequest: ((StashRequest) -> Void)? = nil

    /// 当前刷新任务，关闭仓库时取消。
    private(set) var refreshTask: Task<Void, Never>? = nil

    /// ⌥ 快速修补生效前保存的普通草稿。
    var originalDraft: (subject: String, body: String)? = nil

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

    /// 当前仓库交给本机程序打开的文件副本，关闭仓库时删除。
    @ObservationIgnored
    private(set) var fileCache: RepositoryFileCache? = nil

    /// 工作区列表按仓库记住的显示模式。
    var listMode = WorkingCopyListMode.list

    /// 显示全部文件、被忽略与 assume-unchanged 文件时补充的清单。
    var workingTreeFiles = WorkingTreeFileListing()

    /// 补充清单的读取任务，关闭仓库时取消。
    @ObservationIgnored
    var workingTreeFilesTask: Task<Void, Never>? = nil

    /// 树形列表里单独选中的目录，右栏据此显示目录说明；选中文件时为 nil。
    var selectedDirectory: String? = nil

    /// 窗口负责呈现文件操作的参数表单与多按钮询问。
    var onFileRequest: ((WorkingCopyFileRequest) -> Void)? = nil

    /// 快照读取边界，测试可控制响应顺序和失败。
    private let loadStatus: @Sendable (RepositoryLocation) async throws -> WorkingCopyStatus

    /// 请求代数，阻止已取消的旧请求覆盖新仓库。
    private(set) var generation = 0

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
        fileCache = RepositoryFileCache(runner: makeRunner(repository))

        // 工作区列表沿用这个仓库上次选择的显示模式
        listMode = WorkingCopyListMode.stored(for: repository)

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
        let probe = full || !loadsRepositoryDetails ? nil : selectedEntry.flatMap { $0.hasWorkingCopyDiff ? $0 : nil }
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

                // 状态没有变化的轮询不再重复读取身份、引用、补充清单和 Diff，减少服务器往返。
                if loadsRepositoryDetails {
                    if full || statusChanged {
                        loadContext()
                        loadCommitConfiguration()
                        history.refresh(status: status, runner: makeRunner(repository), reload: full)
                        stashes.refresh(runner: makeRunner(repository))
                        loadWorkingTreeFiles()
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
        stashes.close()
        fileHistory.close()
        fileContent.close()
        fileMonitor?.stop()
        fileMonitor = nil
        fileCache?.removeAll()
        fileCache = nil
        workingTreeFilesTask?.cancel()
        workingTreeFilesTask = nil
        workingTreeFiles = WorkingTreeFileListing()
        selectedDirectory = nil
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
        resetCommitConfiguration()
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
        searchText = ""
        isRefreshing = false
    }

    /// 退出前取消本窗口的全部任务并等待结束，本机子进程与远端操作随之回收。
    func shutdown() async {
        let tasks = [writeTask, refreshTask, diffTask, contextTask, pollingTask, connectionTask, reconnectTask]
            .compactMap { $0 } + history.activeTasks + stashes.activeTasks
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

// MARK: - Diff

extension RepositorySession {
    /// 选区或暂存侧变化后取消旧 Diff，较晚完成的旧请求不会覆盖新选择。
    func loadDiff() {
        diffTask?.cancel()
        diffFailure = nil
        guard loadsRepositoryDetails, let repository, let entry = selectedEntry, entry.hasWorkingCopyDiff else {
            diffSnapshot = nil
            isLoadingDiff = false
            return
        }

        if diffSide == .staged, !entry.hasStagedChanges { diffSide = .unstaged }
        if diffSide == .unstaged, !entry.hasUnstagedChanges { diffSide = .staged }
        let side = diffSide
        let request = generation
        let showLarge = showsLargeDiff

        // 上下文与忽略空白取全局偏好，显示整个文件取本窗口的底栏开关
        let options = DiffPreferences.options(showsEntireFile: diffShowsEntireFile)

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
                    for: entry,
                    side: side,
                    options: options,
                    warningKilobytes: threshold,
                    showLarge: showLarge
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
    ///   - offersAutoStash: 被本地改动挡住时是否按设置询问先储藏，检出、拉取与合并使用。
    /// - Returns: 是否已开始执行；仓库不可写时不启动，调用方据此保留未发送的参数。
    @discardableResult
    func performGit(
        _ action:
        @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        recordsActivity: Bool = true,
        offersAutoStash: Bool = false,
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
        stashes.suspend()
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

                // 被本地改动挡住的检出、拉取与合并改为询问是否先储藏，用户不储藏时再报告失败
                if let self, generation == request {
                    if !(offersAutoStash && !cancelled && offerAutoStash(after: error, title: title, action: action)) {
                        reportWriteFailure(error, cancelled: cancelled, title: title, branch: branch, in: repository)
                    }
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

        // 跟随 HEAD 的文件视图只在 HEAD 移动后重读
        fileHistory.update(head: status.branch.oid)
        fileContent.update(head: status.branch.oid)

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

    /// 当前仓库的视图状态，切换仓库时存入窗口缓存。
    private func captureViewState() -> RepositoryViewState {
        RepositoryViewState(
            // 文件视图的目标不随仓库保存，切回时显示它们所属的历史
            activeView: [.fileHistory, .fileContent].contains(activeView) ? .history : activeView,
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
