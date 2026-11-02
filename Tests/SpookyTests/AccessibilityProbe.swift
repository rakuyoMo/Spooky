import AppKit
import ApplicationServices
import SwiftUI

// MARK: - AccessibilityProbe

/// 经辅助功能接口读本进程窗口里的元素，核对 SwiftUI 控件的名称与位置：这些控件不在 AppKit 的视图树里。
///
/// 进程没有辅助功能权限时读不到任何元素，用到它的测试以 `AXIsProcessTrusted()` 为前提，没有权限时跳过。
@MainActor
enum AccessibilityProbe {
    /// 辅助功能接口读到的一个元素。
    struct Element {
        /// 角色，如 `AXStaticText`。
        let role: String

        /// 值；静态文字是它显示的文字。
        let value: String

        /// 自己的名称（`AXDescription`）。
        let name: String

        /// 作为标题的元素的文字（`AXTitleUIElement` 的值）。
        let title: String

        /// 相对窗口左上角的位置与大小；窗口带标题栏，横坐标与内容区的相同。
        let frame: CGRect
    }

    /// 把视图放进屏外的窗口，在主线程经辅助功能接口读出全部元素。
    ///
    /// 本进程的请求在发出请求的线程上应答，SwiftUI 的下拉等控件只能在主线程读，所以不另开线程。
    ///
    /// - Parameters:
    ///   - width: 窗口内容的宽度。
    ///   - isComplete: 要等的控件都读到了；控件的元素在窗口排版之后才陆续建出，没到齐时转动 run loop 再读，最多读 100 次。
    ///   - content: 窗口的内容。
    static func elements(
        width: CGFloat = 480,
        until isComplete: ([Element]) -> Bool,
        @ViewBuilder of content: () -> some View
    ) -> [Element] {
        // 测试进程的 NSApplication 没有走完启动时，辅助功能请求一律报未实现
        NSApplication.shared.finishLaunching()

        let title = "spooky-accessibility-" + UUID().uuidString
        let window = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: width, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content().frame(width: width))
        window.orderFront(nil)
        defer { window.close() }

        var found: [Element] = []

        for _ in 0 ..< 100 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            found = collect(inWindowTitled: title)

            if isComplete(found) {
                break
            }
        }

        return found
    }
}

// MARK: - Private

extension AccessibilityProbe {
    /// 找到标题对应的窗口，逐层读出它下面的元素。
    private static func collect(inWindowTitled title: String) -> [Element] {
        let application = AXUIElementCreateApplication(getpid())
        AXUIElementSetMessagingTimeout(application, 5)

        let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []

        guard let window = windows.first(where: { attribute($0, kAXTitleAttribute) as? String == title }) else {
            return []
        }

        let origin = frame(of: window).origin
        var elements: [Element] = []
        var pending = [window]

        while let element = pending.popLast() {
            let titleElement = uiElement(attribute(element, kAXTitleUIElementAttribute))

            elements.append(Element(
                role: attribute(element, kAXRoleAttribute) as? String ?? "",
                value: attribute(element, kAXValueAttribute) as? String ?? "",
                name: attribute(element, kAXDescriptionAttribute) as? String ?? "",
                title: titleElement.flatMap { attribute($0, kAXValueAttribute) as? String } ?? "",
                frame: frame(of: element).offsetBy(dx: -origin.x, dy: -origin.y)
            ))

            pending += attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        }

        return elements
    }

    /// 元素在屏幕上的位置与大小，原点在主屏幕左上角；读不到时为零。
    private static func frame(of element: AXUIElement) -> CGRect {
        var position = CGPoint.zero
        var size = CGSize.zero

        if let value = axValue(attribute(element, kAXPositionAttribute)) {
            AXValueGetValue(value, .cgPoint, &position)
        }

        if let value = axValue(attribute(element, kAXSizeAttribute)) {
            AXValueGetValue(value, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    /// 属性值是辅助功能元素时取出它，否则为 nil。
    private static func uiElement(_ value: AnyObject?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    /// 属性值是位置或大小这类结构时取出它，否则为 nil。
    private static func axValue(_ value: AnyObject?) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXValue.self)
    }

    /// 读一个属性；没有这个属性时为 nil。
    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject? = nil
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }
}
