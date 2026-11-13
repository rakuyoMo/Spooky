import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - OperationDialogTests

/// 分支与同步的操作对话框：标题与主按钮按种类取，推送随所选本地分支是不是 HEAD 变化；推送宽 450、其余 480；
/// 表单行距 8，勾选框与说明相隔 8，几处 Skip Hooks 相隔 4；下拉不超过各自的上限。
///
/// 读标题、按钮与位置的一项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct OperationDialogTests {
    /// 推送对话框宽 450，其余分支与同步的对话框宽 480。
    @Test("宽度")
    func widths() {
        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })

        for kind in [RepositoryActionRequest.Kind.create, .push] {
            let dialog = RepositoryOperationDialog(
                session: session,
                request: RepositoryActionRequest(kind: kind),
                cancel: { },
                submit: { _, _, _, _, _ in false }
            )

            let width = DialogLayoutTests.hosting(dialog).frame.width

            #expect(width == (kind == .push ? 450 : 480), "\(kind)")
        }

        let sync = SyncDialog(session: session, kind: .forcePush, close: { })

        #expect(DialogLayoutTests.hosting(sync).frame.width == 480)
    }

    /// 合并只在有冲突时有说明：干净、快进、已并入与 HEAD 自身都没有说明，无法检查时仍有；
    /// 拉取等对话框也说明已确认没有冲突的结果；冲突说明按单复数写出文件数与 HEAD 分支。
    @Test("合并预览的说明")
    func mergePreviewMessages() {
        let message = { MergeabilityPreview.message(for: $0, showsCleanResults: $1, head: "main") }

        #expect(message(.clean, false) == nil)
        #expect(message(.unchanged, false) == nil)
        #expect(message(.unavailable("unknown option"), false) == AppLocalization.text("merge.unavailable"))
        #expect(message(.clean, true) == AppLocalization.text("merge.clean"))
        #expect(message(.unchanged, true) == AppLocalization.text("merge.unchanged"))

        // 冲突说明在两种对话框里相同
        for showsClean in [false, true] {
            let one = message(.conflicts(["a"]), showsClean)
            let many = message(.conflicts(["a", "b"]), showsClean)

            #expect(one == AppLocalization.text("merge.conflicts.one", "main"))
            #expect(many == AppLocalization.text("merge.conflicts", "main", 2))
        }
    }

    /// 同一个仓库上依次打开推送、新建与跟踪分支、合并、发布、拉取、同步与安全强推的对话框，读出标题、主按钮、行距与下拉宽度，
    /// 新建与跟踪分支的检出默认值，以及合并预览的冲突说明换行。
    @Test("标题、主按钮、行距、下拉宽度、检出默认值与合并预览换行", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func layout() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        // 新建分支的检出偏好从没有保存值开始，结束后恢复
        let saved = UserDefaults.standard.object(forKey: "checkoutCreatedBranch")
        defer { UserDefaults.standard.set(saved, forKey: "checkoutCreatedBranch") }

        UserDefaults.standard.removeObject(forKey: "checkoutCreatedBranch")

        try await Self.expectPush(in: fixture.session)
        try await Self.expectBranchForms(in: fixture.session)
        try await Self.expectOptions(in: fixture.session)
        try await Self.expectSyncDialogs(in: fixture.session)
        try await Self.expectMergePreviewWraps(in: fixture)
    }
}

// MARK: - Dialogs

extension OperationDialogTests {
    /// 推送 HEAD 分支时标题与主按钮是 Push HEAD，下拉不超过 320；分支右键菜单这类指定了别的本地分支的推送是 Push Branch。
    private static func expectPush(in session: RepositorySession) async throws {
        let head = await elements(of: RepositoryActionRequest(kind: .push), in: session)

        try expectTitle("sync.pushHead", submit: "sync.pushHead", in: head)
        try expectPopUps(in: head, atMost: 320)

        // 与右键本地分支 side 推送时的请求相同
        let branch = await elements(of: RepositoryActionRequest(kind: .push, localBranch: "side"), in: session)

        try expectTitle("sync.pushBranch", submit: "sync.pushBranch", in: branch)
    }

    /// 新建分支的标题是 Create New Branch，勾选框到说明、说明到下一个勾选框都是 8，三个勾选框在输入列；
    /// 跟踪远端分支的主按钮是 Create，两行相隔 8，下拉伸到右边距 20 处。
    ///
    /// 新建分支的检出没有保存值时不勾，有保存值时按保存值；跟踪远端分支的检出总是勾选，不随新建分支的偏好变化。
    private static func expectBranchForms(in session: RepositorySession) async throws {
        let create = await elements(of: RepositoryActionRequest(kind: .create), in: session)

        try expectTitle("branch.create.title", submit: "branch.create", in: create)

        let name = try #require(create.first { $0.role == "AXTextField" })
        let checkBoxes = create.filter { element in
            element.role == "AXCheckBox" && element.name != AppLocalization.text("dialog.options")
        }

        try #require(checkBoxes.count == 3)

        for checkBox in checkBoxes {
            #expect(abs(checkBox.frame.minX - name.frame.minX) <= 1, "\(checkBox.name)")
        }

        let pin = try #require(checkBoxes.first { $0.name == AppLocalization.text("branch.pin") })
        let pinHelp = try text(AppLocalization.text("branch.pin.help"), in: create)
        let checkout = try #require(
            checkBoxes.first { $0.name == AppLocalization.text("branch.checkoutCreated") }
        )

        #expect(abs(pinHelp.frame.minY - pin.frame.maxY - 8) <= 1.5)
        #expect(abs(checkout.frame.minY - pinHelp.frame.maxY - 8) <= 1.5)
        #expect(checkout.value == "0")

        // 保存过勾选时按保存值
        UserDefaults.standard.set(true, forKey: "checkoutCreatedBranch")

        let checked = await elements(of: RepositoryActionRequest(kind: .create), in: session)

        #expect(checked.contains { $0.role == "AXCheckBox" && $0.name == checkout.name && $0.value == "1" })

        UserDefaults.standard.set(false, forKey: "checkoutCreatedBranch")

        // 跟踪远端分支
        let track = await elements(of: RepositoryActionRequest(kind: .track), in: session)

        try expectTitle("branch.track", submit: "branch.track.submit", in: track)

        let popUp = try #require(track.first { $0.role == "AXPopUpButton" })
        let field = try #require(track.first { $0.role == "AXTextField" })

        #expect(abs(field.frame.minY - popUp.frame.maxY - 8) <= 1.5)
        #expect(abs(popUp.frame.maxX - (480 - 20)) <= 1)

        let trackCheckout = try #require(
            track.first { $0.role == "AXCheckBox" && $0.name == AppLocalization.text("branch.track.checkout") }
        )

        #expect(trackCheckout.value == "1")
    }

    /// 合并里会变为不可用的三个勾选框仍在输入列，选项区里的 Skip Hooks 与说明相隔 8，下拉不超过 360；
    /// 发布的 Skip Hooks 与说明相隔 4，下拉不超过 350；拉取的下拉不超过 360。
    private static func expectOptions(in session: RepositorySession) async throws {
        let options = AppLocalization.text("dialog.options")
        let merge = await elements(of: RepositoryActionRequest(kind: .merge), in: session, pressing: options)
        let popUp = try #require(merge.first { $0.role == "AXPopUpButton" })

        for key in ["merge.squash", "merge.alwaysCommit", "merge.autoCommit"] {
            let checkBox = try #require(
                merge.first { $0.role == "AXCheckBox" && $0.name == AppLocalization.text(key) }
            )

            #expect(abs(checkBox.frame.minX - popUp.frame.minX) <= 3, "\(key)")
        }

        try expectSkipHooksSpacing(8, in: merge)
        try expectPopUps(in: merge, atMost: 360)

        // 发布与拉取
        let publish = await elements(of: RepositoryActionRequest(kind: .publish), in: session, pressing: options)

        try expectSkipHooksSpacing(4, in: publish)
        try expectPopUps(in: publish, atMost: 350)

        let pull = await elements(of: RepositoryActionRequest(kind: .pull), in: session)

        try expectPopUps(in: pull, atMost: 360)
    }

    /// 同步的标题与主按钮是 Sync HEAD，Skip Hooks 与说明相隔 4；安全强推的输入列比上限宽，两个下拉正好 320。
    private static func expectSyncDialogs(in session: RepositorySession) async throws {
        let sync = await AccessibilityProbe.elements(
            pressing: [AppLocalization.text("dialog.options")],
            until: hasSkipHooks
        ) {
            SyncDialog(session: session, kind: .sync, close: { })
        }

        try expectTitle("sync.syncHead", submit: "sync.syncHead", in: sync)
        try expectSkipHooksSpacing(4, in: sync)

        // 安全强推
        let forcePush = await AccessibilityProbe.elements(
            until: { elements in elements.count { $0.role == "AXPopUpButton" } == 2 }
        ) {
            SyncDialog(session: session, kind: .forcePush, close: { })
        }

        let popUps = forcePush.filter { $0.role == "AXPopUpButton" }

        try #require(popUps.count == 2)

        for popUp in popUps {
            #expect(abs(popUp.frame.width - 320) <= 1)
        }
    }

    /// 合并预览的冲突说明在对话框里放不下一行时换行，HEAD 分支名与冲突数不被截掉。
    private static func expectMergePreviewWraps(in fixture: OperationWiringTests.Fixture) async throws {
        let runner = fixture.runner

        // 从 A 起一个分支，新增与 main 同名而内容不同的 B.txt，并入 main 时两边都新增而冲突
        _ = try await runner.run(["checkout", "-q", "-b", "clash", try #require(fixture.ids["A"])])
        try Data("clash\n".utf8).write(to: fixture.directory.appending(path: "B.txt"))
        _ = try await runner.run(["add", "--all"])
        _ = try await runner.run(["commit", "-q", "-m", "Clash"])
        _ = try await runner.run(["checkout", "-q", "main"])

        let message = AppLocalization.text("merge.conflicts.one", "main")
        let merge = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.value == message } }
        ) {
            RepositoryOperationDialog(
                session: fixture.session,
                request: RepositoryActionRequest(kind: .merge, reference: "refs/heads/clash"),
                cancel: { },
                submit: { _, _, _, _, _ in false }
            )
        }

        // 12 pt 的说明至少占两行
        #expect(try text(message, in: merge).frame.height >= 2 * 12)
    }
}

// MARK: - Helpers

extension OperationDialogTests {
    /// 打开这个请求的操作对话框，读出全部元素；给了名称时先按下这个控件，如 Options 开关。
    private static func elements(
        of request: RepositoryActionRequest,
        in session: RepositorySession,
        pressing name: String? = nil
    ) async -> [AccessibilityProbe.Element] {
        await AccessibilityProbe.elements(
            width: request.kind == .push ? 450 : 480,
            pressing: name.map { [$0] } ?? [],
            until: name == nil ? hasDialog : hasSkipHooks
        ) {
            RepositoryOperationDialog(
                session: session,
                request: request,
                cancel: { },
                submit: { _, _, _, _, _ in false }
            )
        }
    }

    /// 标题是这个资源键的文字，底栏有这个资源键的主按钮。
    private static func expectTitle(
        _ titleKey: String,
        submit submitKey: String,
        in elements: [AccessibilityProbe.Element]
    ) throws {
        let submit = AppLocalization.text(submitKey)

        _ = try text(AppLocalization.text(titleKey), in: elements)

        #expect(elements.contains { $0.role == "AXButton" && $0.name == submit }, "\(submit)")
    }

    /// 读到了下拉，且每个都不超过这个宽度。
    private static func expectPopUps(in elements: [AccessibilityProbe.Element], atMost limit: CGFloat) throws {
        let popUps = elements.filter { $0.role == "AXPopUpButton" }

        try #require(!popUps.isEmpty)

        for popUp in popUps {
            #expect(popUp.frame.width <= limit + 1)
        }
    }

    /// Skip Hooks 的勾选框到它的说明相隔这么多。
    private static func expectSkipHooksSpacing(
        _ spacing: CGFloat,
        in elements: [AccessibilityProbe.Element]
    ) throws {
        let title = AppLocalization.text("sync.skipHooks")
        let checkBox = try #require(elements.first { $0.role == "AXCheckBox" && $0.name == title })
        let help = try text(AppLocalization.text("sync.skipHooks.help"), in: elements)

        #expect(abs(help.frame.minY - checkBox.frame.maxY - spacing) <= 1.5)
    }

    /// 显示这段文字的元素。
    private static func text(
        _ value: String,
        in elements: [AccessibilityProbe.Element]
    ) throws -> AccessibilityProbe.Element {
        try #require(elements.first { $0.role == "AXStaticText" && $0.value == value }, "\(value)")
    }

    /// 底栏的按钮与表单的控件都读到了。
    private static func hasDialog(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.count { $0.role == "AXButton" } >= 2
            && elements.contains { ["AXPopUpButton", "AXTextField", "AXComboBox"].contains($0.role) }
    }

    /// 展开的选项区里读到了 Skip Hooks 的说明。
    private static func hasSkipHooks(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.value == AppLocalization.text("sync.skipHooks.help") }
    }
}
