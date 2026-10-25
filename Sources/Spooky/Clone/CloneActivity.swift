import Foundation
import Observation
import SpookyKit

// MARK: - CloneActivity

/// 一次在后台进行的克隆：地址、目标与选项，以及进行中的进度或结束的结果。
@MainActor
@Observable
final class CloneActivity: Identifiable {
    /// 克隆的状态。
    enum State {
        /// 进行中；Git 输出第一行进度之前为 nil。
        case running(CloneProgress?)

        /// 用户取消。
        case cancelled

        /// 失败，带 Git 或连接的原始输出。
        case failed(AppFailure)

        /// 已完成。
        case finished
    }

    /// 活动的稳定身份。
    let id = UUID()

    /// 地址、目标位置与选项。
    let clone: RepositoryClone

    /// 当前状态。
    private(set) var state = State.running(nil)

    /// 进行中的克隆操作，结束后清空。
    @ObservationIgnored
    private var operation: GitOperation?

    /// 列表与进度页显示的名称：目标目录的最后一段，服务器目标带主机前缀。
    var name: String {
        let directory = URL(fileURLWithPath: clone.destination.path).lastPathComponent
        return (clone.destination.host.map { $0 + ":" } ?? "") + directory
    }

    /// 是否仍在进行。
    var isRunning: Bool {
        if case .running = state { true } else { false }
    }

    /// 进行中的最新进度；没有进度或已结束时为 nil。
    var progress: CloneProgress? {
        if case .running(let progress) = state { progress } else { nil }
    }

    /// 只记下参数，由 ``start(_:)`` 开始克隆。
    ///
    /// - Parameter clone: 地址、目标位置与选项。
    init(clone: RepositoryClone) {
        self.clone = clone
    }

    /// 克隆抛出的错误对应的状态：用户取消算取消，其余保留原始输出。
    private static func state(after error: any Error, at location: RepositoryLocation) -> State {
        if error is CancellationError || ((error as? GitError)?.isCancelled ?? false) {
            return .cancelled
        }

        return .failed(AppFailure(error: error, opening: false, location: location, writing: true))
    }

    /// 开始或重新开始克隆；凭据与口令经界面询问，结束后回调。
    ///
    /// - Parameter finished: 克隆完成、失败或取消后调用。
    func start(_ finished: @escaping @MainActor (CloneActivity) -> Void) {
        state = .running(nil)

        let operation = clone.start(
            credentialHandler: { await RemoteCallbackPresenter.shared.respond(to: $0) },
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    // 取消或失败之后才到的进度不再改回进行中
                    guard let self, self.isRunning else { return }
                    self.state = .running(progress)
                }
            }
        )
        self.operation = operation
        let destination = clone.destination

        Task { [weak self] in
            let result: State

            do {
                _ = try await operation.value
                result = .finished
            } catch {
                result = Self.state(after: error, at: destination)
            }

            guard let self else { return }
            self.operation = nil
            state = result
            finished(self)
        }
    }

    /// 取消进行中的克隆；本机终止进程组，服务器经包装器终止 B 上的进程组。
    func cancel() {
        operation?.cancel()
    }

}

// MARK: - CloneActivities

/// App 内最近的克隆，最新的在前；克隆在后台进行，书签在开始时就加入仓库管理。
///
/// 移除没有完成的克隆时一并移除它的书签，书签只为这次克隆而加。
@MainActor
@Observable
final class CloneActivities {
    /// 最近的克隆，最新的在前。
    private(set) var items: [CloneActivity] = []

    /// 克隆开始时加入、完成后标记可用的书签。
    @ObservationIgnored
    private let bookmarks: RepositoryBookmarks

    /// 有克隆在进行，工具栏的 Clone 项据此出现。
    var isEmpty: Bool {
        items.isEmpty
    }

    /// 接上全部窗口共用的书签。
    ///
    /// - Parameter bookmarks: 仓库书签。
    init(bookmarks: RepositoryBookmarks) {
        self.bookmarks = bookmarks
    }

    /// 克隆到这个位置、还没有完成的最近一次活动：进行中、已取消或失败；没有时为 nil。
    func unfinished(at location: RepositoryLocation) -> CloneActivity? {
        items.first { !$0.isFinished && $0.clone.destination == location }
    }

    /// 开始克隆，目标的书签立即加入仓库管理。
    ///
    /// - Parameters:
    ///   - clone: 地址、目标位置与选项。
    ///   - folder: 书签放进的文件夹；nil 表示最外层。
    @discardableResult
    func start(_ clone: RepositoryClone, into folder: Bookmark.ID? = nil) -> CloneActivity {
        let activity = CloneActivity(clone: clone)
        items.insert(activity, at: 0)
        bookmarks.add(clone.destination, into: folder)
        run(activity)
        return activity
    }

    /// 重试取消或失败的克隆；书签已被移除时重新加入。
    func restart(_ activity: CloneActivity) {
        guard !activity.isRunning else {
            return
        }

        bookmarks.add(activity.clone.destination)
        run(activity)
    }

    /// 移除一项：进行中的先取消，没有完成的连同书签一起移除。
    func remove(_ activity: CloneActivity) {
        activity.cancel()
        items.removeAll { $0 === activity }

        if case .finished = activity.state {
            return
        }

        if let bookmark = bookmarks.bookmark(for: activity.clone.destination) {
            bookmarks.delete([bookmark.id])
        }
    }

    /// 清除已经结束的克隆，进行中的保留。
    func clear() {
        for activity in items where !activity.isRunning {
            remove(activity)
        }
    }

    /// 开始克隆；完成后书签去掉失效标记。
    private func run(_ activity: CloneActivity) {
        activity.start { [weak self] activity in
            if case .finished = activity.state {
                self?.bookmarks.markAvailable(activity.clone.destination)
            }
        }
    }
}
