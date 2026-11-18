import Foundation
import SpookyKit

// MARK: - Write Entry

extension RepositorySession {
    /// 新建、检出、同步和工作区写入共用的写操作入口：仓库空闲时立即执行；正有写操作时排进这个仓库的队列，
    /// 轮到时按当时的状态核对后执行。取消后仍刷新真实状态。
    ///
    /// - Parameters:
    ///   - title: 已本地化的操作名称，用于 Activity 与断线后的核对报告。
    ///   - progress: 检出、合并、拉取、变基与重置这类占用工作区的操作传入整页进度的标题，执行期间工作区换成进度；
    ///     其它写操作不传。
    ///   - recordsActivity: 网络与引用操作记入 Activity；工作区的高频写入只用于核对报告，排队期间仍列出等待中的记录，
    ///     开始执行时移除。
    ///   - target: 要连接远端传输对象或引用的操作传入连接的对象，记在 Activity 的 Remote 页，写进记录的图标与标题；
    ///     不传时记在 Repository 页。动作里经 `ActivityRecording` 另起的记录接在后面。
    ///   - offersAutoStash: 被本地改动挡住时是否按设置询问先储藏，检出、拉取与合并使用。
    ///   - background: 不由用户直接发起的写操作（自动获取）：仓库不空闲时不执行也不排队，用户发起的写操作排进来时停下让路，
    ///     失败只记进 Activity。
    ///   - touchesWorkingCopy: 是否改动工作区或索引；执行期间文件列表据此变灰。
    ///   - undo: 这次写操作能否撤销；没有声明的写操作按不能撤销处理。
    ///   - success: 成功后调用；期间关闭或换了仓库时不调用。
    ///   - failureNote: 失败时补在错误说明前面的一段话，如同步停在了哪一步。
    ///   - available: 排队后轮到时的核对，以本会话调用入口所用的同一条 `can…` 规则；为 nil 时只核对仓库能否写入。
    ///   - withdrawn: 在队列里取消或轮到时没有执行时调用，撤回先显示的目标状态。
    ///   - asksToStash: 排进队列的检出：轮到时按那时的状态，有已跟踪文件的修改就按设置先询问是否储藏，询问期间占着轮次。
    ///   - turn: 轮到时询问后接着执行的那一项：在它占着的轮次上执行，不另排队。
    ///   - started: 开始执行后调用，`writeTask` 已是这个写操作：仓库空闲时在接受时，排队时在轮到时；询问后接着执行的不调用。
    /// - Returns: 是否已开始执行或已排进队列；仓库不能写入、后台写操作遇上仓库不空闲、询问期间那一项已被取消时为 false，
    ///   调用方据此保留未发送的参数。
    @discardableResult
    func performGit(
        _ action:
        @escaping @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void,
        title: String,
        progress: String? = nil,
        recordsActivity: Bool = true,
        target: ActivityTarget? = nil,
        offersAutoStash: Bool = false,
        background: Bool = false,
        touchesWorkingCopy: Bool = true,
        undo: UndoRecording = .irreversible,
        success: (() -> Void)? = nil,
        failureNote: (() -> String?)? = nil,
        available: (@MainActor (RepositorySession) -> Bool)? = nil,
        withdrawn: (@MainActor () -> Void)? = nil,
        asksToStash: Bool = false,
        turn: RepositoryWrite? = nil,
        started: (@MainActor () -> Void)? = nil
    ) -> Bool {
        guard canWrite, let repository else {
            return false
        }

        let operation = GitWriteOperation(
            action: action,
            title: title,
            progress: progress,
            recordsActivity: recordsActivity,
            target: target,
            offersAutoStash: offersAutoStash,
            background: background,
            undo: undo,
            success: success,
            failureNote: failureNote
        )

        let queue = RepositoryWriteQueue.shared

        // 询问得到答复：仍占着轮次时在这个轮次上执行
        if let turn {
            guard queue.resume(turn) else {
                return false
            }

            execute(operation, as: turn)
            return true
        }

        let write = RepositoryWrite(
            location: repository,
            session: self,
            title: title,
            isBackground: background,
            touchesWorkingCopy: touchesWorkingCopy,
            available: available,
            withdraw: withdrawn
        ) { [weak self] write in
            // 排进队列的检出轮到时先看要不要询问储藏，询问期间占着轮次
            if asksToStash, self?.askToStash(before: operation, holding: write) ?? false {
                return false
            }

            self?.execute(operation, as: write)
            started?()
            return true
        }

        // 仓库空闲时立即执行
        if queue.begin(write) {
            execute(operation, as: write)
            started?()
            return true
        }

        // 后台写操作只在仓库空闲时执行
        guard !background else {
            return false
        }

        // 排队期间列出等待中的记录，它的停止按钮把这一项移出队列
        let record = RepositoryActivity(repository: repository, title: title, target: target)
        record.state = "activity.waiting"

        record.cancel = { [weak write] in
            if let write { queue.cancel(write) }
        }

        activities.insert(record)
        write.waiting = (record, activities)
        queue.enqueue(write)

        return true
    }

    /// 写操作失败时的处理：后台写入只记进 Activity；被本地改动挡住的检出、拉取与合并改为询问是否先储藏，
    /// 用户不储藏时再报告失败。
    ///
    /// - Parameters:
    ///   - operation: 失败的写操作。
    ///   - branch: 写入前状态快照中的分支与 HEAD。
    ///   - repository: 写操作所在的仓库。
    ///   - output: 追加到 Activity 记录的输出。
    /// - Returns: 以错误与是否取消调用的处理。
    func failureReport(
        for operation: GitWriteOperation,
        branch: BranchStatus?,
        in repository: RepositoryLocation,
        output: @escaping (GitOutputEvent) -> Void
    ) -> (Error, Bool) -> Void {
        { [weak self] error, cancelled in
            guard let self else { return }

            guard !operation.background else {
                recordQuietFailure(error, cancelled: cancelled, in: repository, output: output)
                return
            }

            let stashing = operation.offersAutoStash && !cancelled
                && offerAutoStash(
                    after: error,
                    title: operation.title,
                    action: operation.action,
                    failureNote: operation.failureNote,
                    undo: operation.undo
                )

            if !stashing {
                reportWriteFailure(
                    error,
                    cancelled: cancelled,
                    title: operation.title,
                    note: operation.failureNote?(),
                    branch: branch,
                    in: repository
                )
            }
        }
    }
}

// MARK: - GitWriteOperation

/// `performGit` 收下的一次写操作：动作与执行时的选项，立即执行或排到轮到时再执行。
struct GitWriteOperation {
    /// 写操作的动作。
    let action: @Sendable (GitRunner, @escaping @Sendable (GitOutputEvent) -> Void) async throws -> Void

    /// 已本地化的操作名称。
    let title: String

    /// 整页进度的标题；不占用工作区的写操作为 nil。
    let progress: String?

    /// 是否记进 Activity。
    let recordsActivity: Bool

    /// 连接的对象；不连接远端的写操作为 nil。
    let target: ActivityTarget?

    /// 被本地改动挡住时是否询问先储藏。
    let offersAutoStash: Bool

    /// 不由用户直接发起：失败只记进 Activity。
    let background: Bool

    /// 与撤销记录的关系。
    let undo: UndoRecording

    /// 成功后调用。
    let success: (() -> Void)?

    /// 失败时补在错误说明前面的一段话。
    let failureNote: (() -> String?)?
}
