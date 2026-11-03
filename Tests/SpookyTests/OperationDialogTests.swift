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
/// 读标题、按钮与位置的几项经辅助功能接口读本进程的窗口，进程没有辅助功能权限时跳过。
@MainActor
struct OperationDialogTests {
    /// 新建分支的标题是 Create New Branch，跟踪远端分支的主按钮是 Create，推送的标题与主按钮都按本地分支是不是 HEAD 写；
    /// 其余种类的标题与主按钮是动作名，同步的主按钮是 Sync HEAD。
    @Test("标题与主按钮的资源键")
    func keys() {
        typealias Kind = RepositoryActionRequest.Kind

        #expect(Kind.create.titleKey(pushesHead: false) == "branch.create.title")
        #expect(Kind.create.submitKey(pushesHead: false) == "branch.create")
        #expect(Kind.track.titleKey(pushesHead: false) == "branch.track")
        #expect(Kind.track.submitKey(pushesHead: false) == "branch.track.submit")

        #expect(Kind.push.titleKey(pushesHead: true) == "sync.pushHead")
        #expect(Kind.push.submitKey(pushesHead: true) == "sync.pushHead")
        #expect(Kind.push.titleKey(pushesHead: false) == "sync.pushBranch")
        #expect(Kind.push.submitKey(pushesHead: false) == "sync.pushBranch")

        for kind in [Kind.fetch, .pull, .publish, .merge] {
            #expect(kind.titleKey(pushesHead: true) == kind.rawValue)
            #expect(kind.submitKey(pushesHead: true) == kind.rawValue)
        }

        #expect(SyncDialogKind.sync.submitKey == "sync.syncHead")
        #expect(SyncDialogKind.rebase.submitKey == "sync.rebaseHead")
    }

    /// 推送对话框宽 450，其余分支与同步的对话框宽 480。
    @Test("宽度")
    func widths() {
        let session = RepositorySession(loadStatus: { _ in throw CancellationError() })

        let kinds: [RepositoryActionRequest.Kind] = [.create, .track, .fetch, .pull, .push, .publish, .merge]

        for kind in kinds {
            let dialog = RepositoryOperationDialog(
                session: session,
                request: RepositoryActionRequest(kind: kind),
                cancel: { },
                submit: { _, _, _, _ in false }
            )

            let width = DialogLayoutTests.hosting(dialog).frame.width

            #expect(width == (kind == .push ? 450 : 480), "\(kind)")
        }

        for kind in [SyncDialogKind.sync, .rebase, .forcePush, .pushRevision] {
            let dialog = SyncDialog(session: session, kind: kind, close: { })

            #expect(DialogLayoutTests.hosting(dialog).frame.width == 480)
        }
    }

    /// 推送 HEAD 分支时标题与主按钮是 Push HEAD；本地分支拖到远端分支这类指定了别的本地分支的推送是 Push Branch。
    @Test("推送的标题随本地分支变化", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func pushTitles() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let head = Self.elements(of: RepositoryActionRequest(kind: .push), in: fixture.session)

        try Self.expectTitle(
            AppLocalization.text("sync.pushHead"),
            submit: AppLocalization.text("sync.pushHead"),
            in: head
        )

        // 与本地分支 side 拖到 origin/main 时的请求相同
        let dragged = RepositoryActionRequest(
            kind: .push,
            reference: "refs/remotes/origin/main",
            remote: "origin",
            localBranch: "side"
        )

        let branch = Self.elements(of: dragged, in: fixture.session)

        try Self.expectTitle(
            AppLocalization.text("sync.pushBranch"),
            submit: AppLocalization.text("sync.pushBranch"),
            in: branch
        )
    }

    /// 新建分支、跟踪远端分支与同步对话框读出的标题与主按钮。
    @Test("标题与主按钮", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func titles() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let create = Self.elements(of: RepositoryActionRequest(kind: .create), in: fixture.session)

        try Self.expectTitle(
            AppLocalization.text("branch.create.title"),
            submit: AppLocalization.text("branch.create"),
            in: create
        )

        let track = Self.elements(of: RepositoryActionRequest(kind: .track), in: fixture.session)

        try Self.expectTitle(
            AppLocalization.text("branch.track"),
            submit: AppLocalization.text("branch.track.submit"),
            in: track
        )

        let sync = AccessibilityProbe.elements(until: Self.hasDialog) {
            SyncDialog(session: fixture.session, kind: .sync, close: { })
        }

        try Self.expectTitle(
            AppLocalization.text("sync.syncHead"),
            submit: AppLocalization.text("sync.syncHead"),
            in: sync
        )
    }

    /// 跟踪远端分支的两行相隔 8；新建分支的勾选框到说明、说明到下一个勾选框都是 8，三个勾选框在输入列。
    @Test("行距与勾选框说明的间距", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func spacing() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let track = Self.elements(of: RepositoryActionRequest(kind: .track), in: fixture.session)
        let popUp = try #require(track.first { $0.role == "AXPopUpButton" })
        let field = try #require(track.first { $0.role == "AXTextField" })

        #expect(abs(field.frame.minY - popUp.frame.maxY - 8) <= 1.5)

        let create = Self.elements(of: RepositoryActionRequest(kind: .create), in: fixture.session)
        let name = try #require(create.first { $0.role == "AXTextField" })
        let checkBoxes = create.filter { element in
            element.role == "AXCheckBox" && element.name != AppLocalization.text("dialog.options")
        }

        try #require(checkBoxes.count == 3)

        for checkBox in checkBoxes {
            #expect(abs(checkBox.frame.minX - name.frame.minX) <= 1, "\(checkBox.name)")
        }

        let pin = try #require(checkBoxes.first { $0.name == AppLocalization.text("branch.pin") })
        let pinHelp = try Self.text(AppLocalization.text("branch.pin.help"), in: create)
        let checkout = try #require(
            checkBoxes.first { $0.name == AppLocalization.text("branch.checkoutCreated") }
        )

        #expect(abs(pinHelp.frame.minY - pin.frame.maxY - 8) <= 1.5)
        #expect(abs(checkout.frame.minY - pinHelp.frame.maxY - 8) <= 1.5)
    }

    /// 合并里会变为不可用的三个勾选框仍在输入列；合并选项区里的 Skip Hooks 与说明相隔 8，发布分支与同步相隔 4。
    @Test("Skip Hooks 的间距与不可用的勾选框", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func skipHooks() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let options = AppLocalization.text("dialog.options")

        let merge = Self.elements(
            of: RepositoryActionRequest(kind: .merge),
            in: fixture.session,
            pressing: options
        )
        let popUp = try #require(merge.first { $0.role == "AXPopUpButton" })

        for key in ["merge.squash", "merge.alwaysCommit", "merge.autoCommit"] {
            let checkBox = try #require(
                merge.first { $0.role == "AXCheckBox" && $0.name == AppLocalization.text(key) }
            )

            #expect(abs(checkBox.frame.minX - popUp.frame.minX) <= 3, "\(key)")
        }

        try Self.expectSkipHooksSpacing(8, in: merge)

        let publish = Self.elements(
            of: RepositoryActionRequest(kind: .publish),
            in: fixture.session,
            pressing: options
        )

        try Self.expectSkipHooksSpacing(4, in: publish)

        let sync = AccessibilityProbe.elements(pressing: [options], until: Self.hasSkipHooks) {
            SyncDialog(session: fixture.session, kind: .sync, close: { })
        }

        try Self.expectSkipHooksSpacing(4, in: sync)
    }

    /// 下拉填满输入列：跟踪远端分支的下拉伸到右边距 20 处；安全强推的输入列比上限宽，两个下拉正好 320；
    /// 推送的下拉不超过 320，拉取与合并不超过 360，发布不超过 350。
    @Test("下拉的宽度上限", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func pickerWidths() async throws {
        let fixture = try await OperationWiringTests.makeFixture()
        defer { fixture.close() }

        let forcePush = AccessibilityProbe.elements(
            until: { elements in elements.count { $0.role == "AXPopUpButton" } == 2 }
        ) {
            SyncDialog(session: fixture.session, kind: .forcePush, close: { })
        }

        let popUps = forcePush.filter { $0.role == "AXPopUpButton" }

        try #require(popUps.count == 2)

        for popUp in popUps {
            #expect(abs(popUp.frame.width - 320) <= 1)
        }

        let track = Self.elements(of: RepositoryActionRequest(kind: .track), in: fixture.session)
        let remoteBranch = try #require(track.first { $0.role == "AXPopUpButton" })

        #expect(abs(remoteBranch.frame.maxX - (480 - 20)) <= 1)

        let limits: [(RepositoryActionRequest.Kind, CGFloat)] = [
            (.push, 320),
            (.pull, 360),
            (.merge, 360),
            (.publish, 350),
        ]

        for (kind, limit) in limits {
            let elements = Self.elements(of: RepositoryActionRequest(kind: kind), in: fixture.session)
            let popUps = elements.filter { $0.role == "AXPopUpButton" }

            #expect(!popUps.isEmpty, "\(kind)")

            for popUp in popUps {
                #expect(popUp.frame.width <= limit + 1, "\(kind)")
            }
        }
    }
}

// MARK: - Helpers

extension OperationDialogTests {
    /// 打开这个请求的操作对话框，读出全部元素；给了名称时先按下这个控件，如 Options 开关。
    private static func elements(
        of request: RepositoryActionRequest,
        in session: RepositorySession,
        pressing name: String? = nil
    ) -> [AccessibilityProbe.Element] {
        AccessibilityProbe.elements(
            width: request.kind == .push ? 450 : 480,
            pressing: name.map { [$0] } ?? [],
            until: name == nil ? hasDialog : hasSkipHooks
        ) {
            RepositoryOperationDialog(
                session: session,
                request: request,
                cancel: { },
                submit: { _, _, _, _ in false }
            )
        }
    }

    /// 标题是这段文字，底栏有这个主按钮。
    private static func expectTitle(
        _ title: String,
        submit: String,
        in elements: [AccessibilityProbe.Element]
    ) throws {
        _ = try text(title, in: elements)

        #expect(elements.contains { $0.role == "AXButton" && $0.name == submit }, "\(submit)")
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
