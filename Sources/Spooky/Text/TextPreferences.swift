import Foundation

// MARK: - TextPreferences

/// 设置 → Text 的偏好：语法着色、Diff 中的语法着色、不可见字符与 Tab 宽度，Diff 与文件文本共用。
enum TextPreferences {
    /// 语法着色总开关的偏好键，默认打开。
    static let syntaxColoringKey = "syntaxColoring"

    /// Diff 中语法着色的偏好键，默认关闭。
    static let diffSyntaxColoringKey = "diffSyntaxColoring"

    /// 显示不可见字符的偏好键。
    static let showsInvisiblesKey = "showsInvisibleCharacters"

    /// Tab 宽度的偏好键，单位为空格数。
    static let tabWidthKey = "tabWidth"

    /// 未设置时的 Tab 宽度。
    static let defaultTabWidth = 4

    /// Tab 宽度的取值范围。
    static let tabWidths = 1 ... 100

    /// 文件文本的语法着色是否打开。
    static var colorsSyntax: Bool {
        UserDefaults.standard.object(forKey: syntaxColoringKey) as? Bool ?? true
    }

    /// Diff 着色要求总开关与 Diff 开关同时打开。
    static var colorsDiffSyntax: Bool {
        #warning("TODO: 核实只开 “Syntax Coloring in Diffs” 时 Diff 是否着色；目前还要求总开关打开，只影响 Diff 着色与设置页子选项的禁用。")
        return colorsSyntax && UserDefaults.standard.bool(forKey: diffSyntaxColoringKey)
    }
}
