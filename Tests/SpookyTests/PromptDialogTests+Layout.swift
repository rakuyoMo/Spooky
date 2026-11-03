import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - PromptDialogTests + Layout

/// 询问的版式与勾选框：备选底栏的 Cancel 贴按钮组左端，勾选框只在选了主按钮或备选按钮时生效；
/// 提交信息含注释的两种询问与崩溃报告的询问。
///
/// 经辅助功能接口读本进程的窗口并按下控件，进程没有辅助功能权限时跳过。
extension PromptDialogTests {
    /// 备选底栏：Cancel 对齐对齐线，备选按钮与主按钮贴右端；勾上勾选框后选备选按钮，备选按钮的动作拿到勾选状态。
    @Test("备选按钮拿到勾选状态", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func alternateWithCheckbox() throws {
        var alternate: [Bool] = []
        var submitted = 0
        var closed = 0

        let elements = AccessibilityProbe.elements(
            pressing: ["Remember", "Other"],
            until: { _ in !alternate.isEmpty }
        ) {
            ConfirmationDialog(
                title: "Title",
                message: "Message",
                submitTitle: "OK",
                alternate: (title: "Other", action: { alternate.append($0) }),
                checkbox: "Remember",
                close: { closed += 1 }
            ) { _ in
                submitted += 1
            }
        }

        let cancel = try #require(DialogLayoutTests.button(AppLocalization.text("action.cancel"), in: elements))
        let other = try #require(DialogLayoutTests.button("Other", in: elements))
        let submit = try #require(DialogLayoutTests.button("OK", in: elements))
        let checkbox = try #require(elements.first { $0.role == "AXCheckBox" })

        #expect(abs(cancel.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(checkbox.frame.minX - DialogMetrics.alignment) <= 2)
        #expect(cancel.frame.maxX < other.frame.minX)
        #expect(abs(submit.frame.minX - other.frame.maxX - 8) <= 1)
        #expect(abs(480 - submit.frame.maxX - 20) <= 1)

        #expect(alternate == [true])
        #expect(submitted == 0)
        #expect(closed == 1)
    }

    /// 勾上勾选框后取消：只关闭对话框、执行取消的动作，勾选不生效。
    @Test("取消时勾选不生效", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func cancelWithCheckbox() {
        var submitted: [Bool] = []
        var cancelled = 0
        var closed = 0
        let cancel = AppLocalization.text("action.cancel")

        _ = AccessibilityProbe.elements(
            pressing: ["Remember", cancel],
            until: { _ in cancelled > 0 }
        ) {
            ConfirmationDialog(
                title: "Title",
                message: "Message",
                submitTitle: "OK",
                checkbox: "Remember",
                close: { closed += 1 },
                cancel: { cancelled += 1 }
            ) {
                submitted.append($0)
            }
        }

        #expect(submitted.isEmpty)
        #expect(cancelled == 1)
        #expect(closed == 1)
    }

    /// 提交信息含注释：能删除注释时 Cancel 对齐对齐线，Keep Comments 与 Remove Comments 贴右边 20，有不再询问的勾选框，
    /// 三个按钮在 480 里放不下时对话框随之加宽；去掉注释后为空时只有 Cancel 与 Keep Comments and Commit，没有勾选框。
    @Test("提交信息含注释的询问", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func commitComments() throws {
        let cancel = AppLocalization.text("action.cancel")
        let keep = AppLocalization.text("commit.keepComments")
        let remove = AppLocalization.text("commit.removeComments")
        let keepAndCommit = AppLocalization.text("commit.keepCommentsAndCommit")

        let dialog = CommitCommentsDialog(empty: false) { } finish: { _, _ in }
        let width = DialogLayoutTests.hosting(dialog).frame.width

        let removable = AccessibilityProbe.elements(
            width: width,
            until: { elements in elements.count { $0.role == "AXButton" } >= 3 }
        ) {
            dialog
        }

        let removableButtons = removable
            .filter { $0.role == "AXButton" }
            .sorted { $0.frame.minX < $1.frame.minX }

        #expect(removableButtons.map(\.name) == [cancel, keep, remove])
        #expect(abs((removableButtons.first?.frame.minX ?? 0) - DialogMetrics.alignment) <= 1)
        #expect(abs(width - (removableButtons.last?.frame.maxX ?? 0) - 20) <= 1)
        #expect(removable.contains {
            $0.role == "AXCheckBox" && $0.name == AppLocalization.text("commit.doNotAskAgain")
        })

        let commentsOnly = AccessibilityProbe.elements(until: { $0.contains { $0.name == keepAndCommit } }) {
            CommitCommentsDialog(empty: true) { } finish: { _, _ in }
        }

        let commentsOnlyButtons = commentsOnly
            .filter { $0.role == "AXButton" }
            .sorted { $0.frame.minX < $1.frame.minX }

        #expect(commentsOnlyButtons.map(\.name) == [cancel, keepAndCommit])
        #expect(!commentsOnly.contains { $0.role == "AXCheckBox" })
    }

    /// 崩溃报告：Don’t Report 在取消的位置，Report on GitHub… 是主按钮；勾上 “总是发送” 后选 Don’t Report 不记下，
    /// 选报告才记下。
    @Test("崩溃报告的询问", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func crashReport() throws {
        let domain = "com.rakuyo.spooky.tests.crash." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }

        let always = AppLocalization.text("settings.crashReports.always")
        let dontReport = AppLocalization.text("crash.dontReport")
        let report = AppLocalization.text("crash.report")

        for (choice, reports) in [(dontReport, false), (report, true)] {
            var closed = 0
            var reported = false

            let elements = AccessibilityProbe.elements(pressing: [always, choice], until: { _ in closed > 0 }) {
                CrashReporter.askDialog(defaults: defaults, close: { closed += 1 }) { reported = true }
            }

            let buttons = elements.filter { $0.role == "AXButton" }.sorted { $0.frame.minX < $1.frame.minX }

            #expect(buttons.map(\.name) == [dontReport, report])
            #expect(elements.contains {
                $0.role == "AXStaticText" && $0.value == AppLocalization.text("crash.title")
            })
            #expect(reported == reports)
            #expect(defaults.bool(forKey: CrashReporter.alwaysSendKey) == reports)
        }
    }
}
