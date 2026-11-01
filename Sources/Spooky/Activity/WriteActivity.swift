import Foundation
import SpookyKit

// MARK: - ActivityEvent

/// 写操作执行期间交给 Activity 的事件，与 Git 输出走同一个流，先后不乱。
enum ActivityEvent: Sendable {
    /// 追加到当前记录的输出。
    case output(GitOutputEvent)

    /// 当前记录换成这个状态键。
    case state(String)

    /// 开始连接下一个对象，另起一条 Remote 记录。
    case next(ActivityTarget)
}

// MARK: - ActivityRecording

/// 写操作执行期间送出 Activity 事件的入口，由 `performGit` 在执行动作时设置。
///
/// 动作里的回调（获取到下一个远端、同步到下一步）与 Git 输出在同一个任务里先后发生，经它送出的事件因此排在对应的输出之间。
enum ActivityRecording {
    /// 当前写操作的入口；不在写操作里时为 nil。
    @TaskLocal
    static var send: (@Sendable (ActivityEvent) -> Void)? = nil

    /// 获取全部远端时，每开始获取一个远端就另起一条记录。
    static let fetching: @Sendable (String) -> Void = { remote in
        send?(.next(.fetch(remote)))
    }
}

// MARK: - WriteActivity

/// 一次写操作的 Activity 记录：一般只有一条；获取全部远端时每个远端一条，同步的拉取与推送各一条。
@MainActor
final class WriteActivity {
    /// 记录所在的列表。
    private let activities: RepositoryActivities

    /// 写操作所在的仓库。
    private let repository: RepositoryLocation

    /// 已本地化的操作名称，另起的记录沿用。
    private let title: String

    /// 正在写入的记录；写操作结束时由 `finish()` 收尾最后一条。
    private(set) var current: RepositoryActivity

    /// 写操作的取消入口，另起记录时交给新的一条。
    var cancel: (() -> Void)? = nil {
        didSet { current.cancel = cancel }
    }

    /// 建立第一条记录并插进列表。
    ///
    /// - Parameters:
    ///   - activities: 记录所在的列表。
    ///   - repository: 写操作所在的仓库。
    ///   - title: 已本地化的操作名称。
    ///   - target: 连接的对象；不连接远端的写操作为 nil，记在 Repository 页。
    init(
        activities: RepositoryActivities,
        repository: RepositoryLocation,
        title: String,
        target: ActivityTarget?
    ) {
        self.activities = activities
        self.repository = repository
        self.title = title
        current = RepositoryActivity(repository: repository, title: title, target: target)
        activities.insert(current)
    }

    /// 按事件追加输出、换状态或另起一条记录。
    func receive(_ event: ActivityEvent) {
        switch event {
        case .output(let output):
            current.append(output)

        case .state(let state):
            current.state = state

        case .next(let target):
            begin(target)
        }
    }

    /// 输出收完后结束最后一条记录；Remote 记录这时写进本机。
    func finish() {
        activities.finish(current)
    }
}

// MARK: - Private

extension WriteActivity {
    /// 开始连接下一个对象：当前记录还没有远端名时补上，否则把它记为完成，另起一条。
    ///
    /// 记在 Repository 页的写操作（如储藏后重试的同步）不分条；与当前记录相同的对象不另起。
    private func begin(_ target: ActivityTarget) {
        guard current.kind == .remote, current.target != target else {
            return
        }

        guard current.target?.remote != nil else {
            current.target = target
            return
        }

        current.state = "activity.finished"
        activities.finish(current)

        current = RepositoryActivity(repository: repository, title: title, target: target)
        current.cancel = cancel
        activities.insert(current)
    }
}
