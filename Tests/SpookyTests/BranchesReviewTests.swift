import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - BranchesReviewTests

/// 分支整理、归档与基准分支比较：结论只来自结构化的 Git 结果，未知状态不能当作已合并。
@MainActor
struct BranchesReviewTests {
    /// 列表按与基准的比较筛选与排序；归档带待审阅标记并可撤销；Update Branch 合并父分支。
    @Test("分支整理的比较、筛选、归档与 Update Branch")
    func reviewSession() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-review-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await prepareBranches(runner: runner, in: directory)

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.display(location)
        session.refresh()
        try await waitUntil { session.history.snapshot != nil && !session.history.conditions.isEmpty }

        // 基准默认是 main；比较完成前没有结论，不算已合并
        let review = session.branchesReview
        review.update(snapshot: session.history.snapshot, head: session.status?.branch.head, runner: runner)
        #expect(review.base?.id == "refs/heads/main")
        #expect(review.items(conditions: [:], search: "", order: order(.fullyMerged), staleMonths: 3).isEmpty)

        try await waitUntil { review.comparisons.count == 3 }

        let ids = { (filter: BranchesReviewFilter) in
            review.items(
                conditions: session.history.conditions,
                search: "",
                order: order(filter),
                staleMonths: 3
            )
            .map(\.id)
        }

        #expect(ids(.fullyMerged) == ["refs/heads/merged"])
        #expect(ids(.mergeable) == ["refs/heads/feature/改名'x'"])
        #expect(ids(.mergeConflicts) == ["refs/heads/conflict"])
        #expect(ids(.trackingError).isEmpty)
        #expect(ids(.all).count == 3)

        // 按分支名搜索不区分大小写；降序按名称倒排
        #expect(
            review.items(conditions: [:], search: "CONF", order: order(.all), staleMonths: 3).map(\.id)
                == ["refs/heads/conflict"]
        )
        #expect(
            review.items(
                conditions: [:],
                search: "",
                order: BranchesReviewOrder(filter: .all, sort: .name, ascending: false),
                staleMonths: 3
            )
            .map(\.reference.name) == ["merged", "feature/改名'x'", "conflict"]
        )

        // 单选后详情从分叉点比较到分支顶端
        review.selectedIDs = ["refs/heads/conflict"]
        try await waitUntil { review.comparison.isActive }
        #expect(review.comparison.target?.title == "conflict")
        #expect(review.comparison.base?.title == "main")

        try await archiveAndUndo(session: session)
        try await updateBranch(session: session)
    }

    /// 打开 Compare Branches 后插入分叉点行、置灰父分支的提交；没有新提交的分支只有一行说明。
    @Test("与基准分支比较的表格行")
    func compareRows() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-compare-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        try await prepareBranches(runner: runner, in: directory)

        let suite = "spooky-compare-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: RepositoryHistoryState.comparesBranchesKey)

        let session = RepositorySession(makeRunner: { _ in runner })
        defer { session.close() }
        session.history.preferences = defaults
        session.display(location)
        session.refresh()
        try await waitUntil { session.history.snapshot != nil }

        // 有自己提交的分支：分叉点行插在分叉点提交之前，分叉点及其祖先置灰
        session.history.selectedReference = "refs/heads/conflict"
        try await waitUntil { session.history.rows.contains(.forkPoint("main")) }
        let fork = try #require(session.history.baseComparison?.forkPoint)
        let index = try #require(session.history.rows.firstIndex(of: .forkPoint("main")))
        #expect(session.history.rows[index + 1].commit?.id == fork)
        #expect(session.history.parentCommits.contains(fork))
        #expect(session.history.baseComparison?.comparison?.divergence.behind == 1)

        // 父分支已删除时同样退回 main
        _ = try await runner.run(["config", "branch.conflict.spooky-parent", "refs/heads/gone"])
        session.refresh(full: true)
        try await waitUntil { session.history.snapshot?.metadata(for: "refs/heads/conflict").parent != nil }
        let selected = try #require(session.history.selectedLocalBranch)
        #expect(session.history.defaultBase(for: selected)?.name == "main")

        // 顶端就是分叉点的分支没有新提交
        session.history.selectedReference = "refs/heads/merged"
        try await waitUntil { session.history.rows.first == .noNewCommits("main") }

        // 关掉比较后恢复普通的表格行。关掉的设置写进另一个偏好域：覆盖已有的值后立即读取，可能仍读到旧值
        let closed = try #require(UserDefaults(suiteName: directory.appending(path: "compare-off").path))
        closed.set(false, forKey: RepositoryHistoryState.comparesBranchesKey)
        session.history.preferences = closed
        session.history.loadBaseComparison()
        #expect(session.history.baseComparison == nil)
        #expect(session.history.rows.allSatisfy { $0.commit != nil })
    }

    /// 归档建议排除基准分支、当前分支、置顶与已归档的分支；自动归档还排除勾了跳过的分支；每天只检查一次。
    @Test("归档建议与每日检查")
    func archiveCandidates() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let old = date.addingTimeInterval(-400 * 24 * 60 * 60)
        let references = ["main", "head", "merged", "stale", "pinned", "skipped", "archived", "active"].map {
            reference("refs/heads/" + $0, date: $0 == "active" ? date : old)
        }

        let snapshot = ReferenceSnapshot(
            references: references,
            remotes: [],
            metadata: [
                "refs/heads/pinned": BranchMetadata(isPinned: true),
                "refs/heads/archived": BranchMetadata(isArchived: true),
                "refs/heads/skipped": {
                    var metadata = BranchMetadata()
                    metadata.skipsAutoArchive = true
                    return metadata
                }(),
            ]
        )

        var conditions: [String: BranchCondition] = [:]

        for reference in references {
            conditions[reference.id] = BranchCondition(
                reference: reference.id,
                lastUpdated: reference.date,
                missingUpstream: nil,
                mergedInto: reference.name == "merged" ? "refs/heads/main" : nil,
                isBase: reference.name == "main"
            )
        }

        let manual = BranchArchiving.candidates(
            in: snapshot,
            conditions: conditions,
            head: "head",
            staleMonths: 3,
            automatic: false,
            now: date
        )
        #expect(manual.map(\.name) == ["merged", "skipped", "stale"])

        let automatic = BranchArchiving.candidates(
            in: snapshot,
            conditions: conditions,
            head: "head",
            staleMonths: 3,
            automatic: true,
            now: date
        )
        #expect(automatic.map(\.name) == ["merged", "stale"])

        // 每个仓库各自记录检查时刻，满一天才再检查
        let suite = "spooky-archive-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = RepositoryLocation.remote(host: "spooky-test", path: "/仓库 'x'")

        #expect(BranchArchiving.isDue(for: repository, defaults: defaults, now: date))
        BranchArchiving.recordCheck(for: repository, defaults: defaults, now: date)
        let hourLater = date.addingTimeInterval(3600)
        let dayLater = date.addingTimeInterval(86_400)
        #expect(!BranchArchiving.isDue(for: repository, defaults: defaults, now: hourLater))
        #expect(BranchArchiving.isDue(for: repository, defaults: defaults, now: dayLater))
        #expect(BranchArchiving.isDue(for: .local(path: "/other"), defaults: defaults, now: date))
    }

    /// 还在比较或无法检查的分支不算已合并、能合并或有冲突；陈旧与活跃按阈值互补。
    @Test("筛选不把未知状态当作已合并")
    func unknownStatus() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let branch = reference("refs/heads/topic", date: now.addingTimeInterval(-200 * 24 * 60 * 60))
        let condition = BranchCondition(
            reference: branch.id,
            lastUpdated: branch.date,
            missingUpstream: "refs/remotes/origin/topic",
            mergedInto: nil,
            isBase: false
        )

        let pending = BranchesReviewItem(reference: branch, comparison: nil, condition: condition)
        let unavailable = BranchesReviewItem(
            reference: branch,
            comparison: BranchComparison(
                divergence: ReferenceDivergence(ahead: 1, behind: 1),
                merge: .unavailable("fatal: refusing to merge unrelated histories")
            ),
            condition: condition
        )

        for item in [pending, unavailable] {
            for filter in [BranchesReviewFilter.fullyMerged, .mergeable, .mergeConflicts] {
                #expect(!BranchesReviewState.matches(item, filter: filter, staleMonths: 3, now: now))
            }
        }

        #expect(BranchesReviewState.matches(pending, filter: .trackingError, staleMonths: 3, now: now))
        #expect(BranchesReviewState.matches(pending, filter: .stale, staleMonths: 3, now: now))
        #expect(!BranchesReviewState.matches(pending, filter: .active, staleMonths: 3, now: now))
        #expect(BranchesReviewState.matches(pending, filter: .active, staleMonths: 12, now: now))
    }
}

// MARK: - Steps

extension BranchesReviewTests {
    /// 自动归档写入待审阅标记，撤销后分支回到 Branches 分组并清除标记。
    private func archiveAndUndo(session: RepositorySession) async throws {
        let merged = try #require(session.history.branches.first { $0.id == "refs/heads/merged" })

        // 建议归档的分支：merged 已完全合并；基准与当前分支不在其中
        #expect(session.archiveCandidates(automatic: true).map(\.id) == [merged.id])

        session.archive([merged], automatic: true)
        try await waitUntil { session.history.snapshot?.metadata(for: merged.id).needsArchiveReview ?? false }
        #expect(session.branchesReview.archivedBranches == [merged.id])
        #expect(session.archiveCandidates(automatic: true).isEmpty)

        try await waitUntil { session.canWrite }
        session.undoArchive()
        try await waitUntil { !(session.history.snapshot?.metadata(for: merged.id).isArchived ?? true) }
        #expect(!(session.history.snapshot?.metadata(for: merged.id).needsArchiveReview ?? true))
        #expect(session.branchesReview.archivedBranches == nil)
    }

    /// 设了父分支的分支可以用父分支更新：合并后 HEAD 切到它，父分支的提交并入。
    private func updateBranch(session: RepositorySession) async throws {
        try await waitUntil { session.canWrite }
        let feature = try #require(session.history.branches.first { $0.name == "feature/改名'x'" })
        let main = try #require(session.history.branches.first { $0.id == "refs/heads/main" })
        #expect(!session.canUpdateBranch(feature))

        let runner = try #require(session.runner)
        try await RepositoryReferences(runner: runner).setParent(main.id, of: feature.id)
        session.refresh(full: true)
        try await waitUntil { session.parentBranch(of: feature)?.id == main.id }
        #expect(session.canUpdateBranch(feature))

        session.updateBranch(feature, rebase: false)
        try await waitUntil { session.status?.branch.head == "feature/改名'x'" && !session.isWriting }

        let ancestor = try await runner.execute(
            ["merge-base", "--is-ancestor", main.objectID, "HEAD"],
            acceptedExitCodes: [0, 1]
        )
        #expect(ancestor.exitCode == 0)
    }
}

// MARK: - Helpers

extension BranchesReviewTests {
    /// main 之外三个分支：已并入、能干净合并（名字带中文与引号）与会冲突；main 随后前进一个提交。
    private func prepareBranches(runner: GitRunner, in directory: URL) async throws {
        try Data("base\n".utf8).write(to: directory.appending(path: "file.txt"))
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])
        _ = try await runner.run(["branch", "merged"])

        _ = try await runner.run(["switch", "-q", "-c", "conflict"])
        try Data("conflict\n".utf8).write(to: directory.appending(path: "file.txt"))
        _ = try await runner.run(["commit", "-q", "-am", "conflict"])

        _ = try await runner.run(["switch", "-q", "-c", "feature/改名'x'", "main"])
        try Data("other\n".utf8).write(to: directory.appending(path: "other.txt"))
        _ = try await runner.run(["add", "-A"])
        _ = try await runner.run(["commit", "-q", "-m", "feature"])

        _ = try await runner.run(["switch", "-q", "main"])
        try Data("main\n".utf8).write(to: directory.appending(path: "file.txt"))
        _ = try await runner.run(["commit", "-q", "-am", "main"])
    }

    /// 只有筛选项不同的顺序。
    private func order(_ filter: BranchesReviewFilter) -> BranchesReviewOrder {
        BranchesReviewOrder(filter: filter, sort: .name, ascending: true)
    }

    /// 指向同一个提交、带指定时间的本地分支。
    private func reference(_ id: String, date: Date?) -> RepositoryReference {
        RepositoryReference(
            id: id,
            objectID: String(repeating: "a", count: 40),
            objectType: "commit",
            upstream: nil,
            upstreamRemote: nil,
            upstreamBranch: nil,
            symbolicTarget: nil,
            date: date
        )
    }

    /// 等待写入与随后的刷新落定，最多 5 分钟。
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("等待超时")
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
