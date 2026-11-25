import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Layout

extension WindowChromeTests {
    /// 同一个仓库窗口依次核对：收窄后换成极窄版式，列表与详情上下排列，换主视图时视图导航留着；
    /// 拉宽后回到常规版式，分栏随窗口变宽回到收窄前的宽度；来回切换时所在的视图、选中的文件与提交草稿都不变。
    @Test("极窄版式的切换、视图导航与分栏宽度的恢复")
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

        // 收窄：侧边栏换成视图导航，列表与详情上下排列，跟随内层分栏的分隔符隐藏
        window.setContentSize(NSSize(width: 500, height: 700))

        let content = try #require(controller.narrowContent)

        #expect(controller.layout == .narrow)
        #expect(window.contentViewController === content)
        #expect(controller.outerSplit == nil)
        #expect(try isStacked())
        #expect(Self.item(RepositoryToolbar.detailSeparator, in: controller)?.isHidden ?? true)
        #expect(session.activeView == .workingCopy)
        #expect(session.selectedIDs == [row])
        #expect(session.commitSubject == "draft")

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
}
