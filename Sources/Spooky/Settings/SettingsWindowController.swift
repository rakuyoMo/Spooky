import AppKit
import SwiftUI

// MARK: - SettingsWindowController

/// 设置窗口采用原生工具栏式页签，单例入口为 ⌘,；窗口标题随所选页签变化。
@MainActor
final class SettingsWindowController: NSWindowController {
    /// 页签选择变化时同步窗口标题。
    private var selectionObservation: NSKeyValueObservation?

    /// 按 ``SettingsPage/all`` 的顺序建立页签，窗口先按第一页的大小显示，屏幕放不下时缩到可用区域的高度。
    init() {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = []

        for page in SettingsPage.all {
            // 窗口比页面矮时页面在窗口里上下滚动；放得下时不随触控板回弹
            let content = NSHostingController(
                rootView: ScrollView(.vertical) {
                    page.content()
                }
                .scrollBounceBehavior(.basedOnSize)
            )

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

        // 第一页比屏幕的可用区域高时先缩到放得下，再居中
        if let first = tabs.tabViewItems.first?.viewController {
            window.setFrame(tabs.frame(of: window, fitting: first.preferredContentSize), display: false)
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

    /// 把窗口收进屏幕的可用区域（除去菜单栏与 Dock）：比可用区域高时缩到同高，放不下的部分在页面里滚动；
    /// 高度缩短时上边缘不动，下边缘落到可用区域以下时整个窗口往上移。
    ///
    /// - Parameters:
    ///   - frame: 按页面大小算出的窗口外框。
    ///   - visible: 窗口所在屏幕的可用区域。
    static func constrained(_ frame: NSRect, to visible: NSRect) -> NSRect {
        let height = min(frame.height, visible.height)

        return NSRect(
            x: frame.minX,
            y: max(frame.maxY - height, visible.minY),
            width: frame.width,
            height: height
        )
    }

    /// 显示窗口；窗口原本不在屏幕上时，焦点不留在任何输入框里。
    override func showWindow(_ sender: Any?) {
        let wasVisible = window?.isVisible ?? false

        super.showWindow(sender)

        // 窗口显示时，AppKit 把焦点交给第一个可输入的控件，如 General 页的组合框
        guard !wasVisible else {
            return
        }

        window?.makeFirstResponder(nil)
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

/// 切页时先隐藏内容，窗口以 0.2 s 的动画改成新页的大小并保持左上角不动，动画结束再显示新页；
/// 新的大小超出屏幕的可用区域时按 ``SettingsWindowController/constrained(_:to:)`` 收进来。
private final class SettingsTabViewController: NSTabViewController {
    /// 页面高度的上限：窗口所在屏幕的可用区域里，除去标题栏与工具栏放得下的高度。
    ///
    /// AppKit 以略高于窗口保持原大小的优先级，把页面的 `preferredContentSize` 约束到窗口上，窗口显示时会被撑到整页的高度；
    /// 这条必须满足的上限挡住它。
    private var maxHeight: NSLayoutConstraint?

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

            // 先换上新页再改窗口：页面放进窗口后，preferredContentSize 才是 AppKit 用来定窗口大小的值；
            // 换页前的值与它差 1–2 pt，动画结束后窗口会以左上角不动再补上，窗口靠下时下边缘落到 Dock 后面
            super.transition(from: fromViewController, to: toViewController, options: options, completionHandler: completion)

            window.animator().setFrame(frame(of: window, fitting: toViewController.preferredContentSize), display: true)
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

    /// 内容大小换算成窗口外框；原点按窗口原来的上边缘倒推，左上角保持不动，再收进所在屏幕的可用区域。
    /// 页面高度的上限随之更新为这块可用区域放得下的高度。
    ///
    /// - Parameters:
    ///   - window: 设置窗口；还没显示时按主屏幕算。
    ///   - content: 页面内容的大小。
    func frame(of window: NSWindow, fitting content: NSSize) -> NSRect {
        let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size

        let frame = NSRect(
            x: window.frame.minX,
            y: window.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        guard let visible = (window.screen ?? NSScreen.main)?.visibleFrame else {
            return frame
        }

        limitHeight(to: window.contentRect(forFrameRect: visible).height)

        return SettingsWindowController.constrained(frame, to: visible)
    }

    /// 把页面高度的上限设为给定的高度，第一次调用时建立这条约束。
    ///
    /// - Parameter height: 页面最多能有的高度。
    private func limitHeight(to height: CGFloat) {
        if let maxHeight {
            maxHeight.constant = height
            return
        }

        let constraint = view.heightAnchor.constraint(lessThanOrEqualToConstant: height)
        constraint.isActive = true
        maxHeight = constraint
    }
}
