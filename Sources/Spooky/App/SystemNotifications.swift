import Foundation
import SpookyKit
import UserNotifications

// MARK: - SystemNotifications

/// 克隆完成与自动归档分支之后发出的系统通知。
///
/// 启动时以 provisional 申请授权，不弹询问，通知先安静地进通知中心；发送前只看已有的授权，没有授权或出错时不发，App 内的反馈照常。
@MainActor
final class SystemNotifications: NSObject, UNUserNotificationCenterDelegate {
    /// App 共用的一份，第一次发通知时创建。
    static let shared = SystemNotifications(bundleURL: Bundle.main.bundleURL)

    /// 系统通知中心；不是以 App Bundle 运行时为 nil，因为 `swift run` 与测试进程里取通知中心会抛出异常。
    let center: UNUserNotificationCenter?

    /// 只在 App Bundle 里取通知中心，并接管 App 在前台时的显示方式。
    ///
    /// - Parameter bundleURL: 当前进程的主 Bundle 位置。
    init(bundleURL: URL) {
        center = bundleURL.pathExtension == "app"
            ? UNUserNotificationCenter.current()
            : nil

        super.init()

        center?.delegate = self
    }

    /// 地址里的账号与口令不显示：URL 形式的地址去掉 `://` 与主机之间的 `<账号>[:<口令>]@`，scp 形式与本机路径原样返回。
    ///
    /// - Parameter url: 克隆时填写的远端地址。
    static func displayedRemote(_ url: String) -> String {
        guard let scheme = url.range(of: "://") else {
            return url
        }

        // 口令里可能含 @，以主机前最后一个 @ 为界
        let authority = url[scheme.upperBound...].prefix { $0 != "/" }

        guard let separator = authority.lastIndex(of: "@") else {
            return url
        }

        return String(url[..<scheme.upperBound]) + String(url[url.index(after: separator)...])
    }

    /// 克隆到的位置：本机路径把主目录写成 `~`，服务器位置写成 `<别名>:<路径>`。
    ///
    /// - Parameter location: 克隆的目标位置。
    static func displayedDestination(_ location: RepositoryLocation) -> String {
        switch location {
        case .local(let path):
            HomePath.abbreviated(path)

        case .remote:
            location.displayPath
        }
    }

    /// 克隆完成：副标题是远端地址，正文是克隆到的位置。
    ///
    /// - Parameter clone: 刚完成的克隆。
    func postCloneFinished(_ clone: RepositoryClone) {
        let destination = Self.displayedDestination(clone.destination)

        post(
            title: AppLocalization.text("clone.notification.title"),
            subtitle: Self.displayedRemote(clone.url),
            body: AppLocalization.text("clone.notification.body", destination)
        )
    }

    /// 自动归档完成：副标题是归档了几个分支，没有正文。
    ///
    /// - Parameter count: 归档的分支数。
    func postBranchesArchived(count: Int) {
        post(
            title: AppLocalization.text("review.archived.notification"),
            subtitle: count == 1
                ? AppLocalization.text("review.archived.one")
                : AppLocalization.text("review.archived.many", count)
        )
    }

    /// 启动时申请角标、声音与提醒的授权，带 provisional：系统不询问，先给暂时的授权。
    func requestAuthorization() {
        guard let center else {
            return
        }

        Task {
            _ = try? await center.requestAuthorization(options: [.badge, .sound, .alert, .provisional])
        }
    }

    /// App 在前台时同样显示横幅，并留在通知中心；点通知只激活 App。
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    /// 有授权时立即发送，不带声音与角标；没有授权或出错时不发。
    private func post(title: String, subtitle: String, body: String? = nil) {
        guard let center else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle

        if let body {
            content.body = body
        }

        // 每条通知用新的标识，不会替换之前的通知
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        Task {
            // 暂时的授权同样可以发送
            let status = await center.notificationSettings().authorizationStatus

            guard status == .authorized || status == .provisional else {
                return
            }

            try? await center.add(request)
        }
    }
}
