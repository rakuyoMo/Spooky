import AppKit
import ApplicationServices
import SwiftUI

// MARK: - AccessibilityProbe

/// 经辅助功能接口读本进程窗口里的元素，必要时先按下一个控件，核对 SwiftUI 控件的名称与位置：这些控件不在 AppKit 的视图树里。
///
/// 进程没有辅助功能权限时读不到任何元素，用到它的测试以 `AXIsProcessTrusted()` 为前提，没有权限时跳过。
@MainActor
enum AccessibilityProbe {
    /// 辅助功能接口读到的一个元素。
    struct Element {
        /// 角色，如 `AXStaticText`。
        let role: String

        /// 值；静态文字是它显示的文字，勾选框是 “0” 或 “1”。
        let value: String

        /// 自己的名称（`AXDescription`）。
        let name: String

        /// 作为标题的元素的文字（`AXTitleUIElement` 的值）。
        let title: String

        /// 相对窗口左上角的位置与大小；窗口带标题栏，横坐标与内容区的相同。
        let frame: CGRect

        /// 控件是否可用；没有这个属性的元素算可用。
        let isEnabled: Bool
    }

    /// 把视图放进屏外的窗口，在主线程经辅助功能接口读出全部元素。
    ///
    /// 本进程的请求在发出请求的线程上应答，SwiftUI 的下拉等控件只能在主线程读，所以不另开线程。
    ///
    /// - Parameters:
    ///   - width: 窗口内容的宽度。
    ///   - name: 读到时先按一下的控件的名称，如展开三角；为 nil 时不按。
    ///   - isComplete: 要等的控件都读到了；控件的元素在窗口排版之后才陆续建出，没到齐时转动 run loop 再读，最多读 100 次。
    ///   - content: 窗口的内容。
    static func elements(
        width: CGFloat = 480,
        pressing name: String? = nil,
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
        var pending = name

        for _ in 0 ..< 100 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            let collected = collect(inWindowTitled: title)
            found = collected.map(\.element)

            // 要按的控件读到后按一次，之后读到的是按过以后的样子
            if let name = pending, let target = collected.first(where: { $0.element.name == name }) {
                press(target.reference)
                pending = nil
                continue
            }

            if pending == nil, isComplete(found) {
                break
            }
        }

        return found
    }
}

// MARK: - Private

extension AccessibilityProbe {
    /// 找到标题对应的窗口，逐层读出它下面的元素，连同元素本身，供按下控件用。
    private static func collect(inWindowTitled title: String) -> [(reference: AXUIElement, element: Element)] {
        let application = AXUIElementCreateApplication(getpid())
        AXUIElementSetMessagingTimeout(application, 5)

        let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []

        guard let window = windows.first(where: { attribute($0, kAXTitleAttribute) as? String == title }) else {
            return []
        }

        let origin = frame(of: window).origin
        var elements: [(reference: AXUIElement, element: Element)] = []
        var pending = [window]

        while let reference = pending.popLast() {
            let titleElement = uiElement(attribute(reference, kAXTitleUIElementAttribute))

            let element = Element(
                role: attribute(reference, kAXRoleAttribute) as? String ?? "",
                value: text(attribute(reference, kAXValueAttribute)),
                name: attribute(reference, kAXDescriptionAttribute) as? String ?? "",
                title: titleElement.flatMap { attribute($0, kAXValueAttribute) as? String } ?? "",
                frame: frame(of: reference).offsetBy(dx: -origin.x, dy: -origin.y),
                isEnabled: attribute(reference, kAXEnabledAttribute) as? Bool ?? true
            )

            elements.append((reference, element))

            pending += attribute(reference, kAXChildrenAttribute) as? [AXUIElement] ?? []
        }

        return elements
    }

    /// 按下一个控件。
    ///
    /// 按本进程的控件时，辅助功能接口会停下主线程当前所在的那一层 run loop；直接按会停在测试框架驱动主线程的那一层，
    /// 测试一结束进程就随之退出、来不及报告结果，所以放进单独转一次的 run loop 里按。
    private static func press(_ element: AXUIElement) {
        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
        }

        CFRunLoopRunInMode(.defaultMode, 1, false)
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

    /// 文字或整数的属性值写成文字，其余为空。
    private static func text(_ value: AnyObject?) -> String {
        if let string = value as? String {
            return string
        }

        return (value as? Int).map(String.init) ?? ""
    }

    /// 读一个属性；没有这个属性时为 nil。
    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject? = nil
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }
}
