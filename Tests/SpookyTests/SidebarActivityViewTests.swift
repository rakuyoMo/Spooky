import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarActivityViewTests

/// 侧边栏底部的活动区：列出哪些记录与它们的顺序，以及行里的标题、进度条的值、停止按钮与第三行。
@MainActor
struct SidebarActivityViewTests {
    /// 窗口所在的仓库。
    private let location = RepositoryLocation.local(path: "/tmp/Alpha")

    /// 别的窗口的仓库。
    private let other = RepositoryLocation.local(path: "/tmp/Beta")

    /// 当前时间。
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// 区里只有本仓库本次运行里的远程操作：进行中的一直在，结束的留 4 s，用户看得到刚结束的结果又不会越积越多；
    /// 状态已换成结束、输出还没收完的仍算进行中。顺序同 Activity，最新的在上。
    @Test("列出的记录")
    func items() throws {
        let running = fetch(location)

        let justEnded = fetch(location)

        justEnded.state = "activity.finished"
        justEnded.ended = now.addingTimeInterval(-3.9)

        let collecting = fetch(location)

        collecting.state = "activity.failed"

        let expired = fetch(location)

        expired.state = "activity.finished"
        expired.ended = now.addingTimeInterval(-4)

        let restored = RepositoryActivity(record: try #require(expired.record))
        let elsewhere = fetch(other)
        let checkout = RepositoryActivity(kind: .repository, repository: location, title: "Check Out")
        let request = RepositoryActivity(kind: .service, repository: location, title: "Load Pull Requests")

        let activities = [
            running,
            elsewhere,
            justEnded,
            checkout,
            collecting,
            request,
            expired,
            restored,
        ]

        let listed = SidebarActivityView.items(of: activities, in: location, now: now)

        #expect(listed.map(\.id) == [running.id, justEnded.id, collecting.id])
    }

    /// 进行中的跟着 git 的进度走；完成与失败满格，表示这次传输已经结束；取消停在当时的位置，看得出停在了哪里。
    /// 停止按钮只在进行中、有取消入口时可用；结束后按钮仍在而不可用，不会去取消已经结束的操作。
    @Test("进度条的值与停止按钮")
    func progressAndCancel() {
        let activity = fetch(location)

        #expect(row(activity).progress == 0)

        activity.append(.standardError(Data("Receiving objects:  50% (6/12)\r".utf8)))

        #expect(row(activity).progress == 0.125)

        activity.state = "activity.cancelled"

        #expect(row(activity).progress == 0.125)

        activity.state = "activity.finished"

        #expect(row(activity).progress == 1)

        activity.state = "activity.failed"

        #expect(row(activity).progress == 1)

        // 停止按钮：有取消入口才可用
        let activities = RepositoryActivities()
        let cancellable = fetch(location)

        #expect(!row(cancellable).canCancel)

        cancellable.cancel = { }

        #expect(row(cancellable).canCancel)

        // 状态已换成结束、取消入口还没清掉
        cancellable.state = "activity.finished"

        #expect(!row(cancellable).canCancel)

        activities.finish(cancellable)

        #expect(!row(cancellable).canCancel)
    }

    /// 排队等待的写操作不论哪一页都列在进行中与刚结束的行下面，先轮到的在上；Repository 页的记录开始执行后离开，
    /// 执行中被停止的不列，在队列里取消或跳过的与结束的远程操作一样再留 4 s。
    @Test("等待中与没有执行的记录")
    func waitingItems() {
        let running = fetch(location)

        // 先后排进队列的三项，记录按插入最新的在前
        let first = waiting(RepositoryActivity(repository: location, title: "Check Out", target: nil))
        let second = waiting(fetch(location))
        let third = waiting(RepositoryActivity(repository: location, title: "Commit", target: nil))

        // 在队列里取消的、刚跳过的与已过 4 s 的
        let cancelled = ended(RepositoryActivity(repository: location, title: "Stage", target: nil), "activity.cancelled", -1)
        let skipped = ended(RepositoryActivity(repository: location, title: "Merge", target: nil), "activity.skipped", -3.9)
        let expired = ended(RepositoryActivity(repository: location, title: "Pull", target: nil), "activity.cancelled", -4)

        cancelled.endedWhileWaiting = true
        skipped.endedWhileWaiting = true
        expired.endedWhileWaiting = true

        // 开始执行后的 Repository 记录，以及执行中被停止的
        let started = RepositoryActivity(repository: location, title: "Rebase", target: nil)
        let stopped = ended(RepositoryActivity(repository: location, title: "Reset", target: nil), "activity.cancelled", -1)

        let activities = [third, skipped, second, running, started, cancelled, first, expired, stopped]
        let listed = SidebarActivityView.items(of: activities, in: location, now: now)

        #expect(listed.map(\.id) == [skipped.id, running.id, cancelled.id, first.id, second.id, third.id])
    }

    /// 等待中的行写这次写操作的标题，进度条是空的，停止按钮可用，第三行写 Waiting…；
    /// 在队列里取消后标题接 cancelled、按钮不可用，跳过的接 skipped；执行中被停止的远程操作照 Activity 窗口写。
    @Test("等待中与没有执行的行")
    func waitingRow() {
        let activities = RepositoryActivities()
        let checkout = waiting(RepositoryActivity(repository: location, title: "Check Out", target: nil))
        let push = waiting(RepositoryActivity(repository: location, title: "Push", target: .push("origin", refspec: "main")))

        activities.insert(checkout)

        for activity in [checkout, push] {
            activity.cancel = { }

            #expect(row(activity).title == activity.title)
            #expect(row(activity).summary == AppLocalization.text("activity.waitingDetail"))
            #expect(row(activity).progress == 0)
            #expect(row(activity).canCancel)
        }

        // 经写队列取消：记录结束、记下没有执行，标题接 cancelled
        let queue = RepositoryWriteQueue()
        let holder = RepositoryWrite(location: location, session: nil, title: "Hold")
        let write = RepositoryWrite(location: location, session: nil, title: "Check Out")

        write.waiting = (checkout, activities)

        #expect(queue.begin(holder))
        queue.enqueue(write)
        queue.cancel(write)
        queue.finish(holder)

        #expect(checkout.endedWhileWaiting)
        #expect(row(checkout).title == AppLocalization.text("activity.titleCancelled", "Check Out"))
        #expect(!row(checkout).canCancel)

        push.state = "activity.skipped"
        push.endedWhileWaiting = true

        #expect(row(push).title == AppLocalization.text("activity.titleSkipped", "Push"))

        // 执行中被停止的远程操作
        let stopped = ended(fetch(location), "activity.cancelled", -1)

        #expect(row(stopped).title == stopped.displayTitle)
    }

    /// 本次运行里获取一个远端的记录。
    ///
    /// - Parameter repository: 记录所在的仓库。
    private func fetch(_ repository: RepositoryLocation) -> RepositoryActivity {
        RepositoryActivity(repository: repository, title: "Fetch", target: .fetch("origin"))
    }

    /// 把记录改为排队等待中。
    ///
    /// - Parameter activity: 刚建立的记录。
    private func waiting(_ activity: RepositoryActivity) -> RepositoryActivity {
        activity.state = "activity.waiting"
        return activity
    }

    /// 把记录改为已结束。
    ///
    /// - Parameters:
    ///   - activity: 刚建立的记录。
    ///   - state: 结束的状态键。
    ///   - offset: 结束时刻相对 `now` 的秒数。
    private func ended(_ activity: RepositoryActivity, _ state: String, _ offset: TimeInterval) -> RepositoryActivity {
        activity.state = state
        activity.ended = now.addingTimeInterval(offset)
        return activity
    }

    /// 显示这条记录的行。
    ///
    /// - Parameter activity: 行的记录。
    private func row(_ activity: RepositoryActivity) -> SidebarActivityRow {
        SidebarActivityRow(activity: activity, showsSeparator: false, showActivity: { })
    }
}
