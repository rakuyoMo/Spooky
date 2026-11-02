import AppKit
import ApplicationServices
import os
import SwiftUI
import Testing

@testable import Spooky

// MARK: - DialogFormRowAccessibilityTests

/// 表单行在辅助功能里的名称：标签是控件的标题，只读的文字同时读得出标签与文字本身，一组控件各自保留自己的名称。
///
/// 经辅助功能接口读本进程的窗口；进程没有辅助功能权限时整组跳过。
@MainActor
@Suite(.serialized, .enabled(if: AXIsProcessTrusted(), "需要辅助功能权限"))
struct DialogFormRowAccessibilityTests {
    /// 对话框骨架的表单行：只读文字、输入框与一组控件。
    @Test("DialogFormRow 读出标签与值")
    func dialogFormRow() throws {
        let elements = Self.elements {
            DialogForm {
                DialogFormRow(label: "Merge Strategy:") {
                    Text(verbatim: "Merge Commit")
                }

                DialogFormRow(label: "Project:") {
                    TextField("", text: .constant("group/project"))
                }

                DialogFormRow(label: "Code:") {
                    VStack {
                        Text(verbatim: "ABCD-1234")
                        Button("Open Page") { }
                    }
                }
            }
        }

        try Self.expectPairs(in: elements)
    }

    /// 引用对话框的表格行与骨架的表单行相同。
    @Test("ReferenceDialogRows.row 读出标签与值")
    func referenceRow() throws {
        let elements = Self.elements {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
                ReferenceDialogRows.row("Merge Strategy:") {
                    Text(verbatim: "Merge Commit")
                }

                ReferenceDialogRows.row("Project:") {
                    TextField("", text: .constant("group/project"))
                }

                ReferenceDialogRows.row("Code:") {
                    VStack {
                        Text(verbatim: "ABCD-1234")
                        Button("Open Page") { }
                    }
                }
            }
        }

        try Self.expectPairs(in: elements)
    }
}

// MARK: DialogFormRowAccessibilityTests.Element

extension DialogFormRowAccessibilityTests {
    /// 辅助功能接口读到的一个元素。
    struct Element: Sendable {
        /// 角色，如 `AXStaticText`。
        let role: String

        /// 值；静态文字是它显示的文字。
        let value: String

        /// 自己的名称（`AXDescription`）。
        let name: String

        /// 作为标题的元素的文字（`AXTitleUIElement` 的值）。
        let title: String
    }
}

// MARK: - Helpers

extension DialogFormRowAccessibilityTests {
    /// 三行都配对：只读文字保留自己的文字、以标签为标题；输入框以标签为标题；一组控件里的文字与按钮各自保留名称。
    private static func expectPairs(in elements: [Element]) throws {
        let strategy = try #require(elements.first { $0.role == "AXStaticText" && $0.value == "Merge Commit" })
        #expect(strategy.title == "Merge Strategy:")

        let project = try #require(elements.first { $0.role == "AXTextField" })
        #expect(project.value == "group/project")
        #expect(project.title == "Project:")

        let code = try #require(elements.first { $0.role == "AXStaticText" && $0.value == "ABCD-1234" })
        #expect(code.title == "Code:")

        let button = try #require(elements.first { $0.role == "AXButton" })
        #expect(button.name == "Open Page")
    }

    /// 把视图放进屏外的窗口，在后台线程经辅助功能接口读出全部元素；主线程同时转动 run loop 应答这些请求。
    private static func elements(@ViewBuilder of content: () -> some View) -> [Element] {
        // 测试进程的 NSApplication 没有走完启动时，辅助功能请求一律报未实现
        NSApplication.shared.finishLaunching()

        let title = "spooky-accessibility-" + UUID().uuidString
        let window = NSWindow(
            contentRect: NSRect(x: -3000, y: -3000, width: 480, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content().frame(width: 480))
        window.orderFront(nil)
        defer { window.close() }

        let result = OSAllocatedUnfairLock<[Element]?>(initialState: nil)
        let pid = getpid()

        Thread.detachNewThread {
            let found = collectWhenComplete(inWindowTitled: title, of: pid)
            result.withLock { $0 = found }
        }

        // 后台线程的请求要主线程应答，最多等 30 秒
        let deadline = Date().addingTimeInterval(30)

        while result.withLock({ $0 }) == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        return result.withLock { $0 } ?? []
    }

    /// 读到输入框与按钮为止：控件的辅助功能元素在窗口排版之后才陆续建出，没到齐时隔 0.1 秒再读，最多读 100 次。
    private nonisolated static func collectWhenComplete(inWindowTitled title: String, of pid: pid_t) -> [Element] {
        var found: [Element] = []

        for _ in 0 ..< 100 {
            found = collect(inWindowTitled: title, of: pid)

            let isComplete = found.contains { $0.role == "AXTextField" } && found.contains { $0.role == "AXButton" }

            if isComplete {
                break
            }

            Thread.sleep(forTimeInterval: 0.1)
        }

        return found
    }

    /// 找到标题对应的窗口，逐层读出它下面的元素。
    private nonisolated static func collect(inWindowTitled title: String, of pid: pid_t) -> [Element] {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 5)

        let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []

        guard let window = windows.first(where: { attribute($0, kAXTitleAttribute) as? String == title }) else {
            return []
        }

        var elements: [Element] = []
        var pending = [window]

        while let element = pending.popLast() {
            let titleElement = uiElement(attribute(element, kAXTitleUIElementAttribute))

            elements.append(Element(
                role: attribute(element, kAXRoleAttribute) as? String ?? "",
                value: attribute(element, kAXValueAttribute) as? String ?? "",
                name: attribute(element, kAXDescriptionAttribute) as? String ?? "",
                title: titleElement.flatMap { attribute($0, kAXValueAttribute) as? String } ?? ""
            ))

            pending += attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        }

        return elements
    }

    /// 属性值是辅助功能元素时取出它，否则为 nil。
    private nonisolated static func uiElement(_ value: AnyObject?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    /// 读一个属性；没有这个属性时为 nil。
    private nonisolated static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject? = nil
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }
}
