import Foundation
import SpookyKit

// MARK: - RepositoryAutoFetch

/// 自动获取的调度：按 Settings → General 选的间隔，获取窗口里当前仓库的全部远端。
///
/// 只在窗口显示仓库、App 处于前台、仓库可写时获取；条件不满足时暂停，条件恢复后已经到期的获取随即进行。
@MainActor
final class RepositoryAutoFetch {
    /// 设置里可选的间隔，单位秒；0 表示只手动获取。
    static let intervals = [0, 300, 600, 1800, 3600]

    /// 没改过设置时的间隔。
    static let defaultInterval = 1800

    /// 间隔的偏好键。
    static let intervalKey = "autoFetchInterval"

    #warning("TODO: 打开仓库后先等 10 秒再第一次自动获取是推断值。核实方式：打开一个有远端的仓库，记下 Activity 里第一次自动获取出现的时间；只影响打开仓库后多久开始第一次自动获取")

    /// 打开仓库后第一次自动获取前的等待，避开打开时的首轮读取。
    static let initialDelay: TimeInterval = 10

    /// 检查是否到期的周期。
    static let checkInterval = Duration.seconds(5)

    /// 被调度的窗口会话。
    private weak var session: RepositorySession? = nil

    /// 读取间隔的偏好域，测试使用临时域。
    private let defaults: UserDefaults

    /// 窗口是否正显示仓库且 App 处于前台。
    private let isForeground: @MainActor () -> Bool

    /// 当前仓库、打开它的时间与上一次自动获取的时间；换了仓库就重新计时。
    private var schedule: (repository: RepositoryLocation, opened: Date, lastFetch: Date?)? = nil

    /// 周期检查的任务。
    private var task: Task<Void, Never>? = nil

    /// 设置里选的间隔，单位秒；不在可选范围内时取默认值。
    var interval: Int {
        let value = defaults.object(forKey: Self.intervalKey) as? Int ?? Self.defaultInterval
        return Self.intervals.contains(value) ? value : Self.defaultInterval
    }

    /// 为一个窗口会话建立调度，调用 `start()` 后开始检查。
    init(
        session: RepositorySession,
        defaults: UserDefaults = .standard,
        isForeground: @escaping @MainActor () -> Bool
    ) {
        self.session = session
        self.defaults = defaults
        self.isForeground = isForeground
    }

    /// 开始周期检查；窗口关闭时调用 `stop()`。
    func start() {
        task?.cancel()

        task = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: Self.checkInterval) }
                catch { return }

                self?.check(now: Date())
            }
        }
    }

    /// 停止检查；正在进行的获取由仓库写操作的取消入口控制。
    func stop() {
        task?.cancel()
        task = nil
    }

    /// 一次检查：换了仓库就重新计时；到期且仓库在前台、可获取时开始一次自动获取。
    ///
    /// - Returns: 本次是否开始了自动获取。
    @discardableResult
    func check(now: Date) -> Bool {
        guard let session, let repository = session.repository else {
            schedule = nil
            return false
        }

        if schedule?.repository != repository {
            schedule = (repository, now, nil)
        }

        guard
            let schedule,
            interval > 0,
            now >= due(schedule),
            isForeground(),
            session.canFetch,
            session.autoFetch()
        else {
            return false
        }

        self.schedule?.lastFetch = now
        return true
    }

    /// 下一次自动获取的时间：第一次在打开仓库后稍等片刻，之后每隔一个间隔。
    private func due(_ schedule: (repository: RepositoryLocation, opened: Date, lastFetch: Date?)) -> Date {
        guard let last = schedule.lastFetch else {
            return schedule.opened.addingTimeInterval(Self.initialDelay)
        }

        return last.addingTimeInterval(TimeInterval(interval))
    }
}
