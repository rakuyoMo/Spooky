import AppKit
import ApplicationServices
import Foundation
import SpookyKit
import SwiftUI
import Testing
import TestSupport

@testable import Spooky

// MARK: - InvalidWorktreeTests

/// 目录被删掉的工作树：右键菜单、快捷操作与详情只留下删除与修复，悬停提示照常写出位置，修复对话框预选登记的路径。
@MainActor
struct InvalidWorktreeTests {
    /// 失效的工作树能删除、能修复、不能移动；修复只对它列出，详情的两个按钮与菜单的同名项一样可用；
    /// 服务器仓库里，失效的工作树的悬停提示同样带主机前缀。
    @Test("失效工作树的菜单、快捷操作、详情按钮与悬停提示")
    func invalidWorktree() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appending(path: "spooky-worktree 工作树-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: parent) }

        let session = try await Self.session(in: parent)
        defer { session.close() }

        let gone = try #require(session.worktrees.others.first { !$0.isValid })
        let live = try #require(session.worktrees.others.first { $0.isValid })
        let text = { (key: String) in AppLocalization.text(key) }

        // 右键菜单的第二组依次是删除、移动、修复；失效时只有删除与修复可用
        let menu = HostedMenu(WorktreeMenu(session: session, worktree: gone, branch: nil))

        #expect(
            menu.titles == [
                text("worktree.open.current"), text("worktree.open.newTab"), text("worktree.open.newWindow"), "",
                text("worktree.remove.menu"), text("worktree.move.menu"), text("worktree.repair.menu"), "",
                text("worktree.reveal"), text("action.copyPath"), text("action.openTerminal"),
            ]
        )

        #expect(menu.enabled == [false, false, false, true, false, true, false, false, false])

        // 有效的工作树不列修复，可以移动
        let liveMenu = HostedMenu(WorktreeMenu(session: session, worktree: live, branch: nil))

        #expect(!liveMenu.titles.contains(text("worktree.repair.menu")))
        #expect(try #require(liveMenu.item(text("worktree.move.menu"))).isEnabled)

        // 快捷操作同样不列出失效工作树的移动
        let catalog = QuickActionCatalog(session: session)

        #expect(catalog.actions(for: .worktree(gone)) == [.removeWorktree, .repairWorktree])
        #expect(catalog.actions(for: .worktree(live)).contains(.moveWorktree))

        // 详情的空状态下面是修复与删除两个按钮
        session.showWorktree(gone.path)

        let detail = NSHostingView(rootView: WorktreeDetailView(session: session))
        detail.frame.size = CGSize(width: 600, height: 400)
        detail.layoutSubtreeIfNeeded()

        let buttons = Self.buttons(in: detail)

        #expect(buttons.map(\.title) == [text("worktree.invalid.repair"), text("worktree.invalid.remove")])
        #expect(buttons.allSatisfy { $0.isEnabled })

        // 服务器仓库：失效的工作树没有可以打开的位置，悬停提示仍写出带主机前缀的路径
        let server = RepositoryLocation.remote(host: "spooky-test", path: parent.path)
        let tooltip = RepositorySidebarView.tooltip(of: gone, in: server)

        #expect(tooltip.hasSuffix(AppLocalization.text("worktree.tooltip.path", "spooky-test:" + gone.path)))
    }

    /// 修复对话框打开时，位置菜单选中工作树登记的路径；选的还是它时主按钮不可用，也不写错误说明。
    @Test("修复对话框预选登记的路径", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func relocateDialog() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appending(path: "spooky-worktree 工作树-" + UUID().uuidString)

        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: parent) }

        let session = try await Self.session(in: parent)
        defer { session.close() }

        let gone = try #require(session.worktrees.others.first { !$0.isValid })

        let text = { (key: String) in AppLocalization.text(key) }

        let elements = await AccessibilityProbe.elements(width: 520, until: Self.hasLocation) {
            RelocateWorktreeDialog(session: session, worktree: gone, close: { })
        }

        let location = try #require(elements.first { $0.role == "AXPopUpButton" })
        let relocate = try #require(
            elements.first {
                $0.role == "AXButton"
                    && $0.name == text("worktree.relocate.submit")
            }
        )

        #expect(location.value == HomePath.abbreviated(gone.path))
        #expect(!relocate.isEnabled)

        // 窗口标题之外的文字只有标题、说明与 “Location:”，没有错误说明
        let texts = elements.filter {
            $0.role == "AXStaticText"
                && !$0.value.hasPrefix("spooky-accessibility-")
        }

        #expect(
            Set(texts.map(\.value)) == [
                text("worktree.relocate"),
                AppLocalization.text("worktree.relocate.message", gone.name),
                text("worktree.location"),
            ]
        )
    }
}

// MARK: - Helpers

extension InvalidWorktreeTests {
    /// 在 `parent` 下建仓库与两个工作树，删掉其中一个的目录，打开会话并等它读出工作树。
    private static func session(in parent: URL) async throws -> RepositorySession {
        let directory = parent.appending(path: "repo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)

        let location = RepositoryLocation.local(path: directory.path)
        let runner = try await FileViewsTests.initializeRepository(at: location)

        try Data("base\n".utf8).write(to: directory.appending(path: "a.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "root"])

        // live 留着，gone 的目录删掉后 Git 把它记为 prunable
        _ = try await runner.run(["worktree", "add", "-q", "-b", "live", parent.appending(path: "live").path])
        _ = try await runner.run(["worktree", "add", "-q", "-b", "gone", parent.appending(path: "gone").path])
        try FileManager.default.removeItem(at: parent.appending(path: "gone"))

        let session = RepositorySession(makeRunner: { _ in runner }, activities: RepositoryActivities())
        session.display(location)
        session.refresh(full: true)

        await session.waitForRefresh()
        await until { session.worktrees.others.count == 2 }

        return session
    }

    /// 修复对话框的位置菜单已经读到。
    private static func hasLocation(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXPopUpButton" }
    }

    /// 视图层级里的全部按钮，按层级顺序。
    private static func buttons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
