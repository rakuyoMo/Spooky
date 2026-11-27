import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Toolbar

extension WindowChromeTests {
    /// 工具栏搜索结束编辑时交出焦点，当前搜索词仍用于过滤。
    @Test("Esc 退出工具栏搜索并保留搜索词")
    func escapeEndsToolbarSearch() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)
        defer { fixture.close() }

        let controller = fixture.controller
        let window = try #require(controller.window)
        let item = try #require(Self.item(RepositoryToolbar.search, in: controller) as? NSSearchToolbarItem)
        let search = item.searchField

        // 用工具栏的展开入口切入搜索，模拟搜索框带着当前筛选词获得焦点。
        search.stringValue = "a.txt"
        search.sendAction(search.action, to: search.target)
        item.beginSearchInteraction()

        let editor = try #require(search.currentEditor())
        try #require(window.firstResponder === editor)

        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        ))

        // 直接向窗口分发按键，覆盖搜索框和补全可能拦截 Esc 的路径。
        window.sendEvent(escape)

        #expect(window.firstResponder !== editor)
        #expect(search.stringValue == "a.txt")
        #expect(controller.session.searchText == "a.txt")
    }

    /// 同一个工具栏独有的仓库窗口依次核对：本机仓库的提示随显示方式与 ⌥ 改写；
    /// 跟随内层分栏的分隔符与内层分栏的列表；服务器仓库的主机前缀一项，与本机相同的提示，以及按本机位置的状态写的 Finder 项提示。
    @Test("工具栏的提示、跟随内层分栏的分隔符与服务器仓库的主机前缀")
    func toolbarTipsAndSeparator() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)
        defer { fixture.close() }

        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)

        // Sync 与 Merge | Rebase 不在默认排布里；放在工具栏里的项才随 ⌥ 改写提示
        for identifier in [RepositoryToolbar.synchronize, RepositoryToolbar.merge] {
            toolbar.insertItem(withItemIdentifier: identifier, at: toolbar.items.count)
        }

        // 本机仓库：显示文字时不带标签，只显示图标时多数项在提示前面加上标签，按住 ⌥ 时同步一组换成快速操作的提示
        toolbar.displayMode = .iconAndLabel
        Self.expectLabelModeTips(in: controller)

        // 从显示文字切回只显示图标，提示随显示方式的变化重写
        toolbar.displayMode = .iconOnly
        Self.expectIconOnlyTips(in: controller)
        Self.expectIconOnlyQuickTips(in: controller)

        try Self.expectDetailSeparator(in: controller)
        try Self.expectSeparatorKeptOutOfSecondWindow(in: fixture)

        // 服务器仓库：窗口显示的是本机的工作区，会话换成同一目录的服务器仓库，只用来取主机别名
        controller.showWorkingCopy()
        controller.session.display(.remote(host: "spooky-test", path: fixture.directory.path))
        controller.updateToolbarItems()

        // 主机前缀一项换过三种显示方式后停在只显示图标
        try Self.expectServerHostItem(in: toolbar)

        toolbar.displayMode = .iconAndLabel
        controller.updateToolbarItems()
        Self.expectServerLabelModeTips(in: controller)
        try await Self.expectServerFinderTips(in: controller, directory: fixture.directory)

        toolbar.displayMode = .iconOnly
        Self.expectServerIconOnlyTips(in: controller)
    }
}

// MARK: - Steps

extension WindowChromeTests {
    /// 只显示图标时，有内层分栏的视图在侧边栏分隔符之后有一个跟随内层分隔线的分隔符；
    /// 单栏视图、仓库管理与显示文字时隐藏，留在工具栏里不删。
    /// 有内层分栏的视图里，左侧的列表不延伸到工具栏下面：显示文字时，列表的底色与分隔线不穿过工具栏上的项。
    private static func expectDetailSeparator(in controller: RepositoryWindowController) throws {
        let session = controller.session
        let toolbar = try #require(controller.window?.toolbar)

        /// 当前视图内层分栏左侧的列表不延伸到工具栏下面。
        func expectListBelowToolbar(_ name: String) throws {
            let list = try #require(controller.innerSplit?.splitViewItems.first, "\(name)")
            #expect(!list.allowsFullHeightLayout, "\(name)")
        }

        toolbar.displayMode = .iconOnly
        controller.showWorkingCopy()
        try expectListBelowToolbar("Working Copy")

        let separator = try #require(
            Self.item(RepositoryToolbar.detailSeparator, in: controller) as? NSTrackingSeparatorToolbarItem
        )

        let identifiers = toolbar.items.map(\.itemIdentifier)
        let sidebar = try #require(identifiers.firstIndex(of: RepositoryToolbar.sidebarSeparator))

        #expect(identifiers.firstIndex(of: RepositoryToolbar.detailSeparator) == sidebar + 1)
        #expect(!separator.isHidden)
        #expect(separator.splitView === controller.innerSplit?.splitView)
        #expect(separator.dividerIndex == 0)

        // 换到历史改跟历史的内层分栏
        controller.showHistory()
        try expectListBelowToolbar("History")

        #expect(!separator.isHidden)
        #expect(separator.splitView === controller.innerSplit?.splitView)

        // 其余有内层分栏的视图
        let views: [(name: String, show: () -> Void)] = [
            ("Commit", controller.showCommitPage),
            ("Stashes", controller.showStashes),
            ("Reflog", controller.showReflog),
            ("Branches Review", controller.showBranchesReview),
            ("Pull Requests", controller.showPullRequests),
            ("File History", { session.showFileHistory("a.txt") }),
        ]

        for view in views {
            view.show()
            try expectListBelowToolbar(view.name)
        }

        // 仓库设置是单栏视图
        controller.showRepositorySettings()

        #expect(controller.innerSplit == nil)
        #expect(separator.isHidden)

        // 显示文字时有内层分栏也隐藏
        controller.showWorkingCopy()
        #expect(!separator.isHidden)

        toolbar.displayMode = .iconAndLabel
        #expect(separator.isHidden)

        toolbar.displayMode = .iconOnly
        controller.showRepositories()
        #expect(separator.isHidden)

        // 来回切换始终只有一个
        #expect(toolbar.items.count(where: { $0.itemIdentifier == RepositoryToolbar.detailSeparator }) == 1)
    }

    /// 同一标识的工具栏里已经有一个带着跟随分隔符时，按不含它的排布建出的第二个窗口换到有内层分栏的视图后不插入它：
    /// 系统把插入同步给同一标识的工具栏，已经有这一项的工具栏会抛出重复项的异常。
    private static func expectSeparatorKeptOutOfSecondWindow(in fixture: NavigationTests.WindowFixture) throws {
        let first = try #require(fixture.controller.window?.toolbar)
        let key = "NSToolbar Configuration " + fixture.toolbarIdentifier
        let saved = UserDefaults.standard.dictionary(forKey: key)

        fixture.controller.showWorkingCopy()
        #expect(first.items.contains { $0.itemIdentifier == RepositoryToolbar.detailSeparator })

        // 第二个窗口按不含跟随分隔符的排布建出
        let layout = first.items.map(\.itemIdentifier.rawValue).filter { $0 != RepositoryToolbar.detailSeparator.rawValue }
        UserDefaults.standard.set(["TB Item Identifiers": layout, "TB Display Mode": 2], forKey: key)

        let second = RepositoryWindowController(
            coordinator: fixture.coordinator,
            toolbarIdentifier: NSToolbar.Identifier(fixture.toolbarIdentifier)
        )

        defer {
            second.session.close()
            second.window?.close()
            UserDefaults.standard.set(saved, forKey: key)
        }

        let toolbar = try #require(second.window?.toolbar)
        #expect(!toolbar.items.contains { $0.itemIdentifier == RepositoryToolbar.detailSeparator })

        second.display(fixture.location)

        #expect(second.innerSplit != nil)
        #expect(!toolbar.items.contains { $0.itemIdentifier == RepositoryToolbar.detailSeparator })
        #expect(first.items.count(where: { $0.itemIdentifier == RepositoryToolbar.detailSeparator }) == 1)
    }

    /// 显示文字时提示就是一句话；按住 ⌥ 时同步一组换成快速操作的提示，同样不带标签。
    private static func expectLabelModeTips(in controller: RepositoryWindowController) {
        let text = { (key: String) in AppLocalization.text(key) }

        #expect(Self.tips(of: RepositoryToolbar.repositories, in: controller) == [text("toolbar.bookmarks.tip")])
        #expect(
            Self.tips(of: RepositoryToolbar.navigation, in: controller)
                == [text("navigation.back.tip"), text("navigation.forward.tip")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller)
                == [text("sync.fetch.tip"), text("sync.pull.tip"), text("sync.push.tip")]
        )
        #expect(Self.tips(of: RepositoryToolbar.synchronize, in: controller) == [text("sync.sync.tip")])
        #expect(
            Self.tips(of: RepositoryToolbar.merge, in: controller)
                == [text("sync.merge.tip"), text("sync.rebaseHead.tip")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.stashes, in: controller)
                == [text("toolbar.applyStash.tip"), text("toolbar.saveStash.tip")]
        )
        #expect(Self.tips(of: RepositoryToolbar.quickActions, in: controller) == [text("toolbar.quickActions.tip")])
        #expect(Self.tips(of: RepositoryToolbar.finder, in: controller) == [text("action.revealFinder")])

        // 显示文字时按住 ⌥：快速操作的提示同样不带标签
        controller.updateQuickToolbarItems(option: true)
        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller)
                == [text("sync.quickFetch.tip"), text("sync.quickPull.tip"), text("sync.quickPush.tip")]
        )
        #expect(Self.tips(of: RepositoryToolbar.synchronize, in: controller) == [text("sync.quickSync.tip")])
        #expect(
            Self.tips(of: RepositoryToolbar.merge, in: controller)
                == [text("sync.quickMerge.tip"), text("sync.quickRebase.tip")]
        )
        controller.updateQuickToolbarItems(option: false)
    }

    /// 只显示图标时多数项在提示前面加上 “<标签>: ”，Sync、Create Branch、Refresh、Force Push、Push To
    /// 与 Parent Repository 不加。
    private static func expectIconOnlyTips(in controller: RepositoryWindowController) {
        let text = { (key: String) in AppLocalization.text(key) }

        #expect(
            Self.tips(of: RepositoryToolbar.repositories, in: controller)
                == [Self.labeledTip("toolbar.bookmarks", "toolbar.bookmarks.tip")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.navigation, in: controller) == [
                Self.labeledTip("toolbar.previous", "navigation.back.tip"),
                Self.labeledTip("toolbar.next", "navigation.forward.tip"),
            ]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller) == [
                Self.labeledTip("sync.fetch", "sync.fetch.tip"),
                Self.labeledTip("sync.pull", "sync.pull.tip"),
                Self.labeledTip("sync.push", "sync.push.tip"),
            ]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.merge, in: controller) == [
                Self.labeledTip("sync.merge", "sync.merge.tip"),
                Self.labeledTip("sync.rebaseHead", "sync.rebaseHead.tip"),
            ]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.stashes, in: controller) == [
                Self.labeledTip("stash.apply", "toolbar.applyStash.tip"),
                Self.labeledTip("stash.save", "toolbar.saveStash.tip"),
            ]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.quickActions, in: controller)
                == [Self.labeledTip("toolbar.quickActions", "toolbar.quickActions.tip")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.finder, in: controller)
                == [Self.labeledTip("toolbar.finder", "action.revealFinder")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.terminal, in: controller)
                == [Self.labeledTip("toolbar.terminal", "action.openTerminal")]
        )

        // 只显示图标也不加标签的项
        #expect(Self.tips(of: RepositoryToolbar.synchronize, in: controller) == [text("sync.sync.tip")])
        #expect(Self.tips(of: RepositoryToolbar.createBranch, in: controller) == [text("toolbar.createBranch.tip")])
        #expect(Self.tips(of: RepositoryToolbar.refresh, in: controller) == [text("action.refresh")])
        #expect(Self.tips(of: RepositoryToolbar.forcePush, in: controller) == [text("toolbar.forcePush.tip")])
        #expect(Self.tips(of: RepositoryToolbar.pushTo, in: controller) == [text("toolbar.pushTo")])
        #expect(
            Self.tips(of: RepositoryToolbar.parentRepository, in: controller)
                == [text("toolbar.parentRepository.tip")]
        )
    }

    /// 只显示图标时按住 ⌥：同步一组的提示前面总是加上 “Quick Fetch: ” 这类标签，Sync 也加。
    private static func expectIconOnlyQuickTips(in controller: RepositoryWindowController) {
        controller.updateQuickToolbarItems(option: true)
        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller) == [
                Self.labeledTip("sync.quickFetch", "sync.quickFetch.tip"),
                Self.labeledTip("sync.quickPull", "sync.quickPull.tip"),
                Self.labeledTip("sync.quickPush", "sync.quickPush.tip"),
            ]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.synchronize, in: controller)
                == [Self.labeledTip("sync.quickSync", "sync.quickSync.tip")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.merge, in: controller) == [
                Self.labeledTip("sync.quickMerge", "sync.quickMerge.tip"),
                Self.labeledTip("sync.quickRebase", "sync.quickRebase.tip"),
            ]
        )
        controller.updateQuickToolbarItems(option: false)
    }

    /// 服务器仓库的主机前缀在每种显示方式下只出现一次：显示标签时只由标签写出，只显示图标时只由视图写出；
    /// 标签一直写着主机前缀，溢出菜单里仍是可读的名字；自定义面板里的名字是 “Server”。
    ///
    /// 依次换成显示文字、只显示文字与只显示图标，最后停在只显示图标。
    private static func expectServerHostItem(in toolbar: NSToolbar) throws {
        let item = try #require(toolbar.items.first { $0.itemIdentifier == RepositoryToolbar.host })
        let view = try #require(item.view as? NSTextField)
        #expect(!item.isHidden)
        #expect(item.paletteLabel == AppLocalization.text("toolbar.host"))

        // 换显示方式后由观察者重写这一项
        let expected: [(mode: NSToolbar.DisplayMode, view: String)] = [
            (.iconAndLabel, ""),
            (.labelOnly, ""),
            (.iconOnly, "spooky-test:"),
        ]

        for (mode, text) in expected {
            toolbar.displayMode = mode
            #expect(item.label == "spooky-test:")
            #expect(view.stringValue == text)
        }
    }

    /// 服务器仓库显示文字时，按钮表里的按钮与同步一组的提示与本机仓库相同，不加主机前缀，按住 ⌥ 时同样不加。
    private static func expectServerLabelModeTips(in controller: RepositoryWindowController) {
        let text = { (key: String) in AppLocalization.text(key) }

        #expect(Self.tips(of: RepositoryToolbar.refresh, in: controller) == [text("action.refresh")])
        #expect(Self.tips(of: RepositoryToolbar.sync, in: controller).first == text("sync.fetch.tip"))
        #expect(
            Self.tips(of: RepositoryToolbar.navigation, in: controller)
                == [text("navigation.back.tip"), text("navigation.forward.tip")]
        )

        controller.updateQuickToolbarItems(option: true)
        #expect(Self.tips(of: RepositoryToolbar.sync, in: controller).first == text("sync.quickFetch.tip"))
        controller.updateQuickToolbarItems(option: false)
    }

    /// 服务器仓库的 Finder 项校验时按本机位置的状态写提示：能直接打开时是平常的提示，指定的文件夹不在时写原因。
    private static func expectServerFinderTips(in controller: RepositoryWindowController, directory: URL) async throws {
        let toolbar = try #require(controller.window?.toolbar)
        let mounts = controller.session.mounts

        // 只校验工具栏上看得见的项，窗口放宽到 Finder 项不进溢出菜单
        controller.window?.setContentSize(NSSize(width: 1400, height: 800))

        // 文件夹在不在是在后台查看的，每一轮重新校验后再取提示
        let tips = {
            toolbar.validateVisibleItems()
            return Self.tips(of: RepositoryToolbar.finder, in: controller)
        }

        mounts.apply(.chosenFolder(directory))
        await until { tips() == [AppLocalization.text("action.revealFinder")] }

        let missing = directory.appending(path: "不在")
        let reason = AppLocalization.text("action.revealFinder.folderMissing", HomePath.abbreviated(missing.path))

        mounts.apply(.chosenFolder(missing))
        await until { tips() == [reason] }
    }

    /// 服务器仓库只显示图标时与本机仓库相同：提示前面只加标签，按住 ⌥ 时同样如此；Push To 不加标签。
    private static func expectServerIconOnlyTips(in controller: RepositoryWindowController) {
        let text = { (key: String) in AppLocalization.text(key) }

        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller).first
                == Self.labeledTip("sync.fetch", "sync.fetch.tip")
        )
        #expect(
            Self.tips(of: RepositoryToolbar.quickActions, in: controller)
                == [Self.labeledTip("toolbar.quickActions", "toolbar.quickActions.tip")]
        )
        #expect(Self.tips(of: RepositoryToolbar.pushTo, in: controller) == [text("toolbar.pushTo")])
        #expect(
            Self.tips(of: RepositoryToolbar.repositories, in: controller)
                == [Self.labeledTip("toolbar.bookmarks", "toolbar.bookmarks.tip")]
        )
        #expect(
            Self.tips(of: RepositoryToolbar.stashes, in: controller).first
                == Self.labeledTip("stash.apply", "toolbar.applyStash.tip")
        )

        controller.updateQuickToolbarItems(option: true)
        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller).first
                == Self.labeledTip("sync.quickFetch", "sync.quickFetch.tip")
        )
        controller.updateQuickToolbarItems(option: false)
    }
}

// MARK: - Helpers

extension WindowChromeTests {
    /// 窗口工具栏里的项；不在工具栏里的按标识新建一个，与自定义面板里拖进来的相同。
    static func item(
        _ identifier: NSToolbarItem.Identifier,
        in controller: RepositoryWindowController
    ) -> NSToolbarItem? {
        guard let toolbar = controller.window?.toolbar else {
            return nil
        }

        if let item = toolbar.items.first(where: { $0.itemIdentifier == identifier }) {
            return item
        }

        return controller.toolbar(toolbar, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true)
    }

    /// 只显示图标时的提示：标签与提示按 “<标签>: <提示>” 的格式连起来。
    static func labeledTip(_ label: String, _ tip: String) -> String {
        AppLocalization.text("toolbar.labeledTip", AppLocalization.text(label), AppLocalization.text(tip))
    }

    /// 一项的提示；分段组按段依次取出。
    static func tips(
        of identifier: NSToolbarItem.Identifier,
        in controller: RepositoryWindowController
    ) -> [String?] {
        guard let item = item(identifier, in: controller) else {
            return []
        }

        return ((item as? NSToolbarItemGroup)?.subitems ?? [item]).map(\.toolTip)
    }
}
