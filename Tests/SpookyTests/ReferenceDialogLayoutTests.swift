import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - ReferenceDialogLayoutTests

/// 引用管理对话框的骨架：输入列至少从对齐线开始，头部文字与提示文字对齐输入列。
///
/// 位置经辅助功能接口读取，进程没有辅助功能权限时整组跳过。
@MainActor
@Suite(.enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
struct ReferenceDialogLayoutTests {
    /// 标签长时输入列右移，标签短时输入列从 120 的对齐线开始；两种情况下标题、说明与错误文字都对齐输入列。
    @Test("头部与提示文字对齐输入列")
    func rows() throws {
        for label in ["Personal Access Token:", "Name:"] {
            let elements = AccessibilityProbe.elements(width: 540, until: Self.hasField) {
                Self.layout {
                    ReferenceDialogRows.row(label) {
                        TextField("", text: .constant(""))
                    }
                }
            }

            let field = try #require(elements.first { $0.role == "AXTextField" })

            #expect(field.frame.minX >= DialogMetrics.alignment - 1, "\(label)")
            try Self.expectTexts(in: elements, startingAt: field.frame.minX)
        }
    }

    /// 只有勾选项时，勾选项从 120 的对齐线开始，头部文字对齐它。
    @Test("只有勾选项时对齐勾选项")
    func options() throws {
        let elements = AccessibilityProbe.elements(width: 540, until: Self.hasCheckBox) {
            Self.layout {
                ReferenceDialogRows.option("Force", help: "", isOn: .constant(false))
            }
        }

        let option = try #require(elements.first { $0.role == "AXCheckBox" })

        #expect(abs(option.frame.minX - DialogMetrics.alignment) <= 1)
        try Self.expectTexts(in: elements, startingAt: option.frame.minX)
    }
}

// MARK: - Helpers

extension ReferenceDialogLayoutTests {
    /// 带错误说明的对话框。
    private static func layout(@ViewBuilder content: @escaping () -> some View) -> some View {
        ReferenceDialogLayout(
            session: RepositorySession(),
            title: "Title",
            message: "Message",
            submitTitle: "Submit",
            error: "Error",
            isValid: true,
            cancel: { },
            submit: { },
            content: content
        )
    }

    /// 标题、说明与错误文字的左缘都在这个位置。
    private static func expectTexts(in elements: [AccessibilityProbe.Element], startingAt x: CGFloat) throws {
        for text in ["Title", "Message", "Error"] {
            let element = try #require(elements.first { $0.role == "AXStaticText" && $0.value == text })
            #expect(abs(element.frame.minX - x) <= 1, "\(text)")
        }
    }

    /// 输入框与标题都读到了。
    private static func hasField(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXTextField" } && elements.contains { $0.value == "Title" }
    }

    /// 勾选项与标题都读到了。
    private static func hasCheckBox(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.contains { $0.role == "AXCheckBox" } && elements.contains { $0.value == "Title" }
    }
}
