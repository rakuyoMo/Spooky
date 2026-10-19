import Foundation
import Observation
import SpookyKit

/// 一次远程 Git 操作的日志和状态，完成后仍可在 Activity 查看。
@MainActor
@Observable
final class RepositoryActivity: Identifiable {
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

    /// 建立一个仓库操作记录。
    init(repository: RepositoryLocation, title: String) {
        self.repository = repository
        self.title = title
    }

    /// 控制字符 CR 显示为换行，原始字节仍保留在各自缓冲区。
    var log: String {
        [String(decoding: stdout, as: UTF8.self), String(decoding: stderr, as: UTF8.self)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// 执行器已经脱敏，此处只按管道追加原始数据。
    func append(_ output: GitOutputEvent) {
        switch output {
        case .standardOutput(let data): stdout.append(data)
        case .standardError(let data): stderr.append(data)
        }
    }
}

/// Activity 跨窗口保留记录，关闭一个仓库不会抹掉已完成日志。
@MainActor
@Observable
final class RepositoryActivities {
    /// App 内唯一活动列表。
    static let shared = RepositoryActivities()

    /// 最新活动排在最前面。
    var items: [RepositoryActivity] = []

    /// 只清理已完成活动，运行中的任务仍保留取消入口。
    func clearCompleted() {
        items.removeAll { $0.cancel == nil }
    }
}
