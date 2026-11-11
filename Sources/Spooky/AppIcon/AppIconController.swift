import AppKit
import Observation

// MARK: - AppIconController

/// Dock、⌘Tab 与访达中的 App 图标：显示所选的一组，跟随 “系统设置 › 外观 › 图标与小组件样式”，连着服务器时指示灯亮起。
///
/// Dock 画包内图标时会裁成系统的圆角形状、加上亮边与阴影，运行时设置的图标与写进包里的自定义图标都原样画出；
/// 所以每组都以系统把这一组画成包内图标时的样子为底：服务器幽灵取 App 自身的系统图标，其它组取包里各自壳 App 的系统图标。
///
/// - 默认与深色样式下系统不改动包内图标：深色样式换成该组的深色图标，连着服务器时换成指示灯亮着的一版
/// - 透明、色调样式下系统按样式处理包内图标，运行时设置的图标做不到同样的效果，指示灯不亮：
///   服务器幽灵交还包里的默认图标，其它组用系统已按样式处理过的壳 App 图标
/// - macOS 27 的 ⌘Tab 切换器不用运行时设置的图标（实测）：选中其它组时把当前样式下指示灯灭着的一版写成 App 包的自定义图标，
///   访达与没运行时的 Dock 也随之显示这一组；选回服务器幽灵时清掉
@MainActor
@Observable
final class AppIconController {
    /// 运行时图标的像素边长，与 icns 里最大的一张位图相同：Dock 放大时也要清晰。
    private static let iconPixels = 1024

    /// “图标与小组件样式” 在全局偏好里的键；选 “默认” 时键不存在。
    private static let iconThemeKey = "AppleIconAppearanceTheme"

    /// 样式或色调颜色变化时 `NSWorkspace` 的通知中心发出的通知，此时全局偏好已是新值；名称不在公开头文件里。
    static let iconAppearanceDidChangeNotification = Notification.Name(
        "NSWorkspaceIconAppearanceConfigurationDidChangeNotification"
    )

    /// `NSWorkspace` 读取当前图标样式配置的方法，不在公开头文件里。
    private static let iconAppearanceConfigurationSelector = NSSelectorFromString(
        "currentIconAppearanceConfiguration"
    )

    /// 自定义图标的写入队列：整个进程的写入与清除都按排队的顺序在这里串行执行，主线程不等待。
    ///
    /// 包在 “文稿” 等受保护的位置时，系统询问访问权限期间写入一直等着，放在主线程上整个 App 就会卡住；
    /// `setIcon(_:forFile:options:)` 经过的资源管理器不能在几个线程上同时调用，同时写会失败或崩溃（macOS 27 实测）。
    nonisolated static let writeQueue = DispatchQueue(label: "com.rakuyo.spooky.app-icon", qos: .userInitiated)

    /// 所选的组。
    private(set) var group: AppIconGroup

    /// 当前的深浅：“图标与小组件样式” 选了深色，或选了自动且外观是深色时为深色；设置页按它显示深色或默认图标。
    private(set) var isDark = false

    /// 设置页 “App Icon:” 一行显示的图标：所选的组在当前样式下指示灯灭着的一版，画法与 Dock 相同；生成不了时为 nil。
    private(set) var unlitIcon: NSImage? = nil

    /// 是否有服务器仓库连着：连着时 App 图标上的指示灯亮起；自定义图标总是灭灯的一版，不用重写。
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

    /// 保存所选的组的偏好域，测试使用独立的域。
    @ObservationIgnored
    private let defaults: UserDefaults

    /// 图标资源与壳 App 所在、写入自定义图标的 App 包；测试指向临时目录里的 App。
    @ObservationIgnored
    private let bundle: Bundle

    /// 已排队的写入全部写完后自定义图标所属的组：换组还没写完时，样式变化的重写按它写，不写回原来的组。
    @ObservationIgnored
    private var requestedGroup: AppIconGroup

    /// 换组与重新套用偏好的序号，每排进一次写入加一：写入失败时只有最近的一次请求把 `requestedGroup` 退回已选的组。
    @ObservationIgnored
    private var latestRequest = 0

    /// 已排进队列、还没结算的换组与重新套用偏好：全部结算完时才决定是否重启 Dock；测试据此等待结算。
    @ObservationIgnored
    private(set) var pendingRequests = 0

    /// 换组与重新套用偏好的写入让包上有没有自定义图标变了奇数次，固定在 Dock 里的格子显示的组不对；重启 Dock 后复位。
    @ObservationIgnored
    private var isDockStale = false

    /// 重新套用偏好的次数，每次 `reload()` 加一：此前发出、此后才写完的换组不再存进偏好。
    @ObservationIgnored
    private var reloadCount = 0

    /// 对 “图标与小组件样式” 变化的观察。
    @ObservationIgnored
    private var iconStyleObservation: (any NSObjectProtocol)? = nil

    /// 对 App 外观的观察：样式选了自动子选项时，深浅跟随这个值。
    @ObservationIgnored
    private var appearanceObservation: NSKeyValueObservation? = nil

    /// 包上有没有自定义图标变了时重启 Dock，让固定在 Dock 里的格子换成所选的组；测试传入记录调用的闭包，不碰真实的 Dock。
    @ObservationIgnored
    private let restartDock: @MainActor () -> Void

    /// 从偏好读出所选的组；图标等到 `start()` 才设置。
    /// - Parameters:
    ///   - defaults: 保存所选的组的偏好域，测试使用独立的域
    ///   - bundle: 图标资源与壳 App 所在、写入自定义图标的 App 包；测试指向临时目录里的 App
    ///   - restartDock: 重启 Dock，默认是 `restartSystemDock()`
    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        restartDock: @escaping @MainActor () -> Void = AppIconController.restartSystemDock
    ) {
        let group = AppIconGroup.current(in: defaults)

        self.defaults = defaults
        self.bundle = bundle
        self.restartDock = restartDock
        self.group = group
        requestedGroup = group
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

    /// 写成 App 包自定义图标的一版：当前样式下指示灯灭着的一版；nil 表示清掉自定义图标，交还包里的默认图标。
    ///
    /// ⌘Tab、访达与没运行时的 Dock 只认包里的图标；服务器幽灵就是包里的默认图标，其它组才要写。
    /// 自定义图标与连接状态无关，只有连接状态变化时不用重写。
    /// - Parameters:
    ///   - group: 所选的组
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`，只在 “自动” 子选项下起作用
    static func customIconVariant(
        for group: AppIconGroup,
        iconTheme: String?,
        appearance: NSAppearance
    ) -> AppIconVariant? {
        guard group != .serverGhost else {
            return nil
        }

        return variant(
            for: group,
            iconTheme: iconTheme,
            appearance: appearance,
            isConnected: false
        )
    }

    /// 其它组的自定义图标是否直接写该组默认图标的原图：透明样式（`Clear…`）与色调浅色下为真，与组无关。
    ///
    /// Dock 在这几种样式下按样式处理自定义图标，写进系统已按样式处理过的壳 App 图标会被处理第二遍，
    /// 没运行时固定着的格子发暗、发黑（macOS 27 实测）；色调深色下 Dock 不处理自定义图标，与默认、深色样式一样写合成的一版。
    /// - Parameters:
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`，只在色调的 “自动” 子选项下起作用
    static func writesBundledCustomIcon(
        iconTheme: String?,
        appearance: NSAppearance
    ) -> Bool {
        guard let iconTheme else {
            return false
        }

        if iconTheme.hasPrefix("Clear") {
            return true
        }

        #warning("TODO: 色调的 “自动” 子选项按外观归入色调浅色或色调深色是推断，需在浅色与深色外观下各核实一次没运行时 Dock 里的格子")

        // 色调样式按深浅子选项分开，“自动” 跟随外观
        return iconTheme.hasPrefix("Tinted") && !isDark(forIconTheme: iconTheme, appearance: appearance)
    }

    /// 把图标写成 App 包的自定义图标并等它写完；iconData 为 nil 时清掉，包里没有自定义图标时不改动它。
    ///
    /// 写入排在 `writeQueue` 上，排队在挂起之前同步完成，先调用的先写。
    /// - Parameters:
    ///   - iconData: 要写入的图标数据，nil 表示清除
    ///   - url: App 包的位置
    /// - Returns: 包上有没有自定义图标是否因此变了
    /// - Throws: 包所在的位置不可写时抛出 `AppIconWriteError`
    @discardableResult
    static func setCustomIcon(
        _ iconData: Data?,
        ofApp url: URL
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            enqueueWrite(iconData, ofApp: url) {
                continuation.resume(with: $0)
            }
        }
    }

    /// 重启 Dock：与 `killall Dock` 相同，向 Dock 进程发 SIGTERM，launchd 随即拉起新的 Dock，运行时图标跨重启保留。
    ///
    /// Dock 自己缓存固定格子的图标：写入或清除自定义图标之后，登记 LaunchServices、改包的修改时间都不能让格子换图，
    /// 只有重启才换（macOS 27 实测）。
    static func restartSystemDock() {
        for dock in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock") {
            kill(dock.processIdentifier, SIGTERM)
        }
    }

    /// 按偏好里所选的组与当前样式设一次图标，此后在样式或深浅变化时重新设置。
    func start() {
        reload()

        // AppKit 读过一次当前的样式配置之后，才在样式变化时发出下面这条通知（macOS 27 实测）。
        if NSWorkspace.shared.responds(to: Self.iconAppearanceConfigurationSelector) {
            _ = NSWorkspace.shared.perform(Self.iconAppearanceConfigurationSelector)
        }

        // 样式或色调颜色变化时 AppKit 发出这条通知；透明、色调样式下壳 App 的系统图标随之变化，自定义图标总要重写。
        iconStyleObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: Self.iconAppearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.styleDidChange(rewritesCustomIcon: true)
            }
        }

        // 自动子选项跟随外观；外观在主线程上变化，观察回调也在主线程；深浅没变时自定义图标不用重写。
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.styleDidChange(rewritesCustomIcon: false)
            }
        }
    }

    /// 按偏好里所选的组重新套用：重画运行时图标，并在后台重写自定义图标；不等写完，重写失败不提示。
    ///
    /// 启动时与 Reset / Clear User Defaults 删掉偏好之后调用，后者回到服务器幽灵；此前发出、还没写完的换组不再存进偏好。
    /// 重写与换组一样算一次请求，写完按 `finishRequest(changesIcon:)` 决定是否重启 Dock，
    /// 如更新后第一次启动写了进去、Reset / Clear 清掉了。
    func reload() {
        reloadCount += 1
        group = AppIconGroup.current(in: defaults)
        requestedGroup = group
        isDark = Self.isDark(forIconTheme: iconTheme, appearance: NSApp.effectiveAppearance)

        updateIcon()
        rewriteCustomIcon(restartsDock: true)
    }

    /// 换成另一组：在后台写入或清除 App 包的自定义图标，写完后存进偏好，立即重画运行时图标，并按需重启 Dock。
    ///
    /// 写入按调用的顺序排队，后选的组排在后面、最后写完；等待期间重新套用了偏好时，这一次不再存进偏好。
    /// 写完按 `finishRequest(changesIcon:)` 决定是否重启 Dock：选的就是当前的组时照写，包上没变，不重启。
    /// - Parameter group: 要换成的组
    /// - Throws: 写不进 App 包，或取不到这一组的图标资源或系统图标时抛出 `AppIconWriteError`，偏好与图标都保持原来的组
    func select(_ group: AppIconGroup) async throws {
        let iconData = try customIconData(
            for: group,
            iconTheme: iconTheme,
            appearance: NSApp.effectiveAppearance
        )

        let reloadCount = reloadCount
        let request = beginRequest()
        var changesIcon = false

        requestedGroup = group

        // 成败都要结算；成功时排在存偏好与重画之后，Dock 重启后保留的是新的运行时图标
        defer {
            finishRequest(changesIcon: changesIcon)
        }

        do {
            changesIcon = try await Self.setCustomIcon(iconData, ofApp: bundle.bundleURL)
        } catch {
            // 之后又有请求时，由最近的一次决定退不退回
            if request == latestRequest {
                requestedGroup = self.group
            }

            throw error
        }

        // 写入期间重新套用了偏好：所选的组以偏好为准
        guard reloadCount == self.reloadCount else {
            return
        }

        defaults.set(group.rawValue, forKey: AppIconGroup.key)
        self.group = group
        updateIcon()
    }

    /// 图标列表里这一组在当前深浅下的一张图标，即包里的原图；取不到资源时为 nil。
    /// - Parameters:
    ///   - group: 图标所属的组
    ///   - isConnected: 取指示灯亮着的一版
    func bundledIcon(
        of group: AppIconGroup,
        isConnected: Bool
    ) -> NSImage? {
        let variant = AppIconVariant(isDark: isDark, isConnected: isConnected)
        return bundle.image(forResource: group.iconName(for: variant))
    }

    /// 这一组写成自定义图标的数据：当前样式下指示灯灭着的一版；服务器幽灵为 nil，表示清掉自定义图标。
    ///
    /// 透明样式与色调浅色下是该组默认图标的原图，由 Dock 按样式处理，其余样式下在主线程上合成；交给写入队列的只有数据。
    /// - Parameters:
    ///   - group: 要写入的组
    ///   - iconTheme: 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil
    ///   - appearance: App 的 `effectiveAppearance`，只在 “自动” 子选项下起作用
    /// - Throws: 取不到这一组的图标资源或系统图标时抛出 `AppIconWriteError`
    func customIconData(
        for group: AppIconGroup,
        iconTheme: String?,
        appearance: NSAppearance
    ) throws -> Data? {
        let variant = Self.customIconVariant(
            for: group,
            iconTheme: iconTheme,
            appearance: appearance
        )

        guard let variant else {
            return nil
        }

        // 透明样式与色调浅色：写原图，只由 Dock 按样式处理一遍
        if Self.writesBundledCustomIcon(iconTheme: iconTheme, appearance: appearance) {
            let url = bundle.url(
                forResource: group.iconName(for: .standard),
                withExtension: "icns"
            )

            guard let url, let data = try? Data(contentsOf: url) else {
                throw AppIconWriteError()
            }

            return data
        }

        // 自定义图标与包内图标一样由系统按原样大小画出，不像运行时图标那样放大。
        guard let data = icon(for: variant, of: group, scale: 1)?.tiffRepresentation else {
            throw AppIconWriteError()
        }

        return data
    }
}

// MARK: - Private

extension AppIconController {
    /// 全局偏好里 “图标与小组件样式” 的当前值。
    private var iconTheme: String? {
        UserDefaults.standard.string(forKey: Self.iconThemeKey)
    }

    /// 样式或外观变化后重画运行时图标；样式变了或深浅变了时重写自定义图标，失败不提示。
    /// - Parameter rewritesCustomIcon: 样式变化时为真；只有外观变化时为假，只在深浅随之变化时重写
    private func styleDidChange(rewritesCustomIcon: Bool) {
        let wasDark = isDark
        isDark = Self.isDark(forIconTheme: iconTheme, appearance: NSApp.effectiveAppearance)

        updateIcon()

        if rewritesCustomIcon || isDark != wasDark {
            rewriteCustomIcon(restartsDock: false)
        }
    }

    /// 在后台按 `requestedGroup` 与当前样式重写自定义图标，写完后重画运行时图标；不等写完，失败不提示。
    ///
    /// 服务器幽灵的运行时图标以 App 自身的系统图标为底，清掉自定义图标之后取到的才不是残留的那一张，所以写完再画一次。
    /// - Parameter restartsDock: 重新套用偏好时为真，算一次请求，写完结算是否重启 Dock；
    ///   样式与深浅变化的重写只换同一组的另一版，不算请求，不重启
    private func rewriteCustomIcon(restartsDock: Bool) {
        let iconData: Data?

        do {
            iconData = try customIconData(
                for: requestedGroup,
                iconTheme: iconTheme,
                appearance: NSApp.effectiveAppearance
            )
        } catch {
            return
        }

        if restartsDock {
            beginRequest()
        }

        Self.enqueueWrite(iconData, ofApp: bundle.bundleURL) { result in
            let changesIcon = (try? result.get()) ?? false

            Task { @MainActor [weak self] in
                self?.updateIcon()

                if restartsDock {
                    self?.finishRequest(changesIcon: changesIcon)
                }
            }
        }
    }

    /// 开始一次换组或重新套用偏好：序号与还没结算的次数各加一。
    /// - Returns: 这次请求的序号
    @discardableResult
    private func beginRequest() -> Int {
        latestRequest += 1
        pendingRequests += 1
        return latestRequest
    }

    /// 一次换组或重新套用偏好的写入结束：记下包上有没有自定义图标是否因此变了；
    /// 排着的请求全部结算完、且自上次重启以来变了奇数次时重启 Dock，几次请求先后排队时只在最后结算完时重启一次。
    ///
    /// 换组与重新套用经不同的路径回到主线程，结算的先后不一定与写入的先后相同，所以只数还没结算的次数。
    /// - Parameter changesIcon: 包上有没有自定义图标是否因此变了；写入失败时为假
    private func finishRequest(changesIcon: Bool) {
        pendingRequests -= 1

        // 变了又变回来时，格子显示的仍是对的组
        if changesIcon {
            isDockStale.toggle()
        }

        guard pendingRequests == 0, isDockStale else {
            return
        }

        isDockStale = false
        restartDock()
    }

    /// 把 App 图标设成所选的组在当前样式与连接状态下的一版，不需要换或生成不了时交还包里的默认图标；
    /// 设置页这一行的图标随之重画。
    private func updateIcon() {
        let appearance = NSApp.effectiveAppearance

        // 设置页这一行与 Dock 同样合成，只是指示灯总是灭着；不用换的一版就是包内图标本身，由系统画出的样子即是结果
        let unlitVariant = Self.variant(
            for: group,
            iconTheme: iconTheme,
            appearance: appearance,
            isConnected: false
        )

        unlitIcon = icon(
            for: unlitVariant ?? .standard,
            of: group,
            scale: 1
        )

        let variant = Self.variant(
            for: group,
            iconTheme: iconTheme,
            appearance: appearance,
            isConnected: isConnected
        )

        // 设为 nil 后 Dock 改回显示包里的默认图标，并按透明、色调样式重新处理。
        guard let variant else {
            NSApp.applicationIconImage = nil
            return
        }

        // 生成不了时同样设为 nil：上一次设的运行时图标与当前的组、样式或连接状态不符，默认图标至少由 Dock 按当前样式处理。
        NSApp.applicationIconImage = icon(
            for: variant,
            of: group,
            scale: AppIconRenderer.dockScale
        )
    }

    /// 按组与一版合成图标；取不到资源或合成失败时为 nil。
    ///
    /// 以系统画好的包内图标为底、叠上目标图标与包内图标的差别，在 Dock 里才与系统画同一张图标的样子一致，
    /// 连上服务器时只有指示灯变化；透明、色调样式下包内图标与目标图标相同，结果就是系统按样式处理过的样子。
    /// - Parameters:
    ///   - variant: 要合成的一版
    ///   - group: 图标所属的组
    ///   - scale: 内容放大的倍数，见 `AppIconRenderer.icon(system:bundled:target:scale:)`
    private func icon(
        for variant: AppIconVariant,
        of group: AppIconGroup,
        scale: Double
    ) -> NSImage? {
        // 直接运行可执行文件、没有 .app 包时取不到资源；资源齐全才去取系统图标，取系统图标会让 LaunchServices 登记那个包。
        guard
            let bundledIcon = bundle.image(forResource: group.iconName(for: .standard)),
            let targetIcon = bundle.image(forResource: group.iconName(for: variant)),
            let systemIconPath = systemIconPath(of: group),
            let bundled = Self.image(of: bundledIcon),
            let target = Self.image(of: targetIcon),
            let system = Self.image(of: NSWorkspace.shared.icon(forFile: systemIconPath)),
            let rendered = AppIconRenderer.icon(
                system: system,
                bundled: bundled,
                target: target,
                scale: scale
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
    /// 把一次写入排进写入队列；排队在调用时同步完成，先排的先写。
    /// - Parameters:
    ///   - iconData: 要写入的图标数据，nil 表示清掉自定义图标
    ///   - url: App 包的位置
    ///   - completion: 写完后在写入队列上调用，带上写入的结果：包上有没有自定义图标是否因此变了
    private static func enqueueWrite(
        _ iconData: Data?,
        ofApp url: URL,
        completion: @escaping @Sendable (Result<Bool, any Error>) -> Void
    ) {
        writeQueue.async {
            completion(Result {
                try writeIcon(iconData, toApp: url)
            })
        }
    }

    /// 在写入队列上写入或清除自定义图标：在包的根目录加上或删掉 `Icon\r` 文件与 Finder 信息。
    /// - Parameters:
    ///   - iconData: 要写入的图标数据，nil 表示清除
    ///   - url: App 包的位置
    /// - Returns: 包上有没有自定义图标是否因此变了：原本没有、这次写了进去，或原本有、这次清掉了
    /// - Throws: 包所在的位置不可写，或数据解不出图标时抛出 `AppIconWriteError`
    private nonisolated static func writeIcon(
        _ iconData: Data?,
        toApp url: URL
    ) throws -> Bool {
        let iconFile = url.appending(path: "Icon\r", directoryHint: .notDirectory)
        let hadIcon = FileManager.default.fileExists(atPath: iconFile.path(percentEncoded: false))

        // 不可写的位置上，连没有自定义图标时的清除也会失败。
        if iconData == nil, !hadIcon {
            return false
        }

        let icon = iconData.flatMap(NSImage.init(data:))

        guard iconData == nil || icon != nil else {
            throw AppIconWriteError()
        }

        let isWritten = NSWorkspace.shared.setIcon(
            icon,
            forFile: url.path(percentEncoded: false),
            options: []
        )

        guard isWritten else {
            throw AppIconWriteError()
        }

        return hadIcon == (iconData == nil)
    }

    /// 图标在 `iconPixels` 边长下的位图；取不到时为 nil。
    private static func image(of icon: NSImage) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: iconPixels, height: iconPixels)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

// MARK: - AppIconWriteError

/// App 包的自定义图标写不进去：包所在的位置不可写（如只读的磁盘映像），或取不到所选的组的系统图标。
struct AppIconWriteError: LocalizedError {
    /// 图标列表的错误区里显示的说明。
    var errorDescription: String? {
        AppLocalization.text("appIcon.writeFailed")
    }
}
