import Foundation

// MARK: - RepositoryManagerPreferences

/// 仓库管理列表的显示设置：所有窗口共用，存在偏好里，General 页以 `@AppStorage` 读写同一组键。
enum RepositoryManagerPreferences {
    /// 有别的工作树的仓库可以展开，下一层列出这些工作树。
    static let showsWorktreesKey = "showWorktreesInRepositoryList"

    /// 服务器仓库的行在名称前写主机别名。
    static let showsHostAliasesKey = "showHostAliasesInRepositoryList"

    /// 是否列出工作树；没有记录时不列。
    ///
    /// - Parameter defaults: 读取的偏好，测试使用独立的域。
    static func showsWorktrees(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: showsWorktreesKey) as? Bool ?? false
    }

    /// 是否在服务器仓库的行上写主机别名；没有记录时写。
    ///
    /// - Parameter defaults: 读取的偏好，测试使用独立的域。
    static func showsHostAliases(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: showsHostAliasesKey) as? Bool ?? true
    }
}
