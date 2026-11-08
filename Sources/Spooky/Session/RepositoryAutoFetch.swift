import Foundation
import Network
import SpookyKit

// MARK: - RepositoryAutoFetch

/// 自动获取的调度：仓库视图进入窗口 10 s 后第一次检查，之后每 160 s 检查一次；
/// 每次按 Settings → General 选的间隔逐个判断远端是否到期，到期的远端各自获取。
///
/// 窗口不显示仓库或挂着 sheet 时不获取，App 在后台照常进行；sheet 关闭、切换仓库、修改间隔或增减远端时重新计时。
@MainActor
final class RepositoryAutoFetch {
    /// 设置里可选的间隔，单位秒；0 表示只手动获取。
    static let intervals = [0, 300, 600, 1800, 3600]

    /// 没改过设置时的间隔。
    static let defaultInterval = 1800

    /// 间隔的偏好键。
    static let intervalKey = "autoFetchInterval"

    /// 开始或重新开始计时后，第一次检查前的等待。
    static let initialDelay: TimeInterval = 10

    /// 之后两次检查的间隔；远端是否到期另按设置的间隔判断。
    static let checkInterval: TimeInterval = 160

    /// 看下一次检查是否已到的周期。
    private static let tick = Duration.seconds(1)

    /// 被调度的窗口会话。
    private weak var session: RepositorySession? = nil

    /// 读取间隔与获取选项、记录获取时刻的偏好域，测试使用临时域。
    private let defaults: UserDefaults

    /// 窗口是否正显示仓库且没有挂 sheet。
    private let showsRepository: @MainActor () -> Bool

    /// 当前时刻，测试使用可控的时间。
    private let clock: @MainActor () -> Date

    /// 系统网络路径是否可用；不可用时本机仓库的远端都按主机不可达跳过。
    private let isNetworkAvailable: @MainActor () -> Bool

    /// 下一次检查的时刻；暂停或间隔为 Never 时为 nil。
    private(set) var nextCheck: Date? = nil

    /// 上次计时所用的间隔，偏好变化后据此判断间隔是否改过。
    private var scheduledInterval: Int? = nil

    /// 是否正在检查；一次检查会等它开始的获取逐个结束。
    private var isChecking = false

    /// 看下一次检查是否已到的任务。
    private var task: Task<Void, Never>? = nil

    /// 观察间隔偏好的变化。
    private var intervalObserver: (any NSObjectProtocol)? = nil

    /// 设置里选的间隔，单位秒；不在可选范围内时取默认值。
    var interval: Int {
        let value = defaults.object(forKey: Self.intervalKey) as? Int ?? Self.defaultInterval
        return Self.intervals.contains(value) ? value : Self.defaultInterval
    }

    /// 为一个窗口会话建立调度，调用 `start()` 后开始计时。
    ///
    /// - Parameters:
    ///   - session: 被调度的窗口会话。
    ///   - defaults: 读取间隔与获取选项、记录获取时刻的偏好域。
    ///   - clock: 当前时刻。
    ///   - isNetworkAvailable: 系统网络路径是否可用。
    ///   - showsRepository: 窗口是否正显示仓库且没有挂 sheet。
    init(
        session: RepositorySession,
        defaults: UserDefaults = .standard,
        clock: @escaping @MainActor () -> Date = Date.init,
        isNetworkAvailable: @escaping @MainActor () -> Bool = { SystemNetworkPath.shared.isSatisfied },
        showsRepository: @escaping @MainActor () -> Bool
    ) {
        self.session = session
        self.defaults = defaults
        self.clock = clock
        self.isNetworkAvailable = isNetworkAvailable
        self.showsRepository = showsRepository
    }

    /// 开始计时并观察间隔的变化；窗口关闭时调用 `stop()`。
    func start() {
        stop()
        SystemNetworkPath.shared.start()

        intervalObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.intervalMayHaveChanged() }
        }

        task = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: Self.tick) }
                catch { return }

                await self?.checkIfDue()
            }
        }

        restart()
    }

    /// 停止计时；正在进行的获取由仓库写操作的取消入口控制。
    func stop() {
        task?.cancel()
        task = nil
        nextCheck = nil

        if let intervalObserver {
            NotificationCenter.default.removeObserver(intervalObserver)
        }

        intervalObserver = nil
    }

    /// 重新计时：10 s 后检查；间隔为 Never 时停止检查。
    func restart() {
        scheduledInterval = interval
        nextCheck = interval > 0 ? clock().addingTimeInterval(Self.initialDelay) : nil
    }

    /// 暂停计时，如窗口挂上 sheet 或改为显示仓库管理；之后由 `restart()` 恢复。
    func pause() {
        nextCheck = nil
    }

    /// 一次检查：排好下一次检查，再逐个获取到期的远端，每个远端一次写操作、一条 Activity 记录。
    ///
    /// 窗口不显示仓库、仓库不可写或另有写操作时不获取；跳过的远端不更新上次获取的时刻，下一次检查重新判断。
    ///
    /// - Parameter now: 检查的时刻。
    /// - Returns: 开始获取的远端，按获取的先后。
    @discardableResult
    func check(now: Date) async -> [String] {
        nextCheck = interval > 0 ? now.addingTimeInterval(Self.checkInterval) : nil

        guard
            interval > 0,
            showsRepository(),
            let session,
            let repository = session.repository,
            session.canFetch
        else {
            return []
        }

        let targets = await targets(dueAt: now, in: session, repository: repository)
        var fetched: [String] = []

        // 前一个远端的写操作结束后再开始下一个；期间换了仓库、挂上 sheet 或仓库变得不可写就停下
        for remote in targets {
            guard
                !Task.isCancelled,
                session.repository == repository,
                showsRepository(),
                session.autoFetch(remote: remote, defaults: defaults)
            else {
                break
            }

            fetched.append(remote)
            await session.writeTask?.value
        }

        return fetched
    }
}

// MARK: - Private

extension RepositoryAutoFetch {
    /// 下一次检查已到且没有正在进行的检查时检查一次。
    private func checkIfDue() async {
        let now = clock()

        guard let nextCheck, now >= nextCheck, !isChecking else {
            return
        }

        isChecking = true
        await check(now: now)
        isChecking = false
    }

    /// 偏好变化后，间隔与上次计时所用的不同就重新计时。
    private func intervalMayHaveChanged() {
        guard task != nil, interval != scheduledInterval else {
            return
        }

        restart()
    }

    /// 这次检查要获取的远端：到期的远端去掉设了 skipFetchAll 的；
    /// 本机仓库再去掉地址解析不出主机的，系统网络路径不可用时一个也不获取。服务器仓库的地址交给服务器上的 Git。
    private func targets(
        dueAt now: Date,
        in session: RepositorySession,
        repository: RepositoryLocation
    ) async -> [String] {
        let remotes = session.history.snapshot?.remotes.map(\.name) ?? []

        // 从没获取过的远端直接到期，其余距上次获取满一个间隔才到期
        let due = remotes.filter { remote in
            guard let last = RemoteFetchTimes.lastFetch(of: remote, in: repository, defaults: defaults) else {
                return true
            }

            return now.timeIntervalSince(last) >= TimeInterval(interval)
        }

        let local = repository.host == nil

        guard !due.isEmpty, !local || isNetworkAvailable(), let runner = session.runner else {
            return []
        }

        do {
            return try await RepositorySync(runner: runner).autoFetchTargets(among: due, requiresHost: local)
        } catch {
            return []
        }
    }
}

// MARK: - SystemNetworkPath

/// 系统当前的网络路径，供本机仓库的自动获取判断主机是否已不可达。
@MainActor
final class SystemNetworkPath {
    /// App 共用的一份。
    static let shared = SystemNetworkPath()

    /// 系统网络路径的监视。
    private let monitor = NWPathMonitor()

    /// 是否已开始监视。
    private var isStarted = false

    /// 系统网络路径是否可用。
    var isSatisfied: Bool { monitor.currentPath.status == .satisfied }

    /// 只有共用的一份。
    private init() { }

    /// 开始监视；路径要在开始后才读得准，第一次检查前的等待足够它读到。
    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true
        monitor.start(queue: DispatchQueue(label: "com.rakuyo.spooky.network-path"))
    }
}
