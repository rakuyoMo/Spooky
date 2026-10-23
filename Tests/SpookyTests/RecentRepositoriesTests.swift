import Foundation
import SpookyKit
import Testing

@testable import Spooky

/// 最近仓库记录跨重启保留，失效状态不导致记录被删除。
///
/// 存储以临时目录里的文件路径作为 suite 名，偏好只写进这个目录，测试结束随目录删除；
/// 按名字建的 suite 即使移除了持久域，也会在 ~/Library/Preferences 留下空的 plist。
@MainActor
struct RecentRepositoriesTests {
    /// 去重、排序、重建存储对象与失效记录都作用于独立测试域。
    @Test("最近记录持久化并保留失效路径")
    func persistenceAndInvalidPaths() throws {
        // 偏好写进临时目录里的 plist，测试结束随目录删除。
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-recent-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))

        let recent = RecentRepositories(defaults: defaults)
        recent.remember(.local(path: "/temporary/仓 库'\"\\[*]?"))
        recent.remember(.local(path: "/temporary/second"))
        recent.remember(.local(path: "/temporary/仓 库'\"\\[*]?"))
        recent.markUnavailable(.local(path: "/temporary/second"))

        #expect(recent.locations == [.local(path: "/temporary/仓 库'\"\\[*]?"), .local(path: "/temporary/second")])
        #expect(recent.unavailable == [.local(path: "/temporary/second")])
        #expect(RecentRepositories(defaults: defaults).locations == recent.locations)

        recent.remember(.local(path: "/temporary/second"))
        #expect(recent.locations.first == .local(path: "/temporary/second"))
        #expect(recent.unavailable.isEmpty)
    }

    /// 旧版本本机记录迁移后可以和同名远端记录共存，数据只包含位置。
    @Test("M1 记录迁移与服务器身份持久化")
    func remoteIdentityAndMigration() throws {
        // 偏好写进临时目录里的 plist，测试结束随目录删除。
        let directory = FileManager.default.temporaryDirectory.appending(path: "spooky-recent-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try #require(UserDefaults(suiteName: directory.appending(path: "defaults").path))

        defaults.set(["/temporary/repository"], forKey: "recentRepositoryPaths")
        let recent = RecentRepositories(defaults: defaults)
        let remote = RepositoryLocation.remote(host: "test'alias", path: "/temporary/repository")
        recent.remember(remote)
        recent.markUnavailable(remote)

        #expect(recent.locations == [remote, .local(path: "/temporary/repository")])
        #expect(recent.unavailable.contains(remote))
        let reloaded = RecentRepositories(defaults: defaults)
        #expect(reloaded.locations == recent.locations)
        #expect(reloaded.locations.first?.displayPath == "test'alias:/temporary/repository")
        #expect(reloaded.locations.first?.localURL == nil)
        let data = try #require(defaults.data(forKey: "recentRepositories"))
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("password") && !text.contains("environment") && !text.contains("identity"))
    }
}
