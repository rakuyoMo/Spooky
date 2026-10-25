import AppKit
import SwiftUI

// MARK: - WindowRestoration

/// 退出 App 时是否保留窗口、下次启动时恢复：总是、从不，或交给系统设置。
enum WindowRestoration: CaseIterable, Hashable {
    /// 总是恢复。
    case always

    /// 从不恢复。
    case never

    /// 按系统设置 “退出 App 时关闭窗口” 决定。
    case system

    /// AppKit 读取的偏好键；写在 App 自己的偏好域里时覆盖全局域里的系统设置。
    static let key = "NSQuitAlwaysKeepsWindows"

    /// 弹出菜单里的名称。
    var title: String {
        switch self {
        case .always: AppLocalization.text("settings.windowRestoration.always")
        case .never: AppLocalization.text("settings.windowRestoration.never")
        case .system: AppLocalization.text("settings.windowRestoration.system")
        }
    }

    /// App 偏好域里的取值；全局域里的系统设置不算 App 自己的选择。
    ///
    /// - Parameters:
    ///   - defaults: 读取的偏好。
    ///   - domain: App 的偏好域名。
    static func current(in defaults: UserDefaults, domain: String) -> Self {
        switch defaults.persistentDomain(forName: domain)?[key] as? Bool {
        case true?: .always
        case false?: .never
        case nil: .system
        }
    }

    /// 写进偏好；交给系统设置时删除这个键。
    ///
    /// - Parameter defaults: 写入的偏好。
    func save(in defaults: UserDefaults) {
        switch self {
        case .always: defaults.set(true, forKey: Self.key)
        case .never: defaults.set(false, forKey: Self.key)
        case .system: defaults.removeObject(forKey: Self.key)
        }
    }
}

// MARK: - WindowSettingsRows

/// General 页最后一组：窗口恢复方式与启动时是否显示启动窗口。
struct WindowSettingsRows: View {
    /// App 的偏好域名；没有 Bundle Identifier 时是进程名，与 `UserDefaults.standard` 使用的域一致。
    private static let domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName

    /// 启动时显示启动窗口。
    @AppStorage(SpookyApplicationController.showsLaunchWindowKey)
    private var showsLaunchWindow = false

    /// 菜单里的窗口恢复方式；打开页面时从偏好读出。
    @State
    private var restoration = WindowRestoration.current(in: .standard, domain: domain)

    /// 右对齐的标签与 278 pt 宽的弹出菜单，下面是启动窗口的勾选框。
    var body: some View {
        GridRow {
            Text(AppLocalization.text("settings.windowRestoration"))
                .gridColumnAlignment(.trailing)

            Picker("", selection: $restoration) {
                ForEach(WindowRestoration.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 278)
            .accessibilityLabel(AppLocalization.text("settings.windowRestoration"))
            .onChange(of: restoration) { restoration.save(in: .standard) }
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Toggle(AppLocalization.text("settings.showLaunchWindow"), isOn: $showsLaunchWindow)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 278, alignment: .leading)
        }
    }
}
