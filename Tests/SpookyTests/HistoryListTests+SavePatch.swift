import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Save Patch

extension HistoryListTests {
    /// 快速保存每个提交记一条 Format Patch，写耗时、没有一行结果，没有整次保存的记录；保存后在 Finder 里选中补丁。
    /// 第一个提交执行中取消时只有这一条记为 Cancelled，后面的提交不执行，也不打开 Finder、不提示失败。
    @Test("保存补丁按提交记进 Repository 页", .timeLimit(.minutes(5)))
    func savePatchRecords() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await Self.importCommits(["first", "second"], with: runner)

        // 列表从新到旧排列
        let newer = try await Self.commit(at: 0, with: runner)
        let older = try await Self.commit(at: 1, with: runner)

        // 只记下要在 Finder 里选中的文件，不打开 Finder
        var revealed: [[String]] = []
        let reveal = RepositorySession.revealInFinder
        RepositorySession.revealInFinder = { revealed.append($0.map(\.lastPathComponent)) }
        defer { RepositorySession.revealInFinder = reveal }

        let activities = RepositoryActivities()
        let session = RepositorySession(
            makeRunner: { _ in runner },
            loadStatus: { _ in try await runner.status() },
            activities: activities
        )
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }
        session.display(location)

        session.requestSavePatch([newer, older], quick: true)
        try await FileViewsTests.wait { !revealed.isEmpty }

        let saved = formatPatches(in: activities)
        #expect(saved.count == 2)
        #expect(saved.allSatisfy { activity in
            activity.state == "activity.finished"
                && activity.elapsed != nil
                && activity.result == nil
        })

        #expect(!activities.items.contains { $0.title == AppLocalization.text("patch.title") })
        #expect(revealed == [["0001-first.patch", "0002-second.patch"]])

        // 第一个提交的记录一插入就取消，这时它的 format-patch 还没执行完
        session.requestSavePatch([newer, older], quick: true)

        while formatPatches(in: activities).count == saved.count {
            try await Task.sleep(for: .milliseconds(1))
        }

        let running = try #require(formatPatches(in: activities).first)
        running.cancel?()
        try await FileViewsTests.wait { running.isEnded }

        // 留出后面的提交开始执行所需的时间，确认它没有开始
        try await Task.sleep(for: .milliseconds(200))

        #expect(running.state == "activity.cancelled")
        #expect(formatPatches(in: activities).count == saved.count + 1)
        #expect(revealed.count == 1)
        #expect(failures.isEmpty)
    }

    /// Repository 页里的 Format Patch 记录，最新的在前。
    private func formatPatches(in activities: RepositoryActivities) -> [RepositoryActivity] {
        activities.items.filter { $0.title == AppLocalization.text("patch.formatPatch") }
    }
}
