import AppKit

// MARK: - AppAppearance

/// App 的外观：跟随系统、浅色或深色；Settings › Appearance 与快捷操作的外观项读写同一个偏好。
enum AppAppearance: Int, CaseIterable, Identifiable {
    /// 跟随系统外观。
    case system = 0

    /// 始终使用浅色外观。
    case light = 1

    /// 始终使用深色外观。
    case dark = 2

    /// 偏好键，保存 `rawValue`。
    static let key = "appAppearance"

    /// 当前保存的外观；没有记录或记录无法识别时跟随系统。
    static var current: Self {
        Self(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .system
    }

    /// SwiftUI 列表以 `rawValue` 作为稳定身份。
    var id: Int { rawValue }

    /// 设置页与快捷操作中显示的名称。
    var title: String {
        switch self {
        case .system: AppLocalization.text("appearance.system")
        case .light: AppLocalization.text("appearance.light")
        case .dark: AppLocalization.text("appearance.dark")
        }
    }

    /// 保存为当前外观并立即应用到整个 App。
    @MainActor
    func select() {
        UserDefaults.standard.set(rawValue, forKey: Self.key)
        apply()
    }

    /// 把外观交给 AppKit：跟随系统时清除 App 级外观，文本区主题随之按有效外观切换。
    @MainActor
    func apply() {
        NSApp.appearance =
            switch self {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
    }
}
