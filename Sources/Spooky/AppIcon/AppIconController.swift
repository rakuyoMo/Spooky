import AppKit
import Observation

// MARK: - AppIconController

/// Dock 中的 App 图标：显示所选的一组，跟随 “系统设置 › 外观 › 图标与小组件样式”，连着服务器时指示灯亮起。
///
/// Dock 画包内图标时会裁成系统的圆角形状、加上亮边与阴影，运行时设置的图标与写进包里的自定义图标都原样画出；
/// 所以每组都以系统把这一组画成包内图标时的样子为底：服务器幽灵取 App 自身的系统图标，其它组取包里各自壳 App 的系统图标。
///
/// - 默认与深色样式下系统不改动包内图标：深色样式换成该组的深色图标，连着服务器时换成指示灯亮着的一版
/// - 透明、色调样式下系统按样式处理包内图标，运行时设置的图标做不到同样的效果，指示灯不亮：
///   服务器幽灵交还包里的默认图标，其它组用系统已按样式处理过的壳 App 图标
/// - 访达总是显示包里的默认图标，macOS 27 的 ⌘Tab 切换器也不用运行时设置的图标（实测）
@MainActor
@Observable
final class AppIconController {
    /// 运行时图标的像素边长，与 icns 里最大的一张位图相同：Dock 放大时也要清晰。
    private static let iconPixels = 1024

    /// “图标与小组件样式” 在全局偏好里的键；选 “默认” 时键不存在。
    private static let iconThemeKey = "AppleIconAppearanceTheme"

    /// 样式或色调颜色变化时 `NSWorkspace` 的通知中心发出的通知，此时全局偏好已是新值；名称不在公开头文件里。
    private static let iconAppearanceDidChangeNotification = Notification.Name(
        "NSWorkspaceIconAppearanceConfigurationDidChangeNotification"
    )

    /// `NSWorkspace` 读取当前图标样式配置的方法，不在公开头文件里。
    private static let iconAppearanceConfigurationSelector = NSSelectorFromString(
        "currentIconAppearanceConfiguration"
    )

    /// 所选的组。
    private(set) var group: AppIconGroup

    /// 当前的深浅：“图标与小组件样式” 选了深色，或选了自动且外观是深色时为深色；设置页按它显示深色或默认图标。
    private(set) var isDark = false

    /// 是否有服务器仓库连着：连着时 App 图标上的指示灯亮起。
    @ObservationIgnored
    var isConnected = false {
        didSet {
            // 各窗口的连接状态变化都会通知过来，总的结果没变时不重新生成图标。
            guard isConnected != oldValue else {
                return
            }

            updateIcon()
        }
    }

    /// 图标资源与壳 App 所在的 App 包。
    @ObservationIgnored
    private let bundle: Bundle

    /// 对 “图标与小组件样式” 变化的观察。
    @ObservationIgnored
    private var iconStyleObservation: (any NSObjectProtocol)? = nil

    /// 对 App 外观的观察：样式选了自动子选项时，深浅跟随这个值。
    @ObservationIgnored
    private var appearanceObservation: NSKeyValueObservation? = nil

    /// 从偏好读出所选的组；图标等到 `start()` 才设置。
    /// - Parameters:
    ///   - defaults: 保存所选的组的偏好域，测试使用独立的域
    ///   - bundle: 图标资源与壳 App 所在的 App 包
    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        self.bundle = bundle
        group = AppIconGroup.current(in: defaults)
    }

    /// 当前的深浅：样式没选（默认）时为浅色，深色子选项为深色，自动子选项跟随外观，其余为浅色。
    ///
    /// 默认、透明、色调三种样式都按各自的深浅子选项判断：`RegularDark`、`ClearDark`、`TintedDark` 为深色，
    /// `…Automatic` 跟随外观，`ClearLight`、`TintedLight` 为浅色。
    /// - Parameters:
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`；高对比度等变体归入对应的深色或浅色
    static func isDark(
        forIconTheme iconTheme: String?,
        appearance: NSAppearance
    ) -> Bool {
        guard let iconTheme else {
            return false
        }

        if iconTheme.hasSuffix("Automatic") {
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }

        return iconTheme.hasSuffix("Dark")
    }

    /// 运行时要换上的一版；nil 表示用包里的默认图标，由 Dock 按样式处理。
    ///
    /// 默认与深色样式（键不存在或 `Regular…`）下按深浅与连接状态取该组的一版；服务器幽灵浅色、没连时就是包里的默认图标，不用换。
    /// 透明、色调样式（`Clear…`、`Tinted…`）与其它取值下指示灯不亮：服务器幽灵不换，
    /// 其它组用该组的默认图标，底图是系统已按样式处理过的壳 App 图标。
    /// - Parameters:
    ///   - group: 所选的组
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`，只在 “自动” 子选项下起作用
    ///   - isConnected: 是否有服务器仓库连着
    static func variant(
        for group: AppIconGroup,
        iconTheme: String?,
        appearance: NSAppearance,
        isConnected: Bool
    ) -> AppIconVariant? {
        let isRegular = iconTheme.map { $0.hasPrefix("Regular") } ?? true

        guard isRegular else {
            return group == .serverGhost ? nil : .standard
        }

        let variant = AppIconVariant(
            isDark: isDark(forIconTheme: iconTheme, appearance: appearance),
            isConnected: isConnected
        )

        return group == .serverGhost && variant == .standard ? nil : variant
    }

    /// 按所选的组与当前样式设一次图标，此后在样式或深浅变化时重新设置。
    func start() {
        styleDidChange()

        // AppKit 读过一次当前的样式配置之后，才在样式变化时发出下面这条通知（macOS 27 实测）。
        if NSWorkspace.shared.responds(to: Self.iconAppearanceConfigurationSelector) {
            _ = NSWorkspace.shared.perform(Self.iconAppearanceConfigurationSelector)
        }

        // 样式或色调颜色变化时 AppKit 发出这条通知；透明、色调样式下壳 App 的系统图标随之变化。
        iconStyleObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: Self.iconAppearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.styleDidChange()
            }
        }

        // 自动子选项跟随外观；外观在主线程上变化，观察回调也在主线程。
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.styleDidChange()
            }
        }
    }
}

// MARK: - Private

extension AppIconController {
    /// 全局偏好里 “图标与小组件样式” 的当前值。
    private var iconTheme: String? {
        UserDefaults.standard.string(forKey: Self.iconThemeKey)
    }

    /// 样式或外观变化后更新深浅，并重画运行时图标。
    private func styleDidChange() {
        isDark = Self.isDark(forIconTheme: iconTheme, appearance: NSApp.effectiveAppearance)
        updateIcon()
    }

    /// 把 App 图标设成所选的组在当前样式与连接状态下的一版；不需要换或生成不了时交还包里的默认图标。
    private func updateIcon() {
        let variant = Self.variant(
            for: group,
            iconTheme: iconTheme,
            appearance: NSApp.effectiveAppearance,
            isConnected: isConnected
        )

        // 设为 nil 后 Dock 改回显示包里的默认图标，并按透明、色调样式重新处理。
        guard let variant else {
            NSApp.applicationIconImage = nil
            return
        }

        // 生成不了时同样设为 nil：上一次设的运行时图标与当前的组、样式或连接状态不符，默认图标至少由 Dock 按当前样式处理。
        NSApp.applicationIconImage = icon(for: variant, of: group)
    }

    /// 按组与一版合成运行时图标；取不到资源或合成失败时为 nil。
    ///
    /// 以系统画好的包内图标为底、叠上目标图标与包内图标的差别，在 Dock 里才与系统画同一张图标的样子一致，
    /// 连上服务器时只有指示灯变化；透明、色调样式下包内图标与目标图标相同，结果就是系统按样式处理过的样子。
    /// - Parameters:
    ///   - variant: 要合成的一版
    ///   - group: 图标所属的组
    private func icon(
        for variant: AppIconVariant,
        of group: AppIconGroup
    ) -> NSImage? {
        // 直接运行可执行文件、没有 .app 包时取不到资源；资源齐全才去取系统图标，取系统图标会让 LaunchServices 登记那个包。
        guard
            let bundledIcon = bundle.image(forResource: group.iconName(for: .standard)),
            let targetIcon = bundle.image(forResource: group.iconName(for: variant)),
            let systemIconPath = systemIconPath(of: group),
            let bundled = Self.image(of: bundledIcon),
            let target = Self.image(of: targetIcon),
            let system = Self.image(of: NSWorkspace.shared.icon(forFile: systemIconPath)),
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

    /// 系统画这一组包内图标时用的包：服务器幽灵是 App 自身，其它组是包里与该组默认图标同名的壳 App；找不到时为 nil。
    /// - Parameter group: 图标所属的组
    private func systemIconPath(of group: AppIconGroup) -> String? {
        guard group != .serverGhost else {
            return bundle.bundlePath
        }

        return bundle.path(forResource: group.iconName(for: .standard), ofType: "app")
    }
}

// MARK: - Helpers

extension AppIconController {
    /// 图标在 `iconPixels` 边长下的位图；取不到时为 nil。
    private static func image(of icon: NSImage) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: iconPixels, height: iconPixels)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
