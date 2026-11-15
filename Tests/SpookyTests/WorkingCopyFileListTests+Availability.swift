import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Availability

extension WorkingCopyFileListTests {
    /// 多选与目录行照样列出查看三项且都不可用，规则子菜单只留第一项；已删除的文件不能在 Finder 与终端里打开；
    /// 树形的目录行在 Move…、规则与 LFS 里算一项，自定义规则预填目录本身；被忽略的文件能写规则；标了 assume-unchanged 的无状态行不能恢复到指定版本；
    /// HEAD 里没有的文件不能看原文与 Blame。
    @Test("右键菜单各项的可用条件")
    func contextMenuAvailability() async throws {
        let source = StatusSource()
        let session = RepositorySession(loadStatus: { _ in await source.status }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(RepositoryLocation.local(path: "/temporary/availability-" + UUID().uuidString))

        let list = FileListHarness(session: session, source: source)
        let coordinator = list.coordinator
        let menu = NSMenu()
        let deleted = StatusEntry(kind: .tracked, path: "c.txt", unstaged: .deleted)

        let enabled = { (title: String) throws -> Bool in
            try #require(menu.item(withTitle: title)).isEnabled
        }

        // 多选：查看三项点名第一个文件、都不可用；Ignore ▸ 只有第一项可用
        await list.show([.modified("a.txt"), .added("b.txt"), deleted])
        list.select(rows: [0, 1])
        coordinator.buildMenu(menu, clickedRow: 0)

        for key in ["showFile.show", "blame.show", "fileHistory.showHistoryOf"] {
            #expect(try !enabled(AppLocalization.text(key, "a.txt")), "\(key)")
        }

        #expect(Self.items(menu, "files.ignore").map(\.isEnabled) == [true, false, false, false])

        // 单个已暂存的新文件：只有文件历史可用
        list.select(rows: [1])
        coordinator.buildMenu(menu, clickedRow: 1)

        #expect(try !enabled(AppLocalization.text("showFile.show", "b.txt")))
        #expect(try enabled(AppLocalization.text("fileHistory.showHistoryOf", "b.txt")))

        // 已删除的文件：Finder 与终端不可用
        list.select(rows: [2])
        coordinator.buildMenu(menu, clickedRow: 2)

        #expect(try !enabled(AppLocalization.text("action.revealFinder")))
        #expect(coordinator.terminalLocation == nil)

        // 树形的目录行：Move… 可用，查看三项点名目录且不可用，规则按目录名写，按类型一项与 LFS 两项不可用
        list.listing = WorkingCopyListing(mode: .tree)
        await list.show([.modified("dir/sub/b.txt"), .modified("dir/sub/c.txt"), .modified("top.txt")])

        let row = try #require(list.paths.firstIndex(of: "dir/sub"))

        list.select(rows: [row])
        coordinator.buildMenu(menu, clickedRow: row)

        let ignore = Self.items(menu, "files.ignore")
        let lfs = Self.items(menu, "lfs.menu")

        #expect(coordinator.menuDirectory?.path == "dir/sub")
        #expect(try enabled(AppLocalization.text("files.move.menu")))
        #expect(try !enabled(AppLocalization.text("showFile.show", "sub")))
        #expect(ignore.map(\.isEnabled) == [true, true, false, true])
        #expect(
            ignore.map(\.title) == [
                AppLocalization.text("files.ignore.item"),
                AppLocalization.text("files.ignore.name.single", "sub"),
                AppLocalization.text("files.ignore.type"),
                AppLocalization.text("files.ignore.custom"),
            ]
        )
        #expect(lfs.first?.title == AppLocalization.text("lfs.trackFile"))

        // 目录行的 Create Ignore Pattern… 预填目录本身，已跟踪的文件仍随表单带上
        var requested: WorkingCopyFileRequest? = nil
        session.onFileRequest = { requested = $0 }

        let custom = try #require(ignore.last)
        _ = (custom.target as? NSObject)?.perform(custom.action, with: custom)

        guard case .form(.pattern(.gitignore, let entries, let item))? = requested else {
            Issue.record("没有请求自定义规则表单")
            return
        }

        #expect(item == "dir/sub/")
        #expect(entries.map(\.path) == ["dir/sub/b.txt", "dir/sub/c.txt"])

        // 被忽略的文件能写规则；标了 assume-unchanged 的无状态行不能恢复
        let assumed = StatusEntry(kind: .unchanged, path: "config.local")

        #expect(session.canIgnore([StatusEntry(kind: .ignored, path: "build.log")]))
        #expect(session.canRevert([assumed]))
        #expect(!session.canRevert([assumed], marked: ["config.local"]))

        // 原文与 Blame 读 HEAD：还没有提交时都不可用，HEAD 里没有的文件不可用
        #expect(!session.canShowFile([.modified("a.txt")]))

        await source.set([.modified("a.txt")], oid: String(repeating: "a", count: 40))
        session.refresh()
        await session.refreshTask?.value

        let renamed = StatusEntry(kind: .tracked, path: "new.txt", originalPath: "old.txt", staged: .renamed)
        let conflict = { (ours: FileChange) in
            StatusEntry(kind: .conflicted, path: "x.txt", staged: ours, unstaged: .unmerged)
        }

        #expect(session.canShowFile([.modified("a.txt")]))
        #expect(session.canShowFile([conflict(.unmerged)]))
        #expect(![.added("b.txt"), .untracked("n.txt"), renamed, conflict(.added)].contains { session.canShowFile([$0]) })
    }
}
