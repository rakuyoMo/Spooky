import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryManagerListTests

/// 仓库管理的列表：服务器仓库行上的主机别名与列出仓库的工作树两个显示设置，以及回车改名。
@MainActor
struct RepositoryManagerListTests {
    /// 主机别名默认写在服务器仓库的名称前；关掉后行上只写名称，改动随即生效。
    /// 悬停提示与 VoiceOver 的名字照旧带主机前缀，右键菜单里的名字同样不变。
    @Test("服务器仓库行上的主机别名")
    func hostAliases() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let server = try #require(bookmarks.bookmark(bookmarks.add(.remote(host: "spooky-test", path: "/srv/app"))))
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        let sidebar = BookmarkSidebarController(manager: manager, defaults: defaults)
        _ = sidebar.view

        // 默认写别名
        let shown = try Self.cell(of: server.id, in: sidebar)
        #expect(Self.visibleTexts(in: shown) == ["spooky-test:", "app"])

        // 关掉后列表随即重新载入，行上只写名称
        defaults.set(false, forKey: RepositoryManagerPreferences.showsHostAliasesKey)
        await until { !sidebar.displayOptions.hostAliases }

        let hidden = try Self.cell(of: server.id, in: sidebar)
        #expect(Self.visibleTexts(in: hidden) == ["app"])

        // 悬停提示、VoiceOver 的名字与右键菜单照旧带主机前缀
        #expect(hidden.toolTip == "spooky-test:/srv/app")
        #expect(hidden.accessibilityLabel() == "spooky-test:app")
        #expect(sidebar.singleItems(for: server).first?.title == AppLocalization.text("bookmarks.open", "spooky-test:app"))
    }

    /// 选项关着时不读取，仓库不能展开；打开后只读列表里看得到的仓库，读取都不询问用户；
    /// 服务器仓库连不上时那一行不能展开；展开文件夹后读取里面的仓库；关掉后读到的一并丢掉。
    @Test("列出工作树时读取看得到的仓库")
    func worktreeReading() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let local = RepositoryLocation.local(path: "/tmp/spooky-manager-list/app")
        let server = RepositoryLocation.remote(host: "spooky-test", path: "/srv/app")
        let nested = RepositoryLocation.local(path: "/tmp/spooky-manager-list/nested")

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let repository = bookmarks.add(local)
        let serverRepository = bookmarks.add(server)
        let folder = bookmarks.addFolder(named: "Group")
        bookmarks.add(nested, into: folder)

        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        let sidebar = BookmarkSidebarController(manager: manager, defaults: defaults)
        let reads = WorktreeReads()

        // 本机仓库读到自己与另一个工作树，服务器仓库连不上
        sidebar.worktrees.reader = { location in
            reads.locations.append(location)
            reads.interactive.append(RemoteCallbackRequest.allowsInteraction)

            guard location.host == nil else {
                throw CocoaError(.fileReadNoPermission)
            }

            return [
                Worktree(path: location.path, head: nil, branch: nil, isMain: true, isCurrent: true),
                Worktree(path: "/tmp/spooky-manager-list/other", head: nil, branch: nil, isMain: false),
            ]
        }

        let expandable = { (id: Bookmark.ID) in
            sidebar.outlineView(sidebar.outlineView, isItemExpandable: sidebar.item(for: id))
        }

        _ = sidebar.view

        // 选项关着：不读取，仓库不能展开
        #expect(reads.locations.isEmpty)
        #expect(!expandable(repository))

        // 打开后只读最外层的两个仓库，收起的文件夹里的不读；读取都不询问用户
        defaults.set(true, forKey: RepositoryManagerPreferences.showsWorktreesKey)
        await until { sidebar.displayOptions.worktrees }
        await untilFinished { Array(sidebar.worktrees.tasks.values) }

        #expect(Set(reads.locations) == [local, server])
        #expect(reads.interactive.allSatisfy { !$0 })
        #expect(expandable(repository))
        #expect(!expandable(serverRepository))

        // 展开文件夹后读取里面的仓库，连不上的服务器仓库再读一次
        sidebar.outlineView.expandItem(sidebar.item(for: folder))
        await untilFinished { Array(sidebar.worktrees.tasks.values) }

        #expect(Set(reads.locations.dropFirst(2)) == [nested, server])
        #expect(!expandable(serverRepository))

        // 关掉后读到的工作树一并丢掉，仓库不能展开
        defaults.set(false, forKey: RepositoryManagerPreferences.showsWorktreesKey)
        await until { !sidebar.displayOptions.worktrees }

        #expect(sidebar.worktrees.lists.isEmpty)
        #expect(!expandable(repository))
    }

    /// 列出的与仓库窗口侧边栏相同、按名称排列；失效的工作树名称变灰、带警告图标，菜单各项不可用；
    /// 工作树行不能改名与拖动，只选了它时模型里没有选择；展开记录到下次显示仓库管理时照样展开。
    @Test("工作树行的内容、样子与操作")
    func worktreeRows() async throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let (location, runner) = try await Self.repositoryWithWorktrees(in: directory)
        defaults.set(true, forKey: RepositoryManagerPreferences.showsWorktreesKey)

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let folder = bookmarks.addFolder(named: "Group")
        let repository = bookmarks.add(location)
        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        let sidebar = await Self.loadedSidebar(manager, defaults: defaults, runner: runner)

        // 与侧边栏同一规则：去掉仓库自己，按名称排列
        let items = sidebar.childItems(of: sidebar.item(for: repository)).compactMap { $0 as? BookmarkWorktreeItem }
        let listed = try await RepositoryWorktrees(runner: runner).list()

        #expect(items.map(\.worktree) == RepositoryWorktreeState.others(of: listed))
        #expect(items.map(\.worktree.name) == ["alpha", "zeta"])

        try #require(items.count == 2)
        let (gone, live) = (items[0], items[1])

        // 失效的工作树：名称变灰，带 VoiceOver 读作 Unavailable 的警告图标；悬停提示与侧边栏相同，名称不能改
        let goneCell = try Self.cell(of: gone, in: sidebar)

        #expect(Self.visibleTexts(in: goneCell) == ["alpha"])
        #expect(goneCell.textField?.textColor == .disabledControlTextColor)
        #expect(!(goneCell.textField?.isEditable ?? true))
        #expect(Self.showsWarning(in: goneCell))
        #expect(goneCell.toolTip == RepositorySidebarView.tooltip(of: gone.worktree, in: location))
        #expect(goneCell.accessibilityLabel() == "alpha")

        let liveCell = try Self.cell(of: live, in: sidebar)

        #expect(liveCell.textField?.textColor == .controlTextColor)
        #expect(!Self.showsWarning(in: liveCell))

        // 菜单只有打开与系统两组；失效的各项都不可用，有效的作用于工作树所在的位置
        #expect(
            sidebar.worktreeMenuItems(for: gone).map(\.title) == [
                AppLocalization.text("bookmarks.open", "alpha"), AppLocalization.text("bookmarks.openNewWindow", "alpha"), "",
                AppLocalization.text("action.revealFinder"), AppLocalization.text("action.copyPath"),
                AppLocalization.text("action.openTerminal"),
            ]
        )

        let goneMenu = sidebar.worktreeMenuItems(for: gone).filter { !$0.isSeparatorItem }
        let liveMenu = sidebar.worktreeMenuItems(for: live).filter { !$0.isSeparatorItem }

        #expect(goneMenu.allSatisfy { !$0.isEnabled })
        #expect(liveMenu.allSatisfy { $0.isEnabled })
        #expect(liveMenu.allSatisfy { $0.representedObject as? RepositoryLocation == .local(path: live.worktree.path) })

        // 不能拖动
        #expect(sidebar.outlineView(sidebar.outlineView, pasteboardWriterForItem: live) == nil)

        // 展开工作树时记下
        sidebar.outlineView.expandItem(sidebar.item(for: repository))
        #expect(sidebar.worktrees.isExpanded(repository))

        try Self.checkSelection(in: sidebar, folder: folder, worktree: live)

        // 收起同样记下；再展开后，下次显示仓库管理时读到工作树照样展开
        sidebar.outlineView.collapseItem(sidebar.item(for: repository))
        #expect(!sidebar.worktrees.isExpanded(repository))

        sidebar.outlineView.expandItem(sidebar.item(for: repository))

        let next = await Self.loadedSidebar(manager, defaults: defaults, runner: runner)
        #expect(next.outlineView.isItemExpanded(next.item(for: repository)))
    }

    /// 选项关着时，打开成功的仓库照常自动加入书签，主工作树之外的工作树不加入；工作树已有书签时照常记下打开时间。
    /// 打开选项后，打开的工作树照常加入。
    @Test("选项关着时打开工作树不自动加入书签")
    func openedWorktreeBookmarks() async throws {
        let (defaults, directory) = try Self.defaults()
        let (location, _) = try await Self.repositoryWithWorktrees(in: directory)
        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let coordinator = SpookyApplicationController(bookmarks: bookmarks, recentDocuments: .ignoring)

        defer {
            for window in coordinator.windows {
                window.session.close()
                window.window?.close()
            }

            try? FileManager.default.removeItem(at: directory)
        }

        // 都在同一个窗口里打开，返回 Git 确认后的位置
        let open = { (location: RepositoryLocation) async throws -> RepositoryLocation in
            await coordinator.openRepository(at: location, from: coordinator.windows.first, inNewWindow: false)?.value
            return try #require(coordinator.windows.first?.session.repository)
        }

        // 选项关着：仓库自己加入书签，工作树不加入
        let repository = try await open(location)
        let worktree = try await open(.local(path: directory.appending(path: "zeta").path))

        #expect(worktree != repository)
        #expect(bookmarks.repositories.compactMap(\.location) == [repository])

        // 工作树已有书签时照常记下打开时间
        let added = bookmarks.add(worktree)

        _ = try await open(worktree)
        #expect(bookmarks.bookmark(added)?.lastOpened != nil)

        // 打开选项后，打开的工作树照常加入
        bookmarks.delete([added])
        defaults.set(true, forKey: RepositoryManagerPreferences.showsWorktreesKey)

        _ = try await open(worktree)
        #expect(bookmarks.repositories.compactMap(\.location) == [repository, worktree])
    }

    /// 名称平时不能编辑，点已选中的名称不会进入改名；只选中一个书签时回车进入改名，选中多项时不改名；
    /// 取消与提交之后名称都回到不能编辑。
    @Test("回车改名，名称平时不能编辑")
    func renameFromKeyboard() throws {
        let (defaults, directory) = try Self.defaults()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = RepositoryBookmarks(defaults: defaults)
        let repository = bookmarks.add(.local(path: directory.appending(path: "app").path))
        bookmarks.addFolder(named: "Group")

        let manager = RepositoryManagerController(bookmarks: bookmarks, session: RepositorySession())
        let sidebar = BookmarkSidebarController(manager: manager, defaults: defaults)

        // 编辑名称要用窗口的字段编辑器
        let window = NSWindow(contentViewController: sidebar)
        let outline = sidebar.outlineView
        let row = outline.row(forItem: sidebar.item(for: repository))
        let cell = try #require(outline.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView)
        let name = try #require(cell.textField)

        #expect(!name.isEditable && !name.isSelectable)

        let returnKey = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        ))

        // 选中两项时回车不改名
        window.makeFirstResponder(outline)
        outline.selectAll(nil)
        outline.keyDown(with: returnKey)
        #expect(window.firstResponder === outline)

        // 只选中一个书签时进入改名：字段编辑器属于这一行的名称
        outline.selectRowIndexes([row], byExtendingSelection: false)
        outline.keyDown(with: returnKey)

        let editor = try #require(window.firstResponder as? NSTextView)
        #expect(editor.delegate === name)

        // 取消后名称没变，回到不能编辑
        editor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        #expect(!(window.firstResponder is NSTextView))
        #expect(!name.isEditable && !name.isSelectable)
        #expect(bookmarks.bookmark(repository)?.name == "app")

        // 提交后改了名，同样回到不能编辑
        outline.keyDown(with: returnKey)

        let renaming = try #require(window.firstResponder as? NSTextView)
        renaming.insertText("tool", replacementRange: NSRange(location: 0, length: renaming.string.utf16.count))
        renaming.doCommand(by: #selector(NSResponder.insertNewline(_:)))

        #expect(bookmarks.bookmark(repository)?.name == "tool")
        #expect(!name.isEditable && !name.isSelectable)
    }
}

// MARK: - WorktreeReads

/// 假的工作树读取记下的调用：读的仓库，以及当时能否询问用户。
@MainActor
private final class WorktreeReads {
    /// 读过的仓库，按开始的先后。
    var locations: [RepositoryLocation] = []

    /// 每次读取时能否询问用户。
    var interactive: [Bool] = []
}

// MARK: - Helpers

extension RepositoryManagerListTests {
    /// 带两个工作树的本机仓库：zeta 留着，alpha 的目录删掉后成为失效的；名称的先后与创建的先后相反。
    private static func repositoryWithWorktrees(in directory: URL) async throws -> (RepositoryLocation, GitRunner) {
        let folder = directory.appending(path: "repo")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let location = RepositoryLocation.local(path: folder.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        try Data("base\n".utf8).write(to: folder.appending(path: "a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        _ = try await runner.run(["worktree", "add", "-q", "-b", "zeta", directory.appending(path: "zeta").path])
        _ = try await runner.run(["worktree", "add", "-q", "-b", "alpha", directory.appending(path: "alpha").path])
        try FileManager.default.removeItem(at: directory.appending(path: "alpha"))

        return (location, runner)
    }

    /// 载入好的侧边栏：工作树经测试的执行器读取，等读完再返回。
    private static func loadedSidebar(
        _ manager: RepositoryManagerController,
        defaults: UserDefaults,
        runner: GitRunner
    ) async -> BookmarkSidebarController {
        let sidebar = BookmarkSidebarController(manager: manager, defaults: defaults)

        sidebar.worktrees.reader = { _ in
            try await RepositoryWorktrees(runner: runner).list()
        }

        _ = sidebar.view
        await untilFinished { Array(sidebar.worktrees.tasks.values) }
        return sidebar
    }

    /// 只选工作树行时模型里没有选择，详情区与选中分组时相同；与文件夹一起选中时模型里只有文件夹，重新载入后两行仍选中。
    private static func checkSelection(
        in sidebar: BookmarkSidebarController,
        folder: Bookmark.ID,
        worktree: BookmarkWorktreeItem
    ) throws {
        let outline = sidebar.outlineView
        let folderRow = outline.row(forItem: sidebar.item(for: folder))
        let worktreeRow = outline.row(forItem: worktree)

        try #require(folderRow >= 0 && worktreeRow >= 0)

        outline.selectRowIndexes([folderRow, worktreeRow], byExtendingSelection: false)
        #expect(sidebar.manager.selection == [folder])

        sidebar.reload()
        #expect(outline.selectedRowIndexes == [folderRow, worktreeRow])

        outline.selectRowIndexes([worktreeRow], byExtendingSelection: false)
        #expect(sidebar.manager.selection.isEmpty)
        #expect(sidebar.manager.content == .dropZone)
    }

    /// 每个用例独立的偏好域与它所在的临时目录；用例结束时删掉目录。
    private static func defaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-manager-list-" + UUID().uuidString)

        return (try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path)), directory)
    }

    /// 侧边栏为一个书签建出的行。
    private static func cell(of id: Bookmark.ID, in sidebar: BookmarkSidebarController) throws -> BookmarkCellView {
        let view = sidebar.outlineView(sidebar.outlineView, viewFor: nil, item: sidebar.item(for: id))
        return try #require(view as? BookmarkCellView)
    }

    /// 侧边栏为一个工作树建出的行。
    private static func cell(
        of worktree: BookmarkWorktreeItem,
        in sidebar: BookmarkSidebarController
    ) throws -> BookmarkCellView {
        let view = sidebar.outlineView(sidebar.outlineView, viewFor: nil, item: worktree)
        return try #require(view as? BookmarkCellView)
    }

    /// 行上是否显示着 VoiceOver 读作 Unavailable 的警告图标。
    private static func showsWarning(in view: NSView) -> Bool {
        view.subviews.contains { subview in
            guard !subview.isHidden else {
                return false
            }

            let description = (subview as? NSImageView)?.image?.accessibilityDescription
            return description == AppLocalization.text("repositories.unavailableShort") || showsWarning(in: subview)
        }
    }

    /// 视图里看得到的文字，按视图层级的先后排列。
    private static func visibleTexts(in view: NSView) -> [String] {
        view.subviews.flatMap { subview -> [String] in
            guard !subview.isHidden else {
                return []
            }

            if let field = subview as? NSTextField, !field.stringValue.isEmpty {
                return [field.stringValue]
            }

            return visibleTexts(in: subview)
        }
    }
}
