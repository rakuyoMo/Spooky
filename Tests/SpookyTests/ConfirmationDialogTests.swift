import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ConfirmationDialogTests

/// 确认对话框：会话的确认与空提交的确认都以骨架的确认版挂成 sheet；
/// “Do not ask me again” 在内容区、对齐 120 pt 的对齐线，只在确认时生效；空提交的 “Do not show this warning again” 选哪个按钮都生效。
///
/// 读勾选框与按钮的几项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct ConfirmationDialogTests {
    /// 丢弃文件的确认挂成确认对话框的 sheet；合并没有任何改动时，提交前的空提交确认同样是确认对话框。
    @Test("确认对话框与空提交确认挂成 sheet")
    func presentation() async throws {
        let fixture = try await NavigationTests.makeWindow()
        defer { fixture.close() }

        let controller = fixture.controller
        let session = controller.session
        let window = try #require(controller.window)

        // 丢弃文件：确认对话框挂在窗口上
        try Data("changed\n".utf8).write(to: fixture.directory.appending(path: "a.txt"))
        session.refresh(full: true)
        await session.waitForRefresh()

        session.discard(session.status?.entries ?? [])

        let confirmation = try await PromptDialogTests.attachedSheet(of: window)
        #expect(confirmation.contentViewController is NSHostingController<ConfirmationDialog>)
        window.endSheet(confirmation)

        // 合并冲突按本地版本解决后没有任何改动，提交前确认空提交
        try await Self.prepareEmptyMerge(in: fixture)
        session.refresh(full: true)
        await session.waitForRefresh()
        try await FileViewsTests.wait { session.context?.operation == .merge && session.commitsEmpty }

        let key = WorkingCopyPreferences.warnsEmptyCommit
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        UserDefaults.standard.removeObject(forKey: key)
        session.confirmCommit(("merge", ""), amend: false, signOff: false, skipHooks: false)

        let empty = try await PromptDialogTests.attachedSheet(of: window)
        #expect(empty.contentViewController is NSHostingController<ConfirmationDialog>)
        window.endSheet(empty)
    }

    /// 空提交的两种确认：标题相同，主按钮保留空提交，备选按单个操作与序列分别是中止与跳过，内容区是不再提示的勾选框；
    /// 勾上后选哪个按钮都关掉警告，Cancel 不执行任何动作。
    @Test("空提交确认的内容与不再提示", arguments: [false, true])
    func emptyCommitDialog(isSequence: Bool) {
        let key = WorkingCopyPreferences.warnsEmptyCommit
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        // 没写过这项设置时警告是开着的
        let warns = { UserDefaults.standard.object(forKey: key) as? Bool ?? true }

        var committed = 0
        var alternated = 0

        let request = EmptyCommitRequest(
            isSequence: isSequence,
            commit: { committed += 1 },
            alternate: { alternated += 1 }
        )

        let dialog = RepositoryWindowController.emptyCommitDialog(request) { }

        let keys = isSequence
            ? (message: "commit.empty.sequenceMessage", alternate: "commit.empty.skip")
            : (message: "commit.empty.message", alternate: "commit.empty.abort")

        #expect(dialog.title == AppLocalization.text("commit.empty.title"))
        #expect(dialog.message == AppLocalization.text(keys.message))
        #expect(dialog.submitTitle == AppLocalization.text("commit.empty.use"))
        #expect(dialog.alternate?.title == AppLocalization.text(keys.alternate))
        #expect(dialog.cancelTitle == AppLocalization.text("action.cancel"))
        #expect(dialog.checkbox == AppLocalization.text("commit.empty.doNotShowAgain"))

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

    /// 带可以关掉的确认项时内容区是 “Do not ask me again”，左缘在对齐线；勾上并确认后关掉这项确认，再执行操作。
    @Test("勾选不再提醒并确认", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func suppressAndConfirm() {
        let confirmation = ServerConfirmation.discardChunks
        let saved = UserDefaults.standard.object(forKey: confirmation.key)
        defer { UserDefaults.standard.set(saved, forKey: confirmation.key) }

        UserDefaults.standard.removeObject(forKey: confirmation.key)

        var performed = 0
        var closed = 0
        let checkbox = AppLocalization.text("dialog.doNotAskAgain")
        let submit = AppLocalization.text("working.discard")

        let elements = AccessibilityProbe.elements(
            pressing: [checkbox, submit],
            until: { _ in performed > 0 }
        ) {
            ConfirmationDialog(
                request: Self.request(suppression: confirmation) { performed += 1 },
                close: { closed += 1 }
            )
        }

        let box = elements.first { $0.role == "AXCheckBox" && $0.name == checkbox }

        #expect(abs((box?.frame.minX ?? 0) - DialogMetrics.alignment) <= 2)
        #expect(performed == 1)
        #expect(closed == 1)
        #expect(!confirmation.isEnabled)
    }

    /// 勾上 “Do not ask me again” 后取消：只关闭对话框，确认项保持打开，操作不执行。
    @Test("勾选不再提醒后取消", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func suppressAndCancel() {
        let confirmation = ServerConfirmation.discardChunks
        let saved = UserDefaults.standard.object(forKey: confirmation.key)
        defer { UserDefaults.standard.set(saved, forKey: confirmation.key) }

        UserDefaults.standard.removeObject(forKey: confirmation.key)

        var performed = 0
        var closed = 0
        let checkbox = AppLocalization.text("dialog.doNotAskAgain")
        let cancel = AppLocalization.text("action.cancel")

        _ = AccessibilityProbe.elements(
            pressing: [checkbox, cancel],
            until: { _ in closed > 0 }
        ) {
            ConfirmationDialog(
                request: Self.request(suppression: confirmation) { performed += 1 },
                close: { closed += 1 }
            )
        }

        #expect(performed == 0)
        #expect(closed == 1)
        #expect(confirmation.isEnabled)
    }

    /// 没有可以关掉的确认项时只有头部与底栏：标题、说明，Cancel 与写动作的主按钮，没有勾选框。
    @Test("确认版只有头部与底栏", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func plainConfirmation() {
        let submit = AppLocalization.text("working.discard")

        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXButton" && $0.name == submit } }
        ) {
            ConfirmationDialog(request: Self.request(suppression: nil) { }) { }
        }

        let title = AppLocalization.text("working.discard.title")
        let buttons = elements.filter { $0.role == "AXButton" }.map(\.name)

        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == title })
        #expect(buttons.contains(AppLocalization.text("action.cancel")))
        #expect(buttons.contains(submit))
        #expect(!elements.contains { $0.role == "AXCheckBox" })
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

    /// 让 `side` 与 `main` 都改过 `a.txt`，合并出冲突后按本地版本解决：合并进行中，工作区没有任何改动。
    private static func prepareEmptyMerge(in fixture: NavigationTests.WindowFixture) async throws {
        let runner = try #require(fixture.controller.session.runner)
        let file = fixture.directory.appending(path: "a.txt")

        _ = try await runner.run(["checkout", "-q", "--", "a.txt"])
        _ = try await runner.run(["branch", "side"])

        try Data("main\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-am", "main"])

        _ = try await runner.run(["checkout", "-q", "side"])
        try Data("side\n".utf8).write(to: file)
        _ = try await runner.run(["commit", "-q", "-am", "side"])
        _ = try await runner.run(["checkout", "-q", "main"])

        _ = try? await runner.run(["merge", "-q", "side"])
        _ = try await runner.run(["checkout", "--ours", "--", "a.txt"])
        _ = try await runner.run(["add", "a.txt"])
    }
}
