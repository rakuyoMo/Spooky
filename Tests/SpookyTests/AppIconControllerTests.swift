import AppKit
import Testing

@testable import Spooky

/// App 图标跟随 “图标与小组件样式” 与连接状态：深色样式换成深色图标，默认样式连着服务器时换成点亮指示灯的默认图标，
/// 透明、色调样式一律不换。
///
/// Dock 只对包里的默认图标做透明、色调处理，运行时设置的图标会被它再处理一遍，与系统的样式不符，所以这两种样式下交还默认图标；
/// 包里的默认图标指示灯灭着，所以默认样式只有连着服务器时才换。
@MainActor
struct AppIconControllerTests {
    /// 各样式在深浅外观下、没连与连着服务器时应换上的图标；nil 表示不设运行时图标。
    ///
    /// 深色样式的 “始终” 子变体不看外观；“自动” 子变体只在深色外观（含高对比度、vibrant 变体）下换成深色图标，
    /// 浅色外观下与默认样式（键不存在）相同；透明、色调的各子变体在任何外观下都不换。
    private nonisolated static let cases: [(
        iconTheme: String?,
        appearance: NSAppearance.Name,
        disconnected: AppIconVariant?,
        connected: AppIconVariant?
    )] = [
        (nil, .darkAqua, nil, .connected),
        (nil, .aqua, nil, .connected),

        ("RegularDark", .darkAqua, .dark(isConnected: false), .dark(isConnected: true)),
        ("RegularDark", .aqua, .dark(isConnected: false), .dark(isConnected: true)),
        ("RegularAutomatic", .darkAqua, .dark(isConnected: false), .dark(isConnected: true)),
        ("RegularAutomatic", .accessibilityHighContrastDarkAqua, .dark(isConnected: false), .dark(isConnected: true)),
        ("RegularAutomatic", .vibrantDark, .dark(isConnected: false), .dark(isConnected: true)),
        ("RegularAutomatic", .aqua, nil, .connected),
        ("RegularAutomatic", .accessibilityHighContrastAqua, nil, .connected),
        ("RegularAutomatic", .vibrantLight, nil, .connected),

        ("ClearLight", .darkAqua, nil, nil),
        ("ClearLight", .aqua, nil, nil),
        ("ClearDark", .darkAqua, nil, nil),
        ("ClearDark", .aqua, nil, nil),
        ("ClearAutomatic", .darkAqua, nil, nil),
        ("ClearAutomatic", .aqua, nil, nil),

        ("TintedLight", .darkAqua, nil, nil),
        ("TintedLight", .aqua, nil, nil),
        ("TintedDark", .darkAqua, nil, nil),
        ("TintedDark", .aqua, nil, nil),
        ("TintedAutomatic", .darkAqua, nil, nil),
        ("TintedAutomatic", .aqua, nil, nil),
    ]

    /// 样式、外观与连接状态决定换上哪一版图标。
    @Test("样式、深浅外观与连接状态决定换上的图标", arguments: cases)
    func variantFollowsIconStyleAndConnection(
        iconTheme: String?,
        appearance: NSAppearance.Name,
        disconnected: AppIconVariant?,
        connected: AppIconVariant?
    ) throws {
        let effectiveAppearance = try #require(NSAppearance(named: appearance))

        let whenDisconnected = AppIconController.variant(
            forIconTheme: iconTheme,
            appearance: effectiveAppearance,
            isConnected: false
        )

        let whenConnected = AppIconController.variant(
            forIconTheme: iconTheme,
            appearance: effectiveAppearance,
            isConnected: true
        )

        #expect(whenDisconnected == disconnected)
        #expect(whenConnected == connected)
    }
}
