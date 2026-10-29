import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Base Branch

extension BranchesReviewTests {
    /// trunk 是基准分支：同样久没更新，归档建议只有普通分支。
    @Test("trunk 不进归档建议")
    func trunkNotArchived() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let old = now.addingTimeInterval(-400 * 24 * 60 * 60)
        let references = ["topic", "trunk"].map { reference("refs/heads/" + $0, date: old) }
        let snapshot = ReferenceSnapshot(references: references, remotes: [])

        let candidates = BranchArchiving.candidates(
            in: snapshot,
            conditions: RepositoryReferences.conditions(in: snapshot),
            head: nil,
            staleMonths: 3,
            automatic: false,
            mergedOnServer: [],
            now: now
        )

        #expect(candidates.map(\.name) == ["topic"])
    }

    /// 没选基准时按 next、develop、dev、main、master 取第一个存在的分支，trunk 不在其中；都没有时取当前分支。
    @Test("分支整理的默认基准")
    func reviewDefaultBase() {
        let base = { (names: [String]) -> String? in
            let review = BranchesReviewState()

            // 当前分支 work 的引用名排在 alpha 之后，用来区分 “当前分支” 与 “第一个本地分支”
            let references = (names + ["alpha", "work"])
                .sorted()
                .map { reference("refs/heads/" + $0, date: nil) }

            review.update(
                snapshot: ReferenceSnapshot(references: references, remotes: []),
                head: "work",
                runner: nil
            )

            return review.base?.name
        }

        #expect(base(["main", "master", "trunk", "dev", "develop", "next"]) == "next")
        #expect(base(["main", "master", "trunk", "dev", "develop"]) == "develop")
        #expect(base(["main", "master", "trunk", "dev"]) == "dev")
        #expect(base(["main", "master", "trunk"]) == "main")
        #expect(base(["master", "trunk"]) == "master")
        #expect(base(["trunk"]) == "work")
        #expect(base([]) == "work")
    }

    /// 历史比较没有父分支时取标准名的基准分支（含 trunk），再取引用名排第一的其它本地分支，当前分支不优先。
    @Test("历史比较的默认基准")
    func historyDefaultBase() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-base-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        _ = try await runner.run(["commit", "-q", "--allow-empty", "-m", "root"])

        // 标准名只有 trunk；HEAD 在 work，它的引用名排在 alpha 之后
        _ = try await runner.run(["branch", "-m", "main", "trunk"])
        _ = try await runner.run(["branch", "alpha"])
        _ = try await runner.run(["branch", "topic"])
        _ = try await runner.run(["switch", "-q", "-c", "work"])

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        try await waitUntil { session.history.branches.count == 4 }

        let topic = try #require(session.history.branches.first { $0.name == "topic" })
        #expect(session.history.defaultBase(for: topic)?.name == "trunk")

        // 没有标准名的分支时取引用名排第一的 alpha，不取当前分支 work
        _ = try await runner.run(["branch", "-D", "trunk"])
        session.refresh(full: true)
        try await waitUntil { session.history.branches.count == 3 }
        #expect(session.history.defaultBase(for: topic)?.name == "alpha")
    }
}
