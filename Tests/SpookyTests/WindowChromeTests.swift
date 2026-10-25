import AppKit
import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

/// 仓库窗口的工具栏、窗口标题、标签页与启动窗口。
@MainActor
struct WindowChromeTests {
    /// 工具栏只放有行为的项：默认排布与可选项都能创建，按钮的动作都有响应者，主机前缀不能被移除。
    @Test("工具栏的默认排布与可选项")
    func toolbarItems() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let toolbar = try #require(controller.window?.toolbar)
        #expect(toolbar.identifier == RepositoryToolbar.identifier)
        #expect(toolbar.allowsUserCustomization && toolbar.autosavesConfiguration)
        #expect(toolbar.items.map(\.itemIdentifier) == RepositoryToolbar.defaultItems)
        #expect(Set(RepositoryToolbar.defaultItems).isSubset(of: RepositoryToolbar.allowedItems))
        #expect(controller.toolbarImmovableItemIdentifiers(toolbar).contains(RepositoryToolbar.host))

        // 自定义面板里的每一项都能创建，每个按钮或分段的动作都由窗口响应
        let system: Set<NSToolbarItem.Identifier> = [.space, .flexibleSpace]

        // Gerrit Push 只在开启 Gerrit 推送后出现在面板里，同样要能创建
        for identifier in RepositoryToolbar.allowedItems + [RepositoryToolbar.gerritPush] where !system.contains(identifier) {
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

        // 本机仓库隐藏主机前缀，仓库管理入口只在显示仓库管理时选中
        let host = try #require(toolbar.items.first { $0.itemIdentifier == RepositoryToolbar.host })
        let repositories = try #require(
            toolbar.items.first { $0.itemIdentifier == RepositoryToolbar.repositories } as? NSToolbarItemGroup
        )
        #expect(host.isHidden)
        #expect(!repositories.isSelected(at: 0))

        controller.showRepositories()
        #expect(repositories.isSelected(at: 0))
    }

    /// 隐藏窗口标题是所有仓库窗口共用的偏好，菜单项的标题随状态切换。
    @Test("隐藏与显示窗口标题")
    func windowTitle() async throws {
        let fixture = try await NavigationTests.makeWindow()
        let saved = UserDefaults.standard.object(forKey: RepositoryWindowController.hidesTitleKey)

        defer {
            UserDefaults.standard.set(saved, forKey: RepositoryWindowController.hidesTitleKey)
            fixture.close()
        }

        let controller = fixture.controller
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
    @Test("新标签与显式新窗口")
    func tabs() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

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

    /// 启动窗口 600 × 450、没有标题栏、不能全屏；打开的仓库窗口成为主窗口后它自己关闭。
    @Test("启动窗口")
    func launchWindow() async throws {
        let fixture = try await NavigationTests.makeWindow()
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

        NotificationCenter.default.post(name: NSWindow.didBecomeMainNotification, object: fixture.controller.window)
        try await FileViewsTests.wait { LaunchWindowController.shown == nil }
        #expect(!launch.isVisible)
    }
}
