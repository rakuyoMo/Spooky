import AppKit
import ApplicationServices
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - RepositoryDialogsTests

/// 改写、版本、储藏、工作区文件与外部工具的对话框都是 480 宽、高度随内容的对话框骨架；自动储藏用备选底栏。
///
/// 读按钮位置的一项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct RepositoryDialogsTests {
    /// 每一种对话框都按骨架的默认宽度 480 排版；按理想尺寸取到的高度与按 480 宽排出的高度相同，
    /// 折行的说明不会被截掉，如重置的三档单选。
    @Test("宽度与高度随内容")
    func sizes() async {
        for (name, dialog) in Self.dialogs() {
            #expect(DialogLayoutTests.hosting(dialog).frame.width == 480, "\(name)")

            let controller = NSHostingController(rootView: dialog)
            controller.sizingOptions = .preferredContentSize
            controller.view.frame.size = CGSize(width: 480, height: 300)

            // 理想尺寸在排版时算出，SwiftUI 可能分几轮更新完
            await runLoopTurns(2) { controller.view.layoutSubtreeIfNeeded() }

            let fitting = controller.sizeThatFits(in: CGSize(width: 480, height: 10_000))

            #expect(controller.preferredContentSize.height == fitting.height, "\(name)")
        }
    }

    /// 自动储藏的 Abort 在左、左缘对齐输入列；Do Not Stash 与 Stash Changes 在右，相隔 12，Stash Changes 距右 20。
    /// 完成后恢复改动没有保存值时不勾，保存过勾选时按保存值。
    @Test("自动储藏的备选底栏与恢复选项的默认值", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func autoStashFooter() async throws {
        // 恢复选项从没有保存值开始，结束后恢复
        let saved = UserDefaults.standard.object(forKey: "autoStashReapply")
        defer { UserDefaults.standard.set(saved, forKey: "autoStashReapply") }

        UserDefaults.standard.removeObject(forKey: "autoStashReapply")

        let elements = await Self.autoStashElements()
        let reapply = AppLocalization.text("stash.autoStash.reapply")
        let unchecked = try #require(elements.first { $0.role == "AXCheckBox" && $0.name == reapply })

        #expect(unchecked.value == "0")

        let field = try #require(elements.first { $0.role == "AXTextField" })
        let abort = try Self.button("stash.autoStash.abort", in: elements)
        let skipButton = try Self.button("stash.autoStash.skip", in: elements)
        let stash = try Self.button("stash.autoStash.confirm", in: elements)

        #expect(abs(abort.frame.minX - field.frame.minX) <= 1)
        #expect(abs(stash.frame.minX - skipButton.frame.maxX - 12) <= 1)
        #expect(abs(stash.frame.maxX - (480 - 20)) <= 1)
        #expect(abort.frame.maxX < skipButton.frame.minX)

        // 保存过勾选时按保存值
        UserDefaults.standard.set(true, forKey: "autoStashReapply")

        let checked = try #require(
            await Self.autoStashElements().first { $0.role == "AXCheckBox" && $0.name == reapply }
        )

        #expect(checked.value == "1")
    }

    /// 改信息与删除的范围里有已推送的提交时，先弹提示框，主按钮是动作本身、另一个是 Cancel；
    /// 没有已推送的提交，或是压缩等其它动作时不弹，直接打开对话框。
    @Test("改写已推送的提交前的提示框")
    func pushedRewriteAlert() {
        let commit = String(repeating: "a", count: 40)
        let cancel = AppLocalization.text("action.cancel")

        // 有已推送的提交：改信息与删除各自的主按钮
        let reword = RepositoryWindowController.pushedRewriteAlert(
            for: .reword(Self.singleCommitPlan(pushed: true))
        )
        let drop = RepositoryWindowController.pushedRewriteAlert(
            for: .confirm(Self.singleCommitPlan(pushed: true, action: .drop([commit])))
        )

        #expect(reword?.buttons.map(\.title) == [AppLocalization.text("rewrite.reword"), cancel])
        #expect(drop?.buttons.map(\.title) == [AppLocalization.text("rewrite.drop"), cancel])
        #expect(reword?.alertStyle == .warning)

        // 没有已推送的提交，或是其它动作
        let unpushed = RepositoryWindowController.pushedRewriteAlert(
            for: .reword(Self.singleCommitPlan())
        )
        let squash = RepositoryWindowController.pushedRewriteAlert(
            for: .confirm(Self.singleCommitPlan(pushed: true, action: .squash([commit], into: nil)))
        )

        #expect(unpushed == nil)
        #expect(squash == nil)
    }
}

// MARK: - Helpers

extension RepositoryDialogsTests {
    /// 打开原操作已被本地改动挡住的自动储藏对话框，读出全部元素。
    private static func autoStashElements() async -> [AccessibilityProbe.Element] {
        let skip = AppLocalization.text("stash.autoStash.skip")

        return await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == skip } }
        ) {
            stashDialog(.autoStash(autoStash()), in: session())
        }
    }

    /// 这几类对话框的每一种，名字用于定位失败的那一个。
    private static func dialogs() -> [(String, AnyView)] {
        let session = session()
        let plan = singleCommitPlan()

        return [
            ("checkout", AnyView(CheckoutRevisionDialog(session: session, revision: nil, close: { }))),
            ("revert", AnyView(PickRevisionsDialog(session: session, kind: .revert, commits: ["a"], close: { }))),
            (
                "cherryPick",
                AnyView(PickRevisionsDialog(session: session, kind: .cherryPick, commits: ["a"], close: { }))
            ),
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

    /// 范围里只有一个提交的计划，默认改写这个提交的信息。
    ///
    /// - Parameters:
    ///   - pushed: 这个提交是否已推送到上游。
    ///   - action: 计划的动作；nil 时改写信息。
    private static func singleCommitPlan(pushed: Bool = false, action: RewriteAction? = nil) -> RewritePlan {
        let commit = HistoryListTests.commit("a", date: Date(timeIntervalSince1970: 1_800_000_000))

        return RewritePlan(
            action: action ?? .reword(commit.id, message: commit.message),
            head: commit.id,
            base: nil,
            onto: nil,
            commits: [commit],
            instructions: [],
            pushed: pushed ? [commit.id] : [],
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
