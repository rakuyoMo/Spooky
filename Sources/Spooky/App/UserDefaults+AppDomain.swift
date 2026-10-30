import Foundation

// MARK: - UserDefaults + AppDomain

extension UserDefaults {
    /// App 自己的偏好域名；没有 Bundle Identifier 时是进程名，与 `UserDefaults.standard` 使用的域一致。
    static let appDomain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
}
