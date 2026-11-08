import AppKit
import SwiftUI
import Testing

@testable import Spooky

// MARK: - ThemeColorSpaceTests

/// 直接主题色按 Generic RGB 解释，推导色与界面命名色保持 sRGB，颜色面板的显示和保存不能往返漂移。
@MainActor
struct ThemeColorSpaceTests {
    /// 两套内置主题的全部颜色经过真正的 SwiftUI 渲染入口后，仍保留文件里的 Generic RGB 分量；
    /// 黑白保留原来的外观，中间色必须改变显示分量，防止把直接构色写成保色的空间转换；
    /// 行号与块描边使用 sRGB 偏移，任意精度的不透明度不经过颜色面板的两位舍入。
    @Test("主题色的直接构色、渲染与 Diff 推导色")
    func themeColors() throws {
        for theme in TextTheme.builtin {
            let style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)

            for (key, color) in theme.colors {
                let expected = try Self.components(color.nsColor, space: .sRGB)
                try Self.expect(color.calibratedNSColor, space: .genericRGB, components: expected)
                try Self.expect(NSColor(style.color(key)), space: .genericRGB, components: expected)
                #expect(PaletteColor(nsColor: color.calibratedNSColor, colorSpace: .genericRGB) == color)
                #expect(PaletteColor(nsColor: color.nsColor) == color)
            }
        }

        // 黑白与中间色的空间区别
        for (hex, value) in [("#000000", 0.0), ("#FFFFFF", 1.0)] {
            let color = PaletteColor(hex: hex, alpha: 1)
            try Self.expect(color.calibratedNSColor, space: .sRGB, components: [value, value, value, 1])
        }

        let color = PaletteColor(hex: "#161819", alpha: 1)
        let srgb = try Self.components(color.nsColor, space: .sRGB)
        let calibrated = try Self.components(color.calibratedNSColor, space: .sRGB)
        #expect(abs(srgb[0] - calibrated[0]) > 0.01)

        // Diff 推导色保留 sRGB 与原始不透明度
        let source = PaletteColor(hex: "#161819", alpha: 0.123_456)
        let shifted = source.offset(by: 0.2)
        #expect(shifted.alpha == source.alpha)
        #expect(shifted.hex == "#494B4C")

        var theme = TextTheme.builtin[1]
        theme.colors["text"] = source
        let style = TextStyle(theme: theme, tabWidth: 4, showsInvisibles: false)
        try Self.expect(
            NSColor(style.lineNumberColor),
            space: .sRGB,
            components: Self.components(shifted.nsColor, space: .sRGB)
        )
    }

    /// 原文、背景与选区直接取主题色；次要文字、段高亮与分隔线仍由原始 sRGB 分量按亮度推导。
    @Test("文件视图的直接色与推导色", arguments: [0, 1, 2])
    func fileStyles(_ index: Int) throws {
        var theme = TextTheme.builtin[index == 1 ? 1 : 0]

        if index == 2 {
            theme.colors["text"] = PaletteColor(hex: "#801010", alpha: 0.57)
            theme.colors["background"] = PaletteColor(hex: "#161819", alpha: 0.83)
        }

        let style = FileTextStyle(theme: theme)

        for (key, actual) in [("text", style.text), ("background", style.background), ("selection", style.selection)] {
            let source = try #require(theme.colors[key])
            try Self.expect(actual, space: .genericRGB, components: Self.components(source.nsColor, space: .sRGB))
        }

        for (key, actual, offset) in [
            ("text", style.secondary, 0.2),
            ("background", style.highlight, 0.1),
            ("background", style.separator, 0.2),
        ] {
            let source = try #require(theme.colors[key])
            let components = try Self.components(source.nsColor, space: .sRGB)
            let dark = components[0] * 0.299 + components[1] * 0.587 + components[2] * 0.114 < 0.5
            let shifted = components.prefix(3).map { min(max($0 + (dark ? offset : -offset), 0), 1) }
            try Self.expect(actual, space: .sRGB, components: shifted + [source.alpha])
        }

        if index == 1 {
            let highlight = try Self.components(style.highlight, space: .sRGB)
            #expect(abs(highlight[0] - (22.0 / 255 + 0.1)) < 0.000_001)
            #expect(abs(highlight[0] - 48.0 / 255) > 0.001)
        }
    }

    /// 不同来源先转到 Generic RGB 再夹值与舍入，存回后保持稳定；透明度与图案色也走同一入口；
    /// 色块收到相同颜色时不写回，真实 sRGB 面板输入转换为 Generic RGB 后写入一次。
    @Test("颜色面板的空间转换、保存与写入")
    func panelConversion() throws {
        let inputs = [
            NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.123_456),
            NSColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1),
            NSColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1),
            NSColor(calibratedWhite: 0.5, alpha: 0.25),
            NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.7, alpha: 0),
        ]

        for input in inputs {
            let converted = try Self.components(input, space: .genericRGB)
            let expected = converted.prefix(3).map { (min(max($0, 0), 1) * 255).rounded() / 255 }
                + [(min(max(converted[3], 0), 1) * 100).rounded() / 100]
            let saved = try #require(PaletteColor(nsColor: input, colorSpace: .genericRGB))
            #expect(saved.isValid)
            try Self.expect(saved.calibratedNSColor, space: .genericRGB, components: expected)
            #expect(PaletteColor(nsColor: saved.calibratedNSColor, colorSpace: .genericRGB) == saved)
        }

        let pattern = NSColor(patternImage: NSImage(size: NSSize(width: 2, height: 2)))
        #expect(PaletteColor(nsColor: pattern, colorSpace: .genericRGB) == nil)
        #expect(PaletteColor(nsColor: pattern) == nil)

        // 色块收到相同颜色时不写回
        let original = PaletteColor(hex: "#123456", alpha: 0.5)
        var changes: [PaletteColor] = []
        let parent = ThemeColorWell(color: original, isEnabled: true, label: "Color") { changes.append($0) }
        let coordinator = parent.makeCoordinator()
        let well = NSColorWell()
        well.color = original.calibratedNSColor
        coordinator.colorChanged(well)
        #expect(changes.isEmpty)

        well.color = original.nsColor
        coordinator.colorChanged(well)
        let expected = try #require(PaletteColor(nsColor: original.nsColor, colorSpace: .genericRGB))
        #expect(expected != original)
        #expect(changes == [expected])

        coordinator.parent = ThemeColorWell(color: expected, isEnabled: true, label: "Color") { changes.append($0) }
        coordinator.colorChanged(well)
        #expect(changes == [expected])
    }

    /// 命名色不受主题构色方式影响，浅深外观都仍按资源的 sRGB 分量显示。
    @Test("命名色保持 sRGB", arguments: [false, true])
    func namedColors(_ dark: Bool) throws {
        let appearance = try #require(NSAppearance(named: dark ? .darkAqua : .aqua))

        for (name, variants) in AppPalette.colors {
            var resolved: NSColor? = nil
            appearance.performAsCurrentDrawingAppearance {
                resolved = AppPalette.nsColor(name).usingColorSpace(.sRGB)
            }

            let actual = try #require(resolved)
            let expected = dark ? variants.dark : variants.light
            try Self.expect(actual, space: .sRGB, components: Self.components(expected.nsColor, space: .sRGB))
            let saved = try #require(PaletteColor(nsColor: actual))
            #expect(saved.hex == expected.hex)
            #expect(saved.alpha == (expected.alpha * 100).rounded() / 100)
        }
    }
}

// MARK: - Helpers

extension ThemeColorSpaceTests {
    /// 读取指定色彩空间中的四个分量。
    private static func components(_ color: NSColor, space: NSColorSpace) throws -> [Double] {
        let converted = try #require(color.usingColorSpace(space))
        return [converted.redComponent, converted.greenComponent, converted.blueComponent, converted.alphaComponent]
    }

    /// 颜色转换含浮点误差，逐分量以百万分之一容差比较。
    private static func expect(_ color: NSColor, space: NSColorSpace, components expected: [Double]) throws {
        let actual = try components(color, space: space)

        for (value, target) in zip(actual, expected) {
            #expect(abs(value - target) < 0.000_001)
        }
    }
}
