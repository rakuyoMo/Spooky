import AppKit
import Foundation
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - Separator

extension HistoryListTests {
    /// 提交行在底边画分隔线，起点是头像或短哈希的左缘，终点是单元格的右缘，叠在单元格之上；
    /// 下一行是日期分组的标题时不画，标题行也不画。中号与小号行各核对一次。
    @Test("提交行的分隔线")
    func rowSeparators() async throws {
        let fixture = try await Self.makeSession(commits: ["a", "b", "c"])
        defer { fixture.close() }

        let history = fixture.session.history
        let commits = history.commits

        // 第一个提交之后接一行日期分组的标题
        history.rows = [
            .commit(commits[0]),
            .group(commits[1].commitDate),
            .commit(commits[1]),
            .commit(commits[2]),
        ]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        defer { window.close() }

        // 中号行显示提交图：线性历史的图只有一列，宽 17 pt，再隔 8 pt 才是头像
        let medium = try await Self.rowViews(in: window, session: fixture.session, small: false)
        try Self.expectSeparators(in: medium, inset: 25)

        // 小号行不显示提交图：短哈希贴着单元格的左缘
        let small = try await Self.rowViews(in: window, session: fixture.session, small: true)
        try Self.expectSeparators(in: small, inset: 0)
    }
}

// MARK: - Steps

extension HistoryListTests {
    /// 前两行（分组标题之前的提交行与标题行）不画分隔线；其余提交行在底边画 1 pt 高的线，
    /// 从单元格左缘加上 `inset` 处画到单元格右缘，并排在全部子视图的最上面。
    private static func expectSeparators(in rows: [HistoryRowView], inset: CGFloat) throws {
        #expect(rows[0].separator.isHidden)
        #expect(rows[1].separator.isHidden)

        for row in rows.dropFirst(2) {
            let cell = try #require(row.view(atColumn: 0) as? NSView).frame

            let expected = NSRect(
                x: cell.minX + inset,
                y: row.bounds.maxY - 1,
                width: cell.width - inset,
                height: 1
            )

            #expect(!row.separator.isHidden)
            #expect(row.separator.frame == expected)
            #expect(row.subviews.last === row.separator)
        }
    }
}

// MARK: - Helpers

extension HistoryListTests {
    /// 把会话的历史列表放进窗口，排好版后取出每一行的行视图；中号行显示提交图，小号行不显示。
    private static func rowViews(
        in window: NSWindow,
        session: RepositorySession,
        small: Bool
    ) async throws -> [HistoryRowView] {
        window.contentView = NSHostingView(
            rootView: HistoryCommitTable(
                session: session,
                showGraph: !small,
                smallRows: small,
                dateFormat: .absolute,
                createBranch: { _ in },
                openCommit: { }
            )
        )

        let root = try #require(window.contentView)
        let count = session.history.rows.count
        var found: NSTableView? = nil

        // 行高随大小切换，等表格排出全部的行，且行高已是这一种大小的
        await until {
            root.layoutSubtreeIfNeeded()
            found = Self.commitTable(in: root)

            return found?.numberOfRows == count && found?.rect(ofRow: 0).height == (small ? 24 : 46)
        }

        let table = try #require(found)

        return try (0 ..< count).map { row in
            let view = try #require(table.rowView(atRow: row, makeIfNecessary: true) as? HistoryRowView)
            view.layoutSubtreeIfNeeded()
            return view
        }
    }
}
