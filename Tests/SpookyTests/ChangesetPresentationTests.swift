import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 变更集摘要独立选择各段单复数，不因统计缺失隐藏计数。
@MainActor
struct ChangesetPresentationTests {
    /// 三段计数分别选择资源键，空数组仍保留完整的零摘要。
    @Test("变更集摘要各段独立选择单复数")
    func counts() {
        #expect(ChangesetSummaryBar.summary([]) == expected(files: 0, additions: 0, deletions: 0))

        for count in 1 ... 2 {
            for additions in 0 ... 2 {
                for deletions in 0 ... 2 {
                    let files = (0 ..< count).map {
                        CommitFileChange(
                            path: "file-\($0)",
                            originalPath: nil,
                            status: "M",
                            additions: $0 == 0 ? additions : 0,
                            deletions: $0 == 0 ? deletions : 0
                        )
                    }
                    #expect(ChangesetSummaryBar.summary(files) == expected(
                        files: count,
                        additions: additions,
                        deletions: deletions
                    ))
                }
            }
        }

        for count in 0 ... 2 {
            #expect(ChangesetSummaryBar.fileCount(count) == AppLocalization.text(
                count == 1 ? "history.changes.one" : "history.changes",
                count
            ))
        }
    }

    /// 二进制、组合统计与不完整统计都保留文件数，只分别累加已知值。
    @Test("变更集缺失统计按零累计")
    func unknownCounts() {
        let binary = CommitFileChange(path: "binary", originalPath: nil, status: "M", additions: nil, deletions: nil)
        let partial = CommitFileChange(path: "partial", originalPath: nil, status: "MM", additions: nil, deletions: 2)
        #expect(ChangesetSummaryBar.summary([binary]) == expected(files: 1, additions: 0, deletions: 0))
        #expect(ChangesetSummaryBar.summary([binary, partial]) == expected(files: 2, additions: 0, deletions: 2))
        #expect(!ChangesetSummaryBar(changes: [], expanded: false, toggle: { }).showsToggle)
        #expect(ChangesetSummaryBar(changes: [binary], expanded: false, toggle: { }).showsToggle)
    }

    /// 视图直接使用的空行只在空结果完成后出现，读取中不冒充空提交。
    @Test("整页详情空行与真实提交状态")
    func emptyRow() async throws {
        let directory = try FileViewsTests.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Empty"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let commit = try #require(try await RepositoryHistory(runner: runner).page(roots: [head], limit: 1).commits.first)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.display(location)
        session.refresh()
        await session.waitForRefresh()
        session.showCommit(commit)
        try await FileViewsTests.wait {
            session.history.selectedCommit?.id == commit.id && !session.history.isLoadingChanges
        }
        session.history.loadChanges()
        let view = CommitFileListView(session: session, history: session.history, back: { })
        #expect(session.history.isLoadingChanges)
        #expect(view.emptyMessage == nil)
        try await FileViewsTests.wait { !session.history.isLoadingChanges }
        #expect(session.history.changesFailure == nil)
        #expect(view.emptyMessage == AppLocalization.text("history.noChanges"))
    }

    /// 每段独立按数量选择，整句由语言自己的模板连接。
    private func expected(files: Int, additions: Int, deletions: Int) -> String {
        AppLocalization.text(
            "history.summary",
            AppLocalization.text(files == 1 ? "history.summary.files.one" : "history.summary.files", files),
            AppLocalization.text(additions == 1 ? "history.summary.additions.one" : "history.summary.additions", additions),
            AppLocalization.text(deletions == 1 ? "history.summary.deletions.one" : "history.summary.deletions", deletions)
        )
    }
}
