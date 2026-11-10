import Foundation
import Observation
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Refresh

extension HistoryListTests {
    /// 刷新从头重读列表时读回已加载的条数，选中的提交、展开与选中的文件和已读的补丁都不被改写；
    /// 选中的提交在刷新后不在历史里时，选择与详情一起清空。
    @Test("刷新时保持历史的选择、展开与已读的补丁")
    func refreshKeepsDetails() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 150).map { "commit \($0)" })
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history

        // 续载第二页，选中排在第一页之后的提交，展开并选中它改动的文件
        history.loadNextPage()
        await untilFinished { history.activeTasks }

        let target = try await Self.commit(at: 120, with: fixture.runner)
        history.selectedIDs = [target.id]
        await untilFinished { history.activeTasks }

        history.expandedPaths = ["file.txt"]
        history.selectedPath = "file.txt"
        await untilFinished { history.activeTasks }

        #expect(history.commits.count == 150)
        #expect(history.changes.map(\.path) == ["file.txt"])
        #expect(history.diffs["file.txt"]?.diff != nil)

        // 改动工作区后刷新：列表与详情在后台重读，变更集、展开、选中的文件、补丁与读取状态都不被改写
        let rewritten = Mutex(false)

        withObservationTracking {
            _ = history.changes
            _ = history.expandedPaths
            _ = history.selectedPath
            _ = history.diffs
            _ = history.isLoadingChanges
        } onChange: {
            rewritten.withLock { $0 = true }
        }

        try Data("changed\n".utf8).write(to: fixture.directory.appending(path: "file.txt"))
        session.refresh()
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }

        #expect(!rewritten.withLock { $0 })
        #expect(history.commits.count == 150)
        #expect(history.selectedCommit == target)

        // 回退到选中的提交之前，它不在历史里了
        _ = try await fixture.runner.run(["reset", "-q", "--hard", "HEAD~125"])
        session.refresh()
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }

        #expect(history.selectedIDs.isEmpty)
        #expect(history.changes.isEmpty)
        #expect(history.expandedPaths.isEmpty)
        #expect(history.diffs.isEmpty)
    }
}
