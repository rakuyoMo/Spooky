import AppKit
import Testing

@testable import Spooky

/// App 图标跟随 “图标与小组件样式” 与连接状态：深色样式与透明、色调的深色子变体换成深色图标，
/// 其余样式没连服务器时交还包里的默认图标，连着服务器时换成点亮指示灯的默认图标。
///
/// Dock 对运行时设置的图标原样显示，只对包里的默认图标做透明、色调处理：
/// 深色子变体不换图标就是默认图标处理出的较亮底板，浅色子变体与默认样式换了图标就要自己照系统的处理做好；
/// 包里的默认图标指示灯灭着，所以浅色子变体与默认样式只有连着服务器时才换。
@MainActor
struct AppIconControllerTests {
    /// 各样式在深浅外观下、没连与连着服务器时应换上的图标；nil 表示不设运行时图标。
    ///
    /// “始终” 与 “深色” 子变体不看外观；“自动” 子变体只在深色外观（含高对比度、vibrant 变体）下换成深色图标；
    /// 默认样式（键不存在）与透明、色调的浅色子变体在任何外观下都用默认图标。
    private nonisolated static let cases: [(
        iconTheme: String?,
        appearance: NSAppearance.Name,
        disconnected: AppIconVariant?,
        connected: AppIconVariant?
    )] = [
        (nil, .darkAqua, nil, .connected(.regular)),
        (nil, .aqua, nil, .connected(.regular)),

        ("RegularDark", .darkAqua, .dark(.regular, isConnected: false), .dark(.regular, isConnected: true)),
        ("RegularDark", .aqua, .dark(.regular, isConnected: false), .dark(.regular, isConnected: true)),
        ("RegularAutomatic", .darkAqua, .dark(.regular, isConnected: false), .dark(.regular, isConnected: true)),
        (
            "RegularAutomatic",
            .accessibilityHighContrastDarkAqua,
            .dark(.regular, isConnected: false),
            .dark(.regular, isConnected: true)
        ),
        ("RegularAutomatic", .vibrantDark, .dark(.regular, isConnected: false), .dark(.regular, isConnected: true)),
        ("RegularAutomatic", .aqua, nil, .connected(.regular)),
        ("RegularAutomatic", .accessibilityHighContrastAqua, nil, .connected(.regular)),
        ("RegularAutomatic", .vibrantLight, nil, .connected(.regular)),

        ("ClearLight", .darkAqua, nil, .connected(.clear)),
        ("ClearLight", .aqua, nil, .connected(.clear)),
        ("ClearDark", .darkAqua, .dark(.clear, isConnected: false), .dark(.clear, isConnected: true)),
        ("ClearDark", .aqua, .dark(.clear, isConnected: false), .dark(.clear, isConnected: true)),
        ("ClearAutomatic", .darkAqua, .dark(.clear, isConnected: false), .dark(.clear, isConnected: true)),
        ("ClearAutomatic", .aqua, nil, .connected(.clear)),

        ("TintedLight", .darkAqua, nil, .connected(.tinted)),
        ("TintedLight", .aqua, nil, .connected(.tinted)),
        ("TintedDark", .darkAqua, .dark(.tinted, isConnected: false), .dark(.tinted, isConnected: true)),
        ("TintedDark", .aqua, .dark(.tinted, isConnected: false), .dark(.tinted, isConnected: true)),
        ("TintedAutomatic", .darkAqua, .dark(.tinted, isConnected: false), .dark(.tinted, isConnected: true)),
        ("TintedAutomatic", .aqua, nil, .connected(.tinted)),
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
