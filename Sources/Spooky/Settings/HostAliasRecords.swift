import Foundation
import SpookyKit

// MARK: - HostAliasRecords

/// 按主机别名记下的内容：书签里的服务器仓库、按仓库与按主机记的偏好，以及钥匙串里保存的凭据。
@MainActor
enum HostAliasRecords {
    /// 以仓库的显示路径（`<别名>:<路径>`）为键的偏好。
    static let repositoryKeys = [
        ServerLocalLocation.key,
        ServerLocalLocation.legacyKey,
        SidebarExpansion.storageKey,
        WorkingCopyListMode.repositoryStorageKey,
        RemoteFetchTimes.key,
        PullRequestServices.key,
        BranchArchiving.lastCheckKey,
    ]

    /// 主机别名改名后，把按原来的别名记下的内容都换到新别名。
    ///
    /// - Parameters:
    ///   - alias: 原来的别名。
    ///   - renamed: 新别名。
    ///   - bookmarks: 仓库书签。
    ///   - defaults: 存放偏好的位置，测试使用独立的偏好域。
    ///   - keychain: 存放凭据的钥匙串，测试使用临时钥匙串。
    static func rename(
        _ alias: String,
        to renamed: String,
        bookmarks: RepositoryBookmarks,
        defaults: UserDefaults = .standard,
        keychain: SecurityKeychain = .shared
    ) {
        // 书签里这台主机上的仓库改指向新别名，名称前缀与打开时的连接随之更换
        for location in bookmarks.repositories.compactMap(\.location) where location.host == alias {
            bookmarks.relocate(location, to: .remote(host: renamed, path: location.path))
        }

        // 按仓库记的偏好：这台主机上各仓库的记录换到新别名的键下
        for key in repositoryKeys {
            guard let records = defaults.dictionary(forKey: key) else {
                continue
            }

            var updated = records

            for (id, record) in records {
                guard let location = RepositoryLocation(displayPath: id), location.host == alias else {
                    continue
                }

                updated[id] = nil
                updated[RepositoryLocation.remote(host: renamed, path: location.path).displayPath] = record
            }

            // 没有这台主机上的记录时不写偏好
            if updated.keys != records.keys {
                defaults.set(updated, forKey: key)
            }
        }

        // 在这台主机上克隆时记住的目录
        var directories = defaults.dictionary(forKey: ServerCloneDirectories.key) ?? [:]

        if let directory = directories.removeValue(forKey: alias) {
            directories[renamed] = directory
            defaults.set(directories, forKey: ServerCloneDirectories.key)
        }

        // 钥匙串里保存的用户名、密码与口令
        keychain.moveItems(
            fromService: RemoteCallbackPresenter.keychainService(for: alias),
            toService: RemoteCallbackPresenter.keychainService(for: renamed)
        )
    }
}
