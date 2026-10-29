import CryptoKit
import Foundation
import SpookyKit

// MARK: - ActivityBaselineArchive

/// 读取增减计数的基准在本机的保存位置：每个仓库一个 JSON 文件，以仓库身份的 SHA-256 命名。
///
/// 基准不随书签删除，也不过期；写入与读取失败都不提示，没有文件或读不了时按没有基准算。
struct ActivityBaselineArchive: Sendable {
    /// 保存基准的目录，第一次写入时创建。
    let directory: URL

    /// 一个仓库的基准文件位置，文件名是带主机前缀的仓库身份的 SHA-256。
    func url(of repository: RepositoryLocation) -> URL {
        let name = SHA256.hash(data: Data(repository.displayPath.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return directory.appending(path: name + ".json")
    }

    /// 写入一个仓库的全部基准，替换原来的文件。
    ///
    /// - Parameters:
    ///   - inventories: 各类清单，每项是 “身份 → 比较值的摘要”。
    ///   - repository: 基准所属的仓库。
    func save(_ inventories: [ActivityInventory: [String: String]], of repository: RepositoryLocation) {
        let baseline = SavedBaseline(repository: repository, inventories: inventories)

        guard let data = try? JSONEncoder().encode(baseline) else {
            return
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 整个文件一次换上，退出时写到一半也不会留下残缺的文件
        try? data.write(to: url(of: repository), options: .atomic)
    }

    /// 读回一个仓库的全部基准；没有文件、读不了或文件里写的是别的仓库时为空。
    func load(_ repository: RepositoryLocation) -> [ActivityInventory: [String: String]] {
        guard
            let data = try? Data(contentsOf: url(of: repository)),
            let baseline = try? JSONDecoder().decode(SavedBaseline.self, from: data),
            baseline.repository == repository
        else { return [:] }

        return baseline.inventories
    }
}

// MARK: - SavedBaseline

/// 一个仓库保存在本机的基准。
private struct SavedBaseline: Codable {
    /// 带主机前缀的仓库身份；文件名只是它的摘要，读回时据此核对。
    let repository: RepositoryLocation

    /// 各类清单，每项是 “身份 → 比较值的摘要”。
    let inventories: [ActivityInventory: [String: String]]
}
