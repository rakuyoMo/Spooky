import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - WriteActivityTests

/// 一次写操作的 Activity 记录怎样分条：获取全部远端时每个远端一条，同步的推送另起一条；
/// 输出、状态与取消入口按事件的先后落在各自的记录上。
@MainActor
struct WriteActivityTests {
    /// 测试记录所属的仓库。
    private let location = RepositoryLocation.local(path: "/tmp/Alpha")

    /// 获取全部远端：第一个远端补在开始时的记录上，之后每个远端另起一条，前一条记为完成并收尾；
    /// 取消入口交给正在获取的那一条，最后的状态只落在最后一条上。
    @Test("获取全部远端每个远端一条")
    func fetchAll() {
        let activities = RepositoryActivities()
        let record = WriteActivity(
            activities: activities,
            repository: location,
            title: "Quick Fetch",
            target: .fetch(nil)
        )
        var cancelled = 0
        record.cancel = { cancelled += 1 }

        let first = record.current
        record.receive(.next(.fetch("origin")))
        #expect(record.current === first)
        #expect(first.target == .fetch("origin"))

        record.receive(.output(.standardError(Data("From origin\n".utf8))))
        record.receive(.next(.fetch("second")))
        record.receive(.output(.standardError(Data("From second\n".utf8))))

        let second = record.current
        #expect(activities.items.map(\.id) == [second.id, first.id])
        #expect(first.state == "activity.finished")
        #expect(first.ended != nil)
        #expect(first.cancel == nil)
        #expect(first.log == "From origin\n")

        // 取消入口跟着换到正在获取的记录
        second.cancel?()
        #expect(cancelled == 1)

        record.receive(.state("activity.failed"))
        record.finish()

        #expect(second.target == .fetch("second"))
        #expect(second.title == "Quick Fetch")
        #expect(second.state == "activity.failed")
        #expect(second.log == "From second\n")
        #expect(second.ended != nil)
        #expect(first.state == "activity.finished")
    }

    /// 同步：获取与拉取写在拉取记录里，推送另起一条；与当前记录相同的对象不另起；
    /// 记在 Repository 页的写操作（如储藏后重试的同步）不分条。
    @Test("同步的推送另起一条，Repository 页不分条")
    func syncAndRepository() {
        let activities = RepositoryActivities()
        let pull = ActivityTarget.pull("origin", refspec: "refs/heads/main")
        let sync = WriteActivity(activities: activities, repository: location, title: "Sync", target: pull)

        sync.receive(.state("sync.step.fetch"))
        sync.receive(.next(pull))
        #expect(activities.items.count == 1)

        sync.receive(.next(.push("origin", refspec: "refs/heads/main")))
        sync.receive(.state("sync.step.push"))
        #expect(activities.items.count == 2)
        #expect(activities.items.last?.target == pull)
        #expect(activities.items.last?.state == "activity.finished")
        #expect(sync.current.target == .push("origin", refspec: "refs/heads/main"))
        #expect(sync.current.state == "sync.step.push")

        // 储藏后重试的同步没有连接对象，记在 Repository 页
        let retry = WriteActivity(activities: activities, repository: location, title: "Sync", target: nil)
        retry.receive(.next(.push("origin")))
        #expect(retry.current.kind == .repository)
        #expect(retry.current.target == nil)
        #expect(activities.items.count == 3)
    }
}
