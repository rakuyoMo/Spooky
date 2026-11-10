import Foundation
import Observation
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Refresh

extension FileViewsTests {
    /// HEAD 移动后时间线在后台重读，读回已加载的条数，所选提交与它的补丁都不被改写；
    /// 所选提交不在新的时间线里时，选择与详情一起清空。
    @Test("HEAD 移动后文件历史保持选择与详情")
    func fileHistoryRefresh() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await Self.initializeRepository(at: location)
        try await HistoryListTests.importCommits((0 ..< 150).map { "commit \($0)" }, with: runner)

        let references = RepositoryReferences(runner: runner)
        let state = FileHistoryState()
        state.activities = RepositoryActivities()
        defer { state.close() }

        // 打开 file.txt 的历史，续载第二页，选中排在第一页之后的提交并读出补丁
        state.open("file.txt", head: try await references.resolve("HEAD"), runner: runner)
        await until { !state.isLoading }

        state.loadNextPage()
        await until { !state.isLoading }

        let target = state.commits[120]
        state.selectedID = target.id
        await until { state.diff != nil }

        // 提交一次后按新的 HEAD 重读：所选提交、补丁、原文与详情的失败都不被改写
        let rewritten = Mutex(false)

        withObservationTracking {
            _ = state.selectedID
            _ = state.diff
            _ = state.content
            _ = state.detailFailure
        } onChange: {
            rewritten.withLock { $0 = true }
        }

        try Data("next\n".utf8).write(to: directory.appending(path: "file.txt"))
        _ = try await runner.run(["commit", "-q", "-a", "-m", "next"])

        state.update(head: try await references.resolve("HEAD"))
        await until { !state.isLoading }
        await untilFinished { [state.detailTask].compactMap { $0 } }

        #expect(!rewritten.withLock { $0 })
        #expect(state.commits.count == 150)
        #expect(state.commits.first?.subject == "next")
        #expect(state.selectedCommit == target)

        // 回退到所选提交之前，它不在新的时间线里了
        _ = try await runner.run(["reset", "-q", "--hard", "HEAD~140"])
        state.update(head: try await references.resolve("HEAD"))
        await until { !state.isLoading }

        #expect(state.selectedID == nil)
        #expect(state.diff == nil)
    }
}
