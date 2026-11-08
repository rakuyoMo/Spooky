import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 变更集摘要独立选择各段单复数，不因统计缺失隐藏计数。
@MainActor
struct ChangesetPresentationTests {
    /// 三段计数分别选择资源键，空数组保留完整的零摘要；二进制与不完整统计保留文件数，只累加已知值。
    @Test("变更集摘要各段独立选择单复数，缺失统计按零累计")
    func counts() {
        #expect(ChangesetSummaryBar.summary([]) == expected(files: 0, additions: 0, deletions: 0))

        // 单数与复数分别落在不同的段上
        for (count, additions, deletions) in [(1, 1, 2), (2, 2, 1)] {
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

        for count in 1 ... 2 {
            #expect(ChangesetSummaryBar.fileCount(count) == AppLocalization.text(
                count == 1 ? "history.changes.one" : "history.changes",
                count
            ))
        }

        // 二进制与组合统计缺少的值按零累计，有文件时才显示展开按钮
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

        let runner = try await FileViewsTests.initializeRepository(at: .local(path: directory.path))
        _ = try await runner.run(["commit", "--allow-empty", "-m", "Empty"])
        let head = try await RepositoryReferences(runner: runner).resolve("HEAD")
        let page = try await RepositoryHistory(runner: runner).page(roots: [head], limit: 1)
        let commit = try #require(page.commits.first)
        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }

        session.history.show(commit, runner: runner)
        await until { !session.history.isLoadingChanges }

        // 重新读取期间没有空行，读完空结果才显示
        session.history.loadChanges()
        let view = CommitFileListView(session: session, history: session.history, back: { })
        #expect(session.history.isLoadingChanges)
        #expect(view.emptyMessage == nil)

        await until { !session.history.isLoadingChanges }
        #expect(session.history.changesFailure == nil)
        #expect(view.emptyMessage == AppLocalization.text("history.noChanges"))
    }

    /// 每段独立按数量选择，整句由语言自己的模板连接。
    private func expected(files: Int, additions: Int, deletions: Int) -> String {
        let filesKey = files == 1 ? "history.summary.files.one" : "history.summary.files"
        let additionsKey = additions == 1 ? "history.summary.additions.one" : "history.summary.additions"
        let deletionsKey = deletions == 1 ? "history.summary.deletions.one" : "history.summary.deletions"

        return AppLocalization.text(
            "history.summary",
            AppLocalization.text(filesKey, files),
            AppLocalization.text(additionsKey, additions),
            AppLocalization.text(deletionsKey, deletions)
        )
    }
}
