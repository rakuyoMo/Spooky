import Foundation

// MARK: - AppIconGroup

/// 应用图标的一组：Settings › Appearance 里选定的一组用于 Dock、⌘Tab 与访达。
///
/// 每组四个图标：默认、连接、深色、深色连接，资源名由组的前缀加上 `Dark`、`Connected` 拼成。
enum AppIconGroup: String, CaseIterable, Identifiable {
    /// 幽灵与机架，默认的一组；包里的默认图标（`CFBundleIconFile`）就是这一组的默认图标。
    case serverGhost

    /// 紫色夜空里探身进来的幽灵。
    case midnight

    /// 抱着一对樱桃的幽灵，身后是一排声纹。
    case armful

    /// 伸手从枝上采撷的幽灵。
    case cherryPick

    /// 落在树枝上的幽灵。
    case perch

    /// 默认的一组：没选过时用它，它的默认图标就是包里的默认图标，不需要壳 App 与自定义图标。
    static let defaultGroup = Self.serverGhost

    /// 偏好键，保存 `rawValue`。
    static let key = "appIconGroup"

    /// 底板四周的透明边占图标边长的比例：每组图标的底板都从 1024 网格的 (100, 100) 画起，见 `scripts/make-icon/kit.js`；
    /// 与图标并排的文字和控件按底板排齐。
    static let plateInset = 100.0 / 1024

    /// SwiftUI 列表以 `rawValue` 作为稳定身份。
    var id: String { rawValue }

    /// 设置页与图标列表中显示的组名。
    var title: String {
        switch self {
        case .serverGhost: AppLocalization.text("appIcon.serverGhost")
        case .midnight: AppLocalization.text("appIcon.midnight")
        case .armful: AppLocalization.text("appIcon.armful")
        case .cherryPick: AppLocalization.text("appIcon.cherryPick")
        case .perch: AppLocalization.text("appIcon.perch")
        }
    }

    /// 偏好里所选的组；没有记录或记录无法识别时为默认的一组。
    /// - Parameter defaults: 读取的偏好，测试使用独立的域
    static func current(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: key).flatMap(Self.init(rawValue:)) ?? defaultGroup
    }

    /// 这一组中某一版图标在包里的资源名，不含扩展名。
    /// - Parameter variant: 深浅与指示灯
    func iconName(for variant: AppIconVariant) -> String {
        iconNamePrefix + (variant.isDark ? "Dark" : "") + (variant.isConnected ? "Connected" : "")
    }
}

// MARK: - AppIconVariant

/// 一组图标中的一版：深色或默认，指示灯亮着或灭着。
struct AppIconVariant: Equatable {
    /// 指示灯灭着的默认图标：默认的一组是包里的默认图标，其它组是各自壳 App 的包内图标。
    static let standard = Self(isDark: false, isConnected: false)

    /// 是否深色图标。
    var isDark: Bool

    /// 指示灯是否亮着：连着服务器时亮起。
    var isConnected: Bool
}

// MARK: - Private

extension AppIconGroup {
    /// 这一组四个图标共用的资源名前缀，也是默认图标与壳 App 的名字。
    private var iconNamePrefix: String {
        switch self {
        case .serverGhost: "AppIconServerGhost"
        case .midnight: "AppIconMidnight"
        case .armful: "AppIconArmful"
        case .cherryPick: "AppIconCherryPick"
        case .perch: "AppIconPerch"
        }
    }
}
