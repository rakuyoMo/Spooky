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

        // 空白处没有选择：通用标题，要求条目的项与储藏四项不可用，Quick Look 与终端以仓库根目录为目标
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
            "stash.saveMenu",
            "stash.quickSaveMenu",
            "stash.snapshotMenu",
            "stash.quickSnapshotMenu",
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

    /// 冲突两个父项总能展开，子项按作用对象点名或计数；对方来自补丁或储藏时不加引号，没冲突过的文件不能恢复冲突。
    /// Compare 总列三种工作区比较、按两侧有无差别启用（未跟踪与冲突文件不算），单个对象另列三种冲突比较，
    /// 空白处比较整个工作区。
    @Test("冲突与比较子菜单")
    func conflictAndCompareMenus() async throws {
        let source = StatusSource()
        let session = RepositorySession(loadStatus: { _ in await source.status }, activities: RepositoryActivities())
        defer { session.close() }

        session.display(RepositoryLocation.local(path: "/temporary/compare-" + UUID().uuidString))

        let list = FileListHarness(session: session, source: source)
        let menu = NSMenu()

        await list.show([.added("staged.txt"), .untracked("new.txt"), .modified("work.txt")])

        // 只有暂存改动：工作区对暂存区不可用；冲突比较列出但不可用
        list.select(rows: [1])
        list.coordinator.buildMenu(menu, clickedRow: 1)

        #expect(
            Self.states(menu, "externalTool.compare") == [
                "externalTool.compare.workingTreeToBase": true,
                "externalTool.compare.workingTreeToIndex": false,
                "externalTool.compare.indexToBase": true,
                "externalTool.compare.oursToTheirs": false,
                "externalTool.compare.oursToBase": false,
                "externalTool.compare.theirsToBase": false,
            ]
        )

        // 不是冲突文件：两个父项照样能展开，标题点名但不可用，对方的版本不加引号
        let resolve = Self.items(menu, "conflict.menu.resolve")
        let restore = Self.items(menu, "conflict.menu.restore")

        #expect(resolve.first?.title == AppLocalization.text("conflict.markResolved.one", "staged.txt"))
        #expect(resolve.last?.title == AppLocalization.text("conflict.resolveUsingVersion.applied"))
        #expect(restore.first?.title == AppLocalization.text("conflict.restoreUnmerged.one", "staged.txt"))
        #expect(!resolve.contains { $0.isEnabled })
        #expect(!(restore.first?.isEnabled ?? true))

        // 只有未暂存改动：暂存区对 HEAD 不可用
        list.select(rows: [2])
        list.coordinator.buildMenu(menu, clickedRow: 2)
        #expect(!(Self.states(menu, "externalTool.compare")["externalTool.compare.indexToBase"] ?? true))

        // 未跟踪文件不算有差别：三种工作区比较都不可用
        list.select(rows: [0])
        list.coordinator.buildMenu(menu, clickedRow: 0)
        #expect(!Self.states(menu, "externalTool.compare").values.contains(true))

        // 多选：只有三种工作区比较，冲突标题计数
        list.select(rows: [1, 2])
        list.coordinator.buildMenu(menu, clickedRow: 1)

        let mark = Self.items(menu, "conflict.menu.resolve").first?.title

        #expect(Self.states(menu, "externalTool.compare").count == 3)
        #expect(mark == AppLocalization.text("conflict.markResolved.many", 2))

        // 空白处没有选择：比较整个工作区，三项都可用
        list.select(rows: [])
        list.coordinator.buildMenu(menu, clickedRow: -1)
        #expect(Set(Self.states(menu, "externalTool.compare").values) == [true])

        // 冲突文件的三种工作区比较不可用；只剩未跟踪与冲突文件时，空白处也没有可比较的改动
        let conflicted = StatusEntry(kind: .conflicted, path: "merge.txt", staged: .unmerged, unstaged: .unmerged)

        await list.show([.untracked("new.txt"), conflicted])

        let row = try #require(list.paths.firstIndex(of: "merge.txt"))

        list.select(rows: [row])
        list.coordinator.buildMenu(menu, clickedRow: row)
        #expect(!Self.states(menu, "externalTool.compare").values.contains(true))

        list.select(rows: [])
        list.coordinator.buildMenu(menu, clickedRow: -1)
        #expect(Self.states(menu, "externalTool.compare").count == 3)
        #expect(!Self.states(menu, "externalTool.compare").values.contains(true))
    }

    /// LFS ▸ 的启用状态不在轮询里读取：打开菜单时三项先禁用，读到仓库启用了 Git LFS 后再按各自的条件启用。
    @Test("LFS 子菜单的可用条件")
    func lfsMenu() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-lfs 菜单-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)
        let source = StatusSource()
        let session = RepositorySession(
            makeRunner: { _ in runner },
            loadStatus: { _ in await source.status },
            activities: RepositoryActivities()
        )
        defer { session.close() }

        session.display(location)

        // 仓库本地登记过滤器并装上调用 git lfs pre-push 的钩子，与执行过 git lfs install --local 相同
        _ = try await runner.run(["config", "--local", "filter.lfs.clean", "git-lfs clean -- %f"])
        _ = try await runner.run(["config", "--local", "filter.lfs.smudge", "git-lfs smudge -- %f"])

        let hooks = directory.appending(path: ".git/hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        try Data("#!/bin/sh\ngit lfs pre-push \"$@\"\n".utf8).write(to: hooks.appending(path: "pre-push"))

        let list = FileListHarness(session: session, source: source)
        let menu = NSMenu()

        await list.show([.modified("设计 稿.psd")])
        list.select(rows: [0])
        list.coordinator.buildMenu(menu, clickedRow: 0)

        let items = Self.items(menu, "lfs.menu")

        #expect(items.count == 3 && !items.contains(where: \.isEnabled))
        await until { items.allSatisfy(\.isEnabled) }
    }
}

// MARK: - Private

extension WorkingCopyFileListTests {
    /// 子菜单里除分隔线外的菜单项。
    private static func items(_ menu: NSMenu, _ key: String) -> [NSMenuItem] {
        (menu.item(withTitle: AppLocalization.text(key))?.submenu?.items ?? []).filter { !$0.isSeparatorItem }
    }

    /// 比较子菜单各项的可用性，按标题的资源键查。
    private static func states(_ menu: NSMenu, _ key: String) -> [String: Bool] {
        let keys = WorkingCopyComparison.allCases.map(\.titleKey)

        return Dictionary(
            uniqueKeysWithValues: items(menu, key).compactMap { item in
                keys.first { AppLocalization.text($0) == item.title }.map { ($0, item.isEnabled) }
            }
        )
    }
}
