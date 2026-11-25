import AppKit

// MARK: - NarrowRepositoryViewController

/// 极窄版式的窗口内容：顶部一行视图导航，下面是当前主视图；侧边栏按需盖在主视图的左侧。
///
/// 换主视图时只替换下面的一块，视图导航与侧边栏留着。
final class NarrowRepositoryViewController: NSViewController {
    /// 内容的根视图，能接键盘焦点。
    ///
    /// 极窄版式里没有侧边栏的列表接焦点，窗口会把焦点交给第一个输入框，提交信息框随之进入编辑；
    /// 窗口内容换成极窄版式时焦点先落在这里。
    private final class ContentView: NSView {
        /// 接受键盘焦点。
        override var acceptsFirstResponder: Bool { true }
    }

    /// 侧边栏显示时盖住主视图其余部分的遮罩：压暗主视图，点按后收起侧边栏。
    private final class BackdropView: NSView {
        /// 点按遮罩时调用。
        var onClick: (() -> Void)?

        /// 点按收起侧边栏，不交给下面的主视图。
        override func mouseDown(with _: NSEvent) {
            onClick?()
        }
    }

    /// 视图导航的高度。
    private static let navigationHeight: CGFloat = 40

    /// 盖在主视图上的侧边栏的宽度。
    private static let sidebarWidth: CGFloat = 280

    /// 顶部的视图导航。
    let navigation: NSViewController

    /// 盖在主视图左侧的侧边栏。
    let sidebar: NSViewController

    /// 当前主视图。
    private(set) var detail: NSViewController

    /// 点按遮罩、要收起侧边栏时调用。
    var onDismissSidebar: (() -> Void)?

    /// 侧边栏是否显示；第一次显示时才装入。
    var showsSidebar = false {
        didSet {
            guard showsSidebar != oldValue, isViewLoaded else {
                return
            }

            updateSidebar()
        }
    }

    /// 视图导航与主视图之间的分隔线。
    private let separator = NSBox()

    /// 侧边栏的底：与常规版式的侧边栏相同的材质。
    private let sidebarBackground = NSVisualEffectView()

    /// 侧边栏显示时盖住主视图其余部分的遮罩。
    private let backdrop = BackdropView()

    /// 用视图导航、侧边栏与第一个主视图建立内容。
    ///
    /// - Parameters:
    ///   - navigation: 顶部的视图导航。
    ///   - sidebar: 盖在主视图左侧的侧边栏。
    ///   - detail: 当前主视图。
    init(navigation: NSViewController, sidebar: NSViewController, detail: NSViewController) {
        self.navigation = navigation
        self.sidebar = sidebar
        self.detail = detail
        super.init(nibName: nil, bundle: nil)
    }

    /// 内容由代码构建，不从归档恢复。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    /// 视图导航贴着工具栏的下边，分隔线在它下面，主视图占满其余部分。
    override func loadView() {
        view = ContentView()
        separator.boxType = .separator

        addChild(navigation)

        for subview in [navigation.view, separator] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: RepositoryWindowLayout.narrowMinimumWidth),
            navigation.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigation.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigation.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigation.view.heightAnchor.constraint(equalToConstant: Self.navigationHeight),
            separator.topAnchor.constraint(equalTo: navigation.view.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        install(detail)
    }

    /// 换成另一个主视图；侧边栏显示着时仍盖在新的主视图上面。
    ///
    /// - Parameter detail: 换入的主视图。
    func replaceDetail(with detail: NSViewController) {
        self.detail.view.removeFromSuperview()
        self.detail.removeFromParent()
        self.detail = detail

        guard isViewLoaded else {
            return
        }

        install(detail)
    }
}

// MARK: - Private

extension NarrowRepositoryViewController {
    /// 把主视图放在分隔线下面，占满其余部分，排在遮罩与侧边栏的下层。
    private func install(_ detail: NSViewController) {
        addChild(detail)
        detail.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detail.view, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            detail.view.topAnchor.constraint(equalTo: separator.bottomAnchor),
            detail.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detail.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detail.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// 按 `showsSidebar` 显示或藏起遮罩与侧边栏；第一次显示时装入，之后只切换隐藏，侧边栏的展开与滚动位置留着。
    private func updateSidebar() {
        if showsSidebar, backdrop.superview == nil {
            installSidebar()
        }

        backdrop.isHidden = !showsSidebar
        sidebarBackground.isHidden = !showsSidebar
    }

    /// 遮罩盖住分隔线以下的整块，侧边栏贴在它上面的左侧，右边一条分隔线。
    private func installSidebar() {
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        backdrop.onClick = { [weak self] in self?.onDismissSidebar?() }

        sidebarBackground.material = .sidebar
        sidebarBackground.blendingMode = .withinWindow
        sidebarBackground.state = .followsWindowActiveState

        let edge = NSBox()
        edge.boxType = .separator

        addChild(sidebar)

        let subviews: [(view: NSView, parent: NSView)] = [
            (backdrop, view),
            (sidebarBackground, view),
            (sidebar.view, sidebarBackground),
            (edge, sidebarBackground),
        ]

        for subview in subviews {
            subview.view.translatesAutoresizingMaskIntoConstraints = false
            subview.parent.addSubview(subview.view)
        }

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: separator.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarBackground.topAnchor.constraint(equalTo: separator.bottomAnchor),
            sidebarBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarBackground.widthAnchor.constraint(equalToConstant: Self.sidebarWidth),
            sidebar.view.topAnchor.constraint(equalTo: sidebarBackground.topAnchor),
            sidebar.view.leadingAnchor.constraint(equalTo: sidebarBackground.leadingAnchor),
            sidebar.view.trailingAnchor.constraint(equalTo: edge.leadingAnchor),
            sidebar.view.bottomAnchor.constraint(equalTo: sidebarBackground.bottomAnchor),
            edge.topAnchor.constraint(equalTo: sidebarBackground.topAnchor),
            edge.trailingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor),
            edge.bottomAnchor.constraint(equalTo: sidebarBackground.bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 1),
        ])
    }
}
