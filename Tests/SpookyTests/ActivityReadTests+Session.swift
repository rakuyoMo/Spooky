import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Session

extension ActivityReadTests {
    /// 刷新里各读取的标题键。
    private static let refreshTitles = [
        "activity.read.status",
        "activity.read.branches",
        "activity.read.remotes",
        "activity.read.tags",
        "activity.read.stashes",
        "activity.read.submodules",
        "activity.read.worktrees",
        "activity.read.commits",
        "activity.read.commitCount",
    ]

    /// 完整刷新记下工作区、引用、储藏、子模块、工作树与历史的读取，每条写耗时；选中文件读一侧的 Diff，记一条；
    /// 文件变化这类不记录的刷新不新增记录，也不动基准，随之换了暂存侧的 Diff 不再读第二次；同一仓库的两个会话共用基准。
    @Test("刷新的读取记进 Repository 页", .timeLimit(.minutes(5)))
    func refreshRecords() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-读取 " + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 一个提交、一个储藏，之后再有一个改动与一个未跟踪文件
        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let file = directory.appending(path: "a.txt")
        try Data("one\n".utf8).write(to: file)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])
        try Data("two\n".utf8).write(to: file)
        _ = try await runner.run(["stash", "push", "-q"])
        try Data("three\n".utf8).write(to: file)
        try Data("new\n".utf8).write(to: directory.appending(path: "new.txt"))

        let activities = RepositoryActivities()
        let session = RepositorySession(makeRunner: { _ in runner }, activities: activities)
        defer { session.close() }

        session.display(location)
        session.refresh(full: true)
        try await waitUntil { Self.refreshTitles.allSatisfy { results($0, in: activities).count == 1 } }

        // 读取并发，不核对顺序；没有基准时全算新增
        #expect(results("activity.read.status", in: activities) == [AppLocalization.text("activity.result.entries", 2)])
        #expect(results("activity.read.branches", in: activities) == [changes(0, 1, 0)])
        #expect(results("activity.read.remotes", in: activities) == [changes(0, 0, 0)])
        #expect(results("activity.read.tags", in: activities) == [nil])
        #expect(results("activity.read.stashes", in: activities) == [changes(0, 1, 0)])
        #expect(results("activity.read.submodules", in: activities) == [changes(0, 0, 0)])
        #expect(results("activity.read.worktrees", in: activities) == [nil])
        #expect(results("activity.read.commits", in: activities) == [AppLocalization.text("activity.result.commits", 1)])
        #expect(results("activity.read.commitCount", in: activities) == [nil])
        #expect(activities.items.allSatisfy { $0.kind == .repository && $0.state == "activity.finished" })
        #expect(activities.items.allSatisfy { $0.elapsed != nil })

        // 选中有未暂存改动的文件，读这一侧的 Diff
        session.selectedID = StatusRowID(path: "a.txt", kind: .tracked)
        try await waitUntil { results("activity.read.unstagedDiff", in: activities).count == 1 }
        try await waitUntil { !session.isLoadingDiff }

        // 不记录的刷新：读到新分支也不记录，基准不变；文件只剩暂存的改动，Diff 换到暂存的一侧，暂存侧变化后不再读一次
        _ = try await runner.run(["branch", "extra"])
        _ = try await runner.run(["add", "a.txt"])
        let recorded = activities.items.count
        session.refresh()
        await session.waitForRefresh()
        await waitForReads(of: session)
        try await waitUntil { session.diffSide == .staged && !session.isLoadingDiff }

        session.diffSideChanged()
        #expect(!session.isLoadingDiff)
        #expect(activities.items.count == recorded)

        // 另一个会话的完整刷新与同一份基准比较，只多出这个分支
        let other = RepositorySession(makeRunner: { _ in runner }, activities: activities)
        defer { other.close() }

        other.display(location)
        other.refresh(full: true)
        try await waitUntil { Self.refreshTitles.allSatisfy { results($0, in: activities).count == 2 } }

        #expect(results("activity.read.branches", in: activities).first == changes(0, 1, 0))
        #expect(results("activity.read.stashes", in: activities).first == changes(0, 0, 0))
        #expect(Self.refreshTitles.allSatisfy { results($0, in: activities).count == 2 })
    }

    /// 标题为这个键的记录的一行结果，最新的在前。
    private func results(_ key: String, in activities: RepositoryActivities) -> [String?] {
        activities.items
            .filter { $0.title == AppLocalization.text(key) }
            .map(\.result)
    }

    /// 等引用、历史与储藏的读取结束；读取期间又要求的刷新在读完后另起任务，也一起等完。
    private func waitForReads(of session: RepositorySession) async {
        var awaited = Set<Task<Void, Never>>()

        while
            let task = (session.history.activeTasks + session.stashes.activeTasks)
                .first(where: { !awaited.contains($0) })
        {
            await task.value
            awaited.insert(task)
        }
    }

    /// 等到条件成立，最多 5 分钟。
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("等待超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
