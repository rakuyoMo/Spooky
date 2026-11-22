import Foundation
import SpookyKit

// MARK: - Connection

extension RepositorySession {
    /// 轮询间隔参考的读取次数：轮询任务只留最近这么多次读取用时，记满之后才按用时拉长间隔。
    nonisolated static let pollReadWindow = 3

    /// 两次轮询开始之间的间隔：没记满 ``pollReadWindow`` 次读取时是基础间隔；
    /// 记满之后至少是基础间隔，也至少是其中最短一次用时的五倍：服务器持续地慢时轮询才变稀，读取用时稳定时轮询占用服务器的时间不超过五分之一。
    ///
    /// - Parameters:
    ///   - base: 前台或后台的基础间隔。
    ///   - recentReads: 最近几次轮询的读取用时，每次从轮询开始算到它发起的刷新结束。
    nonisolated static func pollInterval(base: Duration, recentReads: [Duration]) -> Duration {
        guard
            recentReads.count >= pollReadWindow,
            let shortest = recentReads.min()
        else { return base }

        return max(base, shortest * 5)
    }

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

    /// Show in Finder 要连着 B：已连上时直接返回；正在连接时等这一次的结果；自动重连在等下一次重试时立即开始这一次，不等重试的间隔。
    ///
    /// - Returns: 没连上时是失败；连上或仓库已关闭时为 nil。
    func connectNow() async -> AppFailure? {
        guard
            connectionState != .connected,
            let repository,
            let remote = GitRunner(location: repository).remote
        else { return nil }

        // 自动重连进行中：提前结束两次尝试之间的等待，等它这一次的结果
        if reconnectTask != nil {
            return await withCheckedContinuation { continuation in
                reconnectWaiters.append(continuation)
                reconnectDelay?.cancel()
            }
        }

        // 没有自动重连时直接连接；打开仓库时的连接正在进行时，等的是同一次
        do {
            _ = try await remote.open()
            return nil
        } catch {
            return AppFailure(error: error, opening: false, location: repository)
        }
    }

    /// 断线横条上的 Reconnect：自动重连在等下一次重试时立即开始这一次，不等重试的间隔；没有自动重连时开始重连。
    ///
    /// 连接状态变为不可用时自动调用的是 ``reconnect()``，那里不提前结束等待，以免每次失败都立即再试。
    func reconnectNow() {
        // 自动重连进行中：提前结束两次尝试之间的等待
        if reconnectTask != nil {
            reconnectDelay?.cancel()
            return
        }

        reconnect()
    }

    /// 自动重连两次尝试之间的等待：Show in Finder 或 Reconnect 要立即连接时提前结束；整个重连任务取消时等待一并结束。
    func waitBeforeReconnecting() async {
        let delay = Task<Void, Never> {
            try? await Task.sleep(for: RemoteConnection.reconnectInterval)
        }

        reconnectDelay = delay

        await withTaskCancellationHandler {
            await delay.value
        } onCancel: {
            delay.cancel()
        }
    }

    /// 把自动重连这一次的结果交给等它的 Show in Finder。
    ///
    /// - Parameter failure: 没连上时的失败；连上或仓库已关闭时为 nil。
    func resumeReconnectWaiters(with failure: AppFailure?) {
        let waiters = reconnectWaiters
        reconnectWaiters = []

        for waiter in waiters {
            waiter.resume(returning: failure)
        }
    }

    /// 连接状态变化：从已连上变为没连上时，这个仓库排着的写操作全部取消，不在重连后执行。
    ///
    /// - Parameter previous: 变化前的连接状态。
    func connectionStateChanged(from previous: RemoteConnectionState?) {
        // 关闭会话时置为 nil，不算断开
        guard
            previous == .connected,
            let connectionState,
            connectionState != .connected,
            let repository
        else { return }

        RepositoryWriteQueue.shared.disconnected(repository)
    }

    /// 轮询只读状态，任何失败都不重放写操作；两次轮询开始之间的间隔由 ``pollInterval(base:recentReads:)`` 决定，读取用时的记录只属于这一个轮询任务。
    func startPolling() {
        pollingTask?.cancel()
        let base = isActive
            ? RemoteConnection.foregroundPollInterval
            : RemoteConnection.backgroundPollInterval

        pollingTask = Task { [weak self] in
            let clock = ContinuousClock()
            var started = clock.now
            var reads: [Duration] = []

            while !Task.isCancelled {
                let interval = Self.pollInterval(base: base, recentReads: reads)

                do { try await clock.sleep(until: started + interval) }
                catch { return }

                guard let self, repository?.host != nil else { return }

                started = clock.now
                guard connectionState == .connected else { continue }

                // 等这次轮询发起的刷新结束，记下读取用时，只留最近几次；没有发起新的刷新时不记
                let previous = refreshTask
                autoReload()

                guard let reading = refreshTask, reading != previous else { continue }

                await reading.value
                reads.append(started.duration(to: clock.now))
                reads = Array(reads.suffix(Self.pollReadWindow))
            }
        }
    }
}
