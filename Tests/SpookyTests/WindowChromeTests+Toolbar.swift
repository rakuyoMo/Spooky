import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - Toolbar

extension WindowChromeTests {
    /// 显示文字时提示就是一句话；按住 ⌥ 时同步一组换成快速操作的提示，同样不带标签。
    @Test("显示文字时的工具栏提示")
    func labelModeTips() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        let saved = toolbar.displayMode

        defer {
            toolbar.displayMode = saved
            fixture.close()
        }

        let text = { (key: String) in AppLocalization.text(key) }

        toolbar.displayMode = .iconAndLabel
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
    @Test("只显示图标时的工具栏提示")
    func iconOnlyTips() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        let saved = toolbar.displayMode

        defer {
            toolbar.displayMode = saved
            fixture.close()
        }

        let text = { (key: String) in AppLocalization.text(key) }

        // 先切到显示文字再切回，提示随显示方式的变化重写
        toolbar.displayMode = .iconAndLabel
        toolbar.displayMode = .iconOnly
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
    @Test("只显示图标时按住 ⌥ 的工具栏提示")
    func iconOnlyQuickTips() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        let saved = toolbar.displayMode

        defer {
            toolbar.displayMode = saved
            fixture.close()
        }

        toolbar.displayMode = .iconOnly
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

    /// 服务器仓库里，按钮表里的按钮与同步一组的提示在最前面加主机前缀，只显示图标时排在标签之前；
    /// Push To 只显示图标时也不重复标签；Bookmarks、Prev / Next 与储藏两段不加主机前缀。
    @Test("服务器仓库的工具栏提示")
    func serverToolbarTips() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        let saved = toolbar.displayMode

        defer {
            toolbar.displayMode = saved
            fixture.close()
        }

        let text = { (key: String) in AppLocalization.text(key) }
        let host = { (tip: String) in "spooky-test: " + tip }

        // 窗口显示的是本机的工作区，会话换成同一目录的服务器仓库，只用来取主机别名
        controller.session.display(.remote(host: "spooky-test", path: fixture.directory.path))

        toolbar.displayMode = .iconAndLabel
        controller.updateToolbarItems()
        #expect(Self.tips(of: RepositoryToolbar.refresh, in: controller) == [host(text("action.refresh"))])
        #expect(Self.tips(of: RepositoryToolbar.sync, in: controller).first == host(text("sync.fetch.tip")))
        #expect(
            Self.tips(of: RepositoryToolbar.navigation, in: controller)
                == [text("navigation.back.tip"), text("navigation.forward.tip")]
        )

        controller.updateQuickToolbarItems(option: true)
        #expect(Self.tips(of: RepositoryToolbar.sync, in: controller).first == host(text("sync.quickFetch.tip")))
        controller.updateQuickToolbarItems(option: false)

        toolbar.displayMode = .iconOnly
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

    /// 服务器仓库的主机前缀在每种显示方式下只出现一次：显示标签时只由标签写出，只显示图标时只由视图写出；
    /// 标签一直写着主机前缀，溢出菜单里仍是可读的名字；自定义面板里的名字是 “Server”。
    @Test("服务器仓库的主机前缀只出现一次")
    func serverHostItem() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        let saved = toolbar.displayMode

        defer {
            toolbar.displayMode = saved
            fixture.close()
        }

        // 窗口显示的是本机的工作区，会话换成同一目录的服务器仓库，只用来取主机别名
        controller.session.display(.remote(host: "spooky-test", path: fixture.directory.path))
        controller.updateToolbarItems()

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

    /// 仓库管理入口叫 Bookmarks，Sync 在自定义面板里叫 Synchronize，后退 / 前进叫 Prev / Next，储藏两段叫 Apply / Save；
    /// 搜索框、父仓库、Bookmarks、新建分支与安全强推在窗口变窄时最后才进溢出菜单。
    @Test("工具栏的标签与可见优先级")
    func toolbarLabels() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let group = { (identifier: NSToolbarItem.Identifier) in
            Self.item(identifier, in: controller) as? NSToolbarItemGroup
        }

        let repositories = try #require(group(RepositoryToolbar.repositories))
        let navigation = try #require(group(RepositoryToolbar.navigation))
        let stashes = try #require(group(RepositoryToolbar.stashes))
        let synchronize = try #require(Self.item(RepositoryToolbar.synchronize, in: controller))
        let text = { (key: String) in AppLocalization.text(key) }

        #expect(repositories.subitems.map(\.label) == [text("toolbar.bookmarks")])
        #expect(repositories.paletteLabel == text("toolbar.bookmarks"))
        #expect(navigation.subitems.map(\.label) == [text("toolbar.previous"), text("toolbar.next")])
        #expect(stashes.subitems.map(\.label) == [text("toolbar.applyStash"), text("toolbar.saveStash")])
        #expect(synchronize.label == text("sync.sync"))
        #expect(synchronize.paletteLabel == text("toolbar.synchronize"))

        // 高优先级的五项，其余是标准优先级；工具栏里的搜索框读回的优先级随布局变化，取新建的一个
        let high: [NSToolbarItem.Identifier] = [
            RepositoryToolbar.parentRepository, RepositoryToolbar.repositories,
            RepositoryToolbar.createBranch, RepositoryToolbar.forcePush,
        ]

        for identifier in high {
            #expect(Self.item(identifier, in: controller)?.visibilityPriority == .high, "\(identifier.rawValue)")
        }

        let search = controller.makeSearchItem(RepositoryToolbar.search)
        #expect(search.visibilityPriority.rawValue >= NSToolbarItem.VisibilityPriority.high.rawValue)

        for identifier in [RepositoryToolbar.sync, RepositoryToolbar.refresh, RepositoryToolbar.finder] {
            #expect(Self.item(identifier, in: controller)?.visibilityPriority == .standard, "\(identifier.rawValue)")
        }

        // 英文的标签与提示
        let english = try #require(
            AppLocalization.bundle.url(forResource: "en", withExtension: "lproj").flatMap(Bundle.init(url:))
        )
        let expected = [
            "toolbar.bookmarks": "Bookmarks",
            "toolbar.bookmarks.tip": "Navigates to Bookmarks view",
            "toolbar.previous": "Prev",
            "toolbar.next": "Next",
            "navigation.back.tip": "Navigates to the previous view",
            "navigation.forward.tip": "Navigates to the next view",
            "toolbar.synchronize": "Synchronize",
            "toolbar.applyStash": "Apply",
            "toolbar.saveStash": "Save",
            "toolbar.applyStash.tip": "Reapplies changes to your working copy",
            "toolbar.saveStash.tip": "Stores your local changes on the Stash",
            "toolbar.quickActions.tip": "Shows Quick Actions",
            "toolbar.createBranch.tip": "Create a new branch",
            "toolbar.forcePush.tip": "Push using force-push with lease",
            "toolbar.parentRepository.tip": "Go to parent repository",
            "toolbar.labeledTip": "%1$@: %2$@",
            "sync.fetch.tip": "Fetches remotes",
            "sync.pull.tip": "Pulls remote branches",
            "sync.push.tip": "Pushes local branches to remotes",
            "sync.sync.tip": "Sync HEAD with a remote branch",
            "sync.merge.tip": "Merges another branch into the HEAD branch",
            "sync.rebaseHead.tip": "Rebases the current HEAD branch onto another branch",
            "sync.quickFetch.tip": "Immediately fetches remotes",
            "sync.quickPull.tip": "Pulls the tracking remote branch",
            "sync.quickPush.tip": "Pushes the HEAD branch to its tracking branch",
            "sync.quickSync.tip": "Syncs the HEAD branch with its tracking branch",
            "sync.quickMerge.tip": "Merges the tracking branch of the current HEAD branch",
            "sync.quickRebase.tip": "Rebases the current HEAD branch onto its tracking branch",
        ]

        for (key, value) in expected {
            #expect(english.localizedString(forKey: key, value: nil, table: nil) == value, "\(key)")
        }
    }

    /// Fetch | Pull | Push 三段依次用获取、拉取、推送的自绘图标，Push To 与 Force Push 用加了角标的推送图标；
    /// 五张都是随 App 打包、@1x 与 @2x 齐全的 18 pt 模板图，像素两两不同，也与 Clone 的 `arrow.down.circle` 不同，
    /// 几个按钮一眼认得出来。
    @Test("Fetch、Pull、Push、Push To 与 Force Push 的图标")
    func transferIcons() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let sync = try #require(Self.item(RepositoryToolbar.sync, in: controller) as? NSToolbarItemGroup)
        let pushTo = try #require(Self.item(RepositoryToolbar.pushTo, in: controller))
        let forcePush = try #require(Self.item(RepositoryToolbar.forcePush, in: controller))
        let clone = try #require(Self.item(RepositoryToolbar.clone, in: controller))
        let transfers: [ActivityTransfer] = [.fetch, .pull, .push]

        #expect(sync.subitems.count == transfers.count)

        for (segment, transfer) in zip(sync.subitems, transfers) {
            #expect(segment.image === TransferIcon.image(for: transfer))
        }

        #expect(pushTo.image === TransferIcon.pushTo)
        #expect(forcePush.image === TransferIcon.forcePush)

        // 五张传输图标都是 @1x 与 @2x 齐全的 18 pt 模板图
        let icons = transfers.map { TransferIcon.image(for: $0) } + [TransferIcon.pushTo, TransferIcon.forcePush]

        for icon in icons {
            #expect(icon.isTemplate)
            #expect(icon.size == NSSize(width: 18, height: 18))
            #expect(icon.representations.count == 2)
        }

        // 五个按钮与 Clone 的图按像素比较，六张都不一样
        let images = sync.subitems.map(\.image) + [pushTo.image, forcePush.image, clone.image]
        #expect(Set(images.compactMap { $0?.tiffRepresentation }).count == 6)
    }

    /// 只显示图标时，有内层分栏的视图在侧边栏分隔符之后有一个跟随内层分隔线的分隔符；
    /// 单栏视图、仓库管理与显示文字时隐藏，留在工具栏里不删。
    @Test("跟随内层分栏的分隔符")
    func detailSeparator() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        let saved = toolbar.displayMode

        defer {
            toolbar.displayMode = saved
            fixture.close()
        }

        toolbar.displayMode = .iconOnly
        controller.showWorkingCopy()

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
        #expect(!separator.isHidden)
        #expect(separator.splitView === controller.innerSplit?.splitView)

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

    /// 有内层分栏的视图里，左侧的列表不延伸到工具栏下面：显示文字时，列表的底色与分隔线不穿过工具栏上的项。
    @Test("内层分栏的列表不延伸到工具栏下面")
    func innerListBelowToolbar() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session

        let views: [(name: String, show: () -> Void)] = [
            ("Working Copy", controller.showWorkingCopy),
            ("History", controller.showHistory),
            ("Commit", controller.showCommitPage),
            ("Stashes", controller.showStashes),
            ("Reflog", controller.showReflog),
            ("Branches Review", controller.showBranchesReview),
            ("Pull Requests", controller.showPullRequests),
            ("File History", { session.showFileHistory("a.txt") }),
        ]

        for view in views {
            view.show()

            let list = try #require(controller.innerSplit?.splitViewItems.first, "\(view.name)")
            #expect(!list.allowsFullHeightLayout, "\(view.name)")
        }
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
