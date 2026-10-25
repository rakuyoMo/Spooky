import AppKit
import SwiftUI

// MARK: - SettingsWindowController

/// 设置窗口采用原生工具栏式页签，单例入口为 ⌘,；窗口标题随所选页签变化。
@MainActor
final class SettingsWindowController: NSWindowController {
    /// 页签选择变化时同步窗口标题。
    private var selectionObservation: NSKeyValueObservation?

    /// 按 ``SettingsPage/all`` 的顺序建立页签，窗口先按第一页的大小显示。
    init() {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = []

        for page in SettingsPage.all {
            let content = NSHostingController(rootView: page.content())

            // 页面内容的高度会变，如出现读写失败的说明；变化经页签控制器传给窗口。
            content.sizingOptions = .preferredContentSize

            let tab = NSTabViewItem(viewController: content)
            tab.identifier = page.key
            tab.label = AppLocalization.text(page.key)
            tab.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: tab.label)
            tabs.addTabViewItem(tab)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        if let first = tabs.tabViewItems.first?.viewController {
            window.setContentSize(first.view.fittingSize)
        }

        window.center()
        super.init(window: window)

        selectionObservation = tabs.observe(\.selectedTabViewItemIndex, options: [.initial, .new]) { [weak window] tabs, _ in
            MainActor.assumeIsolated {
                guard tabs.tabViewItems.indices.contains(tabs.selectedTabViewItemIndex) else { return }
                window?.title = tabs.tabViewItems[tabs.selectedTabViewItemIndex].label
            }
        }
    }

    /// 设置窗口只由代码构建。
    required init?(coder _: NSCoder) { nil }

    /// 打开设置窗口并切到指定的页，供其它界面直接跳到某一页，如身份菜单的 “Manage User Profiles…”。
    ///
    /// - Parameter page: 要显示的页。
    static func show(_ page: SettingsPage) {
        (NSApp.delegate as? SpookyApplicationController)?.showSettings()

        let controller = NSApp.windows
            .lazy
            .compactMap { $0.windowController as? Self }
            .first

        controller?.select(page)
    }

    /// 切到指定的页；页签已经是它时不动。
    ///
    /// - Parameter page: 要显示的页。
    func select(_ page: SettingsPage) {
        let tabs = window?.contentViewController as? NSTabViewController
        let index = tabs?.tabViewItems.firstIndex { $0.identifier as? String == page.key }

        guard let tabs, let index, tabs.selectedTabViewItemIndex != index else {
            return
        }

        tabs.selectedTabViewItemIndex = index
    }
}

// MARK: - SettingsTabViewController

/// 切页时先隐藏内容，窗口以 0.2 s 的动画改成新页的大小并保持左上角不动，动画结束再显示新页。
private final class SettingsTabViewController: NSTabViewController {
    /// 在窗口改变大小的动画里换页；还没有窗口时直接换页。
    override func transition(
        from fromViewController: NSViewController,
        to toViewController: NSViewController,
        options: NSViewController.TransitionOptions = [],
        completionHandler completion: (@Sendable () -> Void)? = nil
    ) {
        guard let window = view.window else {
            super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)

            return
        }

        view.isHidden = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().setFrame(frame(of: window, fitting: toViewController.view.fittingSize), display: true)
            super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.view.isHidden = false }
        }
    }

    /// 当前页的内容大小变化时，窗口以同样的动画跟着改。
    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)

        let selected = tabViewItems.indices.contains(selectedTabViewItemIndex)
            ? tabViewItems[selectedTabViewItemIndex].viewController
            : nil

        guard let window = view.window, selected === viewController else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().setFrame(frame(of: window, fitting: viewController.preferredContentSize), display: true)
        }
    }

    /// 内容大小换算成窗口外框；原点按窗口原来的上边缘倒推，左上角保持不动。
    private func frame(of window: NSWindow, fitting content: NSSize) -> NSRect {
        let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size

        return NSRect(
            x: window.frame.minX,
            y: window.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
