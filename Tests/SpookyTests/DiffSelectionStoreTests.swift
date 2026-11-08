import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - DiffSelectionStoreTests

/// 块序号只用于当前快照，跨重载只接受完整原文字节身份。
@MainActor
struct DiffSelectionStoreTests {
    /// 当前文件范围。
    static let row = StatusRowID(path: "file", kind: .tracked)

    /// 两块相隔的普通补丁，便于独立改变一块。
    static let patch = "diff --git a/file b/file\n--- a/file\n+++ b/file\n"
        + "@@ -1 +1 @@ first\n-old\n+new\n"
        + "@@ -20 +20 @@ second\n-before\n+after\n"

    /// 在当前文件的未暂存一侧载入补丁。
    static func store(_ diff: RepositoryDiff) throws -> DiffSelectionStore {
        let store = DiffSelectionStore()
        store.setScope(row, side: .unstaged)
        store.reconcile(diff)
        return store
    }

    /// 一个块改变、其它块换了序号，仍然复用各自的选择和范围起点；原文相同的重复块各有实例；组合 Diff 不建立可写模型。
    @Test("块原文跨重载保留选择，重复块互不影响，组合块不可写")
    func reordering() throws {
        let diff = try RepositoryDiff(patch: Data(Self.patch.utf8))
        let store = try Self.store(diff)
        let first = try #require(store.selection(file: 0, hunk: 0))
        let second = try #require(store.selection(file: 0, hunk: 1))
        first.activate(at: 0)
        second.activate(at: 1)
        let revision = store.revision

        // 两块交换次序并加上 index 行
        let blocks = diff.files[0].hunks.map(\.rawContent)
        let header = Data("diff --git a/file b/file\nindex abc..def 100644\n--- a/file\n+++ b/file\n".utf8)
        store.reconcile(try RepositoryDiff(patch: header + blocks[1] + blocks[0]))
        #expect(store.selection(file: 0, hunk: 0) === second)
        #expect(store.selection(file: 0, hunk: 1) === first)
        #expect(first.selected == [0] && first.anchor == 0)
        #expect(second.selected == [1] && second.anchor == 1)
        #expect(store.revision == revision)

        // 缺席一次的块退役，回来时是新实例
        store.reconcile(try RepositoryDiff(patch: header + blocks[1]))
        #expect(!first.isActive && first.selected.isEmpty)
        #expect(store.selection(file: 0, hunk: 0) === second)

        store.reconcile(diff)
        #expect(store.selection(file: 0, hunk: 0) !== first)
        #expect(store.selection(file: 0, hunk: 1) === second)

        try expectDuplicates()

        // 组合 Diff
        let combined = try Self.store(try combinedDiff())
        #expect(combined.selection(file: 0, hunk: 0) == nil)
        #expect(combined.target(file: 0, hunk: 0) == nil)
    }

    /// 头、函数上下文、正文、前缀、无换行标记与块头原始字节都属于身份；文件、条目类型、侧与整组设置边界全部销毁旧实例。
    @Test("原文变化与范围边界退役旧块")
    func changing() throws {
        let replacements = [
            ("@@ -1 +1 @@ first", "@@ -2 +2 @@ first"),
            ("@@ first", "@@ renamed"),
            ("+new\n", "+changed\n"),
            ("-old\n+new\n", " old\n"),
            ("+new\n", "+new\n\\ No newline at end of file\n"),
        ]

        for (original, replacement) in replacements {
            try expectRetired(Self.patch.replacingOccurrences(of: original, with: replacement))
        }

        // 相同显示文字不代表相同原文，非法 UTF-8 不折叠成一个身份
        let header = Data("diff --git a/file b/file\n--- a/file\n+++ b/file\n@@ -1 +1 @@ ".utf8)
        let tail = Data("\n-old\n+new\n".utf8)
        let first = try RepositoryDiff(patch: header + Data([0xFF]) + tail)
        let second = try RepositoryDiff(patch: header + Data([0xFE]) + tail)
        #expect(first.files[0].hunks[0].header == second.files[0].hunks[0].header)

        let store = try Self.store(first)
        let old = try #require(store.selection(file: 0, hunk: 0))
        old.activate(at: 1)
        store.reconcile(second)
        #expect(!old.isActive)
        #expect(store.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)

        for change in ["file", "kind", "side", "reset", "close"] {
            try expectBoundary(change)
        }
    }
}

// MARK: - Private

extension DiffSelectionStoreTests {
    /// 同一补丁出现两次，重载后各自保留，清一个不影响另一个。
    private func expectDuplicates() throws {
        let patch = Data(Self.patch.utf8)
        let diff = try RepositoryDiff(patch: patch + patch)
        let store = try Self.store(diff)
        let first = try #require(store.selection(file: 0, hunk: 0))
        let duplicate = try #require(store.selection(file: 1, hunk: 0))
        first.activate(at: 0)
        duplicate.activate(at: 1)

        store.reconcile(diff)
        #expect(store.selection(file: 0, hunk: 0) === first)
        #expect(store.selection(file: 1, hunk: 0) === duplicate)

        store.clear(store.target(file: 0, hunk: 0))
        #expect(first.selected.isEmpty && first.anchor == nil)
        #expect(duplicate.selected == [1])
    }

    /// 第一块原文变化后退役，另一块保持原实例与选择。
    private func expectRetired(_ changed: String) throws {
        let store = try Self.store(try RepositoryDiff(patch: Data(Self.patch.utf8)))
        let old = try #require(store.selection(file: 0, hunk: 0))
        let other = try #require(store.selection(file: 0, hunk: 1))
        old.activate(at: 1)
        other.activate(at: 0)

        store.reconcile(try RepositoryDiff(patch: Data(changed.utf8)))
        #expect(!old.isActive && old.selected.isEmpty && old.anchor == nil)
        #expect(store.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)
        #expect(store.selection(file: 0, hunk: 1) === other)
        #expect(other.selected == [0])
    }

    /// 离开范围再回来，旧实例的事件与旧确认都不能改动新实例。
    private func expectBoundary(_ change: String) throws {
        let diff = try RepositoryDiff(patch: Data(Self.patch.utf8))
        let store = try Self.store(diff)
        let old = try #require(store.selection(file: 0, hunk: 0))
        old.activate(at: 1)
        let target = store.target(file: 0, hunk: 0)
        let revision = store.revision

        switch change {
        case "file": store.setScope(StatusRowID(path: "other", kind: .tracked), side: .unstaged)
        case "kind": store.setScope(StatusRowID(path: "file", kind: .untracked), side: .unstaged)
        case "side": store.setScope(Self.row, side: .staged)
        case "close": store.setScope(nil, side: .unstaged)
        default: store.reset()
        }

        #expect(store.revision != revision)

        // 回到原范围后，旧实例的拖动、单击与旧确认都落空
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(diff)
        let current = try #require(store.selection(file: 0, hunk: 0))
        current.activate(at: 0)

        old.bind(diff.files[0].hunks[0])
        old.begin(at: 0, extending: false)
        old.drag(to: 1)
        old.end()
        old.activate(at: 1)
        store.clear(target)
        #expect(!old.isActive && old.selected.isEmpty)
        #expect(current.selected == [0] && current.publishedCount == 1)
    }

    /// 核心库夹具里两个父提交的组合 Diff。
    private func combinedDiff() throws -> RepositoryDiff {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "SpookyKitTests/Fixtures/diff-raw-hunks.json")

        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]]
        let item = try #require(fixtures?.first { ($0["name"] as? String) == "combined-2-parents" })
        let encoded = try #require(item["patch"] as? String)
        return try RepositoryDiff(patch: #require(Data(base64Encoded: encoded)))
    }
}
