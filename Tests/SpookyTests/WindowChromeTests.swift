import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - WindowChromeTests

/// 仓库窗口的工具栏、窗口标题、标签页、侧边栏的首次宽度与启动窗口。
@MainActor
struct WindowChromeTests {
    /// 同一个仓库窗口依次核对：工具栏的排布、旧排布里的关闭仓库、标签、可见优先级与图标；刷新进行中 Refresh 照常可用；
    /// 隐藏与显示窗口标题；主机前缀与仓库管理入口的状态；新标签与显式新窗口。
    @Test("工具栏、刷新中的 Refresh、窗口标题与标签页")
    func toolbarItems() async throws {
        let fixture = try await NavigationTests.makeWindow()

        // 隐藏窗口标题是所有仓库窗口共用的标准偏好，测完恢复
        let savedTitle = UserDefaults.standard.object(forKey: RepositoryWindowController.hidesTitleKey)

        defer {
            UserDefaults.standard.set(savedTitle, forKey: RepositoryWindowController.hidesTitleKey)
            fixture.close()
        }

        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)

        // 各项的排布、标签、可见优先级与图标在窗口显示仓库时核对
        try Self.expectToolbarLayout(in: controller)
        Self.expectSavedCloseRepositoryDropped(in: fixture)
        try Self.expectToolbarLabels(in: controller)
        try Self.expectTransferIcons(in: controller)

        // 刷新进行中，工具栏的 Refresh 与 View › Refresh（⌘R）照常可用
        let refresh = NSMenuItem(
            title: "",
            action: #selector(RepositoryWindowController.refreshRepository),
            keyEquivalent: ""
        )

        controller.session.refresh(full: true)
        #expect(controller.session.isRefreshing)
        #expect(controller.validateUserInterfaceItem(refresh))

        await controller.session.waitForRefresh()

        Self.expectWindowTitle(in: controller)

        // 本机仓库隐藏主机前缀，仓库管理入口只在显示仓库管理时选中
        let host = try #require(toolbar.items.first { $0.itemIdentifier == RepositoryToolbar.host })

        let repositories = try #require(
            toolbar.items.first { $0.itemIdentifier == RepositoryToolbar.repositories } as? NSToolbarItemGroup
        )

        #expect(host.isHidden)
        #expect(!repositories.isSelected(at: 0))

        controller.showRepositories()
        #expect(repositories.isSelected(at: 0))

        try Self.expectTabs(after: fixture)
    }

    /// 还没有记下侧边栏宽度与窗口尺寸时，仓库视图的侧边栏宽 428 pt，仓库管理宽 260 pt。
    @Test("侧边栏的首次宽度")
    func defaultSidebarWidths() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        defer { fixture.close() }

        // 分栏宽度与窗口尺寸都记在标准偏好里，其它测试的窗口记下的窄窗口会挤窄侧边栏；
        // 从删掉记录到放回整段同步执行，其它测试的窗口插不进来改写
        let keys = ["Spooky.Repositories", "Spooky.Repository"].map { "NSSplitView Subview Frames " + $0 }
            + ["NSWindow Frame Spooky.RepositoryWindow"]

        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        let controller = RepositoryWindowController(coordinator: fixture.coordinator)

        // 宽度取分栏里侧边栏一栏的右缘，即分隔线的位置：有的系统版本把侧边栏的内容缩进几 pt，内容视图比这一栏窄
        let sidebarWidth = {
            (controller.window?.contentViewController as? NSSplitViewController)?
                .splitView.arrangedSubviews.first?.frame.maxX
        }

        let managerWidth = sidebarWidth()
        controller.display(fixture.location)
        let repositoryWidth = sidebarWidth()

        controller.session.close()
        controller.window?.close()

        for (key, value) in zip(keys, saved) {
            UserDefaults.standard.set(value, forKey: key)
        }

        #expect(managerWidth == 260)
        #expect(repositoryWidth == 428)
    }

    /// 启动窗口 600 × 450、没有标题栏、不能全屏；打开的仓库窗口成为主窗口后它自己关闭。
    @Test("启动窗口")
    func launchWindow() async throws {
        let fixture = try await NavigationTests.makeCoordinator()
        defer { fixture.close() }

        LaunchWindowController.show(coordinator: fixture.coordinator)
        let launch = try #require(LaunchWindowController.shown?.window)
        defer { launch.close() }

        #expect(launch.contentRect(forFrameRect: launch.frame).size == LaunchWindowController.size)
        #expect(!launch.styleMask.contains(.titled))
        #expect(launch.collectionBehavior.contains(.fullScreenNone))
        #expect(launch.isMovableByWindowBackground)
        #expect(launch.canBecomeKey && launch.canBecomeMain)

        // 再次显示只带到前面，不另开一个
        LaunchWindowController.show(coordinator: fixture.coordinator)
        #expect(LaunchWindowController.shown?.window === launch)

        // 启动窗口只看成为主窗口的是不是仓库窗口：仓库窗口不必显示，通知由测试发出
        let repository = fixture.coordinator.makeWindow()
        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: repository.window)
        await until { LaunchWindowController.shown == nil }
        #expect(!launch.isVisible)
    }
}

// MARK: - Steps

extension WindowChromeTests {
    /// 工具栏只放有行为的项：默认排布与可选项都能创建，按钮的动作都有响应者，主机前缀不能被移除；
    /// 跟随内层分栏的分隔符由窗口按需插入，不在自定义面板里，也不能被移除。
    private static func expectToolbarLayout(in controller: RepositoryWindowController) throws {
        let toolbar = try #require(controller.window?.toolbar)
        let identifiers = toolbar.items.map(\.itemIdentifier)
        let immovable = controller.toolbarImmovableItemIdentifiers(toolbar)

        #expect(toolbar.identifier == RepositoryToolbar.identifier)
        #expect(toolbar.allowsUserCustomization && toolbar.autosavesConfiguration)
        #expect(identifiers.filter { $0 != RepositoryToolbar.detailSeparator } == RepositoryToolbar.defaultItems)
        #expect(Set(RepositoryToolbar.defaultItems).isSubset(of: RepositoryToolbar.allowedItems))
        #expect(immovable.contains(RepositoryToolbar.host))
        #expect(!RepositoryToolbar.allowedItems.contains(RepositoryToolbar.detailSeparator))
        #expect(immovable.contains(RepositoryToolbar.detailSeparator))

        // 自定义面板里的每一项都能创建，每个按钮或分段的动作都由窗口响应
        let system: Set<NSToolbarItem.Identifier> = [.space, .flexibleSpace]

        for identifier in RepositoryToolbar.allowedItems where !system.contains(identifier) {
            let item = try #require(
                controller.toolbar(toolbar, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: false),
                "无法创建工具栏项：\(identifier.rawValue)"
            )

            for subitem in (item as? NSToolbarItemGroup)?.subitems ?? [item] {
                guard let action = subitem.action else {
                    continue
                }

                #expect(controller.responds(to: action), "没有响应者：\(identifier.rawValue)")
            }
        }

        // 全部暂存、提交与关闭仓库只在主菜单里；以前保存的配置里留着这几个标识时创建不出项，由系统跳过
        let menuOnly = ["stageAll", "commit", "closeRepository"].map { NSToolbarItem.Identifier($0) }

        for identifier in menuOnly {
            #expect(!RepositoryToolbar.allowedItems.contains(identifier))

            #expect(
                controller.toolbar(toolbar, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: false) == nil
            )
        }
    }

    /// 以前保存的排布里有关闭仓库一项：按这份排布建出的工具栏载入后没有它，其余保存的项照旧；
    /// 显示仓库的窗口里 File › Close Repository 仍然可用。
    private static func expectSavedCloseRepositoryDropped(in fixture: NavigationTests.WindowFixture) {
        let identifier = "spooky-saved-toolbar-" + UUID().uuidString
        let key = "NSToolbar Configuration " + identifier
        let saved = [RepositoryToolbar.refresh.rawValue, "closeRepository", RepositoryToolbar.search.rawValue]

        UserDefaults.standard.set(["TB Item Identifiers": saved], forKey: key)

        let controller = RepositoryWindowController(
            coordinator: fixture.coordinator,
            toolbarIdentifier: NSToolbar.Identifier(identifier)
        )

        defer {
            controller.session.close()
            controller.window?.close()
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 父仓库与跟随内层分栏的分隔符由窗口补进来，不来自保存的排布
        let added: Set<NSToolbarItem.Identifier> = [
            RepositoryToolbar.parentRepository,
            RepositoryToolbar.detailSeparator,
        ]

        let identifiers = controller.window?.toolbar?.items.map(\.itemIdentifier) ?? []
        #expect(identifiers.filter { !added.contains($0) } == [RepositoryToolbar.refresh, RepositoryToolbar.search])

        // 关闭仓库只留在 File 菜单里，显示仓库时照常可用
        let close = NSMenuItem(
            title: "",
            action: #selector(RepositoryWindowController.closeRepository),
            keyEquivalent: ""
        )

        #expect(fixture.controller.validateUserInterfaceItem(close))
    }

    /// 仓库管理入口叫 Bookmarks，Sync 在自定义面板里叫 Synchronize，后退 / 前进叫 Prev / Next，储藏两段叫 Apply / Save；
    /// 搜索框、父仓库、Bookmarks、新建分支与安全强推在窗口变窄时最后才进溢出菜单。
    private static func expectToolbarLabels(in controller: RepositoryWindowController) throws {
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
    }

    /// 隐藏窗口标题是所有仓库窗口共用的偏好，隐藏时一并去掉仓库目录图标，菜单项的标题随状态切换。
    private static func expectWindowTitle(in controller: RepositoryWindowController) {
        let item = NSMenuItem(
            title: "",
            action: #selector(RepositoryWindowController.toggleWindowTitle),
            keyEquivalent: ""
        )

        UserDefaults.standard.set(false, forKey: RepositoryWindowController.hidesTitleKey)
        controller.applyTitleVisibility()

        #expect(controller.window?.titleVisibility == .visible)
        #expect(controller.window?.representedURL != nil)

        controller.toggleWindowTitle()

        #expect(controller.window?.titleVisibility == .hidden)
        #expect(controller.window?.representedURL == nil)
        #expect(controller.validateUserInterfaceItem(item))
        #expect(item.title == AppLocalization.text("menu.showWindowTitle"))

        controller.toggleWindowTitle()

        #expect(controller.window?.titleVisibility == .visible)
        #expect(controller.validateUserInterfaceItem(item))
        #expect(item.title == AppLocalization.text("menu.hideWindowTitle"))
    }

    /// 新标签加在发起窗口的标签组里；显式新窗口即使窗口偏好成为标签也保持独立，显示后仍可手动合并。
    private static func expectTabs(after fixture: NavigationTests.WindowFixture) throws {
        let coordinator = fixture.coordinator
        let source = try #require(fixture.controller.window)

        try #require(NSWindow.allowsAutomaticWindowTabbing)
        coordinator.openTab(after: fixture.controller)

        let tab = try #require(coordinator.windows.last?.window)
        #expect(source.tabGroup?.windows.contains(tab) ?? false)
        #expect(tab.windowController is RepositoryWindowController)

        // 偏好成为标签的窗口经 “显式新窗口” 显示时不并进已有的标签组
        let separate = coordinator.makeWindow()
        separate.window?.tabbingMode = .preferred

        coordinator.showSeparately(separate) {
            separate.showWindow(nil)
        }

        let window = try #require(separate.window)
        #expect(!(source.tabGroup?.windows.contains(window) ?? false))
        #expect(window.tabbingMode == .automatic)
    }

    /// Fetch | Pull | Push 三段依次用获取、拉取、推送的自绘图标，Push To 与 Force Push 用加了角标的推送图标；
    /// 五张都是随 App 打包、@1x 与 @2x 齐全的 18 pt 模板图，像素两两不同，也与 Clone 的 `arrow.down.circle` 不同，
    /// 几个按钮一眼认得出来。
    private static func expectTransferIcons(in controller: RepositoryWindowController) throws {
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
}
