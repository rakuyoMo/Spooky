import Foundation
import Observation
import SpookyKit

// MARK: - ShowInFinderFlow

/// 服务器仓库不能直接在 Finder 中显示时的流程：连上 B、重新查找，方式是挂载时由 Spooky 挂载，都不行时换成本机位置表单；
/// 拿到本机位置后在 Finder 中选中目标。
///
/// 只经仓库的本机位置状态与给定的连接动作工作，不依赖仓库窗口的会话。
@MainActor
@Observable
final class ShowInFinderFlow {
    /// 流程现在的一步。
    enum Step {
        /// 正在连接 B。
        case connecting

        /// 正在查找。
        case searching

        /// Spooky 正在挂载。
        case mounting

        /// 没连上 B。
        case failed(AppFailure)

        /// 换成了本机位置表单。
        case form(LocalLocationForm)
    }

    /// 连接 B 的结果。
    enum ConnectionResult {
        /// 连上了，带仓库的执行器。
        case connected(GitRunner)

        /// 没连上。
        case failed(AppFailure)

        /// 流程不能再继续，如仓库已关闭。
        case ended
    }

    /// 仓库的本机位置状态。
    let mounts: RepositoryMountState

    /// 主机别名。
    let host: String

    /// B 上要在 Finder 中选中的路径。
    let paths: [String]

    /// 现在的一步。
    private(set) var step: Step

    /// 流程结束后的收尾：sheet 已关闭，已开始的连接、查找、挂载与表单的核对都已结束；仓库管理与最近克隆用它交还连接。
    @ObservationIgnored
    var onFinish: (() -> Void)? = nil

    /// 连上 B 并取得仓库的执行器。
    @ObservationIgnored
    private let connect: () async -> ConnectionResult

    /// sheet 出现时开始的那一次流程。
    @ObservationIgnored
    private var running: Task<Void, Never>? = nil

    /// 表单设置成功后，等本机位置再打开 Finder 的任务。
    @ObservationIgnored
    private var revealing: Task<Void, Never>? = nil

    /// 已经取消：进行中的连接、查找与挂载照常结束，之后不再往下走，也不打开 Finder。
    @ObservationIgnored
    private var isCancelled = false

    /// sheet 已经关闭。
    @ObservationIgnored
    private var isClosed = false

    /// 底栏左侧的进度；没连上或换成表单后为 nil。
    var progress: String? {
        switch step {
        case .connecting: AppLocalization.text("action.revealFinder.connecting", host)
        case .searching: AppLocalization.text("localLocation.searching")
        case .mounting: AppLocalization.text("localLocation.mounting")
        case .failed, .form: nil
        }
    }

    /// 创建流程。
    ///
    /// - Parameters:
    ///   - mounts: 仓库的本机位置状态。
    ///   - host: 主机别名。
    ///   - paths: B 上要在 Finder 中选中的路径。
    ///   - isConnected: 现在是否连着 B；没连着时从 “正在连接” 开始。
    ///   - connect: 连上 B 并取得仓库的执行器。
    init(
        mounts: RepositoryMountState,
        host: String,
        paths: [String],
        isConnected: Bool,
        connect: @escaping () async -> ConnectionResult
    ) {
        self.mounts = mounts
        self.host = host
        self.paths = paths
        self.connect = connect
        step = isConnected ? .searching : .connecting
    }

    /// sheet 出现时开始流程，只开始一次。
    ///
    /// 流程在独立的任务里执行，sheet 关闭不会打断已经开始的连接、查找与挂载。
    ///
    /// - Parameters:
    ///   - reveal: 拿到本机位置时关闭 sheet，并在 Finder 中选中这些本机路径。
    ///   - end: 流程不能再继续时关闭 sheet，如仓库在这期间关闭。
    func start(reveal: @escaping ([URL]) -> Void, end: @escaping () -> Void) {
        guard running == nil else {
            return
        }

        running = Task {
            if let urls = await run() {
                reveal(urls)
            } else if !isCancelled, progress != nil {
                // 没有换成错误区或表单就结束了：仓库在这期间关闭
                end()
            }
        }
    }

    /// 依次连接、查找与挂载，都不行时换成本机位置表单。
    ///
    /// - Returns: 拿到本机位置时是要在 Finder 中选中的本机路径；没连上、换成表单、已经取消或仓库已关闭时为 nil。
    func run() async -> [URL]? {
        let runner: GitRunner

        switch await connect() {
        case .connected(let connected):
            runner = connected

        case .failed(let failure):
            show(.failed(failure))
            return nil

        case .ended:
            return nil
        }

        guard !isCancelled else {
            return nil
        }

        step = .searching
        await mounts.relocateRepository(host: host, runner: runner)

        if let urls = localURLs() {
            return isCancelled ? nil : urls
        }

        // 方式是挂载时由 Spooky 挂载；用户发起，允许系统的登录框与口令询问
        if !isCancelled, mounts.location.method.mounting != nil {
            step = .mounting
            await mounts.mountRepository(host: host, runner: runner, interactive: true)

            if let urls = localURLs() {
                return isCancelled ? nil : urls
            }

            // 挂载失败时表单的错误区写出原因与原始输出
            let failure = mounts.failure?.message
            showForm(runner: runner, reason: nil, failure: failure)
            return nil
        }

        // 自动查找没找到、指定的文件夹不在：说明前面先写原因
        showForm(runner: runner, reason: mounts.unavailableReason, failure: nil)
        return nil
    }

    /// 本机位置表单设置成功后的目标：改成自动查找时等保存后开始的那次查找结束。
    ///
    /// - Returns: 拿到本机位置时是要在 Finder 中选中的本机路径；仍然拿不到时为 nil。
    func savedLocation() async -> [URL]? {
        if let path = mounts.repository?.path {
            await mounts.waitForSearch(of: path)
        }

        return localURLs()
    }

    /// 本机位置表单关闭：设置成功时等拿到本机位置后交给 `reveal`。
    ///
    /// - Parameters:
    ///   - saved: 表单是否记下了本机位置。
    ///   - reveal: 在 Finder 中选中这些本机路径。
    func formClosed(saved: Bool, reveal: @escaping ([URL]) -> Void) {
        guard saved else {
            return
        }

        revealing = Task {
            if let urls = await savedLocation() {
                reveal(urls)
            }
        }
    }

    /// 取消：sheet 随即关闭，进行中的连接、查找与挂载照常结束，设置不变。
    func cancel() {
        isCancelled = true
    }

    /// sheet 已关闭：等已开始的连接、查找、挂载、表单的核对与设置后的查找都结束，再执行一次收尾。
    func closed() {
        guard !isClosed else {
            return
        }

        isClosed = true

        Task {
            await running?.value

            if case .form(let form) = step {
                await form.waitForCheck()
            }

            await revealing?.value
            onFinish?()
        }
    }
}

// MARK: - Private

extension ShowInFinderFlow {
    /// 在对话框的动画里换一步：内容换成错误区或表单时，sheet 的高度随之动画。
    private func show(_ step: Step) {
        DialogAnimation.perform {
            self.step = step
        }
    }

    /// 换成本机位置表单；已经取消、或仓库在这期间关闭时不换。
    private func showForm(runner: GitRunner, reason: String?, failure: String?) {
        guard !isCancelled, mounts.repository != nil else {
            return
        }

        let form = LocalLocationForm(
            mounts: mounts,
            host: host,
            runner: runner,
            reason: reason,
            failure: failure
        )

        show(.form(form))
    }

    /// 仓库目录现在的本机位置换算出的目标；拿不到时为 nil。
    private func localURLs() -> [URL]? {
        guard let mount = mounts.repositoryMount() else {
            return nil
        }

        let urls = paths.compactMap { mount.localURL(for: $0) }

        return urls.isEmpty ? nil : urls
    }
}
