import AppKit
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

/// 自动展开只在新对象清单读完后应用，改全局阈值不重排当前详情。
@MainActor
struct ChangesetAutoExpandTests {
    /// 提交、比较与储藏覆盖超过阈值、恰好达标与改阈值三种情形；储藏按带来源的身份加载两类补丁。
    @Test("自动展开阈值只作用于新读取的对象")
    func threshold() async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }

        // 文件数超过阈值时不展开，也不读补丁
        fixture.setThreshold(1)
        try await fixture.load()
        let session = fixture.session
        #expect(fixture.expansions[0 ... 2].allSatisfy { $0.isEmpty })
        #expect(fixture.cachedPaths[0 ... 2].allSatisfy { $0.isEmpty })

        // 全展开、部分展开与全折叠都不随设置跳变，最后停在全折叠与阈值 2
        for expansion in [2, 1, 0] {
            await expectStable(expansion: expansion, fixture: fixture)
        }

        // 新对象读取成功后才应用最后保存的阈值：文件数恰好达标时全部展开
        session.history.show(fixture.commits[1], runner: fixture.runner)
        fixture.open(session.comparison, target: 1)
        session.stashes.selectedIDs = [try #require(session.stashes.entries.last).id]
        try await fixture.waitForChanges()

        let stashIDs = Set(session.stashes.changes.map(\.id))
        #expect(stashIDs.count == 2)
        #expect(session.history.expandedPaths == ["a.txt", "b.txt"])
        #expect(session.comparison.expandedPaths == ["a.txt", "b.txt"])
        #expect(session.stashes.expandedPaths == stashIDs)

        // 展开后逐个读取补丁，储藏的两类文件各自按来源提交读取
        await waitForDiffs(session)
        #expect(session.history.diffs.count == 2)
        #expect(session.comparison.diffs.count == 2)
        try expectStashDiffs(session.stashes)
    }

    /// 设好一种展开组合后依次改阈值，展开集合与补丁缓存都保持原样。
    private func expectStable(expansion: Int, fixture: ChangesetFixture) async {
        let session = fixture.session
        let stashIDs = session.stashes.changes.map(\.id)
        session.history.expandedPaths = Set(["a.txt", "b.txt"].prefix(expansion))
        session.comparison.expandedPaths = Set(["a.txt", "b.txt"].prefix(expansion))
        session.stashes.expandedPaths = Set(stashIDs.prefix(expansion))
        let before = fixture.expansions
        let caches = fixture.cachedPaths

        for threshold in [Int.max, 0, 1, 2] {
            fixture.setThreshold(threshold)
            await untilFinished { session.history.activeTasks + session.stashes.activeTasks }

            #expect(fixture.expansions == before)
            #expect(fixture.cachedPaths == caches)
        }
    }

    /// 储藏的 tracked 与 untracked 文件都读出了所选储藏的内容。
    private func expectStashDiffs(_ stashes: RepositoryStashState) throws {
        #expect(stashes.diffs.count == 2)

        for change in stashes.changes {
            #expect(stashes.diffSource(path: change.id)?.commit == change.commit)

            let diff = try #require(stashes.diffs[change.id]?.diff?.files.first)
            let lines = diff.hunks
                .flatMap(\.lines)
                .map { String(decoding: $0.content, as: UTF8.self) }

            #expect(lines.contains(change.file.path == "a.txt" ? "tracked 1" : "untracked 1"))
        }
    }

    /// 等提交与储藏的补丁任务结束，比较的每个展开文件都有补丁或失败结果。
    private func waitForDiffs(_ session: RepositorySession) async {
        await untilFinished { session.history.activeTasks + session.stashes.activeTasks }

        let comparison = session.comparison

        await until {
            comparison.expandedPaths.allSatisfy {
                comparison.diffs[$0] != nil || comparison.diffFailures[$0] != nil
            }
        }
    }
}
