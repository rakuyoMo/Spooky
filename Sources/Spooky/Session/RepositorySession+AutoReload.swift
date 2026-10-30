import Foundation

// MARK: - Auto Reload

extension RepositorySession {
    /// 本机仓库的文件监听与服务器仓库的轮询发现变化时刷新；Developer 菜单关掉 Auto-Reload Repository 时不刷新，窗口激活与手动刷新照旧。
    ///
    /// - Parameter defaults: 读取开关的偏好，测试使用独立的域。
    func autoReload(defaults: UserDefaults = .standard) {
        guard DeveloperPreferences.autoReloads(in: defaults) else {
            return
        }

        refresh()
    }
}
