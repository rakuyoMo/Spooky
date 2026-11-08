import AppKit
import ApplicationServices
import SwiftUI
import Testing
import TestSupport

@testable import Spooky
@testable import SpookyKit

// MARK: - ConfirmationDialogTests

/// 确认对话框与仓库窗口挂出的 sheet：会话的确认、空提交的确认、提交信息含注释的询问与 Git 错误框都挂成 sheet；
/// “Do not ask me again” 在内容区、对齐 120 pt 的对齐线，只在确认时生效；空提交的 “Do not show this warning again” 选哪个按钮都生效。
///
/// 读勾选框与按钮的一项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct ConfirmationDialogTests {
    /// 会话发起的确认与空提交确认挂成确认对话框的 sheet，提交信息含注释的询问挂成自己的 sheet；
    /// Git 错误框挂成可以拉大的 sheet，以 `GitErrorDialog` 记住排好版的尺寸，下次照记住的尺寸打开。
    @Test("仓库窗口挂出的 sheet")
    func presentation() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let session = fixture.controller.session
        let window = try #require(fixture.controller.window)

        // 会话的确认与空提交确认
        session.onConfirm?(Self.request(suppression: nil) { })
        try await Self.expectSheet(NSHostingController<ConfirmationDialog>.self, on: window)

        session.onEmptyCommitPrompt?(EmptyCommitRequest(isSequence: false, commit: { }, alternate: { }))
        try await Self.expectSheet(NSHostingController<ConfirmationDialog>.self, on: window)

        // 提交信息含注释的询问
        session.onCommentPrompt?(false) { _ in }
        try await Self.expectSheet(NSHostingController<CommitCommentsDialog>.self, on: window)

        try await Self.expectGitErrorSheet(in: fixture)
    }

    /// 空提交确认的备选按单个操作与序列分别是中止与跳过，内容区是不再提示的勾选框；
    /// 不勾选时三个按钮都不改警告设置，勾上后选哪个按钮都关掉警告，Cancel 不执行任何动作。
    @Test("空提交确认的备选与不再提示")
    func emptyCommitDialog() {
        let key = WorkingCopyPreferences.warnsEmptyCommit
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        for (isSequence, alternate) in [(false, "commit.empty.abort"), (true, "commit.empty.skip")] {
            let request = EmptyCommitRequest(isSequence: isSequence, commit: { }, alternate: { })
            let dialog = RepositoryWindowController.emptyCommitDialog(request) { }

            #expect(dialog.alternate?.title == AppLocalization.text(alternate))
            #expect(dialog.checkbox != nil)
        }

        // 没写过这项设置时警告是开着的
        let warns = { UserDefaults.standard.object(forKey: key) as? Bool ?? true }

        var committed = 0
        var alternated = 0

        let request = EmptyCommitRequest(
            isSequence: false,
            commit: { committed += 1 },
            alternate: { alternated += 1 }
        )

        let dialog = RepositoryWindowController.emptyCommitDialog(request) { }

        // 不勾选时三个按钮都不改警告设置；Cancel 不执行任何动作
        UserDefaults.standard.removeObject(forKey: key)
        dialog.cancel(false)
        dialog.alternate?.action(false)
        dialog.submit(false)

        #expect(UserDefaults.standard.object(forKey: key) == nil)
        #expect(committed == 1 && alternated == 1)

        // 勾上后 Cancel 同样关掉警告，仍不执行动作
        dialog.cancel(true)

        #expect(!warns())
        #expect(committed == 1 && alternated == 1)

        // 勾上后选备选或主按钮，关掉警告并执行各自的动作
        UserDefaults.standard.removeObject(forKey: key)
        dialog.alternate?.action(true)

        #expect(!warns())
        #expect(alternated == 2)

        UserDefaults.standard.removeObject(forKey: key)
        dialog.submit(true)

        #expect(!warns())
        #expect(committed == 2)
    }

    /// 带可以关掉的确认项时内容区是 “Do not ask me again”，左缘在对齐线；勾上后取消只关闭对话框，确认项保持打开，
    /// 勾上并确认后关掉这项确认，再执行操作；没有可以关掉的确认项时没有勾选框。
    @Test("勾选不再提醒后取消或确认", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func suppression() async throws {
        let confirmation = ServerConfirmation.deletePermanently
        let saved = UserDefaults.standard.object(forKey: confirmation.key)
        defer { UserDefaults.standard.set(saved, forKey: confirmation.key) }

        UserDefaults.standard.removeObject(forKey: confirmation.key)

        var performed = 0
        var closed = 0
        let checkbox = AppLocalization.text("dialog.doNotAskAgain")

        let dialog = ConfirmationDialog(
            request: Self.request(suppression: confirmation) { performed += 1 },
            close: { closed += 1 }
        )

        // 勾上后取消
        _ = await AccessibilityProbe.elements(
            pressing: [checkbox, AppLocalization.text("action.cancel")],
            until: { _ in closed > 0 }
        ) {
            dialog
        }

        #expect(performed == 0)
        #expect(confirmation.isEnabled)

        // 勾上后确认
        let elements = await AccessibilityProbe.elements(
            pressing: [checkbox, AppLocalization.text("working.discard")],
            until: { _ in performed > 0 }
        ) {
            dialog
        }

        let box = try #require(elements.first { $0.role == "AXCheckBox" && $0.name == checkbox })

        #expect(abs(box.frame.minX - DialogMetrics.alignment) <= 2)
        #expect(performed == 1)
        #expect(closed == 2)
        #expect(!confirmation.isEnabled)

        #expect(ConfirmationDialog(request: Self.request(suppression: nil) { }) { }.checkbox == nil)
    }
}

// MARK: - Helpers

extension ConfirmationDialogTests {
    /// 丢弃文件的确认请求。
    ///
    /// - Parameters:
    ///   - suppression: 可以关掉的确认项。
    ///   - action: 确认后执行的操作。
    private static func request(
        suppression: ServerConfirmation?,
        action: @escaping () -> Void
    ) -> ConfirmationRequest {
        ConfirmationRequest(
            title: AppLocalization.text("working.discard.title"),
            message: "Discard changes in “a.txt”.",
            submitTitle: AppLocalization.text("working.discard"),
            suppression: suppression,
            action: action
        )
    }

    /// Git 错误框挂成可以拉大的 sheet，以 `GitErrorDialog` 记住排好版的尺寸；记住的尺寸比内容宽时，下次照它打开。
    private static func expectGitErrorSheet(in fixture: NavigationTests.WindowFixture) async throws {
        let key = GitErrorDialogTests.frameKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        let controller = fixture.controller
        let window = try #require(controller.window)

        let failure = AppFailure(
            error: FailurePresentationTests.gitError(.pushRejected, ["push", "origin"]),
            opening: false,
            location: fixture.location,
            writing: true
        )

        UserDefaults.standard.removeObject(forKey: key)
        controller.showFailure(failure)

        let sheet = try await PromptDialogTests.attachedSheet(of: window)
        let dialog = try #require(sheet.contentViewController as? NSHostingController<GitErrorDialog>)

        #expect(sheet.styleMask.contains(.resizable))
        #expect(sheet.frameAutosaveName == "GitErrorDialog")
        #expect(savedFrameWidth() == sheet.frame.width)
        #expect(dialog.rootView.chooseAnother == nil)

        window.endSheet(sheet)
        await until { window.attachedSheet == nil }

        // 下次照记住的尺寸打开
        UserDefaults.standard.set("0 0 700 600 0 0 1470 923", forKey: key)
        controller.showFailure(failure)

        let resized = try await PromptDialogTests.attachedSheet(of: window)

        #expect(resized.frame.width == 700)

        window.endSheet(resized)
        await until { window.attachedSheet == nil }
    }

    /// 等窗口挂上 sheet，核对它的内容是这一类，再收起它。
    private static func expectSheet<Content: NSViewController>(
        _: Content.Type,
        on window: NSWindow
    ) async throws {
        let sheet = try await PromptDialogTests.attachedSheet(of: window)

        #expect(sheet.contentViewController is Content)

        window.endSheet(sheet)
        await until { window.attachedSheet == nil }
    }

    /// 记下的错误框宽度：偏好里的值以 “x y 宽 高” 开头；没有记下时为 nil。
    private static func savedFrameWidth() -> CGFloat? {
        let numbers = UserDefaults.standard.string(forKey: GitErrorDialogTests.frameKey)?
            .split(separator: " ")
            .compactMap { Double($0) }

        return numbers.flatMap { $0.count > 2 ? CGFloat($0[2]) : nil }
    }
}
