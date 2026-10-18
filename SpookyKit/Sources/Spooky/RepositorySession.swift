import Foundation
import Observation
import SpookyKit

/// 当前窗口选中的主视图。
enum RepositoryView: String, CaseIterable {
    /// 工作区状态列表。
    case workingCopy

    /// 历史视图的里程碑占位。
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
    /// 当前工作区身份。
    private(set) var repository: RepositoryLocation?

    /// 最近一次成功读取的状态。
    private(set) var status: WorkingCopyStatus?

    /// 服务器连接状态，本机仓库为 nil。
    private(set) var connectionState: RemoteConnectionState?

    /// 写操作断线后的仓库核对结果。
    private(set) var recovery: RemoteRecoverySnapshot?

    /// 仅连接可用时允许远端写入。
    var canWrite: Bool { repository != nil && (repository?.host == nil || connectionState == .connected) }

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
    var selectedID: StatusRowID?

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
        loadStatus: @escaping @Sendable (RepositoryLocation) async throws -> WorkingCopyStatus = {
            try await GitRunner(location: $0).status()
        }
    ) {
        self.loadStatus = loadStatus
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
        }
    }

    /// 读取一次状态，同一窗口的重复刷新合并到正在执行的任务。
    func refresh() {
        guard let repository, !isRefreshing else {
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

                if let selected = self.selectedID,
                   !status.entries.contains(where: {
                       $0.path == selected.path && $0.kind == selected.kind
                   }) {
                    self.selectedID = nil
                }
            } catch {
                guard let self, self.generation == request, !Task.isCancelled else {
                    return
                }

                // 保留旧快照，错误反馈与数据展示互不覆盖。
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
