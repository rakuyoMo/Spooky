import AppKit
import SwiftUI

/// 以 sRGB 数值与透明度保存颜色。
struct PaletteColor: Decodable, Sendable, Equatable {
    /// 六位 RGB 值。
    let hex: String

    /// 不透明度。
    let alpha: Double

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
        guard let url = Bundle.module.url(forResource: "NamedColors", withExtension: "json"),
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
                ? pair.dark.nsColor : pair.light.nsColor
        }
    }
}

/// 内置文本主题，设置页提供只读预览，实际主题随系统外观选择。
struct BuiltinTheme: Decodable, Identifiable, Sendable {
    /// 主题身份与名称相同。
    var id: String { name }

    /// 需求固定的 Default 或 Default (Dark)。
    let name: String

    /// 两套主题均使用 Menlo-Regular。
    let fontName: String

    /// 主题字号为 11 pt。
    let fontSize: Double

    /// 正文、背景、选区、增删行及语法色。
    let colors: [String: PaletteColor]

    /// 随应用交付的两套主题。
    static let all: [BuiltinTheme] = {
        guard let url = Bundle.module.url(forResource: "BuiltinThemes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let themes = try? JSONDecoder().decode([BuiltinTheme].self, from: data)
        else { preconditionFailure("内置主题资源无法读取") }
        return themes
    }()

    /// 深浅外观分别使用对应默认主题。
    static func current(dark: Bool) -> BuiltinTheme { all[dark ? 1 : 0] }
}
