import AppKit

// MARK: - AboutWindowController

/// App 菜单的 About Spooky：自绘的关于窗口，只建一个，关掉后再次打开沿用它。
@MainActor
final class AboutWindowController: NSWindowController {
    /// 关于窗口的内容尺寸。
    static let size = NSSize(width: 470, height: 277)

    /// 建过的关于窗口。
    private(set) static var shared: AboutWindowController?

    /// 不能缩放的窗口：标题栏透明、不显示标题，内容铺到标题栏下面，只有关闭按钮可用。
    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.title = AppLocalization.text("about.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentViewController = AboutViewController()
        window.center()

        super.init(window: window)
    }

    /// 窗口只由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 显示关于窗口；已经在显示时带到前面。
    static func show() {
        let controller = shared ?? AboutWindowController()
        shared = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - AboutViewController

/// 关于窗口的内容：左栏是图标、名称、版本与 Release Notes，右栏是说明、版权与 Acknowledgements、License 两个按钮。
///
/// 左栏从上往下排；右栏的说明从上往下排、顶边与图标对齐，版权与两个按钮从下往上排，两个按钮与 Release Notes 基线对齐。
final class AboutViewController: NSViewController {
    /// 窗口边缘与两栏之间的间距。
    private static let margin: CGFloat = 30

    /// 控件之间的标准间距。
    private static let spacing: CGFloat = 8

    /// 应用图标的边长。
    private static let iconSize: CGFloat = 128

    /// 右栏的宽度：窗口宽度减去图标与三处间距。
    private static let columnWidth = AboutWindowController.size.width - iconSize - margin * 3

    /// 应用图标，显示时取当前的运行时图标。
    private let iconView = NSImageView()

    /// 版本行：短版本号与构建号，如 “Version 0.12.0 (1)”。
    ///
    /// - Parameter info: App 的 `Info.plist`。
    static func versionLine(info: [String: Any]) -> String {
        AppLocalization.text(
            "about.version",
            info["CFBundleShortVersionString"] as? String ?? "",
            info["CFBundleVersion"] as? String ?? ""
        )
    }

    /// 铺满窗口的 `headerView` 材质，跟随窗口的活跃状态。
    override func loadView() {
        let background = NSVisualEffectView()
        background.material = .headerView
        background.blendingMode = .behindWindow
        background.state = .followsWindowActiveState

        let info = Bundle.main.infoDictionary ?? [:]

        let name = NSTextField(labelWithString: info["CFBundleName"] as? String ?? "")
        name.font = .preferredFont(forTextStyle: .largeTitle)

        let version = NSTextField(labelWithString: Self.versionLine(info: info))
        version.font = .systemFont(ofSize: 13)
        version.isSelectable = true

        // Release Notes 与 Help 菜单的同名菜单项是同一个动作，经响应链交给 App 的控制器
        let releaseNotes = button(
            "help.releaseNotes",
            action: #selector(SpookyApplicationController.openReleaseNotes),
            target: nil
        )
        releaseNotes.bezelStyle = .toolbar
        releaseNotes.showsBorderOnlyWhileMouseInside = true

        let credits = paragraph(AppLocalization.text("about.credits"), size: 13)

        let copyright = paragraph(info["NSHumanReadableCopyright"] as? String ?? "", size: 11)
        copyright.textColor = .secondaryLabelColor

        let acknowledgements = button("about.acknowledgements", action: #selector(showAcknowledgements), target: self)

        let license = button("about.license", action: #selector(showLicense), target: self)
        license.isEnabled = AboutDocument.licenseURL != nil

        iconView.imageScaling = .scaleProportionallyDown

        let subviews = [iconView, name, version, releaseNotes, credits, copyright, acknowledgements, license]

        for subview in subviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(subview)
        }

        // 内容固定为 470 × 277；左栏从上往下排，Release Notes 下面余下的就是底边距
        let size = [
            background.widthAnchor.constraint(equalToConstant: AboutWindowController.size.width),
            background.heightAnchor.constraint(equalToConstant: AboutWindowController.size.height),
        ]

        let left = leftColumn(in: background, name: name, version: version, releaseNotes: releaseNotes)

        let right = rightColumn(
            in: background,
            credits: credits,
            copyright: copyright,
            buttons: (acknowledgements, license),
            baseline: releaseNotes
        )

        NSLayoutConstraint.activate(size + left + right)

        view = background
    }

    /// 每次显示时换上当前的应用图标，连接状态改变后图标也跟着变。
    override func viewWillAppear() {
        super.viewWillAppear()

        iconView.image = NSApp.applicationIconImage
    }

    /// Acknowledgements：以 sheet 列出第三方库与各自的许可证。
    @objc
    private func showAcknowledgements() {
        presentAsSheet(AboutDocumentViewController(document: AboutDocument.acknowledgements(AboutDocument.libraries)))
    }

    /// License：以 sheet 显示 Spooky 的 GPL-3.0 许可证。
    @objc
    private func showLicense() {
        guard let document = AboutDocument.licenseURL.flatMap(AboutDocument.license(at:)) else {
            return
        }

        presentAsSheet(AboutDocumentViewController(document: document))
    }

    /// 左栏：图标距左 30、距上 40，名称、版本与 Release Notes 依次排在下面，都与图标水平居中。
    private func leftColumn(
        in background: NSView,
        name: NSView,
        version: NSView,
        releaseNotes: NSView
    ) -> [NSLayoutConstraint] {
        [
            iconView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Self.margin),
            iconView.topAnchor.constraint(equalTo: background.topAnchor, constant: 40),
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            name.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            name.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: Self.spacing),

            version.centerXAnchor.constraint(equalTo: name.centerXAnchor),
            version.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),

            releaseNotes.centerXAnchor.constraint(equalTo: version.centerXAnchor),
            releaseNotes.topAnchor.constraint(equalTo: version.bottomAnchor, constant: Self.spacing),
        ]
    }

    /// 右栏：从图标右边 30 起到距右 30；说明的顶边与图标的顶边对齐，两个按钮在版权下 20，左右分别对齐说明的两边、宽度相同；
    /// 版权与说明之间至少 20，多出的空间留在两者之间。
    private func rightColumn(
        in background: NSView,
        credits: NSView,
        copyright: NSView,
        buttons: (acknowledgements: NSView, license: NSView),
        baseline releaseNotes: NSView
    ) -> [NSLayoutConstraint] {
        [
            credits.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Self.margin),
            background.trailingAnchor.constraint(equalTo: credits.trailingAnchor, constant: Self.margin),
            credits.topAnchor.constraint(equalTo: iconView.topAnchor),

            copyright.leadingAnchor.constraint(equalTo: credits.leadingAnchor),
            copyright.trailingAnchor.constraint(equalTo: credits.trailingAnchor),
            copyright.topAnchor.constraint(greaterThanOrEqualTo: credits.bottomAnchor, constant: 20),

            buttons.acknowledgements.leadingAnchor.constraint(equalTo: credits.leadingAnchor),
            buttons.acknowledgements.topAnchor.constraint(equalTo: copyright.bottomAnchor, constant: 20),
            buttons.acknowledgements.firstBaselineAnchor.constraint(equalTo: releaseNotes.firstBaselineAnchor),

            buttons.license.leadingAnchor.constraint(equalTo: buttons.acknowledgements.trailingAnchor, constant: Self.spacing),
            buttons.license.trailingAnchor.constraint(equalTo: credits.trailingAnchor),
            buttons.license.centerYAnchor.constraint(equalTo: buttons.acknowledgements.centerYAnchor),
            buttons.license.widthAnchor.constraint(equalTo: buttons.acknowledgements.widthAnchor),
        ]
    }

    /// 右栏宽度内自动换行、可以选中的文字。
    ///
    /// - Parameters:
    ///   - text: 文字。
    ///   - size: 字号。
    private func paragraph(_ text: String, size: CGFloat) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size)
        field.isSelectable = true
        field.preferredMaxLayoutWidth = Self.columnWidth
        return field
    }

    /// 11 pt 的小号按钮。
    ///
    /// - Parameters:
    ///   - key: 标题的资源键。
    ///   - action: 按下时的动作。
    ///   - target: 动作的接收者；nil 时沿响应链查找。
    private func button(_ key: String, action: Selector, target: AnyObject?) -> NSButton {
        let button = NSButton(title: AppLocalization.text(key), target: target, action: action)
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        return button
    }
}
