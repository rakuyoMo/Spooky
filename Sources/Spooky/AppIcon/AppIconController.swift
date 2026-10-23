import AppKit

// MARK: - AppIconStyle

/// “图标与小组件样式” 的三种样式，决定图标怎样上色。
enum AppIconStyle {
    /// 默认与深色样式：图标原样显示。
    case regular

    /// 透明样式：图标去色。
    case clear

    /// 色调样式：图标按色调颜色着色。
    case tinted
}

// MARK: - AppIconVariant

/// 运行时换上的 App 图标。
///
/// Dock 对运行时设置的图标原样显示、不做任何样式处理，所以各样式的处理都要先做好再设。
enum AppIconVariant: Equatable {
    /// 深色样式，以及透明、色调的深色子变体：深色图标按样式处理，连着服务器时指示灯亮着。
    case dark(AppIconStyle, isConnected: Bool)

    /// 其余样式下连着服务器：系统按样式处理过的包内默认图标，指示灯换成亮着的。
    case connected(AppIconStyle)
}

// MARK: - AppIconController

/// Dock 与 ⌘Tab 中的 App 图标：跟随 “系统设置 › 外观 › 图标与小组件样式”，连着服务器时机架上的指示灯亮起。
///
/// 包里只有 icns、没有 Assets.car，访达等处总是显示指示灯灭着的默认图标，其余几版只能在运行时换到 Dock 与 ⌘Tab 上。
/// Dock 只对包里的默认图标做透明、色调处理，运行时设置的图标一律原样显示（macOS 27 实测），
/// 所以深色样式与透明、色调的深色子变体都换成处理好的深色图标；其余样式没连服务器时交还包里的默认图标，
/// 连着服务器时换成系统处理过的默认图标、只点亮指示灯。
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
    /// 深色、透明、色调三种样式各有两个子变体要换成深色图标：取值以 `Dark` 结尾的始终换，
    /// 以 `Automatic` 结尾的跟随系统深浅外观，只在深色外观下换。其余情况用默认图标：包里的默认图标指示灯灭着，
    /// 连着服务器时才需要换成点亮指示灯的一版。
    /// - Parameters:
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`，只在 “自动” 子变体下起作用；高对比度等变体归入对应的深色或浅色
    ///   - isConnected: 是否有服务器仓库连着
    static func variant(
        forIconTheme iconTheme: String?,
        appearance: NSAppearance,
        isConnected: Bool
    ) -> AppIconVariant? {
        let isDarkAppearance = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // 取值的前半是样式，后半是子变体；“默认” 样式与 `Light` 子变体都用默认图标。
        let (style, usesDarkIcon): (AppIconStyle, Bool) =
            switch iconTheme {
            case "RegularDark":
                (.regular, true)

            case "RegularAutomatic":
                (.regular, isDarkAppearance)

            case "ClearLight":
                (.clear, false)

            case "ClearDark":
                (.clear, true)

            case "ClearAutomatic":
                (.clear, isDarkAppearance)

            case "TintedLight":
                (.tinted, false)

            case "TintedDark":
                (.tinted, true)

            case "TintedAutomatic":
                (.tinted, isDarkAppearance)

            default:
                (.regular, false)
            }

        if usesDarkIcon {
            return .dark(style, isConnected: isConnected)
        }

        return isConnected ? .connected(style) : nil
    }

    /// 按当前样式与连接状态设一次图标，此后在样式、色调颜色或系统深浅变化时重新设置。
    func start() {
        updateIcon()

        // 样式或色调颜色变化时 AppKit 发出这条通知。
        iconStyleObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: Self.iconAppearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateIcon()
            }
        }

        // 各样式的 “自动” 子变体跟随系统深浅；外观在主线程上变化，观察回调也在主线程。
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
    /// 按变体生成运行时图标；取不到资源、取不到色调颜色或处理失败时为 nil。
    private static func icon(for variant: AppIconVariant) -> NSImage? {
        switch variant {
        case .dark(let style, let isConnected):
            darkIcon(style: style, isConnected: isConnected)

        case .connected(let style):
            connectedIcon(style: style)
        }
    }

    /// 深色图标：原样，或按当前色调颜色去色、着色。
    /// - Parameters:
    ///   - style: 要处理成的样式
    ///   - isConnected: 用指示灯亮着的一版还是灭着的一版
    private static func darkIcon(
        style: AppIconStyle,
        isConnected: Bool
    ) -> NSImage? {
        // 直接运行可执行文件、没有 .app 包时取不到资源。
        guard let darkIcon = Bundle.main.image(forResource: isConnected ? darkConnectedIconName : darkIconName) else {
            return nil
        }

        // 原样显示的样式直接返回；透明、色调先定下处理方式，色调颜色在这时取当前值。
        let render: (CGImage) -> CGImage?

        switch style {
        case .regular:
            return darkIcon

        case .clear:
            render = AppIconRenderer.clear

        case .tinted:
            // 取不到色调颜色时不生成，交还包里的默认图标，由 Dock 按系统设置的颜色处理。
            guard let tintColor = iconTintColor() else {
                return nil
            }

            render = { AppIconRenderer.tinted($0, tintColor: tintColor) }
        }

        guard
            let source = largestImage(of: darkIcon),
            let processed = render(source)
        else {
            return nil
        }

        return NSImage(cgImage: processed, size: darkIcon.size)
    }

    /// 默认图标点亮指示灯的一版：以系统按当前样式处理过的包内默认图标为底，只换指示灯。
    ///
    /// 灯灭时 Dock 显示的就是系统处理过的包内默认图标，系统处理时还会把图标裁成自己的圆角形状、加上描边；
    /// 以它为底，连上服务器时图标只有指示灯变化。
    /// - Parameter style: 当前的样式；透明、色调样式下灯光按系统的处理上色
    private static func connectedIcon(style: AppIconStyle) -> NSImage? {
        // 直接运行可执行文件、没有 .app 包时取不到资源，系统也给不出 App 的图标。
        guard
            let unlitIcon = Bundle.main.image(forResource: defaultIconName),
            let litIcon = Bundle.main.image(forResource: connectedIconName),
            let unlit = largestImage(of: unlitIcon),
            let lit = largestImage(of: litIcon),
            let styled = systemStyledIcon(pixels: unlit.width),
            let processed = AppIconRenderer.lightUp(
                styled,
                unlit: unlit,
                lit: lit,
                recolorsLights: style != .regular
            )
        else {
            return nil
        }

        return NSImage(cgImage: processed, size: unlitIcon.size)
    }

    /// 系统按当前样式处理过的包内默认图标，画成给定边长的位图；建不起位图时为 nil。
    /// - Parameter pixels: 位图的边长
    private static func systemStyledIcon(pixels: Int) -> CGImage? {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: pixels,
                height: pixels,
                bitsPerComponent: 8,
                bytesPerRow: pixels * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        // `NSWorkspace` 给出的 App 图标已按当前样式处理；色调颜色按绘制时的外观解析，与 App 当前的深浅一致。
        #warning("TODO: 在默认样式与透明、色调的浅色子变体下连上服务器，再切换样式、色调颜色与深浅外观，对照 Dock 核实图标只有指示灯变化；只影响这几种样式下连着服务器时的图标。")
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

            icon.draw(
                in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                from: .zero,
                operation: .copy,
                fraction: 1
            )

            NSGraphicsContext.restoreGraphicsState()
        }

        return context.makeImage()
    }

    /// icns 里最大的一张位图：Dock 放大时也要清晰。
    private static func largestImage(of icon: NSImage) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// “图标与小组件样式” 当前的色调颜色；选 “自动” 时是系统解析出的颜色，取不到时为 nil。
    ///
    /// 全局偏好只存颜色名，“自动” 时连名字都没有，解析后的颜色要从 `NSWorkspace` 的私有配置对象取：
    /// `currentIconAppearanceConfiguration` 返回 SkyLight 的 `SLSIconAppearanceConfiguration`，
    /// 色调样式下它的 `resolvedIconTintColor` 是 `NSColor`（macOS 27 实测）。
    private static func iconTintColor() -> NSColor? {
        let configurationSelector = NSSelectorFromString("currentIconAppearanceConfiguration")
        let tintColorKey = "resolvedIconTintColor"

        // 私有接口，逐步确认存在再取，任何一步不满足都算取不到。
        guard
            NSWorkspace.shared.responds(to: configurationSelector),
            let configuration = NSWorkspace.shared
                .perform(configurationSelector)?
                .takeUnretainedValue() as? NSObject,
            configuration.responds(to: NSSelectorFromString(tintColorKey))
        else {
            return nil
        }

        return configuration.value(forKey: tintColorKey) as? NSColor
    }
}
