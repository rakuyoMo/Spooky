import AppKit

// MARK: - AppIconVariant

/// 运行时换上的 App 图标。
enum AppIconVariant: Equatable {
    /// 默认样式下连着服务器：默认图标，指示灯亮着。
    case connected

    /// 深色样式：深色图标，连着服务器时指示灯亮着。
    case dark(isConnected: Bool)
}

// MARK: - AppIconController

/// Dock 中的 App 图标：跟随 “系统设置 › 外观 › 图标与小组件样式”，连着服务器时机架上的指示灯亮起。
///
/// 包里只有 icns、没有 Assets.car，访达等处总是显示指示灯灭着的默认图标，其余几版只能在运行时换上；
/// macOS 27 的 ⌘Tab 切换器不用运行时设置的图标，总是显示包里的默认图标（实测）。
/// 透明、色调样式下 Dock 按样式处理包里的默认图标，运行时设置的图标做不到同样的效果，所以这两种样式下不换图标、指示灯不亮；
/// 默认与深色样式下 Dock 不改动包里的默认图标，深色样式换成深色图标，连着服务器时换成指示灯亮着的一版。
@MainActor
final class AppIconController {
    /// 指示灯灭着的默认图标在包里的资源名，即 Info.plist 的 `CFBundleIconFile`。
    private static let defaultIconName = "AppIcon"

    /// 指示灯亮着的默认图标在包里的资源名。
    private static let connectedIconName = "AppIconConnected"

    /// 指示灯灭着的深色图标在包里的资源名。
    private static let darkIconName = "AppIconDark"

    /// 指示灯亮着的深色图标在包里的资源名。
    private static let darkConnectedIconName = "AppIconDarkConnected"

    /// 运行时图标的像素边长，与 icns 里最大的一张位图相同：Dock 放大时也要清晰。
    private static let iconPixels = 1024

    /// “图标与小组件样式” 在全局偏好里的键；选 “默认” 时键不存在。
    private static let iconThemeKey = "AppleIconAppearanceTheme"

    /// 样式或色调颜色变化时 `NSWorkspace` 的通知中心发出的通知，此时全局偏好已是新值；名称不在公开头文件里。
    private static let iconAppearanceDidChangeNotification = Notification.Name(
        "NSWorkspaceIconAppearanceConfigurationDidChangeNotification"
    )

    /// 是否有服务器仓库连着：连着时 App 图标上的指示灯亮起。
    var isConnected = false {
        didSet {
            // 各窗口的连接状态变化都会通知过来，总的结果没变时不重新生成图标。
            guard isConnected != oldValue else {
                return
            }

            updateIcon()
        }
    }

    /// 对 “图标与小组件样式” 变化的观察。
    private var iconStyleObservation: (any NSObjectProtocol)? = nil

    /// 对 App 外观的观察：App 没有固定外观，这个值跟随系统的深浅。
    private var appearanceObservation: NSKeyValueObservation? = nil

    /// 运行时要换上的图标；nil 表示用包里的默认图标，由 Dock 按样式处理。
    ///
    /// 深色样式的两个子变体换成深色图标：`RegularDark` 始终换，`RegularAutomatic` 跟随系统深浅外观，只在深色外观下换。
    /// 默认样式与 `RegularAutomatic` 的浅色外观用默认图标：包里的默认图标指示灯灭着，连着服务器时才换成点亮指示灯的一版。
    /// 透明、色调样式（`Clear…`、`Tinted…`）与其它取值都不换。
    /// - Parameters:
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`，只在 “自动” 子变体下起作用；高对比度等变体归入对应的深色或浅色
    ///   - isConnected: 是否有服务器仓库连着
    static func variant(
        forIconTheme iconTheme: String?,
        appearance: NSAppearance,
        isConnected: Bool
    ) -> AppIconVariant? {
        let defaultVariant: AppIconVariant? = isConnected ? .connected : nil

        switch iconTheme {
        case nil:
            return defaultVariant

        case "RegularDark":
            return .dark(isConnected: isConnected)

        case "RegularAutomatic":
            let isDarkAppearance = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDarkAppearance ? .dark(isConnected: isConnected) : defaultVariant

        default:
            return nil
        }
    }

    /// 按当前样式与连接状态设一次图标，此后在样式或系统深浅变化时重新设置。
    func start() {
        updateIcon()

        // 样式变化时 AppKit 发出这条通知。
        iconStyleObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: Self.iconAppearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateIcon()
            }
        }

        // 深色样式的 “自动” 子变体跟随系统深浅；外观在主线程上变化，观察回调也在主线程。
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.updateIcon()
            }
        }
    }
}

// MARK: - Private

extension AppIconController {
    /// 把 App 图标设成当前样式与连接状态对应的一版；不需要换或生成不了时交还包里的默认图标。
    private func updateIcon() {
        let variant = Self.variant(
            forIconTheme: UserDefaults.standard.string(forKey: Self.iconThemeKey),
            appearance: NSApp.effectiveAppearance,
            isConnected: isConnected
        )

        // 设为 nil 后 Dock 改回显示包里的默认图标，并按透明、色调样式重新处理。
        guard let variant else {
            NSApp.applicationIconImage = nil
            return
        }

        // 生成不了时同样设为 nil：上一次设的运行时图标与当前样式或连接状态不符，默认图标至少由 Dock 按当前样式处理。
        NSApp.applicationIconImage = Self.icon(for: variant)
    }
}

// MARK: - Helpers

extension AppIconController {
    /// 按变体生成运行时图标；取不到资源或合成失败时为 nil。
    ///
    /// Dock 画包内图标时会裁成系统的圆角形状、加上亮边与阴影，画运行时图标时原样画出；
    /// 系统画好的包内默认图标由 `NSWorkspace` 给出，以它为底、叠上目标图标与默认图标的差别，
    /// 运行时图标在 Dock 里才与系统画同一张图标的样子一致，连上服务器时只有指示灯变化。
    private static func icon(for variant: AppIconVariant) -> NSImage? {
        let targetName =
            switch variant {
            case .connected:
                connectedIconName

            case .dark(let isConnected):
                isConnected ? darkConnectedIconName : darkIconName
            }

        // 直接运行可执行文件、没有 .app 包时取不到资源。
        guard
            let bundledIcon = Bundle.main.image(forResource: defaultIconName),
            let targetIcon = Bundle.main.image(forResource: targetName),
            let bundled = image(of: bundledIcon),
            let target = image(of: targetIcon),
            let system = image(of: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)),
            let rendered = AppIconRenderer.runtimeIcon(
                system: system,
                bundled: bundled,
                target: target
            )
        else {
            return nil
        }

        return NSImage(cgImage: rendered, size: bundledIcon.size)
    }

    /// 图标在 `iconPixels` 边长下的位图；取不到时为 nil。
    private static func image(of icon: NSImage) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: iconPixels, height: iconPixels)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
