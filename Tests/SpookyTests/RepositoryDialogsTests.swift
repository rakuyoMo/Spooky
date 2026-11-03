import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryDialogsTests

/// 改写、版本、储藏、工作区文件与外部工具的对话框都是 480 宽、高度随内容的对话框骨架；改写提交信息的标题带短哈希，
/// 自动储藏用备选底栏。
///
/// 读标题、按钮与位置的几项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct RepositoryDialogsTests {
    /// 每一种对话框都按骨架的默认宽度 480 排版。
    @Test("宽度")
    func widths() {
        for (name, dialog) in Self.dialogs() {
            #expect(DialogLayoutTests.hosting(dialog).frame.width == 480, "\(name)")
        }
    }

    /// 窗口按理想尺寸取到的高度与按 480 宽排出的高度相同，折行的说明不会被截掉，如重置的三档单选。
    @Test("高度随内容")
    func heights() {
        for (name, dialog) in Self.dialogs() {
            let controller = NSHostingController(rootView: dialog)
            controller.sizingOptions = .preferredContentSize

            let window = NSWindow(
                contentRect: NSRect(x: -3000, y: -3000, width: 480, height: 300),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )

            window.isReleasedWhenClosed = false
            window.contentViewController = controller
            window.orderFront(nil)

            RunLoop.main.run(until: Date().addingTimeInterval(0.2))

            let fitting = controller.sizeThatFits(in: CGSize(width: 480, height: 10_000))

            #expect(controller.preferredContentSize.height == fitting.height, "\(name)")

            window.close()
        }
    }

    /// 改写提交信息的标题写出版本的短哈希，主按钮是 Save。
    @Test("改写提交信息的标题", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func rewordTitle() throws {
        let plan = Self.rewordPlan()
        let commit = try #require(plan.commits.first)
        let save = AppLocalization.text("rewrite.reword.button")

        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == save } }
        ) {
            RewordDialog(session: Self.session(), plan: plan, close: { })
        }

        let title = AppLocalization.text("rewrite.reword.title", commit.shortID)

        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == title })
    }

    /// 自动储藏的 Abort 在左、左缘对齐输入列；Do Not Stash 与 Stash Changes 在右，相隔 8，Stash Changes 距右 20。
    @Test("自动储藏的备选底栏", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func autoStashFooter() throws {
        let skip = AppLocalization.text("stash.autoStash.skip")

        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == skip } }
        ) {
            Self.stashDialog(.autoStash(Self.autoStash()), in: Self.session())
        }

        let field = try #require(elements.first { $0.role == "AXTextField" })
        let abort = try Self.button("stash.autoStash.abort", in: elements)
        let skipButton = try Self.button("stash.autoStash.skip", in: elements)
        let stash = try Self.button("stash.autoStash.confirm", in: elements)

        #expect(abs(abort.frame.minX - field.frame.minX) <= 1)
        #expect(abs(stash.frame.minX - skipButton.frame.maxX - 8) <= 1)
        #expect(abs(stash.frame.maxX - (480 - 20)) <= 1)
        #expect(abort.frame.maxX < skipButton.frame.minX)
    }
}

// MARK: - Helpers

extension RepositoryDialogsTests {
    /// 这几类对话框的每一种，名字用于定位失败的那一个。
    private static func dialogs() -> [(String, AnyView)] {
        let session = session()
        let plan = rewordPlan()

        return [
            ("checkout", AnyView(CheckoutRevisionDialog(session: session, revision: nil, close: { }))),
            ("revert", AnyView(PickRevisionsDialog(session: session, kind: .revert, commits: ["a"], close: { }))),
            ("cherryPick", AnyView(PickRevisionsDialog(session: session, kind: .cherryPick, commits: ["a"], close: { }))),
            ("rebaseOnto", AnyView(RebaseOntoDialog(session: session, commits: [], close: { }))),
            ("reset", AnyView(ResetDialog(session: session, revision: nil, close: { }))),
            ("reword", AnyView(RewordDialog(session: session, plan: plan, close: { }))),
            ("confirmation", AnyView(RewriteConfirmationDialog(session: session, plan: plan, close: { }))),
            ("archive", AnyView(ArchiveBranchesDialog(session: session, automatic: false, candidates: [], close: { }))),
            ("export", AnyView(revisionDialog(.export(revision: nil, paths: [], archive: false), in: session))),
            ("savePatch", AnyView(revisionDialog(.savePatch([]), in: session))),
            ("compare", AnyView(revisionDialog(.compare(base: nil), in: session))),
            ("save", AnyView(stashDialog(.save(snapshot: false, entries: []), in: session))),
            ("apply", AnyView(stashDialog(.apply(nil), in: session))),
            ("autoStash", AnyView(stashDialog(.autoStash(autoStash()), in: session))),
            ("applyPatch", AnyView(WorkingCopyFileDialog(session: session, form: .applyPatch, close: { }))),
            ("pattern", AnyView(WorkingCopyFileDialog(session: session, form: .lfsPattern([]), close: { }))),
            ("externalTool", AnyView(ConfigureExternalToolDialog(merge: false, finish: { _ in }))),
        ]
    }

    /// 只设置了本机仓库、不读取它的会话。
    private static func session() -> RepositorySession {
        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })
        session.display(.local(path: "/tmp/spooky-dialogs"))
        return session
    }

    /// 改写一个提交信息的计划，范围里只有这个提交。
    private static func rewordPlan() -> RewritePlan {
        let commit = HistoryListTests.commit("a", date: Date(timeIntervalSince1970: 1_800_000_000))

        return RewritePlan(
            action: .reword(commit.id, message: commit.message),
            head: commit.id,
            base: nil,
            onto: nil,
            commits: [commit],
            instructions: [],
            pushed: [],
            merged: []
        )
    }

    /// 被本地改动挡住的检出。
    private static func autoStash() -> AutoStashRequest {
        AutoStashRequest(title: "Check Out", error: CancellationError()) { _, _ in }
    }

    /// 打开时仓库为空的版本对话框。
    private static func revisionDialog(_ request: RevisionRequest, in session: RepositorySession) -> RevisionDialog {
        RevisionDialog(session: session, request: request, repository: session.repository, close: { })
    }

    /// 储藏对话框。
    private static func stashDialog(_ request: StashRequest, in session: RepositorySession) -> StashDialog {
        StashDialog(session: session, request: request, repository: session.repository, close: { })
    }

    /// 名称是这个资源键的按钮。
    private static func button(
        _ key: String,
        in elements: [AccessibilityProbe.Element]
    ) throws -> AccessibilityProbe.Element {
        let name = AppLocalization.text(key)

        return try #require(elements.first { $0.role == "AXButton" && $0.name == name }, "\(key)")
    }
}
