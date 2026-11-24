import Foundation
import SpookyKit
import Testing
import TestSupport

@testable import Spooky

// MARK: - HostAliasRecordsTests

/// 主机别名改名后，按原来的别名记下的内容都要跟到新别名：留在旧别名下的书签连不上服务器，偏好与凭据等于丢了。
@MainActor
struct HostAliasRecordsTests {
    /// 这台主机上的仓库书签改指向新别名，文件夹里的也算，名称前缀随之更换；按仓库记的偏好、克隆目录与保存的凭据换到新别名下。
    /// 别的主机与本机仓库的书签、偏好与凭据都不动。
    @Test("改别名后书签、偏好与凭据换到新别名")
    func rename() throws {
        let temporary = try TemporaryKeychain()
        defer { temporary.remove() }

        let keychain = SecurityKeychain(keychain: temporary.path)
        let defaults = MemoryDefaults()
        let bookmarks = RepositoryBookmarks(defaults: defaults)

        let app = RepositoryLocation.remote(host: "old", path: "/srv/应用 app")
        let library = RepositoryLocation.remote(host: "old", path: "/srv/lib")
        let elsewhere = RepositoryLocation.remote(host: "older", path: "/srv/应用 app")
        let local = RepositoryLocation.local(path: "/tmp/old:repo")

        let renamedApp = RepositoryLocation.remote(host: "new", path: "/srv/应用 app")
        let renamedLibrary = RepositoryLocation.remote(host: "new", path: "/srv/lib")

        let folder = bookmarks.addFolder(named: "Servers")
        bookmarks.add(app)
        bookmarks.add(library, into: folder)
        bookmarks.add(elsewhere)
        bookmarks.add(local)

        // 旧别名下连不上而标成失效的书签，换了别名后不再带着标记
        bookmarks.markMissing(app)

        let fetched = Date(timeIntervalSince1970: 1000)
        let chosen = ServerLocalLocation.chosenFolder(URL(filePath: "/Volumes/app"))

        for repository in [app, elsewhere, local] {
            ServerLocalLocation.store(chosen, for: repository, defaults: defaults)
            WorkingCopyListMode.store(.tree, for: repository, defaults: defaults)
            RemoteFetchTimes.record("origin", in: repository, at: fetched, defaults: defaults)
            PullRequestServices.store(.gitlab, for: repository, defaults: defaults)
            BranchArchiving.recordCheck(for: repository, defaults: defaults, now: fetched)

            let expansion = SidebarExpansion()
            expansion.load(repository, defaults: defaults)
            expansion.expand(groups: [.tags], nodes: [])
        }

        // 只在旧偏好键里指定过文件夹、还没读过的仓库
        defaults.set([library.displayPath: "/Volumes/lib"], forKey: ServerLocalLocation.legacyKey)

        ServerCloneDirectories.remember("/srv", for: "old", in: defaults)
        ServerCloneDirectories.remember("/data", for: "older", in: defaults)

        let services = (
            old: RemoteCallbackPresenter.keychainService(for: "old"),
            new: RemoteCallbackPresenter.keychainService(for: "new"),
            older: RemoteCallbackPresenter.keychainService(for: "older")
        )

        try keychain.setPassword("secret", service: services.old, account: "password")
        try keychain.setPassword("me", service: services.old, account: "username")
        try keychain.setPassword("kept", service: services.older, account: "password")

        HostAliasRecords.rename("old", to: "new", bookmarks: bookmarks, defaults: defaults, keychain: keychain)

        // 书签：这台主机上的两个仓库换到新别名，位置与所在的文件夹不变
        #expect(bookmarks.repositories.compactMap(\.location) == [renamedLibrary, renamedApp, elsewhere, local])
        #expect(bookmarks.repositories.map(\.displayName) == ["new:lib", "new:应用 app", "older:应用 app", "old:repo"])
        #expect(bookmarks.bookmark(for: renamedLibrary).flatMap { bookmarks.parent(of: $0.id) } == folder)
        #expect(!bookmarks.isMissing(renamedApp))
        #expect(RepositoryBookmarks(defaults: defaults).items == bookmarks.items)

        /// 一个仓库按显示路径记下的偏好是否都在。
        func hasRecords(_ repository: RepositoryLocation) -> Bool {
            let expansion = SidebarExpansion()
            expansion.load(repository, defaults: defaults)

            return ServerLocalLocation.stored(for: repository, defaults: defaults) == chosen
                && WorkingCopyListMode.stored(for: repository, defaults: defaults) == .tree
                && RemoteFetchTimes.lastFetch(of: "origin", in: repository, defaults: defaults) == fetched
                && PullRequestServices.stored(for: repository, defaults: defaults) == .gitlab
                && !BranchArchiving.isDue(for: repository, defaults: defaults, now: fetched)
                && expansion.binding(for: .tags, filtering: false).wrappedValue
        }

        // 按仓库记的偏好：换到新别名下，旧别名下不留；别的主机与本机仓库的不动
        #expect(hasRecords(renamedApp))
        #expect(hasRecords(elsewhere))
        #expect(hasRecords(local))

        for key in HostAliasRecords.repositoryKeys {
            #expect(!(defaults.dictionary(forKey: key) ?? [:]).keys.contains { $0.hasPrefix("old:") })
        }

        #expect(
            ServerLocalLocation
                .stored(for: renamedLibrary, defaults: defaults) == .chosenFolder(URL(filePath: "/Volumes/lib"))
        )

        // 克隆目录
        #expect(ServerCloneDirectories.directory(for: "new", in: defaults) == "/srv")
        #expect(ServerCloneDirectories.directory(for: "old", in: defaults) == nil)
        #expect(ServerCloneDirectories.directory(for: "older", in: defaults) == "/data")

        // 保存的凭据
        #expect(keychain.password(service: services.new, account: "password") == "secret")
        #expect(keychain.password(service: services.new, account: "username") == "me")
        #expect(keychain.password(service: services.old, account: "password") == nil)
        #expect(keychain.password(service: services.older, account: "password") == "kept")
    }
}
