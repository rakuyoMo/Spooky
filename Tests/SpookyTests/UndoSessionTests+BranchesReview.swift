import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - BranchesReview

extension UndoSessionTests {
    /// 归档只改分支配置段，撤销后分支回到 Branches 分组，重做后再次归档。
    @Test("归档分支的撤销与重做")
    func archiveRoundTrip() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session

        try await fixture.createBranch("topic")
        await fixture.refresh()

        let topic = try #require(session.history.branches.first { $0.id == "refs/heads/topic" })
        try await fixture.perform { session.archive([topic], automatic: false) }
        #expect(session.history.snapshot?.metadata(for: topic.id).isArchived ?? false)

        try await fixture.perform { session.undoLastOperation() }
        #expect(!(session.history.snapshot?.metadata(for: topic.id).isArchived ?? true))

        try await fixture.perform { session.redoLastOperation() }
        #expect(session.history.snapshot?.metadata(for: topic.id).isArchived ?? false)
    }

    /// 用父分支更新是本机的合并，撤销后分支回到合并前的提交。
    @Test("Update Branch 的撤销")
    func updateBranchUndo() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let session = fixture.session
        let runner = fixture.runner

        // topic 从 main 分出，之后 main 前进一个提交；topic 的父分支是 main
        _ = try await runner.run(["switch", "-q", "-c", "topic"])
        _ = try await runner.run(["switch", "-q", "main"])
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "main 前进"])
        _ = try await runner.run(["switch", "-q", "topic"])
        try await RepositoryReferences(runner: runner).setParent("refs/heads/main", of: "refs/heads/topic")
        await fixture.refresh()

        let before = try await fixture.head()
        let topic = try #require(session.history.branches.first { $0.id == "refs/heads/topic" })
        #expect(session.canUpdateBranch(topic))

        try await fixture.perform { session.updateBranch(topic, rebase: false) }
        #expect(try await fixture.head() != before)

        try await fixture.perform { session.undoLastOperation() }
        #expect(try await fixture.head() == before)
    }
}
