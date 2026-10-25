import AppKit
import SwiftUI

// MARK: - LaunchWindowController

/// 启动窗口：启动时列出可以打开的仓库；任何仓库窗口成为主窗口时自动关闭。
@MainActor
final class LaunchWindowController: NSWindowController, NSWindowDelegate {
    /// 启动窗口固定的尺寸。
    static let size = NSSize(width: 600, height: 450)

    /// 正在显示的启动窗口，同一时间只有一个。
    private(set) static var shown: LaunchWindowController?

    /// 仓库窗口成为主窗口的通知订阅。
    private var mainWindowObserver: (any NSObjectProtocol)?

    /// 建立无标题栏、可拖动背景、不能全屏的窗口，内容由 SwiftUI 绘制。
    private init(coordinator: SpookyApplicationController) {
        let window = LaunchWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.fullScreenNone, .fullScreenDisallowsTiling]
        window.title = AppLocalization.text("app.name")
        window.contentViewController = NSHostingController(
            rootView: LaunchView(
                bookmarks: coordinator.bookmarks,
                open: { [weak coordinator] in coordinator?.openRepository(at: $0, from: nil, inNewWindow: false) },
                openLocal: { [weak coordinator] in coordinator?.openRepositoryPanel() },
                addRemote: { [weak coordinator] in coordinator?.addRemoteRepository() }
            )
        )

        // 装入内容会把窗口缩到 SwiftUI 的理想尺寸，先回到固定尺寸再居中
        window.setContentSize(Self.size)
        window.center()
        super.init(window: window)

        window.delegate = self

        // 打开的仓库窗口成为主窗口后，启动窗口完成了任务
        mainWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let window = notification.object as? NSWindow

            MainActor.assumeIsolated {
                guard window?.windowController is RepositoryWindowController else {
                    return
                }

                self?.close()
            }
        }
    }

    /// 启动窗口只由代码创建。
    required init?(coder _: NSCoder) {
        nil
    }

    /// 显示启动窗口；已经在显示时只把它带到前面。
    static func show(coordinator: SpookyApplicationController) {
        let controller = shown ?? LaunchWindowController(coordinator: coordinator)
        shown = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    /// 关闭后停止订阅并释放窗口。
    func windowWillClose(_: Notification) {
        if let mainWindowObserver {
            NotificationCenter.default.removeObserver(mainWindowObserver)
        }

        mainWindowObserver = nil
        Self.shown = nil
    }
}

// MARK: - LaunchWindow

/// 没有标题栏的启动窗口：仍可成为主窗口与键盘焦点，⌘W 可以关闭，不能最小化或缩放。
final class LaunchWindow: NSWindow {
    /// 没有标题栏的窗口默认不接受键盘焦点，列表需要它。
    override var canBecomeKey: Bool { true }

    /// 与仓库窗口一样可以成为主窗口。
    override var canBecomeMain: Bool { true }

    /// 没有关闭按钮也能用 ⌘W 关闭。
    override func performClose(_: Any?) {
        close()
    }

    /// ⌘W 可用，最小化与缩放不可用。
    override func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(performClose(_:)):
            true

        case #selector(performMiniaturize(_:)), #selector(performZoom(_:)):
            false

        default:
            super.validateMenuItem(item)
        }
    }
}
