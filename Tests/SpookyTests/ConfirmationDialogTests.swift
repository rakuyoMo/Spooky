import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - ConfirmationDialogTests

/// 确认对话框：会话的确认以骨架的确认版挂成 sheet，空合并提交的询问仍是系统提示框；
/// “Do not ask me again” 在内容区、对齐 120 pt 的对齐线，只在确认时生效。
///
/// 读勾选框与按钮的几项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct ConfirmationDialogTests {
    /// 丢弃文件的确认挂成确认对话框的 sheet；合并没有暂存的改动时，提交前的询问是系统提示框，按钮是建空合并提交与中止。
    @Test("确认对话框与空合并提交的系统提示框")
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

        let confirmation = try await Self.attachedSheet(of: window)
        #expect(confirmation.contentViewController is NSHostingController<ConfirmationDialog>)
        window.endSheet(confirmation)

        // 合并冲突按本地版本解决后没有暂存的改动，提交前询问
        try await Self.prepareEmptyMerge(in: fixture)
        session.refresh(full: true)
        await session.waitForRefresh()
        try await FileViewsTests.wait { session.context?.operation == .merge }

        session.confirmCommit(("merge", ""), amend: false, signOff: false, skipHooks: false)

        let alert = try await Self.attachedSheet(of: window)
        let buttons = Self.subviews(NSButton.self, in: try #require(alert.contentView)).map(\.title)

        #expect(alert.contentViewController == nil)
        #expect(buttons.contains(AppLocalization.text("working.emptyMerge")))
        #expect(buttons.contains(AppLocalization.text("working.abort")))

        window.endSheet(alert)
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

    /// 让 `side` 与 `main` 都改过 `a.txt`，合并出冲突后按本地版本解决：合并进行中，没有暂存的改动。
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

    /// 等窗口挂上 sheet，最多等 5 秒。
    private static func attachedSheet(of window: NSWindow) async throws -> NSWindow {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))

        while window.attachedSheet == nil, .now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        return try #require(window.attachedSheet)
    }

    /// 视图树里某一类的全部子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
