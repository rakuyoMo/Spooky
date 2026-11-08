import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests + Options

/// Options 开关与选项区：开关行高 34、三角距左 20，选项区默认收起、可以指定默认展开；错误文字里的网址是链接。
extension DialogLayoutTests {
    /// 开关从距左 20 开始；收起时开关行与底栏之间是选项区上下各 8 的空白，按钮距底栏顶 12；按下开关后选项区展开。
    /// 指定默认展开时一打开就显示选项区，开关的文字照指定；错误文字里的网址成为可点的链接。
    @Test("Options 开关、选项区与错误文字里的链接", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func options() async throws {
        let title = AppLocalization.text("dialog.options")

        let collapsed = await AccessibilityProbe.elements(
            until: { elements in
                Self.hasButtons(elements) && elements.contains { $0.role == "AXLink" }
            }
        ) {
            Self.layout(optionsExpanded: false)
        }

        let toggle = try #require(collapsed.first { $0.role == "AXCheckBox" && $0.name == title })
        let cancel = try #require(Self.button(AppLocalization.text("action.cancel"), in: collapsed))

        #expect(abs(toggle.frame.minX - 20) <= 1)
        #expect(abs(cancel.frame.minY - toggle.frame.midY - (34 / 2 + 8 + 8 + 12)) <= 1)
        #expect(!collapsed.contains { $0.value == "Option Content" })

        // 按下开关后展开
        let pressed = await AccessibilityProbe.elements(
            pressing: [title],
            until: { elements in elements.contains { $0.value == "Option Content" } }
        ) {
            Self.layout(optionsExpanded: false)
        }

        #expect(pressed.contains { $0.role == "AXStaticText" && $0.value == "Option Content" })

        // 默认展开，开关写指定的文字
        let expanded = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.value == "Option Content" } }
        ) {
            Self.layout(optionsExpanded: true)
        }

        #expect(expanded.contains { $0.role == "AXCheckBox" && $0.name == "Details" })
    }
}

// MARK: - Helpers

extension DialogLayoutTests {
    /// 带选项区的确认版，错误文字里有一个网址；不是默认展开时开关文字是 Options，默认展开时是 Details。
    private static func layout(optionsExpanded: Bool) -> some View {
        DialogLayout(
            title: "Title",
            message: "Message",
            submitTitle: "OK",
            error: "See https://example.com/help for details.",
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
