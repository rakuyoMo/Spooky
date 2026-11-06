import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 块序号只用于当前快照，跨重载只接受完整原文字节身份。
@MainActor
struct DiffSelectionStoreTests {
    /// 当前文件范围。
    static let row = StatusRowID(path: "file", kind: .tracked)

    /// 两块相隔的普通补丁，便于独立改变一块。
    static let patch =
        "diff --git a/file b/file\n--- a/file\n+++ b/file\n@@ -1 +1 @@ first\n-old\n+new\n@@ -20 +20 @@ second\n-before\n+after\n"

    /// 一个块改变、其它块换了序号，仍然复用各自的选择和范围起点。
    @Test("块原文跨重载保留选择")
    func reordering() throws {
        let diff = try RepositoryDiff(patch: Data(Self.patch.utf8))
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(diff)
        let first = try #require(store.selection(file: 0, hunk: 0))
        let second = try #require(store.selection(file: 0, hunk: 1))
        first.activate(at: 0)
        second.activate(at: 1)
        let revision = store.revision
        let blocks = diff.files[0].hunks.map(\.rawContent)
        let header = Data("diff --git a/file b/file\nindex abc..def 100644\n--- a/file\n+++ b/file\n".utf8)
        store.reconcile(try RepositoryDiff(patch: header + blocks[1] + blocks[0]))
        #expect(store.selection(file: 0, hunk: 0) === second)
        #expect(store.selection(file: 0, hunk: 1) === first)
        #expect(first.selected == [0] && first.anchor == 0)
        #expect(second.selected == [1] && second.anchor == 1)
        #expect(store.revision == revision)

        store.reconcile(try RepositoryDiff(patch: header + blocks[1]))
        #expect(!first.isActive && first.selected.isEmpty)
        #expect(store.selection(file: 0, hunk: 0) === second)
        store.reconcile(diff)
        #expect(store.selection(file: 0, hunk: 0) !== first)
        #expect(store.selection(file: 0, hunk: 1) === second)
    }

    /// 头、函数上下文、正文、前缀和无换行标记都属于身份，另一个块保持。
    @Test("原文任一组成变化都会退役旧块", arguments: [
        ("@@ -1 +1 @@ first", "@@ -2 +2 @@ first"),
        ("@@ first", "@@ renamed"),
        ("+new\n", "+changed\n"),
        ("-old\n+new\n", " old\n"),
        ("+new\n", "+new\n\\ No newline at end of file\n"),
    ])
    func changing(replacement: (String, String)) throws {
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(try RepositoryDiff(patch: Data(Self.patch.utf8)))
        let old = try #require(store.selection(file: 0, hunk: 0))
        let other = try #require(store.selection(file: 0, hunk: 1))
        old.activate(at: 1)
        other.activate(at: 0)
        let changed = Self.patch.replacingOccurrences(of: replacement.0, with: replacement.1)
        store.reconcile(try RepositoryDiff(patch: Data(changed.utf8)))
        #expect(!old.isActive && old.selected.isEmpty && old.anchor == nil)
        #expect(store.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)
        #expect(store.selection(file: 0, hunk: 1) === other)
        #expect(other.selected == [0])
    }

    /// 相同显示文字不代表相同原文；非法 UTF-8 不可折叠成一个块身份。
    @Test("块头按字节而非解码文字匹配")
    func invalidUTF8() throws {
        let header = Data("diff --git a/file b/file\n--- a/file\n+++ b/file\n@@ -1 +1 @@ ".utf8)
        let tail = Data("\n-old\n+new\n".utf8)
        let first = try RepositoryDiff(patch: header + Data([0xFF]) + tail)
        let second = try RepositoryDiff(patch: header + Data([0xFE]) + tail)
        #expect(first.files[0].hunks[0].header == second.files[0].hunks[0].header)
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(first)
        let old = try #require(store.selection(file: 0, hunk: 0))
        old.activate(at: 1)
        store.reconcile(second)
        #expect(!old.isActive)
        #expect(store.selection(file: 0, hunk: 0)?.selected.isEmpty ?? false)
    }

    /// 原文相同的重复块仍有各自实例，清一个不影响另一个。
    @Test("重复块的选择和清空互不影响")
    func duplicates() throws {
        let patch = Data(Self.patch.utf8)
        let diff = try RepositoryDiff(patch: patch + patch)
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(diff)
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

    /// 文件、条目类型、侧与整组设置边界全部销毁旧实例，不会在返回时恢复。
    @Test("退出范围后旧事件和旧确认失效", arguments: ["file", "kind", "side", "reset", "close"])
    func boundaries(change: String) throws {
        let diff = try RepositoryDiff(patch: Data(Self.patch.utf8))
        let store = DiffSelectionStore()
        store.setScope(Self.row, side: .unstaged)
        store.reconcile(diff)
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
}
