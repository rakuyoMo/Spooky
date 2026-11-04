import AppKit
import Foundation
import SpookyKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - RepositorySidebarViewTests

/// 同一个窗口换着显示仓库时，侧边栏的排版与新开窗口相同，键盘焦点留在侧边栏。
@MainActor
struct RepositorySidebarViewTests {
    /// 远端是可展开的行，显示它时各行的行首让出展开箭头的位置；换回没有远端的仓库后，行首回到新开时的位置。
    @Test("换回没有可展开行的仓库后，行首与新开时相同")
    func leadingAfterSwitchingRepositories() async throws {
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

        try await Self.display(plain.location, in: session, remotes: 0)
        let window = Self.host(session)
        let fresh = try #require(await Self.workingCopyLeading(in: window) { _ in true })

        // 有远端的仓库：行首右移，让出展开箭头的位置
        try await Self.display(withRemote.location, in: session, remotes: 1)
        let shifted = await Self.workingCopyLeading(in: window) { $0 > fresh }
        #expect(shifted != nil)

        // 换回没有远端的仓库：行首回到新开时的位置
        try await Self.display(plain.location, in: session, remotes: 0)
        let restored = await Self.workingCopyLeading(in: window) { $0 == fresh }
        #expect(restored == fresh)
    }

    /// 换仓库时列表整个重建，原来在侧边栏里的键盘焦点落到新的列表上，不丢给窗口。
    @Test("换了仓库后键盘焦点仍在侧边栏")
    func focusAfterSwitchingRepositories() async throws {
        let first = try await Self.repository()
        let second = try await Self.repository()

        defer {
            try? FileManager.default.removeItem(atPath: first.location.path)
            try? FileManager.default.removeItem(atPath: second.location.path)
        }

        let runners = [first.location: first.runner, second.location: second.runner]
        let session = RepositorySession(
            makeRunner: { runners[$0] ?? first.runner },
            activities: RepositoryActivities()
        )

        defer { session.close() }

        try await Self.display(first.location, in: session, remotes: 0)
        let window = Self.host(session)
        _ = await Self.workingCopyLeading(in: window) { _ in true }

        let root = try #require(window.contentView)
        let original = try #require(Self.outline(in: root))
        window.makeFirstResponder(original)

        // SwiftUI 在之后的更新里才把第一响应者记进列表的焦点状态
        try await Task.sleep(for: .milliseconds(300))

        try await Self.display(second.location, in: session, remotes: 0)

        let focused = await Self.eventually {
            guard let current = Self.outline(in: root) else {
                return false
            }

            return current !== original && window.firstResponder === current
        }

        #expect(focused)
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

    /// 把侧边栏放进不显示的窗口；窗口由调用方持有到测试结束。
    static func host(_ session: RepositorySession) -> NSWindow {
        let sidebar = RepositorySidebarView(
            session: session,
            selectionChanged: { },
            openTerminal: { },
            revealFinder: { },
            copyPath: { },
            request: { _ in },
            showActivity: { }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: sidebar)
        return window
    }

    /// 视图层级里的第一个大纲视图，即列表背后的表格。
    static func outline(in view: NSView) -> NSOutlineView? {
        if let outline = view as? NSOutlineView {
            return outline
        }

        return view.subviews.lazy.compactMap { outline(in: $0) }.first
    }

    /// 让会话显示仓库，等到读出的远端个数与预期相同。
    private static func display(
        _ location: RepositoryLocation,
        in session: RepositorySession,
        remotes: Int
    ) async throws {
        session.display(location)
        session.refresh(full: true)
        await session.waitForRefresh()

        // 整套测试并行时 Git 读取要排队，等的上限按整套测试的耗时留足
        try await FileViewsTests.wait { session.history.snapshot?.remotes.count == remotes }
    }

    /// 等 Working Copy 行（Workspace 标题下的第一行）的单元格左缘满足条件，返回它；超时为 nil。
    private static func workingCopyLeading(
        in window: NSWindow,
        until condition: (CGFloat) -> Bool
    ) async -> CGFloat? {
        var leading: CGFloat? = nil

        let satisfied = await eventually {
            window.contentView?.layoutSubtreeIfNeeded()

            guard
                let root = window.contentView,
                let outline = outline(in: root),
                outline.numberOfRows > 1
            else {
                return false
            }

            leading = outline.frameOfCell(atColumn: 0, row: 1).minX
            return leading.map(condition) ?? false
        }

        return satisfied ? leading : nil
    }

    /// 每 20 ms 检查一次条件，300 s 内满足时返回 true。
    ///
    /// 整套测试并行时主线程要排队，等待上限按整套测试的耗时留足。
    private static func eventually(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))

        while !condition() {
            guard .now < deadline else {
                return false
            }

            try? await Task.sleep(for: .milliseconds(20))
        }

        return true
    }
}
