import AppKit
import Testing

@testable import Spooky

// MARK: - AppIconControllerTests

/// App 图标显示所选的组，跟随 “图标与小组件样式” 与连接状态。
///
/// 默认与深色样式下按深浅与连接状态换成该组的一版，服务器幽灵浅色、没连时就是包里的默认图标，不用换；
/// 透明、色调样式下系统按样式处理包内图标，运行时设置的图标会被原样画出，所以服务器幽灵交还默认图标，
/// 其它组用系统已按样式处理过的壳 App 图标、指示灯不亮。
/// ⌘Tab 与访达只认包里的图标，其它组要写成自定义图标、服务器幽灵清掉；写入在后台按顺序进行，主线程不等，
/// 写不进去时偏好保持原来的组。
@MainActor
struct AppIconControllerTests {
    /// 测试里临时 App 包的 Bundle ID，与 Spooky 自身的不同。
    private static let testBundleIdentifier = "com.rakuyo.spooky.tests.appicon"

    /// 各组在各样式、深浅外观下的深浅，没连与连着服务器时应换上的一版，以及写成自定义图标的一版；nil 表示不换或清掉。
    ///
    /// 深色的 “始终” 子选项不看外观；“自动” 子选项只在深色外观（含高对比度、vibrant 变体）下为深色；
    /// 透明、色调各子选项的深浅同样按子选项判断，但运行时图标不分深浅、指示灯不亮。
    private static let cases: [Entry] = [
        Entry(.serverGhost, nil, .darkAqua, isDark: false, unlit: nil, lit: .lit, customIcon: nil),
        Entry(.serverGhost, "RegularDark", .aqua, isDark: true, unlit: .dark, lit: .darkLit, customIcon: nil),
        Entry(
            .serverGhost,
            "RegularAutomatic",
            .accessibilityHighContrastDarkAqua,
            isDark: true,
            unlit: .dark,
            lit: .darkLit,
            customIcon: nil
        ),
        Entry(.serverGhost, "RegularAutomatic", .vibrantDark, isDark: true, unlit: .dark, lit: .darkLit, customIcon: nil),
        Entry(
            .serverGhost,
            "RegularAutomatic",
            .accessibilityHighContrastAqua,
            isDark: false,
            unlit: nil,
            lit: .lit,
            customIcon: nil
        ),
        Entry(.serverGhost, "ClearAutomatic", .darkAqua, isDark: true, unlit: nil, lit: nil, customIcon: nil),
        Entry(.serverGhost, "TintedLight", .aqua, isDark: false, unlit: nil, lit: nil, customIcon: nil),
        Entry(.midnight, nil, .darkAqua, isDark: false, unlit: .standard, lit: .lit, customIcon: .standard),
        Entry(.midnight, "RegularDark", .aqua, isDark: true, unlit: .dark, lit: .darkLit, customIcon: .dark),
        Entry(.midnight, "RegularAutomatic", .aqua, isDark: false, unlit: .standard, lit: .lit, customIcon: .standard),
        Entry(.midnight, "RegularAutomatic", .darkAqua, isDark: true, unlit: .dark, lit: .darkLit, customIcon: .dark),
        Entry(.midnight, "ClearDark", .aqua, isDark: true, unlit: .standard, lit: .standard, customIcon: .standard),
        Entry(.midnight, "TintedAutomatic", .darkAqua, isDark: true, unlit: .standard, lit: .standard, customIcon: .standard),
        Entry(.midnight, "ClearLight", .darkAqua, isDark: false, unlit: .standard, lit: .standard, customIcon: .standard),
    ]

    /// 组、样式、外观与连接状态决定深浅、运行时图标与自定义图标。
    @Test("组、样式、深浅外观与连接状态决定换上的图标")
    func variantFollowsGroupStyleAndConnection() throws {
        for entry in Self.cases {
            let appearance = try #require(NSAppearance(named: entry.appearance))
            let label = "\(entry.group) \(entry.iconTheme ?? "nil") \(entry.appearance.rawValue)"

            let variant = { (isConnected: Bool) in
                AppIconController.variant(
                    for: entry.group,
                    iconTheme: entry.iconTheme,
                    appearance: appearance,
                    isConnected: isConnected
                )
            }

            let customIcon = AppIconController.customIconVariant(
                for: entry.group,
                iconTheme: entry.iconTheme,
                appearance: appearance
            )

            #expect(AppIconController.isDark(forIconTheme: entry.iconTheme, appearance: appearance) == entry.isDark, "\(label)")
            #expect(variant(false) == entry.unlit, "\(label)")
            #expect(variant(true) == entry.lit, "\(label)")
            #expect(customIcon == entry.customIcon, "\(label)")
        }
    }

    /// 偏好里没有记录或记录无法识别时为服务器幽灵；所选的组不是 Reset User Defaults 保留的数据，
    /// Reset 与 Clear 之后控制器都回到服务器幽灵，清掉 App 包的自定义图标，并重启 Dock。
    @Test("偏好缺省与不认识的值为服务器幽灵，Reset / Clear 之后回到服务器幽灵")
    func preferenceFallsBackToServerGhost() async throws {
        let directory = Self.makeDirectory()

        defer { try? FileManager.default.removeItem(at: directory) }

        let domain = directory.appending(path: "defaults").path
        let defaults = try #require(UserDefaults(suiteName: domain))
        let app = try Self.makeApp(in: directory)

        // 没有记录、记录无法识别
        #expect(AppIconGroup.current(in: defaults) == .serverGhost)

        defaults.set("aurora", forKey: AppIconGroup.key)

        #expect(AppIconGroup.current(in: defaults) == .serverGhost)

        // 控制器读 App 的外观、设置运行时图标
        _ = NSApplication.shared

        // Reset 保留数据、Clear 全删，所选的组都不是数据；删完后控制器按偏好重新套用，清掉自定义图标，Dock 重启一次
        for keepingData in [true, false] {
            defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)
            try await AppIconController.setCustomIcon(Self.sampleIcon(), ofApp: app)

            var dockRestarts = 0

            let controller = try AppIconController(
                defaults: defaults,
                bundle: #require(Bundle(url: app)),
                restartDock: { dockRestarts += 1 }
            )

            #expect(controller.group == .midnight)

            DeveloperPreferences.removeValues(in: domain, of: defaults, keepingData: keepingData)
            controller.reload()
            await Self.waitForWrites()

            #expect(controller.group == .serverGhost, "keepingData: \(keepingData)")
            #expect(!Self.hasCustomIcon(app), "keepingData: \(keepingData)")
            #expect(dockRestarts == 1, "keepingData: \(keepingData)")
        }
    }

    /// 自定义图标写进包的根目录、清除时删掉；只读的包写不进去，换组失败时组、偏好与图标都保持原来的组。
    /// 换组写完重启 Dock 一次，写入失败或选的就是当前的组时不重启。
    @Test("写入与清除 App 包的自定义图标，写不进去时换组失败")
    func writesAndClearsCustomIcon() async throws {
        let directory = Self.makeDirectory()
        let app = try Self.makeApp(in: directory)

        defer {
            try? Self.setPermissions(0o755, of: app)
            try? FileManager.default.removeItem(at: directory)
        }

        // 写入后包的根目录出现 `Icon\r`，清除后消失
        try await AppIconController.setCustomIcon(Self.sampleIcon(), ofApp: app)

        #expect(Self.hasCustomIcon(app))

        try await AppIconController.setCustomIcon(nil, ofApp: app)

        #expect(!Self.hasCustomIcon(app))

        // 只读的包：写入抛错；没有自定义图标时清除不改动它，不算失败
        try Self.setPermissions(0o555, of: app)

        await #expect(throws: AppIconWriteError.self) {
            try await AppIconController.setCustomIcon(Self.sampleIcon(), ofApp: app)
        }

        try await AppIconController.setCustomIcon(nil, ofApp: app)

        // 带着午夜的自定义图标变成只读：选回服务器幽灵失败，组、偏好与图标都还是午夜
        try Self.setPermissions(0o755, of: app)
        try await AppIconController.setCustomIcon(Self.sampleIcon(), ofApp: app)
        try Self.setPermissions(0o555, of: app)

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)

        _ = NSApplication.shared

        var dockRestarts = 0

        let controller = try AppIconController(
            defaults: defaults,
            bundle: #require(Bundle(url: app)),
            restartDock: { dockRestarts += 1 }
        )

        await #expect(throws: AppIconWriteError.self) {
            try await controller.select(.serverGhost)
        }

        #expect(controller.group == .midnight)
        #expect(AppIconGroup.current(in: defaults) == .midnight)
        #expect(Self.hasCustomIcon(app))
        #expect(dockRestarts == 0)

        // 恢复可写后选回服务器幽灵：清掉自定义图标，偏好随之改变，Dock 重启一次
        try Self.setPermissions(0o755, of: app)
        try await controller.select(.serverGhost)

        #expect(controller.group == .serverGhost)
        #expect(AppIconGroup.current(in: defaults) == .serverGhost)
        #expect(!Self.hasCustomIcon(app))
        #expect(dockRestarts == 1)

        // 再选当前的组：Dock 里的格子没有变，不重启
        try await controller.select(.serverGhost)

        #expect(dockRestarts == 1)
    }

    /// 写入在后台排队，系统询问权限这类写入卡住的情形下主线程照常往下走；
    /// 写入按排队的顺序完成，Reset 之前发出、之后才写完的换组不把组存回偏好；连续换组只在后一次写完之后重启 Dock。
    @Test("自定义图标在后台按顺序写入，主线程不等；Reset 之前发出的换组不覆盖 Reset 的结果")
    func writesInBackgroundInOrder() async throws {
        let directory = Self.makeDirectory()

        defer { try? FileManager.default.removeItem(at: directory) }

        let domain = directory.appending(path: "defaults").path
        let defaults = try #require(UserDefaults(suiteName: domain))
        let app = try Self.makeApp(in: directory)

        defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)
        try await AppIconController.setCustomIcon(Self.sampleIcon(), ofApp: app)

        _ = NSApplication.shared

        var dockRestarts = 0

        let controller = try AppIconController(
            defaults: defaults,
            bundle: #require(Bundle(url: app)),
            restartDock: { dockRestarts += 1 }
        )

        // 拦住写入队列，像系统询问权限时那样让写入一直等着
        let gate = DispatchSemaphore(value: 0)

        AppIconController.writeQueue.async {
            gate.wait()
        }

        // 换组排进队列后挂起；主线程照常往下走，组与偏好都还没变
        let selecting = Task.immediate {
            try await controller.select(.serverGhost)
        }

        #expect(controller.group == .midnight)
        #expect(Self.hasCustomIcon(app))

        // Reset：删掉偏好后重新套用，重写同样只是排队，不等写完
        DeveloperPreferences.removeValues(in: domain, of: defaults, keepingData: true)
        controller.reload()

        #expect(controller.group == .serverGhost)
        #expect(Self.hasCustomIcon(app))

        // 放行后按排队的顺序写完：自定义图标清掉了，先发出的换组没有把组存回偏好
        gate.signal()

        try await selecting.value
        await Self.waitForWrites()

        #expect(!Self.hasCustomIcon(app))
        #expect(defaults.string(forKey: AppIconGroup.key) == nil)
        #expect(controller.group == .serverGhost)
        #expect(dockRestarts == 0)

        // 连续两次换组：两次都在主线程让出之前排进队列，只在后一次写完之后重启 Dock
        defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)
        controller.reload()

        let first = Task.immediate {
            try await controller.select(.serverGhost)
        }

        let second = Task.immediate {
            try await controller.select(.serverGhost)
        }

        try await first.value
        try await second.value

        #expect(controller.group == .serverGhost)
        #expect(dockRestarts == 1)
    }

    /// 启动时包上原本没有自定义图标、这次写了进去（如更新后第一次启动），固定在 Dock 里的格子显示的组不对，重启 Dock；
    /// 选着服务器幽灵启动、包上已是所选的组的平常启动与样式变化后的重写都不重启。
    @Test("启动时写进了自定义图标才重启 Dock，平常启动与样式变化的重写不重启")
    func startupRestartsDockWhenCustomIconAppears() async throws {
        let directory = Self.makeDirectory()

        defer { try? FileManager.default.removeItem(at: directory) }

        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))
        let app = try Self.makeApp(in: directory)

        try Self.addMidnightIcons(to: app)

        _ = NSApplication.shared

        var dockRestarts = 0

        let controller = try AppIconController(
            defaults: defaults,
            bundle: #require(Bundle(url: app)),
            restartDock: { dockRestarts += 1 }
        )

        // 选着服务器幽灵启动：包上本来没有自定义图标，不用清，不重启
        controller.reload()
        await Self.waitForWrites()

        #expect(!Self.hasCustomIcon(app))
        #expect(dockRestarts == 0)

        // 更新后第一次启动：选着午夜、包上没有自定义图标，写进去之后重启一次
        defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)
        controller.reload()
        await Self.waitForWrites()

        #expect(Self.hasCustomIcon(app))
        #expect(dockRestarts == 1)

        // 平常启动：包上已是午夜，照样重写，不重启
        controller.start()
        await Self.waitForWrites()

        #expect(dockRestarts == 1)

        // 样式变化后的重写只换同一组的另一版：包上的自定义图标这时没了也只是写回，不重启
        try await AppIconController.setCustomIcon(nil, ofApp: app)

        NSWorkspace.shared.notificationCenter.post(
            name: AppIconController.iconAppearanceDidChangeNotification,
            object: nil
        )

        await Self.waitForWrites()

        #expect(Self.hasCustomIcon(app))
        #expect(dockRestarts == 1)
    }
}

// MARK: AppIconControllerTests.Entry

extension AppIconControllerTests {
    /// 一组核对：组、样式与外观，以及应得的深浅、没连与连着时的运行时图标、自定义图标。
    fileprivate struct Entry {
        /// 所选的组。
        let group: AppIconGroup

        /// 全局偏好 `AppleIconAppearanceTheme` 的值，“默认” 样式时为 nil。
        let iconTheme: String?

        /// App 的外观。
        let appearance: NSAppearance.Name

        /// 应得的深浅。
        let isDark: Bool

        /// 没连服务器时的运行时图标。
        let unlit: AppIconVariant?

        /// 连着服务器时的运行时图标。
        let lit: AppIconVariant?

        /// 写成 App 包自定义图标的一版；nil 表示清掉。
        let customIcon: AppIconVariant?

        /// 按表格的列依次给出各项。
        init(
            _ group: AppIconGroup,
            _ iconTheme: String?,
            _ appearance: NSAppearance.Name,
            isDark: Bool,
            unlit: AppIconVariant?,
            lit: AppIconVariant?,
            customIcon: AppIconVariant?
        ) {
            self.group = group
            self.iconTheme = iconTheme
            self.appearance = appearance
            self.isDark = isDark
            self.unlit = unlit
            self.lit = lit
            self.customIcon = customIcon
        }
    }
}

// MARK: - Fixtures

extension AppIconControllerTests {
    /// 应用图标测试独用的临时目录，放偏好域与临时 App 包；调用方负责删除。
    static func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: testBundleIdentifier + "." + UUID().uuidString, directoryHint: .isDirectory)
    }

    /// 在目录里建一个只有 `Info.plist` 的 App 包，Bundle ID 是测试专用的；不向 LaunchServices 登记。
    /// - Parameter directory: 放 App 包的目录
    static func makeApp(in directory: URL) throws -> URL {
        let app = directory.appending(path: "Spooky.app", directoryHint: .isDirectory)
        let contents = app.appending(path: "Contents", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let info = [
            "CFBundleIdentifier": testBundleIdentifier,
            "CFBundleName": "Spooky",
            "CFBundlePackageType": "APPL",
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist", directoryHint: .notDirectory))

        return app
    }
}

// MARK: - Private

extension AppIconControllerTests {
    /// 写进自定义图标用的一张纯色小图的数据。
    private static func sampleIcon() -> Data? {
        let icon = NSImage(size: NSSize(width: 32, height: 32), flipped: false) {
            NSColor.systemPurple.setFill()
            $0.fill()
            return true
        }

        return icon.tiffRepresentation
    }

    /// 给临时 App 放上午夜组的四张图标，并用指向不存在位置的符号链接代替壳 App：控制器取到通用的系统图标，
    /// 合成得出午夜的自定义图标，LaunchServices 也不登记它；同名的普通文件或目录会被当作 App 登记。
    /// - Parameter app: App 包的位置
    private static func addMidnightIcons(to app: URL) throws {
        let resources = app.appending(path: "Contents/Resources", directoryHint: .isDirectory)
        let icon = try #require(sampleIcon())

        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        for isDark in [false, true] {
            for isConnected in [false, true] {
                let variant = AppIconVariant(isDark: isDark, isConnected: isConnected)
                let name = AppIconGroup.midnight.iconName(for: variant)

                try icon.write(to: resources.appending(path: name + ".tiff", directoryHint: .notDirectory))
            }
        }

        let shell = resources.appending(
            path: AppIconGroup.midnight.iconName(for: .standard) + ".app",
            directoryHint: .notDirectory
        )

        try FileManager.default.createSymbolicLink(
            at: shell,
            withDestinationURL: resources.appending(path: "missing", directoryHint: .notDirectory)
        )
    }

    /// App 包的根目录里是否有自定义图标的 `Icon\r` 文件。
    /// - Parameter app: App 包的位置
    private static func hasCustomIcon(_ app: URL) -> Bool {
        let iconFile = app.appending(path: "Icon\r", directoryHint: .notDirectory)
        return FileManager.default.fileExists(atPath: iconFile.path(percentEncoded: false))
    }

    /// 等写入队列里已经排着的写入全部做完：队列串行，排在最后的这一项执行时，前面的都已写完。
    private static func waitForWrites() async {
        await withCheckedContinuation { continuation in
            AppIconController.writeQueue.async {
                continuation.resume()
            }
        }
    }

    /// 改 App 包根目录的权限，用来模拟只读的位置。
    /// - Parameters:
    ///   - permissions: POSIX 权限位
    ///   - app: App 包的位置
    private static func setPermissions(
        _ permissions: Int,
        of app: URL
    ) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: app.path(percentEncoded: false)
        )
    }
}

// MARK: - AppIconVariant

extension AppIconVariant {
    /// 默认图标，指示灯亮着。
    fileprivate static let lit = Self(isDark: false, isConnected: true)

    /// 深色图标，指示灯灭着。
    fileprivate static let dark = Self(isDark: true, isConnected: false)

    /// 深色图标，指示灯亮着。
    fileprivate static let darkLit = Self(isDark: true, isConnected: true)
}
