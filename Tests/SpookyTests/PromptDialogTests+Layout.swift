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
    /// 备选底栏：Cancel 与勾选框对齐对齐线，备选按钮与主按钮贴右端；勾上勾选框后选备选按钮，备选按钮的动作拿到勾选状态；
    /// 勾上后取消时关闭对话框，取消的动作收到勾选状态，主按钮的动作不执行。
    @Test("勾选状态交给选中按钮的动作", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func checkbox() async throws {
        var alternate: [Bool] = []
        var cancelled: [Bool] = []
        var submitted = 0
        var closed = 0

        let dialog = ConfirmationDialog(
            title: "Title",
            message: "Message",
            submitTitle: "OK",
            alternate: (title: "Other", action: { alternate.append($0) }),
            checkbox: "Remember",
            close: { closed += 1 },
            cancel: { cancelled.append($0) }
        ) { _ in
            submitted += 1
        }

        let elements = await AccessibilityProbe.elements(
            pressing: ["Remember", "Other"],
            until: { _ in !alternate.isEmpty }
        ) {
            dialog
        }

        let cancel = try #require(DialogLayoutTests.button(AppLocalization.text("action.cancel"), in: elements))
        let other = try #require(DialogLayoutTests.button("Other", in: elements))
        let submit = try #require(DialogLayoutTests.button("OK", in: elements))
        let box = try #require(elements.first { $0.role == "AXCheckBox" })

        #expect(abs(cancel.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(box.frame.minX - DialogMetrics.alignment) <= 2)
        #expect(cancel.frame.maxX < other.frame.minX)
        #expect(abs(submit.frame.minX - other.frame.maxX - 12) <= 1)
        #expect(abs(480 - submit.frame.maxX - 20) <= 1)
        #expect(alternate == [true])

        // 勾上后取消
        _ = await AccessibilityProbe.elements(
            pressing: ["Remember", AppLocalization.text("action.cancel")],
            until: { _ in !cancelled.isEmpty }
        ) {
            dialog
        }

        #expect(cancelled == [true])
        #expect(alternate == [true])
        #expect(submitted == 0)
        #expect(closed == 2)
    }

    /// 崩溃报告：Don’t Report 在取消的位置，Report on GitHub… 是主按钮；勾上 “总是发送” 后选 Don’t Report 不记下，
    /// 选报告才记下。
    @Test("崩溃报告的询问", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func crashReport() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.crash." + UUID().uuidString)

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defer { try? FileManager.default.removeItem(at: directory) }

        let always = AppLocalization.text("settings.crashReports.always")
        let dontReport = AppLocalization.text("crash.dontReport")
        let report = AppLocalization.text("crash.report")

        for (choice, reports) in [(dontReport, false), (report, true)] {
            var closed = 0
            var reported = false

            let elements = await AccessibilityProbe.elements(
                pressing: [always, choice],
                until: { _ in closed > 0 }
            ) {
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
