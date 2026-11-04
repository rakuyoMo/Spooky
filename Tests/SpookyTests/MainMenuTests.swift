import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - MainMenuTests

/// 主菜单的结构：应用菜单的 Services，Edit 菜单的系统项、分组与子菜单，Repository、Working Copy、View 与 Window 菜单的
/// 标题、分组与快捷键，以及 Open Recent 的标题与 Clear Menu。
///
/// 系统会往 Edit 与 Window 菜单里自己插入分隔线和项，这里只核对 Spooky 加的项与分隔线，不断言菜单的总项数。
@MainActor
struct MainMenuTests {
    /// Services 排在设置与隐藏两组之间，两侧各一条分隔线；登记给系统后才会被填上可用的服务。
    @Test("应用菜单的 Services")
    func servicesMenu() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

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

        withExtendedLifetime(controller) { }
    }

    /// 撤销、剪贴板、段落重排与五个子菜单各成一组；新加的两项走响应链，由第一响应者决定能不能用。
    @Test("Edit 菜单的分组")
    func editMenuGroups() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let edit = try Self.topMenu("menu.edit")
        let leading = [
            Self.row("menu.undo", "⌘Z"), Self.row("menu.redo", "⇧⌘Z"), "-",
            Self.row("menu.cut", "⌘X"), Self.row("menu.copy", "⌘C"), Self.row("menu.paste", "⌘V"),
            Self.row("menu.pasteAndMatchStyle", "⌥⇧⌘V"), Self.row("menu.delete", "⌘⌫"),
            Self.row("menu.selectAll", "⌘A"), "-",
            Self.row("commit.reformatParagraph", "⇧⌘W"), "-",
            Self.row("menu.find"),
        ]
        #expect(Array(Self.rows(of: edit).prefix(leading.count)) == leading)

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

        let pasteAndMatchStyle = try Self.item("menu.pasteAndMatchStyle", in: edit)
        let delete = try Self.item("menu.delete", in: edit)

        #expect(pasteAndMatchStyle.action == #selector(NSTextView.pasteAsPlainText(_:)))
        #expect(delete.action == #selector(NSText.delete(_:)))
        #expect(pasteAndMatchStyle.target == nil && delete.target == nil)

        withExtendedLifetime(controller) { }
    }

    /// Find 在聚焦搜索框的两项之后接查找栏的四个动作；拼写、替换、大小写与朗读用系统的标准动作，替换里的项都不带快捷键。
    @Test("Edit 菜单的子菜单")
    func editSubmenus() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let edit = try Self.topMenu("menu.edit")
        let find = try #require(Self.item("menu.find", in: edit).submenu)
        let findPanelAction = #selector(NSTextView.performFindPanelAction(_:))

        #expect(Self.rows(of: find) == [
            Self.row("action.find", "⌘F"), Self.row("action.search", "⌥⌘F"), Self.row("menu.findNext", "⌘G"),
            Self.row("menu.findPrevious", "⇧⌘G"), Self.row("menu.useSelectionForFind", "⌘E"),
            Self.row("menu.jumpToSelection", "⌘J"),
        ])
        #expect(find.items[2 ... 4].allSatisfy { $0.action == findPanelAction })
        #expect(find.items[2 ... 4].map(\.tag) == [2, 3, 7])
        #expect(find.items[5].action == #selector(NSResponder.centerSelectionInVisibleArea(_:)))

        let spelling = try #require(Self.item("menu.spelling", in: edit).submenu)
        #expect(Self.rows(of: spelling) == [
            Self.row("menu.showSpelling", "⌘:"), Self.row("menu.checkDocument", "⌘;"), "-",
            Self.row("menu.checkSpellingWhileTyping"), Self.row("menu.checkGrammar"),
            Self.row("menu.correctSpelling"),
        ])
        #expect(spelling.items.compactMap(\.action) == [
            #selector(NSText.showGuessPanel(_:)),
            #selector(NSText.checkSpelling(_:)),
            #selector(NSTextView.toggleContinuousSpellChecking(_:)),
            #selector(NSTextView.toggleGrammarChecking(_:)),
            #selector(NSTextView.toggleAutomaticSpellingCorrection(_:)),
        ])

        let substitutions = try #require(Self.item("menu.substitutions", in: edit).submenu)
        #expect(Self.rows(of: substitutions) == [
            Self.row("menu.showSubstitutions"), "-",
            Self.row("menu.smartCopyPaste"), Self.row("menu.smartQuotes"), Self.row("menu.smartDashes"),
            Self.row("menu.smartLinks"), Self.row("menu.textReplacement"),
        ])
        #expect(substitutions.items.allSatisfy { $0.tag == 0 })

        let transformations = try #require(Self.item("menu.transformations", in: edit).submenu)
        #expect(transformations.items.compactMap(\.action) == [
            #selector(NSResponder.uppercaseWord(_:)),
            #selector(NSResponder.lowercaseWord(_:)),
            #selector(NSResponder.capitalizeWord(_:)),
        ])

        let speech = try #require(Self.item("menu.speech", in: edit).submenu)
        #expect(speech.items.compactMap(\.action) == [
            #selector(NSTextView.startSpeaking(_:)),
            #selector(NSTextView.stopSpeaking(_:)),
        ])

        withExtendedLifetime(controller) { }
    }

    /// 获取、拉取与同步一组，推送 HEAD 起另一组；⌃⌘U 在整个主菜单里只属于安全强推；LFS 的四项不带省略号。
    @Test("Repository 菜单")
    func repositoryMenu() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let repository = try Self.topMenu("menu.repository")
        let leading = [
            Self.row("sync.fetchMenu", "⇧⌘F"), Self.row("sync.quickFetch", "⌥⇧⌘F"), Self.row("sync.fetchAll"),
            Self.row("sync.pullMenu", "⇧⌘P"), Self.row("sync.quickPull", "⌥⇧⌘P"),
            Self.row("sync.syncMenu", "⇧⌘Y"), Self.row("sync.quickSync", "⌥⇧⌘Y"), "-",
            Self.row("sync.pushMenu", "⇧⌘U"), Self.row("sync.quickPushMenu", "⌥⇧⌘U"),
            Self.row("sync.forcePushMenu", "⌃⌘U"), Self.row("sync.pushToMenu"),
            Self.row("sync.publishMenu"), Self.row("tag.publishMainMenu"), Self.row("publish.menu"), "-",
        ]
        #expect(Array(Self.rows(of: repository).prefix(leading.count)) == leading)
        #expect(Self.rows(of: repository).contains(Self.row("branch.createMenu", "⌘B")))

        // 整个主菜单里只有一项用 ⌃⌘U
        let mainMenu = try #require(NSApp.mainMenu)
        let controlCommandU = Self.allItems(in: mainMenu).filter { Self.shortcut(of: $0) == "⌃⌘U" }
        #expect(controlCommandU.map(\.action) == [#selector(RepositoryWindowController.forcePushWithLease)])

        let lfs = try #require(Self.item("lfs.menu", in: repository).submenu)
        #expect(Self.rows(of: lfs) == [
            Self.row("lfs.menu.update"), "-",
            Self.row("lfs.menu.fetch"), Self.row("lfs.menu.pull"), Self.row("lfs.menu.push"), "-",
            Self.row("lfs.menu.track"),
        ])

        withExtendedLifetime(controller) { }
    }

    /// 七组依次为检出、合并与变基、储藏、丢弃全部与重置、提交与暂存、丢弃所选、Compare。
    @Test("Working Copy 菜单")
    func workingCopyMenu() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let working = try Self.topMenu("workspace.title")
        #expect(Self.rows(of: working) == [
            Self.row("rewrite.checkout.menu", "⇧⌘B"), "-",
            Self.row("sync.mergeMenu", "⇧⌘M"), Self.row("sync.quickMerge", "⌥⇧⌘M"),
            Self.row("sync.rebaseMenu", "⇧⌘R"), Self.row("sync.quickRebase", "⌥⇧⌘R"),
            Self.row("rewrite.rebaseOnto.menu", "⌃⇧⌘R"), Self.row("files.applyPatch.menu"), "-",
            Self.row("stash.saveMenu", "⇧⌘S"), Self.row("stash.applyMenu", "⌥⇧⌘S"),
            Self.row("stash.snapshotMenu", "⌃⇧⌘S"), "-",
            Self.row("working.discardAllMenu"), Self.row("rewrite.reset.menu"), "-",
            Self.row("working.commitMenu", "⇧⌘C"), Self.row("working.stage"), Self.row("working.unstage"),
            Self.row("working.stageAllMenu", "⇧⌘E"), Self.row("working.unstageAllMenu", "⌥⇧⌘E"), "-",
            Self.row("working.discardMenu", "⇧⌘⌫"), "-",
            Self.row("externalTool.compare"),
        ])

        withExtendedLifetime(controller) { }
    }

    /// 工作区状态的两种显示带 ⌃⌘T、⌃⌘L，Show Assume-Unchanged Items 不带快捷键；变更集的阈值上方有一行不可选的标题。
    @Test("View 菜单的工作区状态与变更集")
    func viewMenu() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let view = try Self.topMenu("menu.view")
        let status = try #require(Self.item("files.statusMenu", in: view).submenu)
        #expect(Self.rows(of: status) == [
            Self.row("working.tree", "⌃⌘T"), Self.row("working.list", "⌃⌘L"), "-",
            Self.row("files.showNonModified", "⌃⌘M"), Self.row("files.showIgnored", "⌃⌘I"),
            Self.row("files.showAssumeUnchanged"),
        ])

        let changes = try #require(Self.item("history.diffs", in: view).submenu)
        changes.update()

        let title = try Self.item("history.autoExpand.title", in: changes)
        let index = try #require(changes.items.firstIndex(of: title))
        #expect(changes.items[index - 1].isSeparatorItem)
        #expect(!title.isEnabled)
        #expect(changes.items[(index + 1)...].map(\.tag) == [0, 5, 10, 15, 20, 25, 50, Int.max])

        withExtendedLifetime(controller) { }
    }

    /// 最小化与缩放一组，Activity 一组，前置全部窗口一组。
    @Test("Window 菜单")
    func windowMenu() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let window = try Self.topMenu("menu.window")
        let rows = Self.rows(of: window)
        #expect(Array(rows.prefix(2)) == [Self.row("menu.minimize", "⌘M"), Self.row("menu.zoom")])

        // 系统可能在缩放之后插入窗口排布的项，只核对 Activity 与前置全部窗口两组
        let activity = try #require(rows.firstIndex(of: Self.row("activity.title", "⌃⌘0")))
        #expect(rows[activity - 1] == "-")
        #expect(Array(rows[(activity + 1)...].prefix(2)) == ["-", Self.row("menu.bringAll")])
        #expect(NSApp.windowsMenu === window)

        withExtendedLifetime(controller) { }
    }
}

// MARK: - Open Recent and English Titles

extension MainMenuTests {
    /// 菜单项写文件夹名，同名的几项带上一级文件夹名，服务器仓库不带主机前缀，提示写完整位置；
    /// Clear Menu 之后列表为空、书签还在、Clear Menu 不可用，再打开的仓库重新进入列表。
    @Test("Open Recent 的标题与 Clear Menu")
    func openRecent() throws {
        let (controller, suite) = try Self.makeController()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

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

    /// 改了标题与新加的菜单项，英文按下面写。
    @Test("菜单项的英文标题")
    func englishTitles() throws {
        let english = try #require(
            AppLocalization.bundle
                .url(forResource: "en", withExtension: "lproj")
                .flatMap(Bundle.init(url:))
        )
        let titles = [
            "menu.services": "Services",
            "menu.clearRecent": "Clear Menu",
            "menu.pasteAndMatchStyle": "Paste and Match Style",
            "menu.delete": "Delete",
            "menu.findNext": "Find Next",
            "menu.findPrevious": "Find Previous",
            "menu.useSelectionForFind": "Use Selection for Find",
            "menu.jumpToSelection": "Jump to Selection",
            "sync.fetchMenu": "Fetch…",
            "sync.pullMenu": "Pull…",
            "sync.pushMenu": "Push HEAD…",
            "sync.quickPushMenu": "Quick Push HEAD",
            "sync.publishMenu": "Publish Branch…",
            "branch.createMenu": "Create New Branch…",
            "sync.mergeMenu": "Merge…",
            "working.commitMenu": "Commit…",
            "working.stageAllMenu": "Stage All Local Changes",
            "working.unstageAllMenu": "Unstage All Local Changes",
            "working.discardMenu": "Discard Local Changes",
            "working.discardAllMenu": "Discard All Local Changes…",
            "working.tree": "View As Tree",
            "working.list": "View As List",
            "history.autoExpand.title": "Auto-Expand Threshold",
            "lfs.menu.fetch": "Fetch",
            "lfs.menu.track": "Track",
        ]

        for (key, title) in titles {
            #expect(english.localizedString(forKey: key, value: nil, table: nil) == title, "\(key)")
        }
    }
}

// MARK: - Helpers

extension MainMenuTests {
    /// 用独立的偏好域建出应用控制器并装好主菜单；返回控制器与偏好域名。
    private static func makeController() throws -> (SpookyApplicationController, String) {
        let suite = "spooky-main-menu-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        let controller = SpookyApplicationController(bookmarks: RepositoryBookmarks(defaults: defaults))

        _ = NSApplication.shared
        controller.configureMenu()
        return (controller, suite)
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
