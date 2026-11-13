import AppKit
import Foundation
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ContextMenu

extension HistoryListTests {
    /// 读完第一页时选中列表的第一个提交；右键点在选区外只作用于被点的提交，点在选区内作用于整个选区，两种情况选区都不变。
    /// 单个提交的菜单在两项复制后是 Reveal in History：看全部历史时不可用，只看一个分支时可用，执行后回到全部历史并选中它。
    @Test("历史右键的作用对象与 Reveal in History")
    func contextMenuTargets() async throws {
        let fixture = try await Self.makeSession(commits: ["a", "b", "c"])
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history
        let commits = history.commits

        // 第一页读完后选中最新的提交，详情跟着显示
        #expect(history.selectedIDs == [commits[0].id])

        let coordinator = HistoryCommitTable(
            session: session,
            showGraph: false,
            smallRows: false,
            dateFormat: .absolute,
            createBranch: { _ in },
            openCommit: { }
        ).makeCoordinator()

        history.selectedIDs = [commits[0].id, commits[1].id]

        // 选区外右键：只作用于被点的提交，单个提交的标题，看全部历史时 Reveal 不可用
        let outside = NSMenu()
        coordinator.buildMenu(outside, clickedRow: try #require(history.row(of: commits[2].id)))

        #expect(Array(outside.items.prefix(3).map(\.title)) == [
            AppLocalization.text("history.copyHash"),
            AppLocalization.text("history.copyInfo"),
            AppLocalization.text("quickActions.revealInHistory"),
        ])

        #expect(!outside.items[2].isEnabled)
        #expect(outside.items[3].isSeparatorItem)
        #expect(history.selectedIDs == [commits[0].id, commits[1].id])

        // 选区内右键：作用于两个提交，没有 Reveal
        let inside = NSMenu()
        coordinator.buildMenu(inside, clickedRow: try #require(history.row(of: commits[0].id)))

        #expect(Array(inside.items.prefix(3).map(\.title)) == [
            AppLocalization.text("history.copyHashes", 2),
            AppLocalization.text("history.copyInfo"),
            "",
        ])

        #expect(history.selectedIDs == [commits[0].id, commits[1].id])

        // 只看 main：Reveal 可用，执行后回到全部历史并选中被点的提交
        history.selectedReferences = ["refs/heads/main"]
        await untilFinished { history.activeTasks }

        let branch = NSMenu()
        coordinator.buildMenu(branch, clickedRow: try #require(history.row(of: commits[2].id)))

        #expect(branch.items[2].isEnabled)

        // 直接把菜单项的动作发给它的目标，与用户选中这一项相同
        let reveal = branch.items[2]

        NSApplication.shared.sendAction(
            try #require(reveal.action),
            to: reveal.target,
            from: reveal
        )

        await untilFinished { history.activeTasks }

        #expect(history.selectedReferences.isEmpty)
        #expect(history.selectedIDs == [commits[2].id])
    }
}
