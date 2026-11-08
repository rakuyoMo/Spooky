import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ChangesetExpansionTests

/// 三种详情都以当前文件身份判断全展开，残留身份不能改变按钮含义。
@MainActor
struct ChangesetExpansionTests {
    /// 历史、比较与储藏都从折叠、部分展开到全展开，再明确折叠；储藏同时计入已跟踪与未跟踪文件。
    @Test("提交、比较与储藏的部分展开保留已有文件")
    func expansion() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Base"])
        let base = try await RepositoryReferences(runner: runner).resolve("HEAD")

        for file in ["one.txt", "two.txt"] {
            try Data("\(file)\n".utf8).write(to: directory.appending(path: file))
        }

        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-m", "Files"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: runner).page(roots: [head], limit: 1)
        let commit = try #require(page.commits.first)

        try Data("after\n".utf8).write(to: directory.appending(path: "one.txt"))
        try Data("new\n".utf8).write(to: directory.appending(path: "untracked.txt"))
        _ = try await RepositoryStashes(runner: runner).save(message: "Both", includeUntracked: true)

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        // 提交详情
        let history = session.history
        history.show(commit, runner: runner)
        await until { !history.isLoadingChanges }
        #expect(history.changes.count == 2)
        expectToggle(history, all: ["one.txt", "two.txt"], expandAll: history.expandAll)

        // 两个版本的比较
        let comparison = session.comparison
        comparison.open(
            base: .init(id: base, title: "base"),
            target: .init(id: commit.id, title: "target"),
            runner: runner
        )
        await until { !comparison.isLoadingChanges }
        #expect(comparison.changes.count == 2)
        expectToggle(comparison, all: ["one.txt", "two.txt"], expandAll: comparison.expandAll)

        // 储藏的摘要与展开都包含未跟踪文件，展开使用储藏条目的身份
        let stashes = session.stashes
        stashes.refresh(runner: runner, records: false)
        await until { !stashes.isLoading }
        stashes.selectedIDs = [try #require(stashes.entries.first).id]
        await until { !stashes.isLoadingChanges }
        #expect(stashes.changes.contains { $0.isUntracked })

        #expect(ChangesetSummaryBar.summary(stashes.changes.map(\.file)) == AppLocalization.text(
            "history.summary",
            AppLocalization.text("history.summary.files", 2),
            AppLocalization.text("history.summary.additions", 2),
            AppLocalization.text("history.summary.deletions.one", 1)
        ))

        expectToggle(stashes, all: Set(stashes.changes.map(\.id)), expandAll: stashes.expandAll)
    }

    /// 折叠、带残留身份的部分展开都不算全展开；按钮先全展开当前文件，再全部折叠。
    private func expectToggle(
        _ state: some ChangesetExpansionState,
        all: Set<String>,
        expandAll: (Bool) -> Void
    ) {
        expandAll(false)
        #expect(!state.allItemsExpanded)

        state.expandedPaths = [all.sorted()[0], "stale"]
        #expect(!state.allItemsExpanded)

        expandAll(!state.allItemsExpanded)
        #expect(state.allItemsExpanded && state.expandedPaths == all)

        expandAll(!state.allItemsExpanded)
        #expect(state.expandedPaths.isEmpty && !state.allItemsExpanded)
    }
}

// MARK: - ChangesetExpansionState

/// 三种详情状态共有的展开集合与全展开判断，供同一套展开核对使用。
@MainActor
private protocol ChangesetExpansionState: AnyObject {
    /// 当前展开的文件身份。
    var expandedPaths: Set<String> { get set }

    /// 当前文件是否全部展开。
    var allItemsExpanded: Bool { get }
}

// MARK: - RepositoryHistoryState + ChangesetExpansionState

extension RepositoryHistoryState: ChangesetExpansionState { }

// MARK: - RevisionComparisonState + ChangesetExpansionState

extension RevisionComparisonState: ChangesetExpansionState { }

// MARK: - RepositoryStashState + ChangesetExpansionState

extension RepositoryStashState: ChangesetExpansionState { }
