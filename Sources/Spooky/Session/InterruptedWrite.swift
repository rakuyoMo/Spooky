import Foundation
import SpookyKit

// MARK: - InterruptedWrite

/// 因断线而结果未知的写操作；重连核对后据此告诉用户 HEAD 是否变化。
struct InterruptedWrite {
    /// 已本地化的操作名称。
    let title: String

    /// 写入前状态快照中的分支与 HEAD。
    let branch: BranchStatus?

    /// 中断发生的时间，只采用在此之后完成的核对结果。
    let time: Date

    /// 写入前快照中的远端跟踪分支与提交，核对获取、推送是否已改动它们。
    var remoteReferences: [String: String] = [:]
}
