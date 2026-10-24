import AppKit
import SwiftUI

// MARK: - PaletteColor

/// 以 sRGB 数值与透明度保存颜色；命名色资源与主题文件使用同一种写法。
struct PaletteColor: Codable, Sendable, Equatable {
    /// `#` 开头的六位 RGB 值。
    let hex: String

    /// 不透明度。
    let alpha: Double

    /// 值是否可以解释成颜色：六位十六进制，不透明度在 0–1 之间。
    var isValid: Bool {
        hex.wholeMatch(of: /#[0-9A-Fa-f]{6}/) != nil && (0 ... 1).contains(alpha)
    }

    /// AppKit 与 SwiftUI 共用同一种色彩空间。
    var nsColor: NSColor {
        let rgb = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return NSColor(
            srgbRed: Double((rgb >> 16) & 255) / 255,
            green: Double((rgb >> 8) & 255) / 255,
            blue: Double(rgb & 255) / 255,
            alpha: alpha
        )
    }

    /// 文本主题的固定外观颜色。
    var color: Color { Color(nsColor: nsColor) }
}

extension PaletteColor {
    /// 取颜色面板等处选出的颜色；无法换算到 sRGB 的颜色（如图案）返回 nil。
    init?(nsColor: NSColor) {
        guard let srgb = nsColor.usingColorSpace(.sRGB) else {
            return nil
        }

        // 分量先夹到 0–1，扩展色域的颜色超出范围时取最接近的 sRGB 值。
        let components = [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]
            .map { Int((min(max(Double($0), 0), 1) * 255).rounded()) }

        hex = String(format: "#%02X%02X%02X", components[0], components[1], components[2])

        // 颜色面板的不透明度以百分比调节，保留两位小数即可还原面板上的值。
        alpha = (min(max(Double(srgb.alphaComponent), 0), 1) * 100).rounded() / 100
    }
}

extension PaletteColor {
    /// 红、绿、蓝三个分量都低于 0.5 时算深色，不看不透明度。
    var isDark: Bool {
        let color = nsColor

        return color.redComponent < 0.5
            && color.greenComponent < 0.5
            && color.blueComponent < 0.5
    }

    /// 由这个颜色推出的颜色：红、绿、蓝分量各加上同一个值，夹在 0–1 之间，不透明度不变。
    func offset(by amount: Double) -> Self {
        let color = nsColor

        // 先夹到 0–1 再建颜色：超出范围的分量交给 NSColor 时，换算结果并不可靠
        let components = [color.redComponent, color.greenComponent, color.blueComponent]
            .map { min(max($0 + amount, 0), 1) }

        let shifted = NSColor(
            srgbRed: components[0],
            green: components[1],
            blue: components[2],
            alpha: 1
        )

        // 不透明度直接沿用，不经过两位小数的取整
        return Self(hex: Self(nsColor: shifted)?.hex ?? hex, alpha: alpha)
    }
}

// MARK: - AppPalette

/// 当前界面使用的命名色，外观改变时由 AppKit 自动切换。
enum AppPalette {
    /// 两种外观对应的颜色。
    struct Variants: Decodable, Sendable {
        /// 浅色外观。
        let light: PaletteColor

        /// 深色外观。
        let dark: PaletteColor
    }

    /// 资源只包含当前视图使用的颜色。
    static let colors: [String: Variants] = {
        guard
            let url = Bundle.module.url(forResource: "NamedColors", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let colors = try? JSONDecoder().decode([String: Variants].self, from: data)
        else { preconditionFailure("命名色资源无法读取") }
        return colors
    }()

    /// 通过命名颜色映射动态外观，未定义的名称属于资源错误。
    static func color(_ name: String) -> Color {
        Color(nsColor: nsColor(name))
    }

    /// AppKit 绘制使用的动态命名色，外观切换时自动取对应的值。
    static func nsColor(_ name: String) -> NSColor {
        guard let pair = colors[name] else { preconditionFailure("命名色缺失：\(name)") }
        return NSColor(name: NSColor.Name(name)) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? pair.dark.nsColor
                : pair.light.nsColor
        }
    }
}
