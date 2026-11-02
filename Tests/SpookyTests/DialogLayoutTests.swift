import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests

/// 对话框骨架的底栏：等待中的步骤写在左侧，前面是小号转圈；不在等待时左侧是空的。
///
/// 文字的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这一项。
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
