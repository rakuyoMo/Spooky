import AppKit
import SpookyKit

// MARK: - QuickActionPanel

/// 快捷操作的浮窗：能成为 key window，不能成为 main window，仓库窗口在它显示时仍是主窗口。
final class QuickActionPanel: NSPanel {
    /// 输入框要接收键盘输入。
    override var canBecomeKey: Bool { true }

    /// 菜单与工具栏的动作仍发往仓库窗口。
    override var canBecomeMain: Bool { false }
}

// MARK: - QuickActionWindowController

/// 全局唯一的快捷操作面板：没有标题栏的玻璃浮窗，水平居中、上沿在屏幕可见区域顶端往下 1/5 处。
///
/// 失去焦点即关闭；再次为同一个窗口的同一个仓库打开时保留输入与动作模式，换了窗口或仓库时从空白开始。
@MainActor
final class QuickActionWindowController: NSWindowController, NSWindowDelegate {
    /// 整个 App 共用的面板。
    static let shared = QuickActionWindowController()

    /// 面板内容的尺寸。
    static let contentSize = NSSize(width: 480, height: 460)

    /// 面板里的输入框与结果表。
    let content = QuickActionViewController()

    /// 上次打开面板的仓库窗口。
    private weak var sourceWindow: RepositoryWindowController?

    /// 上次打开面板时窗口里的仓库。
    private var repository: RepositoryLocation?

    /// 创建透明标题栏、隐藏红绿灯的面板，内容放进玻璃效果视图。
    init() {
        let panel = QuickActionPanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = NSSize(width: 100, height: 250)
        panel.contentMaxSize = NSSize(width: 500, height: 800)

        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }

        let glass = NSGlassEffectView()
        glass.cornerRadius = 16
        glass.contentView = content.view
        panel.contentView = glass
        panel.setAccessibilityTitle(AppLocalization.text("quickActions.placeholder"))

        super.init(window: panel)

        panel.delegate = self
        content.close = { [weak self] in self?.window?.close() }
    }

    /// 只从代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 为仓库窗口打开面板，焦点放进输入框。
    func show(for owner: RepositoryWindowController) {
        guard let window, let location = owner.session.repository else {
            return
        }

        // 换了窗口或仓库时换上新的状态，旧的查询随之取消
        if sourceWindow !== owner || repository != location || content.controller == nil {
            content.controller?.stop()
            content.attach(QuickActionController(catalog: QuickActionCatalog(session: owner.session))) { [weak owner] in
                owner?.performQuickAction($1, on: $0)
            }
        }

        sourceWindow = owner
        repository = location

        place(window, on: owner.window?.screen ?? NSScreen.main)
        window.makeKeyAndOrderFront(nil)
        content.controller?.start()
        content.focusInput()
    }

    /// 面板失去焦点即关闭。
    func windowDidResignKey(_: Notification) {
        window?.close()
    }

    /// 关闭时取消还在进行的查询。
    func windowWillClose(_: Notification) {
        content.controller?.stop()
    }
}

// MARK: - Private

extension QuickActionWindowController {
    /// 水平居中于屏幕可见区域，上沿在可见区域顶端往下 1/5 处。
    private func place(_ window: NSWindow, on screen: NSScreen?) {
        guard let visible = screen?.visibleFrame else {
            window.center()
            return
        }

        let size = window.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.maxY - visible.height / 5 - size.height
        )

        window.setFrameOrigin(origin)
    }
}
