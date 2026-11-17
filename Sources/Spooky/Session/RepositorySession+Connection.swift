import Foundation
import SpookyKit

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

    /// 自动重连两次尝试之间的等待：Show in Finder 要立即连接时提前结束；整个重连任务取消时等待一并结束。
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

    /// 轮询只读状态，任何失败都不重放写操作。
    func startPolling() {
        pollingTask?.cancel()
        let interval = isActive
            ? RemoteConnection.foregroundPollInterval
            : RemoteConnection.backgroundPollInterval

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) }
                catch { return }

                guard let self, repository?.host != nil else { return }
                if connectionState == .connected { autoReload() }
            }
        }
    }
}
