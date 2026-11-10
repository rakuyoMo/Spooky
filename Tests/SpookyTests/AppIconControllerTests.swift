import AppKit
import Testing

@testable import Spooky

// MARK: - AppIconControllerTests

/// App 图标显示所选的组，跟随 “图标与小组件样式” 与连接状态。
///
/// 默认与深色样式下按深浅与连接状态换成该组的一版，服务器幽灵浅色、没连时就是包里的默认图标，不用换；
/// 透明、色调样式下系统按样式处理包内图标，运行时设置的图标会被原样画出，所以服务器幽灵交还默认图标，
/// 其它组用系统已按样式处理过的壳 App 图标、指示灯不亮。
@MainActor
struct AppIconControllerTests {
    /// 各组在各样式、深浅外观下的深浅，以及没连与连着服务器时应换上的一版；nil 表示不换。
    ///
    /// 深色的 “始终” 子选项不看外观；“自动” 子选项只在深色外观（含高对比度、vibrant 变体）下为深色；
    /// 透明、色调各子选项的深浅同样按子选项判断，但运行时图标不分深浅、指示灯不亮。
    private static let cases: [Entry] = [
        Entry(.serverGhost, nil, .darkAqua, isDark: false, unlit: nil, lit: .lit),
        Entry(.serverGhost, "RegularDark", .aqua, isDark: true, unlit: .dark, lit: .darkLit),
        Entry(.serverGhost, "RegularAutomatic", .accessibilityHighContrastDarkAqua, isDark: true, unlit: .dark, lit: .darkLit),
        Entry(.serverGhost, "RegularAutomatic", .vibrantDark, isDark: true, unlit: .dark, lit: .darkLit),
        Entry(.serverGhost, "RegularAutomatic", .accessibilityHighContrastAqua, isDark: false, unlit: nil, lit: .lit),
        Entry(.serverGhost, "ClearAutomatic", .darkAqua, isDark: true, unlit: nil, lit: nil),
        Entry(.serverGhost, "TintedLight", .aqua, isDark: false, unlit: nil, lit: nil),
        Entry(.midnight, nil, .darkAqua, isDark: false, unlit: .standard, lit: .lit),
        Entry(.midnight, "RegularDark", .aqua, isDark: true, unlit: .dark, lit: .darkLit),
        Entry(.midnight, "RegularAutomatic", .aqua, isDark: false, unlit: .standard, lit: .lit),
        Entry(.midnight, "RegularAutomatic", .darkAqua, isDark: true, unlit: .dark, lit: .darkLit),
        Entry(.midnight, "ClearDark", .aqua, isDark: true, unlit: .standard, lit: .standard),
        Entry(.midnight, "TintedAutomatic", .darkAqua, isDark: true, unlit: .standard, lit: .standard),
        Entry(.midnight, "ClearLight", .darkAqua, isDark: false, unlit: .standard, lit: .standard),
    ]

    /// 组、样式、外观与连接状态决定深浅与运行时图标。
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

            #expect(AppIconController.isDark(forIconTheme: entry.iconTheme, appearance: appearance) == entry.isDark, "\(label)")
            #expect(variant(false) == entry.unlit, "\(label)")
            #expect(variant(true) == entry.lit, "\(label)")
        }
    }

    /// 偏好里没有记录或记录无法识别时为服务器幽灵；所选的组不是 Reset User Defaults 保留的数据，Reset 与 Clear 之后都回到服务器幽灵。
    @Test("偏好缺省与不认识的值为服务器幽灵，Reset / Clear 之后回到服务器幽灵")
    func preferenceFallsBackToServerGhost() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "com.rakuyo.spooky.tests.appicon." + UUID().uuidString, directoryHint: .isDirectory)

        defer { try? FileManager.default.removeItem(at: directory) }

        let domain = directory.appending(path: "defaults").path
        let defaults = try #require(UserDefaults(suiteName: domain))

        // 没有记录、记录无法识别
        #expect(AppIconGroup.current(in: defaults) == .serverGhost)

        defaults.set("aurora", forKey: AppIconGroup.key)

        #expect(AppIconGroup.current(in: defaults) == .serverGhost)

        // Reset 保留数据、Clear 全删
        for keepingData in [true, false] {
            defaults.set(AppIconGroup.midnight.rawValue, forKey: AppIconGroup.key)

            #expect(AppIconGroup.current(in: defaults) == .midnight)

            DeveloperPreferences.removeValues(in: domain, of: defaults, keepingData: keepingData)

            #expect(AppIconGroup.current(in: defaults) == .serverGhost, "keepingData: \(keepingData)")
        }
    }
}

// MARK: AppIconControllerTests.Entry

extension AppIconControllerTests {
    /// 一组核对：组、样式与外观，以及应得的深浅、没连与连着时的运行时图标。
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

        /// 按表格的列依次给出各项。
        init(
            _ group: AppIconGroup,
            _ iconTheme: String?,
            _ appearance: NSAppearance.Name,
            isDark: Bool,
            unlit: AppIconVariant?,
            lit: AppIconVariant?
        ) {
            self.group = group
            self.iconTheme = iconTheme
            self.appearance = appearance
            self.isDark = isDark
            self.unlit = unlit
            self.lit = lit
        }
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
