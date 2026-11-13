import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryFocusTests

/// 仓库窗口里的键盘焦点：打开仓库时在侧边栏，点选哪个列表就交给哪个列表，刷新与读取不把它拉回侧边栏。
@MainActor
struct RepositoryFocusTests {
    /// 打开仓库后焦点在侧边栏；历史列表有焦点时，↓ 移动的是历史的选中，侧边栏的选中不变；之后的刷新与提交详情的读取都不改变焦点。
    ///
    /// 点击时交给哪个列表经 `RepositoryWindow.unfocusedList(at:)` 核对，点击本身不在这里核对：测试进程里的窗口当不了 key window，窗口不把点击交给视图；表格的跟踪循环会从窗口服务器拉取事件，
    /// 之后到来的事件会停下测试进程的主 run loop，整个进程随之退出。这里照点击的结果让表格成为第一响应者并选中一行。
    @Test("方向键跟着键盘焦点走")
    func arrowKeysFollowFocus() async throws {
        let fixture = try await NavigationTests.makeWindow(commits: ["a", "b", "c"])
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let history = session.history
        let window = try #require(controller.window)
        let root = try #require(window.contentView)

        // 打开仓库后焦点在侧边栏
        root.layoutSubtreeIfNeeded()

        let split = try #require(window.contentViewController as? NSSplitViewController)
        let outline = try #require(RepositorySidebarViewTests.outline(in: split.splitViewItems[0].viewController.view))
        #expect(window.firstResponder === outline)

        controller.showHistory()
        await untilFinished { history.activeTasks }

        let table = try #require(await Self.commitTable(in: root, rows: 3))
        let sidebarRow = outline.selectedRow
        #expect(window.firstResponder === outline)

        // 点在已有焦点的侧边栏里不动，点在历史列表里先把焦点交给表格
        let repositoryWindow = try #require(window as? RepositoryWindow)
        #expect(repositoryWindow.unfocusedList(at: Self.center(of: outline)) == nil)
        #expect(repositoryWindow.unfocusedList(at: Self.center(of: table)) === table)

        // 点选第二个提交的结果：表格拿到焦点，选中这一行
        #expect(window.makeFirstResponder(table))

        // 历史默认按月分组，第二个提交前面还有一行分组标题
        let second = try #require(history.row(of: history.commits[1].id))
        table.selectRowIndexes([second], byExtendingSelection: false)

        #expect(history.selectedIDs == [history.commits[1].id])

        // ↓ 移到第三个提交，侧边栏的选中与主视图不变
        try Self.press(keyCode: 125, function: NSDownArrowFunctionKey, in: window)

        #expect(history.selectedIDs == [history.commits[2].id])
        #expect(outline.selectedRow == sidebarRow)
        #expect(session.activeView == .history)

        // 提交详情读完、刷新读完，焦点都还在表格
        await untilFinished { history.activeTasks }
        await runLoopTurns(3) { root.layoutSubtreeIfNeeded() }
        #expect(window.firstResponder === table)

        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }
        await runLoopTurns(3) { root.layoutSubtreeIfNeeded() }
        #expect(window.firstResponder === table)

        // 再点回侧边栏时焦点交还给它
        #expect(repositoryWindow.unfocusedList(at: Self.center(of: outline)) === outline)
    }
}

// MARK: - Helpers

extension RepositoryFocusTests {
    /// 视图可见部分的中心，窗口坐标。
    static func center(of view: NSView) -> NSPoint {
        view.convert(NSPoint(x: view.visibleRect.midX, y: view.visibleRect.midY), to: nil)
    }

    /// 等历史列表排出至少 `rows` 行后取出表格。
    static func commitTable(in root: NSView, rows: Int) async -> NSTableView? {
        var found: NSTableView? = nil

        await until {
            root.layoutSubtreeIfNeeded()
            found = HistoryListTests.commitTable(in: root)

            return (found?.numberOfRows ?? 0) >= rows
        }

        return found
    }

    /// 经窗口按下一个功能键，交给当前的第一响应者。
    static func press(keyCode: UInt16, function: Int, in window: NSWindow) throws {
        let characters = String(Character(try #require(UnicodeScalar(function))))

        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ))

        window.sendEvent(event)
    }
}
