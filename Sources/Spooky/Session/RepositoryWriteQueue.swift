import Foundation
import Observation
import os
import SpookyKit

// MARK: - RepositoryWrite

/// 交给仓库写队列的一个写操作：仓库空闲时立即执行，否则排在这个仓库的队列里，轮到时按当时的状态核对后再执行。
@MainActor
final class RepositoryWrite {
    /// 写操作所在的仓库。
    let location: RepositoryLocation

    /// 已本地化的操作名称，写进日志与后面排着的写操作被取消的原因。
    let title: String

    /// 不由用户直接发起的写操作（自动获取）：不排队，用户发起的写操作排进来时停下让路，失败时不取消后面排着的写操作。
    let isBackground: Bool

    /// 改动工作区或索引；执行期间文件列表变灰。
    let touchesWorkingCopy: Bool

    /// 等待中的 Activity 记录与它所在的列表；立即执行的写操作没有。
    var waiting: (record: RepositoryActivity, activities: RepositoryActivities)? = nil

    /// 后台写操作执行期间给用户发起的写操作让路：在记录里写明让给了谁，再停下；参数是那个操作的名称。
    /// 由执行段设置，队列只调用一次。
    var giveWay: ((String) -> Void)? = nil

    /// 提交它的会话；仓库管理详情区的写入没有会话。
    private(set) weak var session: RepositorySession? = nil

    /// 提交时会话的代次；会话关闭或换了仓库后，这一项不再属于它。
    private let generation: Int

    /// 轮到时的核对，与入口所用的 `can…` 规则相同，参数是提交它的会话；为 nil 时只核对仓库能否写入。
    private let available: (@MainActor (RepositorySession) -> Bool)?

    /// 在队列里取消或轮到时没有执行时，撤回先显示的目标状态。
    private let withdraw: (@MainActor () -> Void)?

    /// 轮到时开始执行；返回是否已开始执行，为假时这一项正在询问用户，占着轮次等答复。
    private let start: (@MainActor (RepositoryWrite) -> Bool)?

    /// 提交它的会话仍显示着这个仓库时为这个会话；会话已关闭或换了仓库时为 nil。
    var owner: RepositorySession? {
        guard let session, session.generation == generation, session.repository == location else {
            return nil
        }

        return session
    }

    /// 建立一个写操作。
    ///
    /// - Parameters:
    ///   - location: 写操作所在的仓库。
    ///   - session: 提交它的会话；仓库管理详情区的写入传 nil。
    ///   - title: 已本地化的操作名称。
    ///   - isBackground: 是否不由用户直接发起。
    ///   - touchesWorkingCopy: 是否改动工作区或索引。
    ///   - available: 轮到时的核对；nil 时只核对仓库能否写入。
    ///   - withdraw: 没有执行就结束时撤回先显示的目标状态。
    ///   - start: 轮到时开始执行，返回是否已开始执行；只在仓库空闲时执行、从不排队的写入不传。
    init(
        location: RepositoryLocation,
        session: RepositorySession?,
        title: String,
        isBackground: Bool = false,
        touchesWorkingCopy: Bool = true,
        available: (@MainActor (RepositorySession) -> Bool)? = nil,
        withdraw: (@MainActor () -> Void)? = nil,
        start: (@MainActor (RepositoryWrite) -> Bool)? = nil
    ) {
        self.location = location
        self.session = session
        generation = session?.generation ?? 0
        self.title = title
        self.isBackground = isBackground
        self.touchesWorkingCopy = touchesWorkingCopy
        self.available = available
        self.withdraw = withdraw
        self.start = start
    }
}

// MARK: - RepositoryWriteQueue

/// App 内每个仓库一条写队列，全部窗口共用：同一时刻只执行一个写操作，其余的按提交的先后等待；只在内存里，不跨重启保留。
///
/// 前一个写操作结束后，等它与下一项的会话都刷新完，再按当时的状态核对下一项：通过才执行，不通过记为已跳过。
@MainActor
@Observable
final class RepositoryWriteQueue {
    /// App 内唯一的写队列登记。
    static let shared = RepositoryWriteQueue()

    /// 在队列里被取消与轮到时没有执行的日志；只记操作名与原因类别。
    private nonisolated static let logger = Logger(subsystem: "com.rakuyo.spooky", category: "RepositoryWriteQueue")

    /// 各仓库的队列；空闲的仓库没有项。
    private var lanes: [RepositoryLocation: Lane] = [:]

    /// 仓库空闲：没有执行中、也没有排队的写操作。
    func isIdle(_ location: RepositoryLocation) -> Bool {
        lanes[location] == nil
    }

    /// 仓库有用户发起的写操作在执行或排队；只有后台写操作在执行时为假。
    func hasUserWrite(in location: RepositoryLocation) -> Bool {
        guard let lane = lanes[location] else {
            return false
        }

        return !lane.pending.isEmpty || lane.current.map { !$0.isBackground } ?? false
    }

    /// 仓库里正在执行的写操作；轮到时还在核对或在询问用户的不算。
    func executing(in location: RepositoryLocation) -> RepositoryWrite? {
        guard let lane = lanes[location], lane.isExecuting else {
            return nil
        }

        return lane.current
    }

    /// 仓库空闲时把写操作登记为执行中并返回真，调用方随即开始执行；不空闲时不登记，返回假。
    func begin(_ write: RepositoryWrite) -> Bool {
        guard isIdle(write.location) else {
            return false
        }

        lanes[write.location] = Lane(current: write, isExecuting: true)
        return true
    }

    /// 把写操作排在仓库队列的最后；正在执行的是后台写操作时让它停下，这一项接着轮到。
    func enqueue(_ write: RepositoryWrite) {
        var lane = lanes[write.location] ?? Lane()
        lane.pending.append(write)
        lanes[write.location] = lane

        // 自动获取不挡用户发起的写操作；停下不算失败，排着的照常轮到
        guard
            !write.isBackground,
            lane.isExecuting,
            let current = lane.current,
            let giveWay = current.giveWay
        else {
            return
        }

        current.giveWay = nil
        giveWay(write.title)
    }

    /// 轮到时在询问用户的写操作得到答复后开始执行：它仍占着轮次时登记为执行中并返回真；已被取消时返回假。
    func resume(_ write: RepositoryWrite) -> Bool {
        guard let lane = lanes[write.location], lane.current === write, !lane.isExecuting else {
            return false
        }

        lanes[write.location]?.isExecuting = true
        return true
    }

    /// 执行中的写操作结束：轮到队列里的下一项。
    func finish(_ write: RepositoryWrite) {
        guard var lane = lanes[write.location], lane.current === write else {
            return
        }

        lane.current = nil
        lane.isExecuting = false
        store(lane, for: write.location)

        advance(write.location, after: write.session)
    }

    /// 执行中的用户写操作失败：后面排着的全部取消，原因写明失败的是哪个操作。
    func failed(_ write: RepositoryWrite) {
        guard !write.isBackground else {
            return
        }

        remove(in: write.location, reason: .failure(write.title)) { _ in true }
    }

    /// 用户在活动区或 Activity 窗口取消一项等待中的写操作。
    func cancel(_ write: RepositoryWrite) {
        remove(in: write.location, reason: .user) { $0 === write }
    }

    /// 服务器仓库断开：排着的全部取消，不在重连后执行；执行中的由执行段按中断与核对处理。
    func disconnected(_ location: RepositoryLocation) {
        remove(in: location, reason: .disconnected) { _ in true }
    }

    /// 窗口关闭或换了仓库：取消这个会话排着的写操作，别的会话提交的照常。
    ///
    /// - Parameters:
    ///   - session: 关闭的会话。
    ///   - location: 会话关闭前显示的仓库。
    func closed(_ session: RepositorySession, in location: RepositoryLocation) {
        remove(in: location, reason: .closed) { $0.session === session }
    }

    /// App 退出：全部仓库排着的写操作取消；执行中的由各窗口照退出流程取消并等待。
    func cancelAllPending() {
        for location in Array(lanes.keys) {
            remove(in: location, reason: .closed) { _ in true }
        }
    }
}

// MARK: - Private

extension RepositoryWriteQueue {
    /// 一个仓库的队列。
    private struct Lane {
        /// 正在执行，或轮到时正在等刷新、核对与询问用户的一项。
        var current: RepositoryWrite? = nil

        /// `current` 已开始执行；还在等刷新、核对与询问用户时为假。
        var isExecuting = false

        /// 等待的项，按提交的先后。
        var pending: [RepositoryWrite] = []

        /// 没有任何写操作。
        var isEmpty: Bool {
            current == nil && pending.isEmpty
        }
    }

    /// 写回一个仓库的队列；空了就去掉。
    private func store(_ lane: Lane, for location: RepositoryLocation) {
        lanes[location] = lane.isEmpty ? nil : lane
    }

    /// 没有正在执行或核对的项时取出下一项：等前一项与这一项的会话都刷新完，再核对并执行。
    ///
    /// - Parameters:
    ///   - location: 仓库。
    ///   - previous: 刚结束的写操作的会话；没有时只等下一项的会话。
    private func advance(_ location: RepositoryLocation, after previous: RepositorySession?) {
        guard var lane = lanes[location], lane.current == nil, !lane.pending.isEmpty else {
            return
        }

        let next = lane.pending.removeFirst()
        lane.current = next
        lanes[location] = lane

        Task {
            // 核对与执行看到的是写入之后刷新出的状态；别的窗口的刷新由写操作结束时的通知带起
            await previous?.waitForRefresh()
            await next.session?.waitForRefresh()

            // 等刷新期间被取消的已经离开队列
            guard lanes[location]?.current === next else {
                return
            }

            turn(next)
        }
    }

    /// 轮到一项：提交它的窗口已关闭或换了仓库时取消，核对不通过时跳过，否则开始执行。
    private func turn(_ write: RepositoryWrite) {
        guard let session = write.owner else {
            remove(in: write.location, reason: .closed) { $0 === write }
            return
        }

        guard session.canWrite, write.isAvailable(for: session) else {
            remove(in: write.location, reason: .changed) { $0 === write }
            return
        }

        lanes[write.location]?.isExecuting = true

        // 先询问用户的项占着轮次，答复前不算执行中，取消、关窗与断线照等待中的项移出
        if !write.begin() {
            lanes[write.location]?.isExecuting = false
        }
    }

    /// 把还没开始执行的项移出队列：等待中的，以及轮到时还在核对或询问用户的；记录按原因结束，再轮到下一项。
    ///
    /// - Parameters:
    ///   - location: 仓库。
    ///   - reason: 没有执行的原因。
    ///   - matches: 要移出的项。
    private func remove(
        in location: RepositoryLocation,
        reason: Reason,
        where matches: (RepositoryWrite) -> Bool
    ) {
        guard var lane = lanes[location] else {
            return
        }

        var removed = lane.pending.filter(matches)
        lane.pending.removeAll(where: matches)

        if let current = lane.current, !lane.isExecuting, matches(current) {
            removed.insert(current, at: 0)
            lane.current = nil
        }

        guard !removed.isEmpty else {
            return
        }

        store(lane, for: location)

        for write in removed {
            write.end(reason)
            Self.logger.info("排队的写操作没有执行：\(write.title, privacy: .public)，原因 \(reason.category, privacy: .public)")
        }

        advance(location, after: nil)
    }
}

// MARK: RepositoryWriteQueue.Reason

extension RepositoryWriteQueue {
    /// 等待中的写操作没有执行就结束的原因。
    enum Reason {
        /// 用户在活动区或 Activity 窗口取消。
        case user

        /// 执行中的写操作失败，附它的名称。
        case failure(String)

        /// 提交它的窗口已关闭或换了仓库，或 App 退出。
        case closed

        /// 服务器仓库断开。
        case disconnected

        /// 轮到时核对不通过。
        case changed

        /// 记录的状态键：核对不通过记为已跳过，其余记为取消。
        var state: String {
            switch self {
            case .changed: "activity.skipped"
            case .user, .failure, .closed, .disconnected: "activity.cancelled"
            }
        }

        /// 写进记录输出的说明；用户取消、关窗与退出不写。
        var detail: String? {
            switch self {
            case .failure(let title): AppLocalization.text("queue.cancelledAfterFailure", title)
            case .changed: AppLocalization.text("queue.notRun")
            case .disconnected: AppLocalization.text("queue.cancelledDisconnected")
            case .user, .closed: nil
            }
        }

        /// 日志里的原因类别。
        var category: String {
            switch self {
            case .user: "user"
            case .failure: "failure"
            case .closed: "closed"
            case .disconnected: "disconnected"
            case .changed: "changed"
            }
        }
    }
}

// MARK: - RepositoryWrite Private

extension RepositoryWrite {
    /// 轮到时的核对是否通过。
    fileprivate func isAvailable(for session: RepositorySession) -> Bool {
        available?(session) ?? true
    }

    /// 轮到时开始执行；返回是否已开始执行。
    fileprivate func begin() -> Bool {
        start?(self) ?? true
    }

    /// 没有执行就结束：等待中的记录写上状态与原因后结束，撤回先显示的目标状态。
    fileprivate func end(_ reason: RepositoryWriteQueue.Reason) {
        if let waiting {
            if let detail = reason.detail {
                waiting.record.append(.standardError(Data((detail + "\n").utf8)))
            }

            waiting.record.state = reason.state
            waiting.activities.finish(waiting.record)
        }

        withdraw?()
    }
}
