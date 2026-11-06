import AppKit
import Testing

@testable import Spooky
@testable import SpookyKit

/// 自动展开只在新对象清单读完后应用，改全局阈值不重排当前详情。
@MainActor
struct ChangesetAutoExpandTests {
    /// 三种状态都覆盖关闭、恰好达标、超过阈值与总是展开；储藏按带来源的身份加载两类补丁。
    @Test("提交、比较与储藏的自动展开阈值", arguments: [0, 1, 2, Int.max])
    func threshold(_ threshold: Int) async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        fixture.setThreshold(threshold)
        try await fixture.load()
        let session = fixture.session
        let expands = threshold >= 2
        #expect(session.history.expandedPaths == (expands ? ["a.txt", "b.txt"] : []))
        #expect(session.comparison.expandedPaths == (expands ? ["a.txt", "b.txt"] : []))
        let stashIDs = Set(session.stashes.changes.map(\.id))
        #expect(stashIDs.count == 2)
        #expect(session.stashes.expandedPaths == (expands ? stashIDs : []))

        if expands {
            try await FileViewsTests.wait {
                session.history.diffs.count == 2 && session.comparison.diffs.count == 2 && session.stashes.diffs.count == 2
            }

            for change in session.stashes.changes {
                #expect(session.stashes.diffSource(path: change.id)?.commit == change.commit)
                let diff = try #require(session.stashes.diffs[change.id]?.diff?.files.first)
                let lines = diff.hunks.flatMap(\.lines).map { String(decoding: $0.content, as: UTF8.self) }
                #expect(lines.contains(change.file.path == "a.txt" ? "tracked 2" : "untracked 2"))
            }
        } else {
            #expect(session.history.diffs.isEmpty && session.comparison.diffs.isEmpty && session.stashes.diffs.isEmpty)
        }
    }

    /// 全折叠、部分展开与全展开都不随设置跳变；切换到新对象时再按新阈值读补丁。
    @Test("修改阈值保持当前展开与缓存", arguments: 0 ... 2)
    func preferenceChange(expansion: Int) async throws {
        let fixture = try await ChangesetFixture.make()
        defer { fixture.close() }
        try await fixture.load()
        let session = fixture.session
        let stashIDs = session.stashes.changes.map(\.id)
        session.history.expandedPaths = Set(["a.txt", "b.txt"].prefix(expansion))
        session.comparison.expandedPaths = Set(["a.txt", "b.txt"].prefix(expansion))
        session.stashes.expandedPaths = Set(stashIDs.prefix(expansion))
        let before = fixture.expansions
        let caches = fixture.cachedPaths

        for threshold in [Int.max, 0, 1, 2] {
            fixture.setThreshold(threshold)
            for task in session.history.activeTasks + session.stashes.activeTasks { await task.value }
            #expect(fixture.expansions == before)
            #expect(fixture.cachedPaths == caches)
        }

        // 新对象读取成功后才应用最后保存的阈值。
        session.history.show(fixture.commits[1], runner: fixture.runner)
        fixture.open(session.comparison, target: 1)
        session.stashes.selectedIDs = [try #require(session.stashes.entries.last).id]
        try await fixture.waitForChanges()
        #expect(session.history.expandedPaths == ["a.txt", "b.txt"])
        #expect(session.comparison.expandedPaths == ["a.txt", "b.txt"])
        #expect(session.stashes.expandedPaths == Set(session.stashes.changes.map(\.id)))
        try await FileViewsTests.wait {
            session.history.diffs.count == 2 && session.comparison.diffs.count == 2 && session.stashes.diffs.count == 2
        }
    }
}
