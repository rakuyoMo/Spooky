import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests

/// 对话框骨架：头部与错误文字对齐内容区的输入列；底栏左侧写等待中的步骤，前面是小号转圈。
///
/// 文字的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这几项。
@MainActor
struct DialogLayoutTests {
    /// 有进度文字时底栏左侧距左 20 是转圈；没有时没有转圈。
    @Test("底栏的转圈")
    func spinner() throws {
        let waiting = Self.hosting(Self.layout(progress: "Validating…"))
        let indicator = try #require(Self.subviews(NSProgressIndicator.self, in: waiting).first)
        let frame = indicator.convert(indicator.bounds, to: waiting)

        #expect(abs(frame.minX - 20) <= 1)

        let idle = Self.hosting(Self.layout(progress: nil))

        #expect(Self.subviews(NSProgressIndicator.self, in: idle).isEmpty)
    }

    /// 文字在转圈右侧 8，两者与按钮在同一条水平中线上；没有进度文字时底栏只有两个按钮。
    @Test("底栏的进度文字", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func progressText() throws {
        let waiting = AccessibilityProbe.elements(until: Self.hasButtons) {
            Self.layout(progress: "Validating…")
        }

        let spinner = try #require(waiting.first { $0.role == "AXBusyIndicator" })
        let text = try #require(waiting.first { $0.role == "AXStaticText" && $0.value == "Validating…" })
        let cancelTitle = AppLocalization.text("action.cancel")
        let cancel = try #require(waiting.first { $0.role == "AXButton" && $0.name == cancelTitle })

        #expect(abs(text.frame.minX - spinner.frame.maxX - 8) <= 1)
        #expect(abs(spinner.frame.midY - cancel.frame.midY) <= 1)
        #expect(abs(text.frame.midY - cancel.frame.midY) <= 1)

        let idle = AccessibilityProbe.elements(until: Self.hasButtons) {
            Self.layout(progress: nil)
        }

        #expect(!idle.contains { $0.role == "AXBusyIndicator" })
        #expect(!idle.contains { $0.value == "Validating…" })
    }

    /// 标签比标签列的最小宽度长时输入列右移，标题、说明与错误文字跟着它；没有表单时对齐 120 的对齐线。
    @Test("头部与错误文字对齐输入列", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func alignment() throws {
        let form = AccessibilityProbe.elements(until: { elements in elements.contains { $0.role == "AXTextField" } }) {
            Self.layout(error: "Error") {
                DialogForm {
                    DialogFormRow(label: "Personal Access Token:") {
                        TextField("", text: .constant(""))
                    }
                }
            }
        }

        let field = try #require(form.first { $0.role == "AXTextField" })

        #expect(field.frame.minX > DialogMetrics.alignment + 1)
        try Self.expectTexts(in: form, startingAt: field.frame.minX)

        let empty = AccessibilityProbe.elements(until: Self.hasButtons) {
            Self.layout(error: "Error") {
                EmptyView()
            }
        }

        try Self.expectTexts(in: empty, startingAt: DialogMetrics.alignment)
    }
}

// MARK: - Helpers

extension DialogLayoutTests {
    /// 只有头部与底栏的对话框。
    private static func layout(progress: String?) -> some View {
        DialogLayout(
            title: "Title",
            message: "Message",
            submitTitle: "Submit",
            error: nil,
            progress: progress,
            canSubmit: true,
            cancel: { },
            submit: { }
        ) {
            EmptyView()
        }
    }

    /// 带错误区与内容区的对话框。
    private static func layout(error: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        DialogLayout(
            title: "Title",
            message: "Message",
            submitTitle: "Submit",
            error: error,
            canSubmit: true,
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

    /// 排好版的视图。
    private static func hosting(_ view: some View) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        hosting.layoutSubtreeIfNeeded()

        return hosting
    }

    /// 底栏的两个按钮都读到了。
    private static func hasButtons(_ elements: [AccessibilityProbe.Element]) -> Bool {
        elements.filter { $0.role == "AXButton" }.count >= 2
    }

    /// 根视图下所有这一类的子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
