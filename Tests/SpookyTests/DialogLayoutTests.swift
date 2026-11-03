import AppKit
import ApplicationServices
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogLayoutTests

/// 对话框骨架：宽度与头部图标的位置，单行标题，头部与错误文字对齐内容区的输入列；底栏左侧写加载中的步骤，前面是小号转圈。
///
/// 文字与控件的位置经辅助功能接口读取，进程没有辅助功能权限时跳过这几项。
@MainActor
struct DialogLayoutTests {
    /// 默认宽 480，指定宽度时照指定。
    @Test("宽度")
    func width() {
        #expect(Self.hosting(Self.layout(progress: nil)).frame.width == 480)
        #expect(Self.hosting(Self.layout(width: 450)).frame.width == 450)
    }

    /// 头部图标 64 × 64，没有内容区时距左 40（对齐线 120 减去间距 16 与图标宽 64），距顶 20。
    @Test("头部图标的位置")
    func icon() throws {
        let frame = try #require(Self.iconFrame())

        #expect(frame == CGRect(x: 40, y: 20, width: 64, height: 64))
    }

    /// 标题超长时只占一行，截在右边距 20 之前。
    @Test("标题单行", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func singleLineTitle() throws {
        let title = String(repeating: "Very Long Dialog Title ", count: 6)

        let elements = AccessibilityProbe.elements(until: Self.hasButtons) {
            DialogLayout(title: title, message: "Message", submitTitle: "Submit", cancel: { }, submit: { })
        }

        let text = try #require(elements.first { $0.role == "AXStaticText" && $0.value == title })
        let message = try #require(elements.first { $0.role == "AXStaticText" && $0.value == "Message" })

        #expect(text.frame.maxX <= 480 - 20 + 1)
        #expect(abs(message.frame.minY - text.frame.maxY - 8) <= 2)
        #expect(text.frame.height < 20)
    }

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
        let form = AccessibilityProbe.elements(
            until: { elements in elements.contains { $0.role == "AXTextField" } }
        ) {
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

    /// 内容区里按输入列排版的部分读到的就是输入列：标签长时跟着右移，没有表单时是 120。
    @Test("内容区读到输入列", .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
    func inputColumnReader() throws {
        let form = AccessibilityProbe.elements(
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
        let text = try #require(form.first { $0.role == "AXStaticText" && $0.value == "Column" })

        #expect(field.frame.minX > DialogMetrics.alignment + 1)
        #expect(abs(text.frame.minX - field.frame.minX) <= 1)

        let empty = AccessibilityProbe.elements(until: Self.hasButtons) {
            Self.layout(error: "Error") {
                Self.columnText
            }
        }

        let alone = try #require(empty.first { $0.role == "AXStaticText" && $0.value == "Column" })

        #expect(abs(alone.frame.minX - DialogMetrics.alignment) <= 1)
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

    /// 只有头部与底栏的对话框。
    static func layout(progress: String? = nil, width: CGFloat = 480) -> some View {
        DialogLayout(
            title: "Title",
            message: "Message",
            width: width,
            submitTitle: "Submit",
            progress: progress,
            cancel: { },
            submit: { }
        )
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

    /// 标题、说明与错误文字的左缘都在这个位置。
    private static func expectTexts(in elements: [AccessibilityProbe.Element], startingAt x: CGFloat) throws {
        for text in ["Title", "Message", "Error"] {
            let element = try #require(elements.first { $0.role == "AXStaticText" && $0.value == text })
            #expect(abs(element.frame.minX - x) <= 1, "\(text)")
        }
    }

    /// 头部图标换成纯红的图后，在渲染出的对话框里红色像素的范围；找不到时为 nil。
    private static func iconFrame() -> CGRect? {
        let red = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            rect.fill()
            return true
        }

        let renderer = ImageRenderer(
            content: DialogLayout(
                title: "Title",
                message: "Message",
                icon: red,
                submitTitle: "OK",
                cancel: { },
                submit: { }
            )
        )
        renderer.scale = 1

        guard
            let image = renderer.cgImage,
            let bitmap = NSBitmapImageRep(cgImage: image).converting(to: .sRGB, renderingIntent: .default)
        else {
            return nil
        }

        return redBounds(in: bitmap)
    }

    /// 位图里红色像素的外接矩形，原点在左上角。
    private static func redBounds(in bitmap: NSBitmapImageRep) -> CGRect? {
        var bounds: CGRect? = nil

        for y in 0 ..< bitmap.pixelsHigh {
            for x in 0 ..< bitmap.pixelsWide {
                guard
                    let color = bitmap.colorAt(x: x, y: y),
                    color.redComponent > 0.9,
                    color.greenComponent < 0.1
                else {
                    continue
                }

                let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                bounds = bounds?.union(pixel) ?? pixel
            }
        }

        return bounds
    }

    /// 根视图下所有这一类的子视图。
    private static func subviews<Element: NSView>(_: Element.Type, in root: NSView) -> [Element] {
        root.subviews.flatMap { child in
            [child as? Element].compactMap(\.self) + subviews(Element.self, in: child)
        }
    }
}
