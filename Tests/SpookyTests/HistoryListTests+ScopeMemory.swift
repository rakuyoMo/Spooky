import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ScopeMemory

extension HistoryListTests {
    /// 每个历史范围各记一份选中与滚动位置：换到另一个范围时回到它上次的选中，换回来时选中与可见区顶边都和离开时相同；
    /// 没看过的范围读完后选中第一行。
    @Test("各历史范围各自记住选中与滚动位置")
    func scopeMemory() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 60).map { "commit \($0)" })
        defer { fixture.close() }

        let history = fixture.session.history

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        defer { window.close() }

        window.contentView = NSHostingView(
            rootView: HistoryCommitTable(
                session: fixture.session,
                showGraph: false,
                smallRows: false,
                dateFormat: .absolute,
                createBranch: { _ in },
                openCommit: { }
            )
        )

        let root = try #require(window.contentView)
        let table = try #require(await RepositoryFocusTests.commitTable(in: root, rows: history.rows.count))

        // 全部历史里选中第一个提交，列表在顶部
        let first = try #require(history.commits.first)
        #expect(history.selectedIDs == [first.id])

        let allTop = table.visibleRect.minY

        // 换到 main：没看过，读完后选中第一行
        try await Self.switchScope(to: ["refs/heads/main"], in: history, table: table, root: root)
        #expect(history.selectedIDs == [first.id])

        // 在 main 里选中排在后面的提交并滚到它
        let target = try #require(history.commits.dropFirst(40).first)
        history.selectedIDs = [target.id]

        await until {
            root.layoutSubtreeIfNeeded()

            return table.visibleRect.minY > allTop
        }

        let mainOffset = table.visibleRect.minY

        // 换回全部历史：回到它上次的选中与顶部
        try await Self.switchScope(to: [], in: history, table: table, root: root)
        #expect(history.selectedIDs == [first.id])

        await until {
            root.layoutSubtreeIfNeeded()

            return table.visibleRect.minY == allTop
        }

        // 再换回 main：回到 main 里的选中，可见区顶边与离开时相同
        try await Self.switchScope(to: ["refs/heads/main"], in: history, table: table, root: root)
        #expect(history.selectedIDs == [target.id])

        await until {
            root.layoutSubtreeIfNeeded()

            return table.visibleRect.minY == mainOffset
        }
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 换到一个范围，等新范围读完、表格显示出新的行。
    ///
    /// - Parameters:
    ///   - references: 选中的引用；空集合表示全部历史。
    ///   - history: 历史状态。
    ///   - table: 历史列表的表格。
    ///   - root: 表格所在的视图树的根，等待时排版。
    private static func switchScope(
        to references: Set<String>,
        in history: RepositoryHistoryState,
        table: NSTableView,
        root: NSView
    ) async throws {
        history.selectedReferences = references
        await untilFinished { history.activeTasks }

        await until {
            root.layoutSubtreeIfNeeded()

            return table.numberOfRows == history.rows.count && !history.selectedIDs.isEmpty
        }
    }
}
