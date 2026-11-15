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
    /// 没看过的范围读完后选中第一行、从顶部开始。侧边栏换范围时窗口会重建列表，新建的列表同样滚回记下的位置。
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

        window.contentView = Self.tableHost(fixture.session)
        var table = try #require(await Self.shownTable(in: window, history: history))

        // 全部历史里选中第一个提交，列表在顶部
        let first = try #require(history.commits.first)
        #expect(history.selectedIDs == [first.id])

        let top = table.visibleRect.minY

        // 在全部历史里选中排在后面的提交，再把它滚到可见区顶部；只靠滚到选中行回不到这个位置
        let allTarget = try #require(history.commits.dropFirst(30).first)
        history.selectedIDs = [allTarget.id]

        await until {
            window.contentView?.layoutSubtreeIfNeeded()

            return table.visibleRect.minY > top
        }

        let targetRow = try #require(history.row(of: allTarget.id))
        table.scroll(NSPoint(x: table.visibleRect.minX, y: table.rect(ofRow: targetRow).minY))
        let allOffset = table.visibleRect.minY

        // 换到 main，像侧边栏那样重建列表：没看过，读完后选中第一行、列表在顶部
        table = try await Self.switchScope(to: ["refs/heads/main"], of: fixture.session, in: window, rebuilding: true)
        #expect(history.selectedIDs == [first.id])

        await until {
            window.contentView?.layoutSubtreeIfNeeded()

            return table.visibleRect.minY == top
        }

        // 在 main 里选中更靠后的提交并滚到它
        let mainTarget = try #require(history.commits.dropFirst(40).first)
        history.selectedIDs = [mainTarget.id]

        await until {
            window.contentView?.layoutSubtreeIfNeeded()

            return table.visibleRect.minY > top
        }

        let mainOffset = table.visibleRect.minY

        // 重建列表换回全部历史：回到它上次的选中，可见区顶边与离开时相同
        table = try await Self.switchScope(to: [], of: fixture.session, in: window, rebuilding: true)
        #expect(history.selectedIDs == [allTarget.id])

        await until {
            window.contentView?.layoutSubtreeIfNeeded()

            return table.visibleRect.minY == allOffset
        }

        // 在同一个列表里换回 main：回到 main 里的选中，可见区顶边与离开时相同
        table = try await Self.switchScope(to: ["refs/heads/main"], of: fixture.session, in: window, rebuilding: false)
        #expect(history.selectedIDs == [mainTarget.id])

        await until {
            window.contentView?.layoutSubtreeIfNeeded()

            return table.visibleRect.minY == mainOffset
        }
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 换到一个范围，等新范围读完、列表显示出新的行。
    ///
    /// - Parameters:
    ///   - references: 选中的引用；空集合表示全部历史。
    ///   - session: 列表所属的会话。
    ///   - window: 列表所在的窗口。
    ///   - rebuilding: 是否像侧边栏换范围时的窗口那样换上新建的列表；否则沿用窗口里的列表。
    /// - Returns: 显示新范围的表格。
    private static func switchScope(
        to references: Set<String>,
        of session: RepositorySession,
        in window: NSWindow,
        rebuilding: Bool
    ) async throws -> NSTableView {
        let history = session.history
        history.selectedReferences = references

        if rebuilding {
            window.contentView = tableHost(session)
        }

        await untilFinished { history.activeTasks }

        return try #require(await shownTable(in: window, history: history))
    }

    /// 等窗口里的列表显示出全部已读的行，并且已经有选中的提交。
    ///
    /// - Parameters:
    ///   - window: 列表所在的窗口。
    ///   - history: 历史状态。
    /// - Returns: 窗口里的表格；没有找到时为 nil。
    private static func shownTable(in window: NSWindow, history: RepositoryHistoryState) async -> NSTableView? {
        guard let root = window.contentView else {
            return nil
        }

        var found: NSTableView? = nil

        await until {
            root.layoutSubtreeIfNeeded()
            found = commitTable(in: root)

            return found?.numberOfRows == history.rows.count && !history.rows.isEmpty
                && !history.selectedIDs.isEmpty
        }

        return found
    }

    /// 承载历史列表的视图：不显示提交图，用中号行。
    ///
    /// - Parameter session: 列表所属的会话。
    private static func tableHost(_ session: RepositorySession) -> NSView {
        NSHostingView(
            rootView: HistoryCommitTable(
                session: session,
                showGraph: false,
                smallRows: false,
                dateFormat: .absolute,
                createBranch: { _ in },
                openCommit: { }
            )
        )
    }
}
