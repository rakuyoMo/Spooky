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
    /// 中号行的头像比行的正中高 1 pt，头像底离分隔线 7 pt。隐藏提交图时保存的小号档位不生效，行固定为 46 pt 的中号行。
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

        // 46 pt 的行里，32 pt 的头像画在行内 6–38 pt，底边到分隔线（45 pt 处）是 7 pt
        let avatar = try Self.drawnRows(in: medium[2], x: 25 + 16)
        #expect(avatar == 6 ..< 38)

        // 小号行同样在图右侧 8 pt 起画
        let small = try await Self.rowViews(in: window, session: fixture.session, small: true)
        try Self.expectSeparators(in: small, inset: 25)

        // 隐藏提交图：保存的是小号档位，行仍是 46 pt 的中号行，头像贴着单元格的左缘
        let hidden = try await Self.rowViews(in: window, session: fixture.session, small: true, showGraph: false)
        try Self.expectSeparators(in: hidden, inset: 0)
        #expect(hidden[0].frame.height == 46)
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

    /// 提交行在 `x` 这一列上画到的纵向范围（pt，从行顶起算）：按单元格的尺寸以 2 倍像素画出行的内容，
    /// 从上往下找第一个与最后一个画到的像素（头像的底色是半透明的填充色）。
    private static func drawnRows(in row: HistoryRowView, x: CGFloat) throws -> Range<CGFloat>? {
        let cell = try #require(row.view(atColumn: 0) as? NSHostingView<HistoryCommitRow>)

        let renderer = ImageRenderer(
            content: cell.rootView.frame(width: cell.bounds.width, height: cell.bounds.height)
        )

        renderer.scale = 2

        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))

        let drawn = (0 ..< bitmap.pixelsHigh).filter {
            (bitmap.colorAt(x: Int(x * 2), y: $0)?.alphaComponent ?? 0) > 0.01
        }

        guard let first = drawn.first, let last = drawn.last else {
            return nil
        }

        return CGFloat(first) / 2 ..< CGFloat(last + 1) / 2
    }
}

// MARK: - Helpers

extension HistoryListTests {
    /// 把会话的历史列表放进窗口，排好版后取出每一行的行视图。
    ///
    /// - Parameters:
    ///   - small: 保存的行高档位是否是小号。
    ///   - showGraph: 是否显示提交图；隐藏时行固定为中号。
    static func rowViews(
        in window: NSWindow,
        session: RepositorySession,
        small: Bool,
        showGraph: Bool = true
    ) async throws -> [HistoryRowView] {
        window.contentView = NSHostingView(
            rootView: HistoryCommitTable(
                session: session,
                showGraph: showGraph,
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

            return found?.numberOfRows == count && found?.rect(ofRow: 0).height == (small && showGraph ? 24 : 46)
        }

        let table = try #require(found)

        return try (0 ..< count).map { row in
            let view = try #require(table.rowView(atRow: row, makeIfNecessary: true) as? HistoryRowView)
            view.layoutSubtreeIfNeeded()
            return view
        }
    }
}
