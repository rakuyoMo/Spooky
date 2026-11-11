import AppKit
import Testing

@testable import Spooky

// MARK: - SettingsWindowTests

/// 设置窗口打开时的焦点，与设置页弹出菜单里的图标。
@MainActor
struct SettingsWindowTests {
    /// General 页的组合框是第一个可输入的控件；窗口打开时焦点不能落进去，否则一打开就在编辑阈值。
    @Test("打开设置窗口时焦点不在输入框里")
    func noInitialFocus() throws {
        let controller = SettingsWindowController()
        defer { controller.close() }

        controller.showWindow(nil)

        let window = try #require(controller.window)
        #expect(window.firstResponder === window)
    }

    /// 弹出菜单拿到的图标是 16 × 16 pt；改的是新取的一份，系统再给出的图标仍是原来的尺寸。
    @Test("菜单图标按 16 × 16 pt 取，不改动系统给出的图标")
    func menuIcon() {
        let path = NSHomeDirectory()
        let icon = NSWorkspace.shared.menuIcon(forFile: path)

        #expect(icon.size == NSSize(width: 16, height: 16))
        #expect(NSWorkspace.shared.icon(forFile: path).size != icon.size)
    }
}
