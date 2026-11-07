import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 三种详情都以当前文件身份判断全展开，残留身份不能改变按钮含义。
@MainActor
struct ChangesetExpansionTests {
    /// 历史和比较从折叠、部分展开到全展开，再明确折叠。
    @Test("历史与比较的部分展开保留已有文件")
    func historyAndComparison() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Base"])
        let base = try await RepositoryReferences(runner: runner).resolve("HEAD")

        for file in ["one.txt", "two.txt"] {
            try Data(file.utf8).write(to: directory.appending(path: file))
        }

        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-m", "Files"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let commit = try #require(try await RepositoryHistory(runner: runner).page(roots: [head], limit: 1).commits.first)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh()
        await session.waitForRefresh()
        session.showCommit(commit)
        let history = session.history
        try await FileViewsTests.wait { !history.isLoadingChanges && history.changes.count == 2 }
        history.expandAll(false)
        #expect(!history.allItemsExpanded)
        history.expandedPaths = ["one.txt", "stale"]
        #expect(!history.allItemsExpanded)
        history.expandAll(!history.allItemsExpanded)
        #expect(history.allItemsExpanded && history.expandedPaths == ["one.txt", "two.txt"])
        history.expandAll(!history.allItemsExpanded)
        #expect(history.expandedPaths.isEmpty && !history.allItemsExpanded)

        let comparison = session.comparison
        comparison.open(base: .init(id: base, title: "base"), target: .init(id: commit.id, title: "target"), runner: runner)
        try await FileViewsTests.wait { !comparison.isLoadingChanges && comparison.changes.count == 2 }
        comparison.expandAll(false)
        #expect(!comparison.allItemsExpanded)
        comparison.expandedPaths = ["one.txt", "stale"]
        #expect(!comparison.allItemsExpanded)
        comparison.expandAll(!comparison.allItemsExpanded)
        #expect(comparison.allItemsExpanded && comparison.expandedPaths == ["one.txt", "two.txt"])
        comparison.expandAll(!comparison.allItemsExpanded)
        #expect(comparison.expandedPaths.isEmpty && !comparison.allItemsExpanded)
    }

    /// 储藏同时计入已跟踪与未跟踪文件，展开使用储藏条目的身份。
    @Test("储藏摘要与部分展开包含未跟踪文件")
    func stash() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        try Data("before\n".utf8).write(to: directory.appending(path: "tracked.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-m", "Base"])
        try Data("after\n".utf8).write(to: directory.appending(path: "tracked.txt"))
        try Data("new\n".utf8).write(to: directory.appending(path: "untracked.txt"))
        _ = try await RepositoryStashes(runner: runner).save(message: "Both", includeUntracked: true)
        let state = RepositoryStashState()
        defer { state.close() }

        state.refresh(runner: runner)
        try await FileViewsTests.wait { state.isLoaded }
        state.selectedIDs = [try #require(state.entries.first).id]
        try await FileViewsTests.wait { !state.isLoadingChanges && state.changes.count == 2 }
        #expect(state.changes.contains { $0.isUntracked })
        #expect(ChangesetSummaryBar.summary(state.changes.map(\.file)) == AppLocalization.text(
            "history.summary",
            AppLocalization.text("history.summary.files", 2),
            AppLocalization.text("history.summary.additions", 2),
            AppLocalization.text("history.summary.deletions.one", 1)
        ))
        state.expandAll(false)
        #expect(!state.allItemsExpanded)
        state.expandedPaths = [try #require(state.changes.first).id, "stale"]
        #expect(!state.allItemsExpanded)
        state.expandAll(!state.allItemsExpanded)
        #expect(state.allItemsExpanded && state.expandedPaths == Set(state.changes.map(\.id)))
        state.expandAll(!state.allItemsExpanded)
        #expect(state.expandedPaths.isEmpty && !state.allItemsExpanded)
    }
}
