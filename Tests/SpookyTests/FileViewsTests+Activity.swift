import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Activity

extension FileViewsTests {
    /// 文件历史、原文与 Blame 的读取记进 Repository 页：第一页写出读到的提交数，总数、补丁、原文与逐行追溯各记一条；
    /// HEAD 移动引起的重读与引起它的刷新相同，不记录的刷新引起的不记，完整刷新引起的照常记；按版本范围筛选时不读总数。
    @Test("文件视图的读取记进 Repository 页", .timeLimit(.minutes(5)))
    func fileViewReads() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)
        let file = directory.appending(path: "root.txt")
        try Data("one\n".utf8).write(to: file)
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        // 注入状态读取的会话不读其余视图，也没有文件监听另起的刷新：记录只来自状态与文件视图
        let activities = RepositoryActivities()
        let session = RepositorySession(
            makeRunner: { _ in runner },
            loadStatus: { _ in try await runner.status() },
            activities: activities
        )
        defer { session.close() }

        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        // 文件历史：第一页写出读到的提交数，总数没有结果
        session.showFileHistory("root.txt")
        try await Self.wait { session.fileHistory.totalCount != nil }

        let root = try #require(session.fileHistory.commits.first)

        #expect(
            results("activity.read.commits", in: activities)
                == [AppLocalization.text("activity.result.commits", 1)]
        )
        #expect(results("activity.read.commitCount", in: activities) == [nil])

        // 所选提交的补丁与原文各记一条
        session.fileHistory.selectedID = root.id
        try await Self.wait { session.fileHistory.diff != nil }
        #expect(results("activity.read.commitDiffs", in: activities) == [nil])

        session.fileHistory.detailMode = .raw
        try await Self.wait { session.fileHistory.content != nil }
        #expect(results("activity.read.blob", in: activities) == [nil])

        // Blame 先读原文再读逐行追溯
        session.showFile("root.txt", at: nil, mode: .blame)
        try await Self.wait { session.fileContent.blame != nil }
        #expect(results("activity.read.blob", in: activities).count == 2)
        #expect(results("activity.read.blame", in: activities) == [nil])

        // 读取都在结束时记一条已结束的记录
        #expect(activities.items.allSatisfy { $0.kind == .repository && $0.state == "activity.finished" })

        // HEAD 移动后不记录的刷新：文件历史、所选提交的原文与 Blame 都重读，但不新增记录
        try Data("one\ntwo\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-a", "-m", "second"])

        let recorded = activities.items.count
        session.refresh()
        await session.waitForRefresh()
        try await waitForFileViews(of: session, commits: 2)
        #expect(activities.items.count == recorded)

        // 再提交一次，完整刷新引起的重读照常记录
        try Data("one\ntwo\nthree\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-a", "-m", "third"])

        session.refresh(full: true)
        await session.waitForRefresh()
        try await waitForFileViews(of: session, commits: 3)

        #expect(
            results("activity.read.commits", in: activities).first
                == AppLocalization.text("activity.result.commits", 3)
        )
        #expect(results("activity.read.commitCount", in: activities).count == 2)
        #expect(results("activity.read.blob", in: activities).count == 4)
        #expect(results("activity.read.blame", in: activities).count == 2)

        // 按版本范围筛选：只读最近修改过这个文件的一个提交，不读总数
        session.fileHistory.scope = .revision
        try await Self.wait { session.fileHistory.totalCount == 3 && session.fileHistory.content != nil }

        let before = activities.items.count
        session.fileHistory.search(root.id)
        try await Self.wait { session.fileHistory.totalCount == 1 && session.fileHistory.content != nil }

        let added = activities.items.prefix(activities.items.count - before).map(\.title)
        #expect(added.contains(AppLocalization.text("activity.read.commits")))
        #expect(!added.contains(AppLocalization.text("activity.read.commitCount")))
    }

    /// 标题为这个键的记录的一行结果，最新的在前。
    private func results(_ key: String, in activities: RepositoryActivities) -> [String?] {
        activities.items
            .filter { $0.title == AppLocalization.text(key) }
            .map(\.result)
    }

    /// 等 HEAD 移动后文件历史、所选提交的原文与跟随 HEAD 的 Blame 都重读完。
    ///
    /// 刷新替换状态时已同步发起重读、清掉旧结果，所以这些结果再出现时就是重读的结果。
    private func waitForFileViews(of session: RepositorySession, commits: Int) async throws {
        try await Self.wait {
            session.fileHistory.totalCount == commits
                && session.fileHistory.content != nil
                && session.fileContent.blame?.lines.count == commits
        }
    }
}
