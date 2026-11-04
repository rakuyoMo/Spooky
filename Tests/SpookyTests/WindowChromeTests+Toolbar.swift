import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Toolbar

extension WindowChromeTests {
    /// 本机仓库的提示随显示方式与 ⌥ 改写：显示文字时不带标签，只显示图标时多数项在提示前面加上标签，
    /// 按住 ⌥ 时同步一组换成快速操作的提示。
    @Test("本机仓库的工具栏提示")
    func localToolbarTips() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)
        defer { fixture.close() }

        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)

        toolbar.displayMode = .iconAndLabel
        Self.expectLabelModeTips(in: controller)

        // 从显示文字切回只显示图标，提示随显示方式的变化重写
        toolbar.displayMode = .iconOnly
        Self.expectIconOnlyTips(in: controller)
        Self.expectIconOnlyQuickTips(in: controller)
    }

    /// 服务器仓库的工具栏标明主机：主机前缀一项在每种显示方式下只写出一次，
    /// 按钮表里的按钮与同步一组的提示在最前面加主机前缀，Bookmarks、Prev / Next 与储藏两段不加。
    @Test("服务器仓库的工具栏提示与主机前缀")
    func serverToolbarTips() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)
        defer { fixture.close() }

        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)

        // 窗口显示的是本机的工作区，会话换成同一目录的服务器仓库，只用来取主机别名
        controller.session.display(.remote(host: "spooky-test", path: fixture.directory.path))
        controller.updateToolbarItems()

        // 主机前缀一项换过三种显示方式后停在只显示图标
        try Self.expectServerHostItem(in: toolbar)

        toolbar.displayMode = .iconAndLabel
        controller.updateToolbarItems()
        Self.expectServerLabelModeTips(in: controller)

        toolbar.displayMode = .iconOnly
        Self.expectServerIconOnlyTips(in: controller)
    }

    /// 只显示图标时，有内层分栏的视图在侧边栏分隔符之后有一个跟随内层分隔线的分隔符；
    /// 单栏视图、仓库管理与显示文字时隐藏，留在工具栏里不删。
    /// 有内层分栏的视图里，左侧的列表不延伸到工具栏下面：显示文字时，列表的底色与分隔线不穿过工具栏上的项。
    @Test("跟随内层分栏的分隔符，内层分栏的列表不延伸到工具栏下面")
    func detailSeparatorAndInnerList() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)
        defer { fixture.close() }

        let controller = fixture.controller
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

    /// 刷新进行中，工具栏的 Refresh 与 View › Refresh（⌘R）照常可用。
    @Test("刷新中 Refresh 可用")
    func refreshWhileRefreshing() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let item = NSMenuItem(
            title: "",
            action: #selector(RepositoryWindowController.refreshRepository),
            keyEquivalent: ""
        )

        controller.session.refresh(full: true)
        #expect(controller.session.isRefreshing)
        #expect(controller.validateUserInterfaceItem(item))

        await controller.session.waitForRefresh()
    }
}

// MARK: - Steps

extension WindowChromeTests {
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

    /// 只显示图标时多数项在提示前面加上 “<标签>: ”，Sync、Create Branch、Refresh、Force Push、Push To、Close Repository
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
        #expect(Self.tips(of: RepositoryToolbar.closeRepository, in: controller) == [text("action.closeRepository")])
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

    /// 服务器仓库显示文字时，按钮表里的按钮与同步一组的提示在最前面加主机前缀，按住 ⌥ 时同样加；Prev / Next 不加。
    private static func expectServerLabelModeTips(in controller: RepositoryWindowController) {
        let text = { (key: String) in AppLocalization.text(key) }
        let host = { (tip: String) in "spooky-test: " + tip }

        #expect(Self.tips(of: RepositoryToolbar.refresh, in: controller) == [host(text("action.refresh"))])
        #expect(Self.tips(of: RepositoryToolbar.sync, in: controller).first == host(text("sync.fetch.tip")))
        #expect(
            Self.tips(of: RepositoryToolbar.navigation, in: controller)
                == [text("navigation.back.tip"), text("navigation.forward.tip")]
        )

        controller.updateQuickToolbarItems(option: true)
        #expect(Self.tips(of: RepositoryToolbar.sync, in: controller).first == host(text("sync.quickFetch.tip")))
        controller.updateQuickToolbarItems(option: false)
    }

    /// 服务器仓库只显示图标时，主机前缀排在标签之前，按住 ⌥ 时同样如此；Push To 也不重复标签；
    /// Bookmarks 与储藏两段不加主机前缀。
    private static func expectServerIconOnlyTips(in controller: RepositoryWindowController) {
        let text = { (key: String) in AppLocalization.text(key) }
        let host = { (tip: String) in "spooky-test: " + tip }

        #expect(
            Self.tips(of: RepositoryToolbar.sync, in: controller).first
                == host(Self.labeledTip("sync.fetch", "sync.fetch.tip"))
        )
        #expect(
            Self.tips(of: RepositoryToolbar.quickActions, in: controller)
                == [host(Self.labeledTip("toolbar.quickActions", "toolbar.quickActions.tip"))]
        )
        #expect(Self.tips(of: RepositoryToolbar.pushTo, in: controller) == [host(text("toolbar.pushTo"))])
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
                == host(Self.labeledTip("sync.quickFetch", "sync.quickFetch.tip"))
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
