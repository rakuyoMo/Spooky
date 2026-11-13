import AppKit
import Foundation
import Observation
import SwiftUI
import Synchronization
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Refresh

extension HistoryListTests {
    /// 刷新从头重读列表时读回已加载的条数，选中的提交、展开与选中的文件、文件行的选区和已读的补丁都不被改写；
    /// 选中的提交在刷新后不在历史里时，选择与详情一起清空。
    @Test("刷新时保持历史的选择、展开与已读的补丁")
    func refreshKeepsDetails() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 150).map { "commit \($0)" })
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history

        // 续载第二页，选中排在第一页之后的提交，展开并选中它改动的文件
        history.loadNextPage()
        await untilFinished { history.activeTasks }

        let target = try await Self.commit(at: 120, with: fixture.runner)
        history.selectedIDs = [target.id]
        await untilFinished { history.activeTasks }

        history.expandedPaths = ["file.txt"]
        history.selectedPath = "file.txt"
        history.fileSelection.click("file.txt", extending: false, toggling: false, order: ["file.txt"])
        await untilFinished { history.activeTasks }

        #expect(history.commits.count == 150)
        #expect(history.changes.map(\.path) == ["file.txt"])
        #expect(history.diffs["file.txt"]?.diff != nil)

        // 改动工作区后刷新：列表与详情在后台重读，变更集、展开、选中的文件、文件行的选区、补丁与读取状态都不被改写
        let rewritten = Mutex(false)

        withObservationTracking {
            _ = history.changes
            _ = history.expandedPaths
            _ = history.selectedPath
            _ = history.fileSelection
            _ = history.diffs
            _ = history.isLoadingChanges
        } onChange: {
            rewritten.withLock { $0 = true }
        }

        try Data("changed\n".utf8).write(to: fixture.directory.appending(path: "file.txt"))
        session.refresh()
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }

        #expect(!rewritten.withLock { $0 })
        #expect(history.commits.count == 150)
        #expect(history.selectedCommit == target)

        // 回退到选中的提交之前，它不在历史里了
        _ = try await fixture.runner.run(["reset", "-q", "--hard", "HEAD~125"])
        session.refresh()
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }

        #expect(history.selectedIDs.isEmpty)
        #expect(history.changes.isEmpty)
        #expect(history.expandedPaths.isEmpty)
        #expect(history.diffs.isEmpty)
    }

    /// 会话的选择改变时列表滚到选中的提交；引用变化引起的刷新重载列表后恢复原有选中，
    /// 不把用户滚开的列表滚回选中的提交。
    @Test("引用变化后历史列表的滚动位置不变")
    func refreshKeepsScrollPosition() async throws {
        let fixture = try await Self.makeSession(commits: (0 ..< 60).map { "commit \($0)" })
        defer { fixture.close() }

        let session = fixture.session
        let history = session.history

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
                session: session,
                showGraph: false,
                smallRows: false,
                dateFormat: .absolute,
                createBranch: { _ in },
                openCommit: { }
            )
        )

        let root = try #require(window.contentView)
        var found: NSTableView? = nil

        await until {
            root.layoutSubtreeIfNeeded()
            found = Self.commitTable(in: root)

            return found?.numberOfRows == history.rows.count
        }

        let table = try #require(found)

        // 选中排在可见区之外的提交，列表滚到它
        let target = try #require(history.commits.dropFirst(40).first)
        let row = try #require(history.row(of: target.id))

        history.selectedIDs = [target.id]

        await until {
            root.layoutSubtreeIfNeeded()

            return table.visibleRect.contains(table.rect(ofRow: row))
        }

        await untilFinished { history.activeTasks }

        // 用户把列表滚回顶部，选中的提交移出可见区
        table.scroll(.zero)

        let position = table.visibleRect.minY

        #expect(!table.visibleRect.intersects(table.rect(ofRow: row)))

        // 新建分支后刷新：引用变化让列表重载，表格按会话的选择恢复选中时发出选择变化的通知
        let selectionChanges = Mutex(0)

        let observer = NotificationCenter.default.addObserver(
            forName: NSTableView.selectionDidChangeNotification,
            object: table,
            queue: nil
        ) { _ in
            selectionChanges.withLock { $0 += 1 }
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        _ = try await fixture.runner.run(["branch", "marker"])
        session.refresh()
        await session.waitForRefresh()
        await untilFinished { history.activeTasks }

        await until {
            root.layoutSubtreeIfNeeded()

            return selectionChanges.withLock { $0 } > 0 && table.selectedRowIndexes == [row]
        }

        // 恢复选中时排进主线程的工作都执行完，再核对滚动位置
        await Task { @MainActor in }.value

        let references = try #require(history.snapshot).references

        #expect(references.contains { $0.name == "marker" })
        #expect(history.selectedIDs == [target.id])
        #expect(table.visibleRect.minY == position)
    }
}

// MARK: - Helpers

extension HistoryListTests {
    /// 视图层级里的历史提交表格。
    static func commitTable(in view: NSView) -> NSTableView? {
        if let table = view as? HistoryCommitTable.CommitTableView {
            return table
        }

        return view.subviews.lazy.compactMap { commitTable(in: $0) }.first
    }
}
