import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests + Footer

/// 底栏：按钮最小宽 70、相隔 8、右边距 20；备选底栏的取消对齐输入列；提交中两个按钮都不可用；确认版与提示版的结构。
extension DialogLayoutTests {
    /// 取消与主按钮都至少 70 宽，相隔 8，主按钮距右边 20。
    @Test("底栏的按钮", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func footerButtons() throws {
        let elements = AccessibilityProbe.elements(until: Self.hasButtons) {
            DialogLayout(title: "Title", message: "Message", submitTitle: "OK", cancel: { }, submit: { })
        }

        let cancel = try #require(Self.button(AppLocalization.text("action.cancel"), in: elements))
        let submit = try #require(Self.button("OK", in: elements))

        #expect(cancel.frame.width >= 70 - 0.5)
        #expect(submit.frame.width >= 70 - 0.5)
        #expect(abs(submit.frame.minX - cancel.frame.maxX - 8) <= 1)
        #expect(abs(480 - submit.frame.maxX - 20) <= 1)
    }

    /// 备选底栏：取消的左缘对齐输入列（没有内容区时是 120），备选按钮与主按钮相隔 8、贴右边 20。
    @Test("备选底栏", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func alternateFooter() throws {
        let elements = AccessibilityProbe.elements(
            until: { elements in elements.count { $0.role == "AXButton" } >= 3 }
        ) {
            DialogLayout(
                title: "Title",
                message: "Message",
                submitTitle: "OK",
                alternate: (title: "Alternate", action: { }),
                cancel: { },
                submit: { }
            )
        }

        let cancel = try #require(Self.button(AppLocalization.text("action.cancel"), in: elements))
        let alternate = try #require(Self.button("Alternate", in: elements))
        let submit = try #require(Self.button("OK", in: elements))

        #expect(abs(cancel.frame.minX - DialogMetrics.alignment) <= 1)
        #expect(abs(submit.frame.minX - alternate.frame.maxX - 8) <= 1)
        #expect(abs(480 - submit.frame.maxX - 20) <= 1)
    }

    /// 提交中主按钮与取消都不可用；平时两者都可用。
    @Test("提交中的按钮", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func submitting() throws {
        for submitting in [true, false] {
            let elements = AccessibilityProbe.elements(until: Self.hasButtons) {
                DialogLayout(
                    title: "Title",
                    message: "Message",
                    submitTitle: "OK",
                    submitting: submitting,
                    cancel: { },
                    submit: { }
                )
            }

            let cancel = try #require(Self.button(AppLocalization.text("action.cancel"), in: elements))
            let submit = try #require(Self.button("OK", in: elements))

            #expect(cancel.isEnabled == !submitting)
            #expect(submit.isEnabled == !submitting)
        }
    }

    /// 确认版只有标题、说明与两个按钮；提示版只有一个 Close。
    @Test("确认版与提示版", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func confirmationAndNotice() throws {
        let confirmation = AccessibilityProbe.elements(until: Self.hasButtons) {
            DialogLayout(title: "Title", message: "Message", submitTitle: "Delete", cancel: { }, submit: { })
        }

        let names = Self.controls(in: confirmation).map(\.name).sorted()
        let expected = ["Delete", AppLocalization.text("action.cancel")].sorted()

        #expect(names == expected)
        #expect(confirmation.contains { $0.role == "AXStaticText" && $0.value == "Message" })

        let close = AppLocalization.text("action.close")
        let notice = AccessibilityProbe.elements(
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
}
