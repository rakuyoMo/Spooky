import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Save Patch

extension HistoryListTests {
    /// 快速保存每个提交记一条 Format Patch，写耗时、没有一行结果，没有整次保存的记录；保存后在 Finder 里选中补丁。
    /// 第一个提交执行中取消时只有这一条记为 Cancelled，后面的提交不执行，也不打开 Finder、不提示失败。
    @Test("保存补丁按提交记进 Repository 页")
    func savePatchRecords() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        let tools = try FileViewsTests.temporaryDirectory()

        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: tools)
        }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await Self.importCommits(["first", "second"], with: runner)

        // 列表从新到旧排列
        let newer = try await Self.commit(at: 0, with: runner)
        let older = try await Self.commit(at: 1, with: runner)

        // 每个提交的 format-patch 开始前停在闸门上，放行后才执行
        let gate = try ProcessGate(in: tools)
        defer { gate.release() }

        let gated = try Self.scriptedRunner(location: location, tools: tools, cases: """
            *format-patch*)
                \(gate.command)
                ;;
            """)

        // 只记下要在 Finder 里选中的文件，不打开 Finder
        var revealed: [[String]] = []
        let reveal = RepositorySession.revealInFinder
        RepositorySession.revealInFinder = { revealed.append($0.map(\.lastPathComponent)) }
        defer { RepositorySession.revealInFinder = reveal }

        let activities = RepositoryActivities()
        let session = RepositorySession(
            makeRunner: { _ in gated },
            loadStatus: { _ in try await runner.status() },
            activities: activities
        )
        defer { session.close() }

        var failures: [AppFailure] = []
        session.onFailure = { failures.append($0) }
        session.display(location)

        // 两个提交依次走到闸门，逐个放行；保存完最后一步是在 Finder 里选中补丁
        session.requestSavePatch([newer, older], quick: true)

        for _ in 0 ..< 2 {
            await gate.arrival()
            gate.release()
        }

        await until { !revealed.isEmpty }

        let saved = formatPatches(in: activities)
        #expect(saved.count == 2)
        #expect(saved.allSatisfy { activity in
            activity.state == "activity.finished"
                && activity.elapsed != nil
                && activity.log.isEmpty
        })

        #expect(!activities.items.contains { $0.title == AppLocalization.text("patch.title") })
        #expect(revealed == [["0001-first.patch", "0002-second.patch"]])

        // 再保存一次：第一个提交的记录已插入，它的 format-patch 停在闸门上，这时取消
        session.requestSavePatch([newer, older], quick: true)
        await gate.arrival()

        let running = try #require(formatPatches(in: activities).first)
        #expect(formatPatches(in: activities).count == saved.count + 1)

        running.cancel?()

        // 取消带来的错误在这条记录结束之后才离开这个提交，后面的提交不会再开始
        await until { running.isEnded }

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
