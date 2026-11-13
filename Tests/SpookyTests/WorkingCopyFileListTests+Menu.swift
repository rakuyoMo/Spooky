import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Menu

extension WorkingCopyFileListTests {
    /// 右键菜单的作用对象决定标题、可用性与终端位置：点在选区内、选区外与空白处的规则不同，树形里一个目录算一项；
    /// 没有作用对象时要求条目的项不可用、标题回到通用写法，Quick Look、Finder 与终端仍以仓库根目录为目标。
    @Test("右键菜单的作用对象")
    func contextMenuTargets() async throws {
        let root = "/temporary/menu-" + UUID().uuidString
        let source = StatusSource()
        let session = RepositorySession(loadStatus: { _ in await source.status }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(RepositoryLocation.local(path: root))

        let list = FileListHarness(session: session, source: source)
        let coordinator = list.coordinator
        let menu = NSMenu()

        // 单选：标题点名，终端进文件所在的目录
        await list.show([.modified("a.txt"), .modified("dir/sub/b.txt"), .untracked("new/")])
        list.select(rows: [1])
        coordinator.buildMenu(menu, clickedRow: 1)

        #expect(menu.item(withTitle: AppLocalization.text("working.stage.single", "b.txt")) != nil)
        #expect(menu.item(withTitle: AppLocalization.text("working.unstage.single", "b.txt")) != nil)
        #expect(try #require(menu.item(withTitle: AppLocalization.text("workspace.copyPathMenu"))).isEnabled)
        #expect(coordinator.terminalLocation == .local(path: root + "/dir/sub"))

        // 多选：标题计数，终端不可用
        list.select(rows: [0, 1])
        coordinator.buildMenu(menu, clickedRow: 0)

        let terminal = try #require(menu.item(withTitle: AppLocalization.text("action.openTerminal")))

        #expect(menu.item(withTitle: AppLocalization.text("working.stage.multiple", 2)) != nil)
        #expect(!terminal.isEnabled)
        #expect(coordinator.terminalLocation == nil)

        // 选区外的行只作用于这一行，选区不变；目录条目的终端进该目录
        coordinator.buildMenu(menu, clickedRow: 2)

        #expect(coordinator.menuEntries.map(\.path) == ["new/"])
        #expect(menu.item(withTitle: AppLocalization.text("files.untrack.single", "new")) != nil)
        #expect(coordinator.terminalLocation == .local(path: root + "/new"))
        #expect(list.selectedPaths == ["a.txt", "dir/sub/b.txt"])

        // 空白处有选择时沿用选区
        coordinator.buildMenu(menu, clickedRow: -1)
        #expect(coordinator.menuTargets.map(\.path) == ["a.txt", "dir/sub/b.txt"])

        // 空白处没有选择：通用标题，要求条目的项不可用，Quick Look 与终端以仓库根目录为目标
        list.select(rows: [])
        coordinator.buildMenu(menu, clickedRow: -1)

        let enabled = Set(menu.items.filter(\.isEnabled).map(\.title))
        let disabled = Set(menu.items.filter { !$0.isEnabled }.map(\.title))
        let requiringEntries = [
            "working.stage",
            "files.untrack",
            "working.discard.menu",
            "workspace.copyPathMenu",
            "quickActions.showFile",
            "files.open",
        ]

        #expect(coordinator.menuEntries.isEmpty)
        #expect(disabled.isSuperset(of: requiringEntries.map { AppLocalization.text($0) }))
        #expect(enabled.contains(AppLocalization.text("files.spacebar.quickLook")))
        #expect(coordinator.terminalLocation == .local(path: root))
        #expect(!menu.items.contains { $0.title.contains("(null)") })

        // 树形：目录算一项，执行时展开成目录里的文件，终端进该目录
        list.listing = WorkingCopyListing(mode: .tree)
        await list.show([.modified("dir/sub/b.txt"), .modified("dir/sub/c.txt"), .modified("top.txt")])

        let row = try #require(list.paths.firstIndex(of: "dir/sub"))

        list.select(rows: [row])
        coordinator.buildMenu(menu, clickedRow: row)

        #expect(menu.item(withTitle: AppLocalization.text("working.stage.single", "sub")) != nil)
        #expect(coordinator.menuEntries.map(\.path) == ["dir/sub/b.txt", "dir/sub/c.txt"])
        #expect(coordinator.terminalLocation == .local(path: root + "/dir/sub"))
    }
}
