import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - MainMenuTests

/// 主菜单的结构：应用菜单的 Services，Edit 菜单的系统项、分组与子菜单，Repository、Working Copy、View 与 Window 菜单的
/// 标题、分组与快捷键，Diff 上下文行数的入口，以及 Open Recent 的标题与 Clear Menu、变更集菜单的全局阈值。
///
/// 系统会往 Edit 与 Window 菜单里自己插入分隔线和项，这里只核对 Spooky 加的项与分隔线，不断言菜单的总项数。
@MainActor
struct MainMenuTests {
    /// 同一份主菜单依次核对各个顶层菜单的分组、快捷键与动作。
    @Test("主菜单的分组、快捷键与动作")
    func menuStructure() throws {
        let (controller, directory) = try Self.makeController()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Self.expectServicesMenu()
        try Self.expectEditMenu()
        try Self.expectEditSubmenus()
        try Self.expectRepositoryMenu()
        try Self.expectWorkingCopyMenu()
        try Self.expectViewMenu()
        try Self.expectWindowMenu()
        try Self.expectDiffContextMenu()

        withExtendedLifetime(controller) { }
    }

    /// 菜单项写文件夹名，同名的几项带上一级文件夹名，服务器仓库不带主机前缀，提示写完整位置；
    /// Clear Menu 之后列表为空、书签还在、Clear Menu 不可用，再打开的仓库重新进入列表。
    @Test("Open Recent 的标题与 Clear Menu")
    func openRecent() throws {
        let (controller, directory) = try Self.makeController()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookmarks = controller.bookmarks
        let first = RepositoryLocation.local(path: "/tmp/alpha/demo")
        let second = RepositoryLocation.remote(host: "spooky-test", path: "/srv/beta/demo")
        let unique = RepositoryLocation.remote(host: "spooky-test", path: "/srv/仓 库")

        bookmarks.recordOpened(first, at: Date(timeIntervalSince1970: 100))
        bookmarks.recordOpened(second, at: Date(timeIntervalSince1970: 200))
        bookmarks.recordOpened(unique, at: Date(timeIntervalSince1970: 300))

        let file = try Self.topMenu("menu.file")
        let recent = try #require(Self.item("menu.openRecent", in: file).submenu)
        controller.menuNeedsUpdate(recent)

        let clearTitle = AppLocalization.text("menu.clearRecent")

        #expect(Self.rows(of: recent) == ["仓 库", "demo — beta", "demo — alpha", "-", clearTitle])
        #expect(recent.items.prefix(3).map(\.toolTip) == [unique, second, first].map(\.displayPath))

        let clear = try #require(recent.items.last)
        #expect(controller.validateMenuItem(clear))

        controller.clearRecentRepositories()
        controller.menuNeedsUpdate(recent)

        let emptyClear = try #require(recent.items.last)

        #expect(Self.rows(of: recent) == [clearTitle])
        #expect(!controller.validateMenuItem(emptyClear))
        #expect(bookmarks.repositories.compactMap(\.location) == [first, second, unique])

        // 清空之后打开的仓库照常进入列表
        bookmarks.recordOpened(first, at: Date().addingTimeInterval(1))
        controller.menuNeedsUpdate(recent)

        #expect(Self.rows(of: recent) == ["demo", "-", clearTitle])
    }
}

// MARK: - Changeset Menu

extension MainMenuTests {
    /// 阈值是全局动作，静态命令仍走窗口响应链；无仓库和管理页都能保存并勾选八档设置。
    @Test("变更集菜单的全局阈值与快捷键")
    func changesetMenu() throws {
        let (controller, directory) = try Self.makeController()

        // 与控制器的偏好放在同一个临时目录里，随目录删除；按名称建的偏好域即使清空，也会在用户的偏好目录里留下空文件
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "changeset").path))

        defer { try? FileManager.default.removeItem(at: directory) }

        controller.changesetPreferences = defaults
        let menu = try #require(Self.item("history.diffs", in: Self.topMenu("menu.view")).submenu)

        // 展开与收起两项走窗口响应链，带 ⌃⌘→ 与 ⌃⌘←
        let commands = Array(menu.items.prefix(2))

        #expect(menu.items.count == 12)
        #expect(menu.items[0].action == #selector(RepositoryWindowController.expandChanges))
        #expect(menu.items[1].action == #selector(RepositoryWindowController.collapseChanges))
        #expect(menu.items[0].keyEquivalent == "\u{f703}")
        #expect(menu.items[1].keyEquivalent == "\u{f702}")
        #expect(commands.allSatisfy { $0.keyEquivalentModifierMask == [.control, .command] && $0.target == nil })

        // 分隔线之后是不可选的标题，再往后是八档阈值
        #expect(menu.items[2].isSeparatorItem)
        #expect(menu.items[3].title == AppLocalization.text("history.autoExpand.title"))
        #expect(menu.items[3].action == nil)
        #expect(menu.items.allSatisfy { !$0.isAlternate })

        let thresholds = Array(menu.items.dropFirst(4))
        let setAutoExpand = #selector(controller.setAutoExpand(_:))

        let titles = [AppLocalization.text("history.autoExpand.never")]
            + [5, 10, 15, 20, 25, 50].map { AppLocalization.text("history.autoExpand.items", $0) }
            + [AppLocalization.text("history.autoExpand.always")]

        #expect(thresholds.map(\.tag) == [0, 5, 10, 15, 20, 25, 50, Int.max])
        #expect(thresholds.allSatisfy { $0.target === controller && $0.action == setAutoExpand })
        #expect(thresholds.allSatisfy { $0.keyEquivalent.isEmpty })
        #expect(thresholds.map(\.title) == titles)

        // 没有任何窗口时就能切换档位
        #expect(controller.windows.isEmpty)
        #expect(controller.validateMenuItem(thresholds[0]) && thresholds[0].state == .on)
        assertThresholds(thresholds, controller: controller)

        // 窗口显示仓库管理时同样能切换，标题仍不可选
        let manager = RepositoryWindowController(coordinator: controller)
        defer { manager.window?.close() }

        #expect(manager.showsManager)
        assertThresholds(thresholds, controller: controller)

        menu.update()
        #expect(!menu.items[3].isEnabled)
    }

    /// 经真实菜单动作切换档位，验证只勾选保存值，动作不依赖任何仓库窗口。
    private func assertThresholds(_ items: [NSMenuItem], controller: SpookyApplicationController) {
        for selected in items {
            guard let action = selected.action else {
                Issue.record("阈值项必须提供全局设置动作")
                continue
            }

            #expect(NSApp.sendAction(action, to: selected.target, from: selected))

            for item in items {
                #expect(controller.validateMenuItem(item))
                #expect(item.state == (item.tag == selected.tag ? .on : .off))
            }
        }
    }
}

// MARK: - Steps

extension MainMenuTests {
    /// Services 排在设置与隐藏两组之间，两侧各一条分隔线；登记给系统后才会被填上可用的服务。
    private static func expectServicesMenu() throws {
        let application = try #require(NSApp.mainMenu?.items.first?.submenu)
        let servicesTitle = AppLocalization.text("menu.services")
        let index = try #require(application.items.firstIndex { $0.title == servicesTitle })

        // 一个进程里 AppKit 只认第一次登记的 Services 菜单，别的用例先装过主菜单时这里拿到的是那一份，所以只核对标题
        #expect(application.items[index].submenu != nil)
        #expect(NSApp.servicesMenu?.title == servicesTitle)

        #expect(application.items[index - 1].isSeparatorItem)
        #expect(application.items[index + 1].isSeparatorItem)
        #expect(application.items[index - 2].action == #selector(SpookyApplicationController.showSettings))
        #expect(application.items[index + 2].action == #selector(NSApplication.hide(_:)))
    }

    /// Edit 菜单：撤销、剪贴板、段落重排与五个子菜单各成一组；新加的两项走响应链，由第一响应者决定能不能用。
    private static func expectEditMenu() throws {
        let edit = try topMenu("menu.edit")

        let leading = [
            row("menu.undo", "⌘Z"), row("menu.redo", "⇧⌘Z"), "-",
            row("menu.cut", "⌘X"), row("menu.copy", "⌘C"), row("menu.paste", "⌘V"),
            row("menu.pasteAndMatchStyle", "⌥⇧⌘V"), row("menu.delete", "⌘⌫"),
            row("menu.selectAll", "⌘A"), "-",
            row("commit.reformatParagraph", "⇧⌘W"), "-",
            row("menu.find"),
        ]

        #expect(Array(rows(of: edit).prefix(leading.count)) == leading)

        // 五个子菜单依次排列；系统在它们之间插入的分隔线不在断言之内
        let submenus = [
            "menu.find",
            "menu.spelling",
            "menu.substitutions",
            "menu.transformations",
            "menu.speech",
        ]

        let positions = try submenus.map { key in
            try #require(edit.items.firstIndex { $0.title == AppLocalization.text(key) && $0.submenu != nil })
        }

        #expect(positions == positions.sorted())

        let pasteAndMatchStyle = try item("menu.pasteAndMatchStyle", in: edit)
        let delete = try item("menu.delete", in: edit)

        #expect(pasteAndMatchStyle.action == #selector(NSTextView.pasteAsPlainText(_:)))
        #expect(delete.action == #selector(NSText.delete(_:)))
        #expect(pasteAndMatchStyle.target == nil && delete.target == nil)
    }

    /// Find 在聚焦搜索框的两项之后接查找栏的四个动作；拼写、替换、大小写与朗读用系统的标准动作，替换里的项都不带快捷键。
    private static func expectEditSubmenus() throws {
        let edit = try topMenu("menu.edit")
        let find = try #require(item("menu.find", in: edit).submenu)
        let findPanelAction = #selector(NSTextView.performFindPanelAction(_:))

        #expect(rows(of: find) == [
            row("action.find", "⌘F"), row("action.search", "⌥⌘F"), row("menu.findNext", "⌘G"),
            row("menu.findPrevious", "⇧⌘G"), row("menu.useSelectionForFind", "⌘E"),
            row("menu.jumpToSelection", "⌘J"),
        ])
        #expect(find.items[2 ... 4].allSatisfy { $0.action == findPanelAction })
        #expect(find.items[2 ... 4].map(\.tag) == [2, 3, 7])
        #expect(find.items[5].action == #selector(NSResponder.centerSelectionInVisibleArea(_:)))

        let spelling = try #require(item("menu.spelling", in: edit).submenu)

        #expect(rows(of: spelling) == [
            row("menu.showSpelling", "⌘:"), row("menu.checkDocument", "⌘;"), "-",
            row("menu.checkSpellingWhileTyping"), row("menu.checkGrammar"),
            row("menu.correctSpelling"),
        ])
        #expect(spelling.items.compactMap(\.action) == [
            #selector(NSText.showGuessPanel(_:)),
            #selector(NSText.checkSpelling(_:)),
            #selector(NSTextView.toggleContinuousSpellChecking(_:)),
            #selector(NSTextView.toggleGrammarChecking(_:)),
            #selector(NSTextView.toggleAutomaticSpellingCorrection(_:)),
        ])

        let substitutions = try #require(item("menu.substitutions", in: edit).submenu)

        #expect(rows(of: substitutions) == [
            row("menu.showSubstitutions"), "-",
            row("menu.smartCopyPaste"), row("menu.smartQuotes"), row("menu.smartDashes"),
            row("menu.smartLinks"), row("menu.textReplacement"),
        ])
        #expect(substitutions.items.allSatisfy { $0.tag == 0 })

        let transformations = try #require(item("menu.transformations", in: edit).submenu)

        #expect(transformations.items.compactMap(\.action) == [
            #selector(NSResponder.uppercaseWord(_:)),
            #selector(NSResponder.lowercaseWord(_:)),
            #selector(NSResponder.capitalizeWord(_:)),
        ])

        let speech = try #require(item("menu.speech", in: edit).submenu)

        #expect(speech.items.compactMap(\.action) == [
            #selector(NSTextView.startSpeaking(_:)),
            #selector(NSTextView.stopSpeaking(_:)),
        ])
    }

    /// Repository 菜单：获取、拉取与同步一组，推送 HEAD 起另一组；⌃⌘U 在整个主菜单里只属于安全强推；LFS 的四项不带省略号。
    private static func expectRepositoryMenu() throws {
        let repository = try topMenu("menu.repository")

        let leading = [
            row("sync.fetchMenu", "⇧⌘F"), row("sync.quickFetch", "⌥⇧⌘F"), row("sync.fetchAll"),
            row("sync.pullMenu", "⇧⌘P"), row("sync.quickPull", "⌥⇧⌘P"),
            row("sync.syncMenu", "⇧⌘Y"), row("sync.quickSync", "⌥⇧⌘Y"), "-",
            row("sync.pushMenu", "⇧⌘U"), row("sync.quickPushMenu", "⌥⇧⌘U"),
            row("sync.forcePushMenu", "⌃⌘U"), row("sync.pushToMenu"),
            row("sync.publishMenu"), row("tag.publishMainMenu"), row("publish.menu"), "-",
        ]

        #expect(Array(rows(of: repository).prefix(leading.count)) == leading)
        #expect(rows(of: repository).contains(row("branch.createMenu", "⌘B")))

        // 整个主菜单里只有一项用 ⌃⌘U
        let mainMenu = try #require(NSApp.mainMenu)
        let controlCommandU = allItems(in: mainMenu).filter { shortcut(of: $0) == "⌃⌘U" }

        #expect(controlCommandU.map(\.action) == [#selector(RepositoryWindowController.forcePushWithLease)])

        let lfs = try #require(item("lfs.menu", in: repository).submenu)

        #expect(rows(of: lfs) == [
            row("lfs.menu.update"), "-",
            row("lfs.menu.fetch"), row("lfs.menu.pull"), row("lfs.menu.push"), "-",
            row("lfs.menu.track"),
        ])
    }

    /// Working Copy 菜单的七组依次为检出、合并与变基、储藏、丢弃全部与重置、提交与暂存、丢弃所选、Compare。
    private static func expectWorkingCopyMenu() throws {
        let working = try topMenu("workspace.title")

        #expect(rows(of: working) == [
            row("rewrite.checkout.menu", "⇧⌘B"), "-",
            row("sync.mergeMenu", "⇧⌘M"), row("sync.quickMerge", "⌥⇧⌘M"),
            row("sync.rebaseMenu", "⇧⌘R"), row("sync.quickRebase", "⌥⇧⌘R"),
            row("rewrite.rebaseOnto.menu", "⌃⇧⌘R"), row("files.applyPatch.menu"), "-",
            row("stash.saveMenu", "⇧⌘S"), row("stash.applyMenu", "⌥⇧⌘S"),
            row("stash.snapshotMenu", "⌃⇧⌘S"), "-",
            row("working.discardAllMenu"), row("rewrite.reset.menu"), "-",
            row("working.commitMenu", "⇧⌘C"), row("working.stage"), row("working.unstage"),
            row("working.stageAllMenu", "⇧⌘E"), row("working.unstageAllMenu", "⌥⇧⌘E"), "-",
            row("working.discardMenu", "⇧⌘⌫"), "-",
            row("externalTool.compare"),
        ])
    }

    /// View 菜单：工作区状态的两种显示带 ⌃⌘T、⌃⌘L，Show Assume-Unchanged Items 不带快捷键；
    /// 变更集的阈值上方有一行不可选的标题。
    private static func expectViewMenu() throws {
        let view = try topMenu("menu.view")
        let status = try #require(item("files.statusMenu", in: view).submenu)

        #expect(rows(of: status) == [
            row("working.tree", "⌃⌘T"), row("working.list", "⌃⌘L"), "-",
            row("files.showNonModified", "⌃⌘M"), row("files.showIgnored", "⌃⌘I"),
            row("files.showAssumeUnchanged"),
        ])

        let changes = try #require(item("history.diffs", in: view).submenu)
        changes.update()

        let title = try item("history.autoExpand.title", in: changes)
        let index = try #require(changes.items.firstIndex(of: title))

        #expect(changes.items[index - 1].isSeparatorItem)
        #expect(!title.isEnabled)
        #expect(changes.items[(index + 1)...].map(\.tag) == [0, 5, 10, 15, 20, 25, 50, Int.max])
    }

    /// Window 菜单：最小化与缩放一组，Activity 一组，前置全部窗口一组。
    private static func expectWindowMenu() throws {
        let window = try topMenu("menu.window")
        let lines = rows(of: window)

        #expect(Array(lines.prefix(2)) == [row("menu.minimize", "⌘M"), row("menu.zoom")])

        // 系统可能在缩放之后插入窗口排布的项，只核对 Activity 与前置全部窗口两组
        let activity = try #require(lines.firstIndex(of: row("activity.title", "⌃⌘0")))

        #expect(lines[activity - 1] == "-")
        #expect(Array(lines[(activity + 1)...].prefix(2)) == ["-", row("menu.bringAll")])
        #expect(NSApp.windowsMenu === window)
    }

    /// 上下文行数的菜单入口列出全部档位，连到窗口的动作上，否则功能只能从底栏使用；
    /// 每个档位一项，标签即行数，标题与底栏的弹出菜单一致。
    private static func expectDiffContextMenu() throws {
        let items = NSApp.mainMenu?.items.compactMap(\.submenu).flatMap(\.items) ?? []
        let context = try #require(items.first { $0.title == AppLocalization.text("diff.contextMenu") }?.submenu)
        let action = #selector(RepositoryWindowController.setDiffContextLines(_:))

        #expect(context.items.map(\.tag) == DiffOptions.contextChoices)
        #expect(context.items.map(\.title) == DiffOptions.contextChoices.map(DiffPreferences.contextTitle))
        #expect(context.items.allSatisfy { $0.action == action })
    }
}

// MARK: - Helpers

extension MainMenuTests {
    /// 用独立的偏好域建出应用控制器并装好主菜单；返回控制器与偏好域所在的临时目录，用例结束时删掉目录。
    private static func makeController() throws -> (SpookyApplicationController, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-main-menu-" + UUID().uuidString)
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let controller = SpookyApplicationController(
            bookmarks: RepositoryBookmarks(defaults: defaults),
            recentDocuments: .ignoring
        )

        _ = NSApplication.shared
        controller.configureMenu()
        return (controller, directory)
    }

    /// 主菜单里标题为某个资源键的顶层菜单。
    private static func topMenu(_ key: String) throws -> NSMenu {
        try #require(NSApp.mainMenu?.items.first { $0.title == AppLocalization.text(key) }?.submenu)
    }

    /// 菜单里标题为某个资源键的项。
    private static func item(_ key: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.title == AppLocalization.text(key) })
    }

    /// 菜单与它全部子菜单里的项。
    private static func allItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { [$0] + ($0.submenu.map(allItems) ?? []) }
    }

    /// 菜单的逐项描述：分隔线写 “-”，其余写标题，有快捷键的在标题后空一格接快捷键。
    private static func rows(of menu: NSMenu) -> [String] {
        menu.items.map { item in
            guard !item.isSeparatorItem else {
                return "-"
            }

            let shortcut = shortcut(of: item)
            return shortcut.isEmpty ? item.title : item.title + " " + shortcut
        }
    }

    /// 按资源键与快捷键写出期望的一行，写法与 `rows(of:)` 相同。
    private static func row(_ key: String, _ shortcut: String = "") -> String {
        shortcut.isEmpty ? AppLocalization.text(key) : AppLocalization.text(key) + " " + shortcut
    }

    /// 菜单项快捷键的符号写法，如 “⇧⌘F”；没有快捷键时为空串。
    private static func shortcut(of item: NSMenuItem) -> String {
        guard !item.keyEquivalent.isEmpty else {
            return ""
        }

        let modifiers = item.keyEquivalentModifierMask
        let symbols: [(NSEvent.ModifierFlags, String)] = [
            (.control, "⌃"),
            (.option, "⌥"),
            (.shift, "⇧"),
            (.command, "⌘"),
        ]
        let prefix = symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
        let key = item.keyEquivalent == "\u{8}" ? "⌫" : item.keyEquivalent.uppercased()
        return prefix + key
    }
}
