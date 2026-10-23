import Foundation
import Observation
import SpookyKit

// MARK: - RepositoryActivity

/// 一次远程 Git 操作的日志和状态，完成后仍可在 Activity 查看。
@MainActor
@Observable
final class RepositoryActivity: Identifiable {
    /// 每条输出流最多保留的字节数，长时间运行的进度输出只保留最近部分。
    static let streamLimit = 512 * 1024

    /// 活动的稳定身份。
    let id = UUID()

    /// 带主机前缀的仓库身份。
    let repository: RepositoryLocation

    /// 已本地化的操作名称。
    let title: String

    /// 开始时间。
    let started = Date()

    /// 完成、失败或取消的本地化状态键。
    var state = "activity.running"

    /// 正在运行时提供取消入口，结束后清空。
    var cancel: (() -> Void)?

    /// stdout 与 stderr 分别积累字节，避免 UTF-8 跨块乱码。
    private(set) var stdout = Data()

    /// 原始 stderr 进度。
    private(set) var stderr = Data()

    /// 较早的输出因超过保留上限被丢弃。
    private(set) var truncated = false

    /// 控制字符 CR 显示为换行，原始字节仍保留在各自缓冲区。
    var log: String {
        [
            truncated ? AppLocalization.text("activity.truncated") : "",
            String(decoding: stdout, as: UTF8.self),
            String(decoding: stderr, as: UTF8.self),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    }

    /// 建立一个仓库操作记录。
    init(repository: RepositoryLocation, title: String) {
        self.repository = repository
        self.title = title
    }

    /// 执行器已经脱敏，此处只按管道追加原始数据，超出上限时丢弃最早的字节。
    func append(_ output: GitOutputEvent) {
        switch output {
        case .standardOutput(let data):
            stdout.append(data)

            if stdout.count > Self.streamLimit {
                stdout.removeFirst(stdout.count - Self.streamLimit)
                truncated = true
            }

        case .standardError(let data):
            stderr.append(data)

            if stderr.count > Self.streamLimit {
                stderr.removeFirst(stderr.count - Self.streamLimit)
                truncated = true
            }
        }
    }
}

// MARK: - RepositoryActivities

/// Activity 跨窗口保留记录，关闭一个仓库不会抹掉已完成日志。
@MainActor
@Observable
final class RepositoryActivities {
    /// App 内唯一活动列表。
    static let shared = RepositoryActivities()

    /// 保留的活动数量上限，超出时先淘汰最早的已完成活动。
    static let limit = 200

    /// 最新活动排在最前面。
    var items: [RepositoryActivity] = []

    /// 新活动插到最前；超过上限时移除最早的已完成活动，运行中的活动始终保留。
    func insert(_ activity: RepositoryActivity) {
        items.insert(activity, at: 0)

        // 新活动此时尚未登记取消入口，淘汰只在更早的记录中查找。
        while items.count > Self.limit, let index = items.dropFirst().lastIndex(where: { $0.cancel == nil }) {
            items.remove(at: index)
        }
    }

    /// 只清理已完成活动，运行中的任务仍保留取消入口。
    func clearCompleted() {
        items.removeAll { $0.cancel == nil }
    }
}

// MARK: - RepositoryWriteLocks

/// 应用内每个仓库同一时间只允许一个明确的写操作；所有窗口的写入口都据此禁用。
@MainActor
@Observable
final class RepositoryWriteLocks {
    /// 应用内唯一的写操作登记。
    static let shared = RepositoryWriteLocks()

    /// 正在写入的仓库。
    private(set) var active: Set<RepositoryLocation> = []

    /// 登记写操作；同一仓库已有写操作时拒绝。
    func acquire(_ location: RepositoryLocation) -> Bool {
        active.insert(location).inserted
    }

    /// 写操作结束后释放登记。
    func release(_ location: RepositoryLocation) {
        active.remove(location)
    }

    /// 仓库是否正在写入。
    func contains(_ location: RepositoryLocation) -> Bool {
        active.contains(location)
    }
}
