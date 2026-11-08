import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests + Footer

/// 头部与底栏：标题只占一行；按钮最小宽 70、相隔 8、右边距 20；提交中两个按钮都不可用，进度文字在转圈右侧；
/// 备选底栏的取消对齐输入列；确认版与提示版的结构。
extension DialogLayoutTests {
    /// 确认版只有标题、说明与两个按钮：超长的标题只占一行、截在右边距 20 之前，说明在它下方 8；
    /// 取消与主按钮都至少 70 宽、相隔 8，主按钮距右边 20；平时两个按钮都可用，底栏没有转圈。
    /// 提交中两个按钮都不可用，进度文字在转圈右侧 8，两者与按钮在同一条水平中线上。
    @Test("确认版的头部、底栏与提交中的状态", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func confirmation() async throws {
        let title = String(repeating: "Very Long Dialog Title ", count: 6)

        let idle = await AccessibilityProbe.elements(until: Self.hasButtons) {
            DialogLayout(title: title, message: "Message", submitTitle: "OK", cancel: { }, submit: { })
        }

        try Self.expectHeader(title: title, in: idle)
        try Self.expectButtons(in: idle, enabled: true)

        let expected = ["OK", AppLocalization.text("action.cancel")].sorted()

        #expect(Self.controls(in: idle).map(\.name).sorted() == expected)
        #expect(!idle.contains { $0.role == "AXBusyIndicator" })

        // 提交中：按钮都不可用，左侧是转圈与进度文字
        let submitting = await AccessibilityProbe.elements(until: Self.hasButtons) {
            DialogLayout(
                title: "Title",
                message: "Message",
                submitTitle: "OK",
                progress: "Validating…",
                submitting: true,
                cancel: { },
                submit: { }
            )
        }

        try Self.expectButtons(in: submitting, enabled: false)
        try Self.expectProgress("Validating…", in: submitting)
    }

    /// 按钮组在 480 里放不下时对话框随之加宽：备选底栏的取消仍对齐输入列（没有内容区时是 120），
    /// 备选按钮与主按钮相隔 8、主按钮距右边 20；提示版只有一个 Close。
    @Test("备选底栏与提示版", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func alternateAndNotice() async throws {
        let alternateTitle = String(repeating: "Alternate ", count: 8)

        let dialog = DialogLayout(
            title: "Title",
            message: "Message",
            submitTitle: "OK",
            alternate: (title: alternateTitle, action: { }),
            cancel: { },
            submit: { }
        )

        let width = Self.hosting(dialog).frame.width

        let elements = await AccessibilityProbe.elements(
            width: width,
            until: { elements in elements.count { $0.role == "AXButton" } >= 3 }
        ) {
            dialog
        }

        let cancel = try #require(Self.button(AppLocalization.text("action.cancel"), in: elements))
        let alternate = try #require(Self.button(alternateTitle, in: elements))
        let submit = try #require(Self.button("OK", in: elements))

        #expect(width > 480)
        #expect(abs(cancel.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(submit.frame.minX - alternate.frame.maxX - 8) <= 1)
        #expect(abs(width - submit.frame.maxX - 20) <= 1)

        // 提示版：没有取消，只有 Close
        let close = AppLocalization.text("action.close")

        let notice = await AccessibilityProbe.elements(
            until: { elements in Self.button(close, in: elements) != nil }
        ) {
            DialogLayout(title: "Title", message: "Message", submitTitle: close, cancel: nil, submit: { })
        }

        #expect(Self.controls(in: notice).map(\.name) == [close])
    }
}

// MARK: - Helpers

extension DialogLayoutTests {
    /// 名称为这个标题的按钮。
    static func button(_ title: String, in elements: [AccessibilityProbe.Element]) -> AccessibilityProbe.Element? {
        elements.first { $0.role == "AXButton" && $0.name == title }
    }

    /// 窗口里的按钮、输入框与勾选框，不含标题栏上的窗口按钮。
    private static func controls(in elements: [AccessibilityProbe.Element]) -> [AccessibilityProbe.Element] {
        elements.filter { element in
            ["AXButton", "AXTextField", "AXCheckBox"].contains(element.role) && element.frame.minY > 30
        }
    }

    /// 标题只占一行、截在右边距 20 之前，说明在标题下方 8。
    private static func expectHeader(title: String, in elements: [AccessibilityProbe.Element]) throws {
        let text = try #require(elements.first { $0.role == "AXStaticText" && $0.value == title })
        let message = try #require(elements.first { $0.role == "AXStaticText" && $0.value == "Message" })

        #expect(text.frame.maxX <= 480 - 20 + 1)
        #expect(text.frame.height < 20)
        #expect(abs(message.frame.minY - text.frame.maxY - 8) <= 2)
    }

    /// 取消与主按钮 OK 都至少 70 宽、相隔 8，主按钮距右边 20，两者同为可用或不可用。
    private static func expectButtons(in elements: [AccessibilityProbe.Element], enabled: Bool) throws {
        let cancel = try #require(button(AppLocalization.text("action.cancel"), in: elements))
        let submit = try #require(button("OK", in: elements))

        #expect(cancel.frame.width >= 70 - 0.5)
        #expect(submit.frame.width >= 70 - 0.5)
        #expect(abs(submit.frame.minX - cancel.frame.maxX - 8) <= 1)
        #expect(abs(480 - submit.frame.maxX - 20) <= 1)
        #expect(cancel.isEnabled == enabled)
        #expect(submit.isEnabled == enabled)
    }

    /// 进度文字在转圈右侧 8，两者与取消按钮在同一条水平中线上。
    private static func expectProgress(_ progress: String, in elements: [AccessibilityProbe.Element]) throws {
        let spinner = try #require(elements.first { $0.role == "AXBusyIndicator" })
        let text = try #require(elements.first { $0.role == "AXStaticText" && $0.value == progress })
        let cancel = try #require(button(AppLocalization.text("action.cancel"), in: elements))

        #expect(abs(text.frame.minX - spinner.frame.maxX - 8) <= 1)
        #expect(abs(spinner.frame.midY - cancel.frame.midY) <= 1)
        #expect(abs(text.frame.midY - cancel.frame.midY) <= 1)
    }
}
