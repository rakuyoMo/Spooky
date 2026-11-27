import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Layout

extension WindowChromeTests {
    /// 同一个仓库窗口依次核对：收窄后换成极窄版式，列表与详情上下排列，工具栏的仓库管理与 Clone 排到标题之前，
    /// 换主视图时视图导航留着；拉宽后回到常规版式，分栏随窗口变宽回到收窄前的宽度；
    /// 来回切换时所在的视图、选中的文件与提交草稿都不变。
    @Test("极窄版式的切换、工具栏、视图导航与分栏宽度的恢复")
    func narrowLayout() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let window = try #require(controller.window)

        /// 窗口排版后，外层分栏与当前内层分栏首栏的宽度。
        func firstWidths() -> [CGFloat?] {
            window.layoutIfNeeded()

            return [controller.outerSplit, controller.innerSplit].map {
                $0?.splitViewItems.first?.viewController.view.frame.width
            }
        }

        /// 当前主视图的列表与详情是否上下排列。
        func isStacked() throws -> Bool {
            try !#require(controller.innerSplit).splitView.isVertical
        }

        // 窗口尺寸记在所有仓库窗口共用的标准偏好里；本窗口不再保存，别的测试的窗口不会恢复成收窄后的宽度
        window.setFrameAutosaveName("")
        window.setContentSize(NSSize(width: 1200, height: 700))

        // 常规版式：选中一个改动的文件，写下草稿，定好侧边栏与文件列表的宽度
        try "changed\n".write(to: fixture.directory.appending(path: "a.txt"), atomically: true, encoding: .utf8)
        session.refresh(full: true)
        await session.waitForRefresh()

        let entry = try #require(session.status?.entries.first)
        let row = StatusRowID(path: entry.path, kind: entry.kind)

        controller.showWorkingCopy()
        session.selectedIDs = [row]
        session.commitSubject = "draft"

        try #require(controller.outerSplit).splitView.setPosition(400, ofDividerAt: 0)
        try #require(controller.innerSplit).splitView.setPosition(400, ofDividerAt: 0)

        #expect(controller.layout == .regular)
        #expect(try !isStacked())
        #expect(firstWidths() == [400, 400])

        // 收到最窄：侧边栏换成视图导航，列表与详情上下排列，跟随内层分栏的分隔符隐藏
        window.setContentSize(NSSize(width: RepositoryWindowLayout.narrowMinimumWidth, height: 700))

        let content = try #require(controller.narrowContent)

        #expect(controller.layout == .narrow)
        #expect(window.contentViewController === content)
        #expect(controller.outerSplit == nil)
        #expect(try isStacked())
        #expect(Self.item(RepositoryToolbar.detailSeparator, in: controller)?.isHidden ?? true)
        #expect(session.activeView == .workingCopy)
        #expect(session.selectedIDs == [row])
        #expect(session.commitSubject == "draft")

        try Self.expectNarrowToolbar(in: controller)

        // 极窄版式里换主视图只替换下面的一块，盖在上面的侧边栏留着；单栏视图没有内层分栏
        controller.setCompactSidebarShown(true)
        controller.showHistory()
        #expect(controller.narrowContent === content)
        #expect(content.showsSidebar)
        #expect(try isStacked())

        // 点按遮罩收起侧边栏
        content.onDismissSidebar?()
        #expect(!content.showsSidebar)
        #expect(!controller.compactNavigation.showsSidebar)

        controller.showStashes()
        #expect(controller.narrowContent === content)
        #expect(try isStacked())

        controller.showRepositorySettings()
        #expect(controller.narrowContent === content)
        #expect(controller.innerSplit == nil)

        // 拉宽到刚过界线：回到常规版式，侧边栏先回到收窄前的宽度，文件列表还放不下
        controller.showWorkingCopy()
        window.setContentSize(NSSize(width: 840, height: 700))

        #expect(controller.layout == .regular)
        #expect(controller.narrowContent == nil)
        #expect(try !isStacked())

        // 仓库管理与 Clone 回到侧边栏上方
        #expect(try !#require(Self.item(RepositoryToolbar.repositories, in: controller)).isNavigational)
        #expect(try !#require(Self.item(RepositoryToolbar.clone, in: controller)).isNavigational)

        let squeezed = firstWidths()
        #expect(squeezed.first == 400)
        #expect((squeezed.last ?? 0) ?? 0 < 400)

        // 再拉宽：文件列表也回到收窄前的宽度
        window.setContentSize(NSSize(width: 1200, height: 700))

        #expect(firstWidths() == [400, 400])
        #expect(session.activeView == .workingCopy)
        #expect(session.selectedIDs == [row])
        #expect(session.commitSubject == "draft")
    }

    /// 同一个仓库窗口依次核对：仓库管理收窄后书签列表与详情上下排列，用的还是同一份列表与详情，拉宽后回到左右分栏；
    /// View › Window Layout 固定版式后不再看宽度，同一协调者的其它仓库窗口一起重排，选回自动后重新按宽度取。
    @Test("仓库管理的极窄版式与固定的版式")
    func managerLayoutAndPinnedMode() async throws {
        let fixture = try await NavigationTests.makeWindow(isolatesToolbar: true)

        // 取版式的方式是所有仓库窗口共用的标准偏好，测完恢复；固定版式之后到恢复之前不等待，别的测试的窗口读不到它
        let savedMode = UserDefaults.standard.object(forKey: RepositoryWindowLayoutMode.key)

        defer {
            UserDefaults.standard.set(savedMode, forKey: RepositoryWindowLayoutMode.key)
            fixture.close()
        }

        let controller = fixture.controller
        let window = try #require(controller.window)

        /// 选中 View › Window Layout 里的一项，返回这一项。
        func choose(_ mode: RepositoryWindowLayoutMode) -> NSMenuItem {
            let item = NSMenuItem(
                title: "",
                action: #selector(RepositoryWindowController.setLayoutMode(_:)),
                keyEquivalent: ""
            )
            item.tag = mode.rawValue
            controller.setLayoutMode(item)
            return item
        }

        UserDefaults.standard.removeObject(forKey: RepositoryWindowLayoutMode.key)
        window.setFrameAutosaveName("")
        window.setContentSize(NSSize(width: 1200, height: 700))

        // 仓库管理的常规版式：书签列表是左边的侧边栏
        controller.showRepositories()

        let regular = try #require(controller.outerSplit)
        let parts = regular.splitViewItems.map(\.viewController)

        #expect(controller.layout == .regular)
        #expect(regular.splitView.isVertical)
        #expect(parts.first is BookmarkSidebarController)

        // 收窄：同一份书签列表与详情改成上下排列，侧边栏分隔符隐藏
        window.setContentSize(NSSize(width: 500, height: 700))

        let stacked = try #require(controller.outerSplit)

        #expect(controller.layout == .narrow)
        #expect(!stacked.splitView.isVertical)
        #expect(stacked.splitViewItems.map(\.viewController) == parts)

        // 换下的分栏不再保存，否则各栏取走之后它会把记着的侧边栏宽度写成空记录
        #expect(regular.splitView.autosaveName == nil)
        #expect(stacked.splitView.autosaveName != nil)
        #expect(Self.item(RepositoryToolbar.sidebarSeparator, in: controller)?.isHidden ?? true)

        // 拉宽：回到左右分栏
        window.setContentSize(NSSize(width: 1200, height: 700))

        #expect(controller.layout == .regular)
        #expect(controller.outerSplit?.splitView.isVertical ?? false)
        #expect(controller.outerSplit?.splitViewItems.map(\.viewController) == parts)

        // 固定窄版：宽窗口里的仓库管理、仓库视图与同一协调者的另一个窗口都排成极窄版式，菜单里这一项打勾
        let other = fixture.coordinator.makeWindow()
        defer { other.close() }

        let narrow = choose(.narrow)

        #expect(controller.layout == .narrow)
        #expect(!(controller.outerSplit?.splitView.isVertical ?? true))
        #expect(other.layout == .narrow)
        #expect(controller.validateUserInterfaceItem(narrow))
        #expect(narrow.state == .on)

        controller.showWorkingCopy()
        #expect(controller.narrowContent != nil)

        // 固定宽版：窄窗口里也是常规版式，菜单里的勾换到这一项
        let wide = choose(.regular)

        #expect(controller.layout == .regular)
        #expect(controller.narrowContent == nil)
        #expect(controller.validateUserInterfaceItem(narrow))
        #expect(controller.validateUserInterfaceItem(wide))
        #expect(narrow.state == .off)
        #expect(wide.state == .on)

        window.setContentSize(NSSize(width: 500, height: 700))

        #expect(controller.layout == .regular)
        #expect(other.layout == .regular)

        // 选回自动：重新按内容区的宽度取，窄的窗口换成极窄版式，宽的那个不变
        _ = choose(.automatic)

        #expect(controller.layout == .narrow)
        #expect(other.layout == .regular)
    }
}

// MARK: - Helpers

extension WindowChromeTests {
    /// 收到最窄的极窄版式工具栏：仓库管理与 Clone 随后退 / 前进排在标题之前，仓库管理、后退 / 前进与搜索框仍在工具栏上；
    /// 标题之后的其余各项排不下时都进溢出菜单，Fetch | Pull | Push 在其中最后才进。
    private static func expectNarrowToolbar(in controller: RepositoryWindowController) throws {
        let window = try #require(controller.window)
        window.layoutIfNeeded()

        let visible = Set(window.toolbar?.visibleItems?.map(\.itemIdentifier) ?? [])

        /// 一项的可见优先级。
        func priority(_ identifier: NSToolbarItem.Identifier) throws -> Int {
            try #require(item(identifier, in: controller)).visibilityPriority.rawValue
        }

        let sync = try priority(RepositoryToolbar.sync)

        let others = try [
            RepositoryToolbar.finder,
            RepositoryToolbar.terminal,
            RepositoryToolbar.forcePush,
            RepositoryToolbar.stashes,
            RepositoryToolbar.createBranch,
            RepositoryToolbar.refresh,
        ].map(priority)

        #expect(try #require(item(RepositoryToolbar.repositories, in: controller)).isNavigational)
        #expect(try #require(item(RepositoryToolbar.clone, in: controller)).isNavigational)
        #expect(visible.isSuperset(of: [RepositoryToolbar.repositories, RepositoryToolbar.navigation, RepositoryToolbar.search]))
        #expect(others.allSatisfy { $0 < sync })
    }
}
