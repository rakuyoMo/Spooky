import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - DeleteKeyTests

/// 列表里的删除：单独的 ⌫ 不删除，只有 Edit › Delete（⌘⌫）打开删除确认。
@MainActor
struct DeleteKeyTests {
    /// 侧边栏拿到键盘焦点后，先按单独的 ⌫，再执行 Edit › Delete 的动作，只有后者打开删除确认；
    /// 分支整理列表的 Edit › Delete 作用于所选的分支。
    ///
    /// 测试进程里的窗口当不了 key window，菜单的快捷键到不了窗口，Edit › Delete 改为经第一响应者执行它的动作。
    @Test("列表只响应 ⌘⌫")
    func deleteOnlyFromEditMenu() async throws {
        let fixture = try await NavigationTests.makeWindow(commits: ["a", "b"])
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let runner = try #require(session.runner)
        let window = try #require(controller.window)
        let split = try #require(window.contentViewController as? NSSplitViewController)

        // 另建分支 topic
        _ = try await runner.run(["branch", "topic"])

        session.refresh(full: true)
        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }

        var requests = 0
        session.onReferenceRequest = { _ in requests += 1 }

        // 侧边栏：选中 topic
        session.activeView = .history
        session.history.selectedReferences = ["refs/heads/topic"]

        let outline = try #require(RepositorySidebarViewTests.outline(in: split.splitViewItems[0].viewController.view))

        try await Self.pressDeleteKeys(on: outline, in: window, count: { requests })

        // 分支整理与储藏列表的 ⌘⌫ 与侧边栏同一种接法；这里核对分支整理的对象：所选的分支，没有选中或选中当前分支时不可用
        let branches = session.history.branches.filter(\.isLocal)
        let items = branches.map { BranchesReviewItem(reference: $0, comparison: nil, condition: nil, pullRequest: nil) }
        let review = BranchesReviewListView(session: session) { _ in }
        var targets: [String] = []
        session.onReferenceRequest = { request in
            if case .deleteBranches(let references) = request {
                targets = references.map(\.name)
            }
        }

        session.branchesReview.selectedIDs = []
        #expect(review.deleteCommand(items) == nil)

        session.branchesReview.selectedIDs = ["refs/heads/main"]
        #expect(review.deleteCommand(items) == nil)

        session.branchesReview.selectedIDs = ["refs/heads/topic"]
        review.deleteCommand(items)?()
        #expect(targets == ["topic"])
    }
}

// MARK: - Helpers

extension DeleteKeyTests {
    /// 让列表成为第一响应者，单独的 ⌫ 之后计数不变，Edit › Delete 的动作之后计数加一。
    private static func pressDeleteKeys(
        on list: NSTableView,
        in window: NSWindow,
        count: @escaping () -> Int
    ) async throws {
        let before = count()

        #expect(window.makeFirstResponder(list))

        try RepositoryFocusTests.press(keyCode: 51, function: NSDeleteCharacter, in: window)
        await runLoopTurns(3)

        #expect(count() == before)

        #expect(window.firstResponder?.tryToPerform(#selector(NSText.delete(_:)), with: nil) ?? false)
        await until { count() > before }

        #expect(count() == before + 1)
    }
}
