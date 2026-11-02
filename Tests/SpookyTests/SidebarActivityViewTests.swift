import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SidebarActivityViewTests

/// 侧边栏底部的活动区：列出哪些记录、区高，以及行里进度条的值与停止按钮。
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

    /// 每行 65，最多露出三行，再多在区内滚动；没有行时收起成 0。
    @Test("区高")
    func height() {
        #expect(SidebarActivityView.height(rows: 0) == 0)
        #expect(SidebarActivityView.height(rows: 1) == 65)
        #expect(SidebarActivityView.height(rows: 3) == 195)
        #expect(SidebarActivityView.height(rows: 4) == 195)
    }

    /// 进行中的跟着 git 的进度走；完成与失败满格，表示这次传输已经结束；取消停在当时的位置，看得出停在了哪里。
    @Test("进度条的值")
    func progress() {
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
    }

    /// 停止按钮只在进行中、有取消入口时可用；结束后按钮仍在而不可用，不会去取消已经结束的操作。
    @Test("停止按钮")
    func cancel() {
        let activities = RepositoryActivities()
        let activity = fetch(location)
        #expect(!row(activity).canCancel)

        activity.cancel = { }
        #expect(row(activity).canCancel)

        // 状态已换成结束、取消入口还没清掉
        activity.state = "activity.finished"
        #expect(!row(activity).canCancel)

        activities.finish(activity)
        #expect(!row(activity).canCancel)
    }

    /// 本次运行里获取一个远端的记录。
    ///
    /// - Parameter repository: 记录所在的仓库。
    private func fetch(_ repository: RepositoryLocation) -> RepositoryActivity {
        RepositoryActivity(repository: repository, title: "Fetch", target: .fetch("origin"))
    }

    /// 显示这条记录的行。
    ///
    /// - Parameter activity: 行的记录。
    private func row(_ activity: RepositoryActivity) -> SidebarActivityRow {
        SidebarActivityRow(activity: activity, showsSeparator: false, showActivity: { })
    }
}
