import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests + Options

/// Options 开关与选项区：开关行高 34、三角距左 20，选项区默认收起、可以指定默认展开；错误文字里的网址是链接。
extension DialogLayoutTests {
    /// 开关从距左 20 开始；收起时开关行与底栏之间是选项区上下各 8 的空白，按钮距底栏顶 12；按下开关后选项区展开。
    @Test("Options 开关", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func optionsToggle() throws {
        let title = AppLocalization.text("dialog.options")

        let collapsed = AccessibilityProbe.elements(until: Self.hasButtons) {
            Self.layout(optionsExpanded: false)
        }

        let toggle = try #require(collapsed.first { $0.role == "AXCheckBox" && $0.name == title })
        let cancel = try #require(Self.button(AppLocalization.text("action.cancel"), in: collapsed))

        #expect(abs(toggle.frame.minX - 20) <= 1)
        #expect(abs(cancel.frame.minY - toggle.frame.midY - (34 / 2 + 8 + 8 + 12)) <= 1)
        #expect(!collapsed.contains { $0.value == "Option Content" })

        let expanded = AccessibilityProbe.elements(
            pressing: title,
            until: { elements in elements.contains { $0.value == "Option Content" } }
        ) {
            Self.layout(optionsExpanded: false)
        }

        #expect(expanded.contains { $0.role == "AXStaticText" && $0.value == "Option Content" })
    }

    /// 指定默认展开时一打开就显示选项区，开关的文字照指定。
    @Test("选项区默认展开", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func optionsInitiallyExpanded() throws {
        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.value == "Option Content" } }
        ) {
            Self.layout(optionsExpanded: true)
        }

        #expect(elements.contains { $0.role == "AXCheckBox" && $0.name == "Details" })
        #expect(elements.contains { $0.role == "AXStaticText" && $0.value == "Option Content" })
    }

    /// 错误文字里的网址成为可点的链接。
    @Test("错误文字里的链接", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func errorLink() throws {
        let elements = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXLink" } }
        ) {
            Self.layout(error: "See https://example.com/help for details.") {
                EmptyView()
            }
        }

        #expect(elements.contains { $0.role == "AXLink" })
    }
}

// MARK: - Helpers

extension DialogLayoutTests {
    /// 带选项区的确认版；不是默认展开时开关文字是 Options，默认展开时是 Details。
    private static func layout(optionsExpanded: Bool) -> some View {
        DialogLayout(
            title: "Title",
            message: "Message",
            submitTitle: "OK",
            optionsTitle: optionsExpanded ? "Details" : AppLocalization.text("dialog.options"),
            optionsExpanded: optionsExpanded,
            cancel: { },
            submit: { },
            options: {
                Text(verbatim: "Option Content")
                    .padding(20)
            }
        )
    }
}
