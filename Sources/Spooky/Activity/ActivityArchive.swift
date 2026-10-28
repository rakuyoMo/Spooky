import Foundation
import SpookyKit

// MARK: - ActivityRecord

/// 保存到本机的一条已结束记录。
struct ActivityRecord: Codable, Sendable {
    /// 记录的身份，也是文件名。
    let id: UUID

    /// 记录所在的页。
    let kind: ActivityKind

    /// 带主机前缀的仓库身份。
    let repository: RepositoryLocation

    /// 记录时已本地化的操作名称。
    let title: String

    /// 开始时间。
    let started: Date

    /// 完成、失败或取消的本地化状态键。
    let state: String

    /// 整理后的标准输出。
    let stdout: Data

    /// 整理后的标准错误。
    let stderr: Data
}

// MARK: - ActivityArchive

/// Remote 记录在本机的保存位置：每条记录一个 JSON 文件，以记录的 id 命名。
///
/// 写入、读取与删除失败都不提示；读不了的文件跳过。
struct ActivityArchive: Sendable {
    /// 保存记录的目录，第一次写入时创建。
    let directory: URL

    /// 一条记录的文件位置。
    func url(of id: UUID) -> URL {
        directory.appending(path: id.uuidString + ".json")
    }

    /// 写入一条记录。
    func save(_ record: ActivityRecord) {
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(of: record.id), options: .atomic)
    }

    /// 删掉一条记录的文件。
    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(of: id))
    }

    /// 读回开始于 `cutoff` 之后的记录，按开始时间从新到旧排列；更早的记录连文件一起删掉。
    func load(since cutoff: Date) -> [ActivityRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var records: [ActivityRecord] = []

        for file in files where file.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: file),
                let record = try? JSONDecoder().decode(ActivityRecord.self, from: data)
            else { continue }

            if record.started < cutoff {
                try? FileManager.default.removeItem(at: file)
                continue
            }

            records.append(record)
        }

        return records.sorted { $0.started > $1.started }
    }
}
