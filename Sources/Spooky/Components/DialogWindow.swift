import AppKit
import SwiftUI

// MARK: - DialogWindow

/// 对话框骨架所在的窗口：有发起的窗口时挂成它的 sheet，没有时是应用级的模态窗口。
///
/// 窗口不参与系统标签页与窗口恢复，高度随内容；给了尺寸记录名的对话框可以拉大，拉大后的尺寸按这个名字记住。
@MainActor
enum DialogWindow {
    /// 呈现对话框。
    ///
    /// 挂成 sheet 时立即返回，发起的窗口已有 sheet 时由 AppKit 排在它之后。
    /// 没有发起的窗口时进入模态循环，对话框关闭后才返回；窗口带标题栏、居中，标题栏的关闭按钮与 Cancel 相同，只关掉窗口。
    ///
    /// - Parameters:
    ///   - parent: 发起的窗口；为 nil 时成为应用级的模态窗口。
    ///   - autosaveName: 记住尺寸用的名字；为 nil 时不能拉大。
    ///   - content: 用关闭动作构建对话框内容。
    static func present(
        on parent: NSWindow?,
        autosaveName: String? = nil,
        @ViewBuilder content: (_ close: @escaping () -> Void) -> some View
    ) {
        let window = NSWindow()
        window.styleMask = parent == nil ? [.titled, .closable] : [.titled]
        window.title = ""
        window.tabbingMode = .disallowed
        window.isRestorable = false
        window.isReleasedWhenClosed = false

        let close = { [weak window] in
            guard let window else {
                return
            }

            if let parent {
                parent.endSheet(window)
            } else {
                window.close()
            }
        }

        let controller = NSHostingController(rootView: content(close))
        window.contentViewController = controller

        if let autosaveName {
            // 可以拉大的对话框以内容的最小尺寸为下限，先按理想尺寸打开，再换成记住的尺寸
            controller.sizingOptions = [.minSize]
            window.styleMask.insert(.resizable)
            window.setContentSize(controller.view.fittingSize)
            window.setFrameAutosaveName(autosaveName)
        } else {
            // 高度取内容的理想尺寸，说明折成几行就留几行的高度
            controller.sizingOptions = .preferredContentSize
        }

        guard let parent else {
            runModal(window)
            return
        }

        parent.beginSheet(window)
    }
}

// MARK: - Private

extension DialogWindow {
    /// 居中显示并进入模态循环，窗口关闭时结束。
    private static func runModal(_ window: NSWindow) {
        window.center()

        // 关窗时窗口自己关掉，模态循环要另外结束
        let closing = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { NSApp.stopModal() }
        }

        _ = NSApp.runModal(for: window)
        NotificationCenter.default.removeObserver(closing)
    }
}
