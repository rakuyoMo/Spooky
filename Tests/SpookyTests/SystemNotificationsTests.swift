import Foundation
import Testing

@testable import Spooky
@testable import SpookyKit

// MARK: - SystemNotificationsTests

/// 系统通知：地址里的凭据不进通知，克隆位置的写法，以及不是 App Bundle 时不碰通知中心。
@MainActor
struct SystemNotificationsTests {
    /// 通知会显示在锁屏与通知中心里，URL 形式地址里的账号与口令都要去掉，scp 形式没有凭据，原样显示；
    /// 本机位置把主目录缩写成 `~`，不在主目录下的照写；服务器位置带主机别名，不会与本机路径混淆。
    @Test("通知里的克隆地址与克隆位置")
    func displayedClone() {
        let remotes: [(url: String, expected: String)] = [
            ("https://rakuyo:p@ss:word@example.com/team/应用 仓库.git", "https://example.com/team/应用 仓库.git"),
            ("https://token@example.com:8443/team/app.git", "https://example.com:8443/team/app.git"),
            ("https://example.com/team/a@b.git", "https://example.com/team/a@b.git"),
            ("git@example.com:team/app.git", "git@example.com:team/app.git"),
        ]

        for remote in remotes {
            #expect(SystemNotifications.displayedRemote(remote.url) == remote.expected, "\(remote.url)")
        }

        // 克隆位置
        let home = NSHomeDirectory()

        #expect(SystemNotifications.displayedDestination(.local(path: home + "/项目/app")) == "~/项目/app")
        #expect(SystemNotifications.displayedDestination(.local(path: "/tmp/app")) == "/tmp/app")

        #expect(
            SystemNotifications.displayedDestination(.remote(host: "spooky-test", path: home + "/app"))
                == "spooky-test:" + home + "/app"
        )
    }

    /// 不是 App Bundle 时取通知中心会抛出异常，测试与 `swift run` 都靠这一条才能走完克隆与自动归档。
    @Test("不是 App Bundle 时不取通知中心")
    func unavailableOutsideBundle() {
        #expect(SystemNotifications(bundleURL: URL(fileURLWithPath: "/usr/local/bin")).center == nil)
        #expect(SystemNotifications(bundleURL: URL(fileURLWithPath: "/tmp/Spooky.xctest")).center == nil)

        #expect(SystemNotifications.shared.center == nil)

        // 没有通知中心时发送直接返回
        SystemNotifications.shared.postCloneFinished(
            RepositoryClone(url: "https://example.invalid/app.git", destination: .local(path: "/tmp/app"))
        )

        SystemNotifications.shared.postBranchesArchived(count: 2)
    }
}
