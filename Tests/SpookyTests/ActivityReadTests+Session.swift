import Foundation
import Testing
import TestSupport

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
    /// 文件变化这类不记录的刷新不新增记录，也不动基准，随之换了暂存侧的 Diff 不再读第二次；同一仓库的两个会话共用基准；
    /// 设了保存位置时基准写进本机，退出再打开后与读回的基准接着比。
    @Test("刷新的读取记进 Repository 页，基准存到本机")
    func refreshRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-读取 " + UUID().uuidString)

        let repository = directory.appending(path: "仓库")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 一个提交、一个储藏，之后再有一个改动与一个未跟踪文件
        let location = RepositoryLocation.local(path: repository.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let file = repository.appending(path: "a.txt")
        try Data("one\n".utf8).write(to: file)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])
        try Data("two\n".utf8).write(to: file)
        _ = try await runner.run(["stash", "push", "-q"])
        try Data("three\n".utf8).write(to: file)
        try Data("new\n".utf8).write(to: repository.appending(path: "new.txt"))

        let archive = ActivityBaselineArchive(directory: directory.appending(path: "Baselines"))
        let activities = RepositoryActivities()
        activities.baselineArchive = archive

        let session = RepositorySession(makeRunner: { _ in runner }, activities: activities)
        defer { session.close() }

        await refreshFully(session, at: location, times: 1)

        // 读取并发，不核对顺序；没有基准时全算新增
        let entries = AppLocalization.text("activity.result.entries", 2)
        let commits = AppLocalization.text("activity.result.commits", 1)

        #expect(results("activity.read.status", in: activities) == [entries])
        #expect(results("activity.read.branches", in: activities) == [changes(0, 1, 0)])
        #expect(results("activity.read.remotes", in: activities) == [changes(0, 0, 0)])
        #expect(results("activity.read.tags", in: activities) == [nil])
        #expect(results("activity.read.stashes", in: activities) == [changes(0, 1, 0)])
        #expect(results("activity.read.submodules", in: activities) == [changes(0, 0, 0)])
        #expect(results("activity.read.worktrees", in: activities) == [nil])
        #expect(results("activity.read.commits", in: activities) == [commits])
        #expect(results("activity.read.commitCount", in: activities) == [nil])
        #expect(activities.items.allSatisfy { $0.kind == .repository && $0.state == "activity.finished" })
        #expect(activities.items.allSatisfy { $0.elapsed != nil })

        // 选中有未暂存改动的文件，读这一侧的 Diff
        session.selectedID = StatusRowID(path: "a.txt", kind: .tracked)
        await session.diffTask?.value

        #expect(results("activity.read.unstagedDiff", in: activities).count == 1)

        // 不记录的刷新：读到新分支也不记录，基准不变；文件只剩暂存的改动，Diff 换到暂存的一侧，暂存侧变化后不再读一次
        _ = try await runner.run(["branch", "extra"])
        _ = try await runner.run(["add", "a.txt"])
        let recorded = activities.items.count

        session.refresh()
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks + session.stashes.activeTasks }
        await session.diffTask?.value

        #expect(session.diffSide == .staged)
        session.diffSideChanged()
        #expect(!session.isLoadingDiff)
        #expect(activities.items.count == recorded)

        // 另一个会话的完整刷新与同一份基准比较，只多出这个分支
        let other = RepositorySession(makeRunner: { _ in runner }, activities: activities)
        defer { other.close() }

        await refreshFully(other, at: location, times: 2)

        #expect(results("activity.read.branches", in: activities).first == changes(0, 1, 0))
        #expect(results("activity.read.stashes", in: activities).first == changes(0, 0, 0))

        // 退出：两个会话都关掉，基准写完
        session.close()
        other.close()
        await activities.baselineWrite?.value

        try await reopen(location, runner: runner, archive: archive)
    }

    /// 退出期间在终端新建一个分支，再换一个用同一目录的活动列表打开：四类基准都已写进本机，
    /// 与读回的基准比较时没变的储藏不算增减，退出期间多出的分支算新增。
    ///
    /// - Parameters:
    ///   - location: 仓库位置。
    ///   - runner: 仓库的执行器。
    ///   - archive: 上一次运行写进基准的位置。
    private func reopen(
        _ location: RepositoryLocation,
        runner: GitRunner,
        archive: ActivityBaselineArchive
    ) async throws {
        #expect(archive.load(location).keys.sorted(by: { $0.rawValue < $1.rawValue }) == [
            .branches,
            .remotes,
            .stashes,
            .submodules,
        ])

        _ = try await runner.run(["branch", "late"])

        let activities = RepositoryActivities()
        activities.baselineArchive = archive

        let session = RepositorySession(makeRunner: { _ in runner }, activities: activities)
        defer { session.close() }

        await refreshFully(session, at: location, times: 1)

        #expect(results("activity.read.branches", in: activities) == [changes(0, 1, 0)])
        #expect(results("activity.read.stashes", in: activities) == [changes(0, 0, 0)])
    }

    /// 用会话打开仓库做一次完整刷新，等这次刷新的每一项读取都记下。
    ///
    /// 每条记录在它的读取结束时插入，各标题的记录都到了第 `times` 条，就是这次刷新的读取都结束了。
    ///
    /// - Parameters:
    ///   - session: 显示仓库的会话。
    ///   - location: 仓库位置。
    ///   - times: 刷新结束后同一活动列表里每个标题应有的记录条数。
    private func refreshFully(_ session: RepositorySession, at location: RepositoryLocation, times: Int) async {
        session.display(location)
        session.refresh(full: true)

        await until {
            Self.refreshTitles.allSatisfy { results($0, in: session.activities).count == times }
        }
    }

    /// 标题为这个键的记录的一行结果，最新的在前。
    private func results(_ key: String, in activities: RepositoryActivities) -> [String?] {
        activities.items
            .filter { $0.title == AppLocalization.text(key) }
            .map(\.lastLine)
    }
}
