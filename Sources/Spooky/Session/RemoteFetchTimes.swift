import Foundation
import SpookyKit

// MARK: - RemoteFetchTimes

/// 各远端上次获取的时刻，跨重启保留：自动获取据此逐个判断远端是否到期。
///
/// 记的是获取尝试：手动与自动、成功与失败的获取在开始获取这个远端时都会更新。
@MainActor
enum RemoteFetchTimes {
    /// 偏好键；值按仓库的显示路径、再按远端名记 Unix 秒。
    static let key = "remoteLastFetch"

    /// 这个远端上次获取的时刻；从没获取过时为 nil。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - repository: 远端所在的仓库。
    ///   - defaults: 读取的偏好，测试使用独立的域。
    static func lastFetch(
        of remote: String,
        in repository: RepositoryLocation,
        defaults: UserDefaults = .standard
    ) -> Date? {
        let times = defaults.dictionary(forKey: key)?[repository.displayPath] as? [String: Double]
        return times?[remote].map(Date.init(timeIntervalSince1970:))
    }

    /// 记下这个远端开始获取的时刻。
    ///
    /// - Parameters:
    ///   - remote: 远端名。
    ///   - repository: 远端所在的仓库。
    ///   - date: 开始获取的时刻。
    ///   - defaults: 写入的偏好，测试使用独立的域。
    static func record(
        _ remote: String,
        in repository: RepositoryLocation,
        at date: Date,
        defaults: UserDefaults = .standard
    ) {
        var all = defaults.dictionary(forKey: key) ?? [:]
        var times = all[repository.displayPath] as? [String: Double] ?? [:]

        times[remote] = date.timeIntervalSince1970
        all[repository.displayPath] = times
        defaults.set(all, forKey: key)
    }
}
