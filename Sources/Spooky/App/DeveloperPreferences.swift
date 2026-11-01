import Foundation

// MARK: - DeveloperPreferences

/// Developer 菜单用到的偏好：菜单是否显示、仓库是否自动刷新，以及重置与清空偏好域。
enum DeveloperPreferences {
    /// 是否在主菜单显示 Developer 菜单，由 General 页的勾选框写入；没有记录时不显示。
    static let showsMenuKey = "showDeveloperMenu"

    /// 本机仓库的文件监听与服务器仓库的轮询是否触发刷新；没有记录时触发。
    static let autoReloadKey = "autoReloadRepository"

    /// Reset User Defaults 保留的数据：书签、身份档案、托管账号、远端地址与账号的关联，以及服务器仓库手动指定的本机目录。
    @MainActor
    static let dataKeys = [
        RepositoryBookmarks.key,
        UserProfiles.key,
        HostingAccounts.key,
        PullRequestAssociations.key,
        ServerLocalFolders.key,
    ]

    /// 文件监听与轮询发现变化时是否刷新仓库。
    ///
    /// - Parameter defaults: 读取的偏好，测试使用独立的域。
    static func autoReloads(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: autoReloadKey) as? Bool ?? true
    }

    /// 删掉偏好域里的内容，之后读取的设置回到默认值。
    ///
    /// 已经读进内存的设置不随之改变，重启 App 后才全部回到默认。
    ///
    /// - Parameters:
    ///   - domain: 偏好域名。
    ///   - defaults: App 读写这个域所用的偏好。
    ///   - keepingData: Reset User Defaults 传 true，只删设置、保留 `dataKeys`；Clear User Defaults 传 false，整个域都删。
    @MainActor
    static func removeValues(in domain: String, of defaults: UserDefaults, keepingData: Bool) {
        let values = defaults.persistentDomain(forName: domain) ?? [:]
        let kept = keepingData ? values.filter { dataKeys.contains($0.key) } : [:]

        defaults.removePersistentDomain(forName: domain)

        // 只有 Reset 且域里有数据时才写回
        if !kept.isEmpty {
            defaults.setPersistentDomain(kept, forName: domain)
        }
    }
}
