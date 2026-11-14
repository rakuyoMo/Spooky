import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Rows

extension WorkingCopyFileListTests {
    /// 目录行的每一列只看其下在这一列有改动的条目：全是删除写 “D”，全是未跟踪写 “?”，
    /// 未跟踪与被忽略混合也写 “?”；只有新增、新增与删除混合、含冲突时都写 “M”；这一列没有改动时空着。
    @Test("目录行的汇总徽标")
    func directoryBadges() {
        let codes = { (entries: [StatusEntry]) in
            let codes = DirectoryStatusView(entries: entries).codes
            return codes.staged + "|" + codes.unstaged
        }

        // 只有新增：暂存区一列是修改，工作区一列没有改动
        #expect(codes([.added("d/a.txt"), .added("d/b.txt")]) == "M|")

        // 只有删除：工作区一列是删除
        let deleted = StatusEntry(kind: .tracked, path: "d/c.txt", unstaged: .deleted)

        #expect(codes([deleted]) == "|D")

        // 新增与删除混合
        let stagedDeletion = StatusEntry(kind: .tracked, path: "d/e.txt", staged: .deleted)

        #expect(codes([.added("d/a.txt"), stagedDeletion]) == "M|")

        // 未跟踪、被忽略与冲突
        let ignored = StatusEntry(kind: .ignored, path: "d/build/")
        let conflicted = StatusEntry(kind: .conflicted, path: "d/f.txt", staged: .deleted, unstaged: .unmerged)

        #expect(codes([.untracked("d/a.txt"), .untracked("d/b.txt")]) == "|?")
        #expect(codes([.untracked("d/a.txt"), ignored]) == "|?")
        #expect(codes([deleted, .untracked("d/a.txt")]) == "|M")
        #expect(codes([conflicted]) == "M|M")
    }

    /// 停止跟踪后同一路径的暂存删除与未跟踪文件是一行，徽标左删除右未跟踪；原先选中的行仍选中，
    /// 选中它即同时选中两条记录；树形里同样只有一行。
    @Test("停止跟踪后的同一路径合成一行")
    func untrackedCopyRow() async throws {
        let source = StatusSource()
        let session = RepositorySession(loadStatus: { _ in await source.status }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(RepositoryLocation.local(path: "/temporary/untrack-" + UUID().uuidString))

        let list = FileListHarness(session: session, source: source)

        await list.show([.modified("a.txt"), .untracked("b.txt")])
        list.select(rows: [0])

        // 停止跟踪 a.txt：两条记录合成原来的那一行
        let deletion = StatusEntry(kind: .tracked, path: "a.txt", staged: .deleted)
        let entries = [deletion, .untracked("a.txt"), .untracked("b.txt")]

        await list.show(entries)

        let row = try #require(list.node(at: 0))
        let badge = FileStatusView(entry: deletion, untrackedCopy: row.untrackedCopy != nil).codes

        #expect(list.paths == ["a.txt", "b.txt"])
        #expect(list.selectedPaths == ["a.txt"])
        #expect(badge == ("D", "?"))
        #expect(entries.untrackedCopies == [.untracked("a.txt")])

        await until { session.selectedID?.path == "a.txt" }
        #expect(session.selectedEntries == [deletion, .untracked("a.txt")])

        // 树形
        list.listing = WorkingCopyListing(mode: .tree)
        await list.show(entries)

        #expect(list.paths == ["a.txt", "b.txt"])
    }
}
