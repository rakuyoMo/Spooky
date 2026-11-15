import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests

/// 对话框骨架：头部、错误文字与内容区对齐输入列。
///
/// 文字的位置经辅助功能接口读取，进程没有辅助功能权限时跳过。
@MainActor
struct DialogLayoutTests {
    /// 标签比标签列的最小宽度长时输入列右移，标题、说明、错误文字与内容区里按输入列排版的部分都跟着它；
    /// 没有表单时它们对齐 120 的对齐线。
    @Test("头部、错误文字与内容区对齐输入列", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func alignment() async throws {
        let form = await AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXTextField" } }
        ) {
            Self.layout(error: "Error") {
                VStack(alignment: .leading, spacing: 0) {
                    DialogForm {
                        DialogFormRow(label: "Personal Access Token:") {
                            TextField("", text: .constant(""))
                        }
                    }

                    Self.columnText
                }
            }
        }

        let field = try #require(form.first { $0.role == "AXTextField" })

        #expect(field.frame.minX > DialogMetrics.inputColumn + 1)
        try Self.expectTexts(["Title", "Message", "Error", "Column"], in: form, startingAt: field.frame.minX)

        // 没有表单时都在对齐线上
        let empty = await AccessibilityProbe.elements(until: Self.hasButtons) {
            Self.layout(error: "Error") {
                Self.columnText
            }
        }

        try Self.expectTexts(["Title", "Message", "Error", "Column"], in: empty, startingAt: DialogMetrics.alignment)
    }
}

// MARK: - Helpers

extension DialogLayoutTests {
    /// 从输入列开始的一行文字。
    private static var columnText: some View {
        DialogInputColumnReader { inputColumn in
            Text(verbatim: "Column")
                .padding(.leading, inputColumn)
        }
    }

    /// 带错误区与内容区的对话框。
    static func layout(error: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        DialogLayout(
            title: "Title",
            message: "Message",
            submitTitle: "Submit",
            error: error,
            cancel: { },
            submit: { },
            content: content
        )
    }

    /// 底栏的两个按钮都读到了。
    static func hasButtons(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.filter { $0.role == "AXButton" }.count >= 2
    }

    /// 排好版的视图。
    static func hosting(_ view: some View) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()

        return hosting
    }

    /// 这几段文字的左缘都在这个位置。
    private static func expectTexts(
        _ texts: [String],
        in elements: [AccessibilityProbe.Element],
        startingAt x: CGFloat
    ) throws {
        for text in texts {
            let element = try #require(elements.first { $0.role == "AXStaticText" && $0.value == text })

            #expect(abs(element.frame.minX - x) <= 1, "\(text)")
        }
    }
}
