import AppKit
import Foundation
import SpookyKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - RepositorySidebarViewTests

/// 同一个窗口换着显示仓库时，侧边栏的排版与新开窗口相同，键盘焦点留在侧边栏；程序化选中的引用展开并滚动到可见。
@MainActor
struct RepositorySidebarViewTests {
    /// 远端是可展开的行，显示它时各行的行首让出展开箭头的位置；换回没有远端的仓库后，行首回到新开时的位置。
    /// 换仓库时列表整个重建，原来在侧边栏里的键盘焦点落到新的列表上，不丢给窗口。
    @Test("换仓库后行首与新开时相同，键盘焦点仍在侧边栏")
    func switchingRepositories() async throws {
        let plain = try await Self.repository()
        let withRemote = try await Self.repository()

        defer {
            try? FileManager.default.removeItem(atPath: plain.location.path)
            try? FileManager.default.removeItem(atPath: withRemote.location.path)
        }

        _ = try await withRemote.runner.run(["remote", "add", "origin", plain.location.path])

        let runners = [plain.location: plain.runner, withRemote.location: withRemote.runner]

        let session = RepositorySession(
            makeRunner: { runners[$0] ?? plain.runner },
            activities: RepositoryActivities()
        )

        defer { session.close() }

        await Self.display(plain.location, in: session, remotes: 0)

        let window = Self.host(session)
        let root = try #require(window.contentView)
        let fresh = try #require(await Self.rebuiltOutline(in: root, replacing: nil))

        // 有远端的仓库：行首右移，让出展开箭头的位置
        await Self.display(withRemote.location, in: session, remotes: 1)

        let shifted = try #require(await Self.rebuiltOutline(in: root, replacing: fresh))
        #expect(Self.workingCopyLeading(of: shifted) > Self.workingCopyLeading(of: fresh))

        // 换仓库之前让列表拿到键盘焦点；SwiftUI 在之后的几轮更新里才把第一响应者记进列表的焦点状态
        window.makeFirstResponder(shifted)
        await runLoopTurns(3) { root.layoutSubtreeIfNeeded() }

        // 换回没有远端的仓库：行首回到新开时的位置
        await Self.display(plain.location, in: session, remotes: 0)

        let restored = try #require(await Self.rebuiltOutline(in: root, replacing: shifted))
        #expect(Self.workingCopyLeading(of: restored) == Self.workingCopyLeading(of: fresh))

        // 新列表在重建之后的更新里拿回焦点，这是焦点恢复唯一的完成信号
        await until {
            root.layoutSubtreeIfNeeded()
            return window.firstResponder === Self.outline(in: root)
        }

        #expect(window.firstResponder === restored)
    }

    /// 程序化选中收起的 Tags 分组里、文件夹中的标签时，列表展开分组与文件夹，选中那一行并滚动到可见；
    /// 分离 HEAD 时，当前分支行的名字是当前提交的 8 位短哈希。
    @Test("程序化选中展开分组与文件夹并滚动到可见，分离 HEAD 的行名是短哈希")
    func revealingReferences() async throws {
        let fixture = try await Self.repository()
        defer { try? FileManager.default.removeItem(atPath: fixture.location.path) }

        // 足够多的分支把 Tags 分组推出首屏；标签放在文件夹里，HEAD 分离在根提交上
        let branches = 40

        for index in 1 ... branches {
            _ = try await fixture.runner.run(["branch", "branch-" + String(index)])
        }

        _ = try await fixture.runner.run(["tag", "release/v1"])
        _ = try await fixture.runner.run(["switch", "-q", "--detach"])

        let session = RepositorySession(
            makeRunner: { _ in fixture.runner },
            activities: RepositoryActivities()
        )

        defer { session.close() }

        await Self.display(fixture.location, in: session, remotes: 0)

        let oid = try #require(session.status?.branch.oid)
        #expect(Self.sidebar(session).headRowName == String(oid.prefix(8)))

        let window = Self.host(session)
        let root = try #require(window.contentView)
        let outline = try #require(await Self.rebuiltOutline(in: root, replacing: nil))
        let rows = outline.numberOfRows

        // 经快捷操作的入口选中标签：Tags 分组与 release 文件夹各展开一行，选中的标签行排在全部分支之后并滚动到可见
        let tag = try #require(session.history.snapshot?.references.first { $0.id == "refs/tags/release/v1" })
        session.showHistory(of: tag)

        await until {
            root.layoutSubtreeIfNeeded()

            let row = outline.selectedRow

            guard row > branches, outline.numberOfRows == rows + 2 else {
                return false
            }

            return outline.visibleRect.intersects(outline.rect(ofRow: row))
        }

        #expect(session.history.selectedReferences == [tag.id])
    }
}

// MARK: - Helpers

extension RepositorySidebarViewTests {
    /// 带一个提交的临时仓库与它的执行器。
    static func repository() async throws -> (location: RepositoryLocation, runner: GitRunner) {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "spooky-sidebar 侧边栏-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        try Data("base\n".utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        return (location, runner)
    }

    /// 回调什么都不做的侧边栏。
    static func sidebar(_ session: RepositorySession) -> RepositorySidebarView {
        RepositorySidebarView(
            session: session,
            selectionChanged: { },
            openTerminal: { },
            revealFinder: { },
            copyPath: { },
            request: { _ in },
            showActivity: { }
        )
    }

    /// 把侧边栏放进不显示的窗口；窗口由调用方持有到测试结束。
    static func host(_ session: RepositorySession) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: sidebar(session))
        return window
    }

    /// 视图层级里的第一个大纲视图，即列表背后的表格。
    static func outline(in view: NSView) -> NSOutlineView? {
        if let outline = view as? NSOutlineView {
            return outline
        }

        return view.subviews.lazy.compactMap { outline(in: $0) }.first
    }

    /// 让会话显示仓库，等工作区刷新与它带起的历史读取结束，核对读出的远端个数。
    private static func display(
        _ location: RepositoryLocation,
        in session: RepositorySession,
        remotes: Int
    ) async {
        session.display(location)
        session.refresh(full: true)

        await session.waitForRefresh()
        await untilFinished { session.history.activeTasks }

        #expect(session.history.snapshot?.remotes.count == remotes)
    }

    /// 等侧边栏换上新的列表并排好版：列表不是换仓库之前的那个，且 Workspace 标题下已有行。
    ///
    /// - Parameters:
    ///   - root: 侧边栏的根视图。
    ///   - previous: 换仓库之前的列表；nil 时等第一个列表。
    /// - Returns: 新的列表。
    private static func rebuiltOutline(in root: NSView, replacing previous: NSOutlineView?) async -> NSOutlineView? {
        var current: NSOutlineView? = nil

        await until {
            root.layoutSubtreeIfNeeded()
            current = outline(in: root)

            guard let current, current !== previous else {
                return false
            }

            return current.numberOfRows > 1
        }

        return current
    }

    /// Working Copy 行（Workspace 标题下的第一行）单元格的左缘。
    private static func workingCopyLeading(of outline: NSOutlineView) -> CGFloat {
        outline.frameOfCell(atColumn: 0, row: 1).minX
    }
}
