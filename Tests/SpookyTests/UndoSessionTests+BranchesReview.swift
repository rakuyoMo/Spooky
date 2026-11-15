import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - BranchesReview

extension UndoSessionTests {
    /// 归档只改分支配置段，撤销后分支回到 Branches 分组，重做后再次归档；
    /// 用父分支更新先检出所选分支再合并，只有落后父分支时可用，撤销后 HEAD 回到原分支。
    @Test("归档分支与 Update Branch 的撤销")
    func branchesReviewRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }

        let session = fixture.session
        let runner = fixture.runner

        // old 留在 main 上待归档；topic 从 main 分出，之后 main 前进一个提交，topic 的父分支是 main
        _ = try await runner.run(["branch", "old"])
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "main 前进"])
        try await RepositoryReferences(runner: runner).setParent("refs/heads/main", of: "refs/heads/topic")
        await fixture.refresh()

        // 归档：撤销与重做来回切换归档标记
        let old = try #require(session.history.branches.first { $0.id == "refs/heads/old" })
        try await fixture.perform { session.archive([old], automatic: false) }
        #expect(session.history.snapshot?.metadata(for: old.id).isArchived ?? false)

        try await fixture.perform { session.undoLastOperation() }
        #expect(!(session.history.snapshot?.metadata(for: old.id).isArchived ?? true))

        try await fixture.perform { session.redoLastOperation() }
        #expect(session.history.snapshot?.metadata(for: old.id).isArchived ?? false)

        // Update Branch：HEAD 在 main 上，更新 topic 后 HEAD 切到 topic；撤销名是 Update Branch，撤销后 HEAD 回到 main
        let before = try await fixture.head()
        let topic = try #require(session.history.branches.first { $0.id == "refs/heads/topic" })
        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })

        #expect(session.canUpdateBranch(topic))
        #expect(!session.canUpdateBranch(main))

        try await fixture.perform { session.updateBranch(topic, rebase: false) }
        #expect(session.status?.branch.head == "topic")
        #expect(try await fixture.head() == main.objectID)
        #expect(session.undoHistory?.undoEntries.last?.title == AppLocalization.text("review.updateBranch"))

        // 并入后不再落后父分支，入口不可用
        #expect(!session.canUpdateBranch(topic))

        try await fixture.perform { session.undoLastOperation() }
        #expect(session.status?.branch.head == "main")
        #expect(try await fixture.head() == before)
    }
}
