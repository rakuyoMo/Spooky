import Foundation

// MARK: - AppIconGroup

/// 应用图标的一组：Settings › Appearance 里选定的一组用于 Dock、⌘Tab 与访达。
///
/// 每组四个图标：默认、连接、深色、深色连接，资源名由组的前缀加上 `Dark`、`Connected` 拼成。
/// 每组属于一个系列，各组声明的先后就是它在所属系列里的顺序。
enum AppIconGroup: String, CaseIterable, Identifiable {
    /// 幽灵正面从两层机架后升起来、举着两只小手，默认的一组；包里的默认图标（`CFBundleIconFile`）就是这一组的默认图标。
    case rise

    /// 幽灵侧身浮在三层机架前面，一只小手抬向指示灯。
    case front

    /// 幽灵从机柜背后探出来，望向机柜。
    case hide

    /// 幽灵浮在服务器往上投出的一束光里。
    case reveal

    /// 从左下角探身进来的幽灵，身后是一轮紫色的满月。
    case midnight

    /// 坐在树枝上的幽灵，眼前垂着一对樱桃。
    case perch

    /// 伸手去摘枝上樱桃的幽灵。
    case cherryPick

    /// 抱着一对樱桃的幽灵，身后是一轮紫色的满月。
    case armful

    /// 默认的一组：没选过时用它，它的默认图标就是包里的默认图标，不需要自定义图标。
    static let defaultGroup = Self.rise

    /// 偏好键，保存 `rawValue`。
    static let key = "appIconGroup"

    /// 底板四周的透明边占图标边长的比例：每组图标的底板都从 1024 网格的 (100, 100) 画起，见 `scripts/make-icon/kit.js`；
    /// 与图标并排的文字和控件按底板排齐。
    static let plateInset = 100.0 / 1024

    /// SwiftUI 列表以 `rawValue` 作为稳定身份。
    var id: String { rawValue }

    /// 这一组所属的系列。
    var series: AppIconSeries {
        switch self {
        case .rise,
             .front,
             .hide,
             .reveal:
            .hideAndSeek

        case .midnight,
             .perch,
             .cherryPick,
             .armful:
            .cherryPick
        }
    }

    /// 组名，由辅助功能读出。
    var title: String {
        switch self {
        case .rise: AppLocalization.text("appIcon.rise")
        case .front: AppLocalization.text("appIcon.front")
        case .hide: AppLocalization.text("appIcon.hide")
        case .reveal: AppLocalization.text("appIcon.reveal")
        case .midnight: AppLocalization.text("appIcon.midnight")
        case .perch: AppLocalization.text("appIcon.perch")
        case .cherryPick: AppLocalization.text("appIcon.cherryPick")
        case .armful: AppLocalization.text("appIcon.armful")
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

// MARK: - AppIconSeries

/// 应用图标的系列：设置页按系列分节列出各组，系列声明的先后就是从上到下的顺序。
enum AppIconSeries: CaseIterable, Identifiable {
    /// 躲猫猫：幽灵与服务器。
    case hideAndSeek

    /// cherry-pick：幽灵与一对樱桃。
    case cherryPick

    /// SwiftUI 列表以系列自身作为稳定身份。
    var id: Self { self }

    /// 设置页中显示的系列名。
    var title: String {
        switch self {
        case .hideAndSeek: AppLocalization.text("appIcon.series.hideAndSeek")
        case .cherryPick: AppLocalization.text("appIcon.series.cherryPick")
        }
    }

    /// 这一系列的各组，按声明的先后。
    var groups: [AppIconGroup] {
        AppIconGroup.allCases.filter { $0.series == self }
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
        case .rise: "AppIconRise"
        case .front: "AppIconFront"
        case .hide: "AppIconHide"
        case .reveal: "AppIconReveal"
        case .midnight: "AppIconMidnight"
        case .perch: "AppIconPerch"
        case .cherryPick: "AppIconCherryPick"
        case .armful: "AppIconArmful"
        }
    }
}
