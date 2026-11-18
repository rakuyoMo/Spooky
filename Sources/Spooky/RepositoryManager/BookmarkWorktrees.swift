import Foundation
import SpookyKit

// MARK: - BookmarkWorktrees

/// 仓库管理列表里各仓库的工作树：列出工作树时在后台读取列表里看得到的仓库，只留这个仓库之外的工作树；
/// 展开了工作树的仓库书签记在偏好里，下次读到时照样展开。
///
/// 读取都不询问用户，连不上或读取失败的仓库没有结果。展开的记录不登记进 `DeveloperPreferences.dataKeys`，Reset User Defaults 后回到默认。
@MainActor
final class BookmarkWorktrees {
    /// 读取一个仓库的全部工作树。
    typealias Reader = @MainActor (RepositoryLocation) async throws -> [Worktree]

    /// 偏好键：展开了工作树的仓库书签，值是书签身份的字符串。
    static let expandedKey = "repositoryListExpandedWorktrees"

    /// 各仓库读到的工作树：这个仓库之外的，按名称排列；还没读完与读取失败的仓库不在其中。
    private(set) var lists: [RepositoryLocation: [Worktree]] = [:]

    /// 进行中的读取。
    private(set) var tasks: [RepositoryLocation: Task<Void, Never>] = [:]

    /// 读取一个仓库的全部工作树；测试换成假实现。
    var reader: Reader = BookmarkWorktrees.read

    /// 一个仓库读完后调用，读取失败同样调用；参数是那个仓库。
    var onLoad: ((RepositoryLocation) -> Void)? = nil

    /// 每次读取结束后调用，被取消的读取同样调用；服务器仓库据此交还为读取建立的连接。
    var onFinish: ((RepositoryLocation) -> Void)? = nil

    /// 记展开状态的偏好。
    private let defaults: UserDefaults

    /// 创建列表的工作树状态，不立即读取。
    ///
    /// - Parameter defaults: 记展开状态的偏好，测试使用独立的域。
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 离开仓库管理时停止进行中的读取。
    isolated deinit {
        for task in tasks.values {
            task.cancel()
        }
    }

    /// 读取一个仓库的全部工作树：本机仓库直接读；服务器仓库按打开检查经它的主连接读。
    ///
    /// - Parameter location: 仓库的位置。
    static func read(_ location: RepositoryLocation) async throws -> [Worktree] {
        let runner =
            if location.host == nil {
                GitRunner(location: location)
            } else {
                try await RepositoryManagerController.openedRunner(for: location)
            }

        return try await RepositoryWorktrees(runner: runner).list()
    }

    /// 读取还没有结果的仓库：正在读的不重复读，读取失败的下次再读。
    ///
    /// - Parameter locations: 列表里看得到的仓库。
    func load(_ locations: [RepositoryLocation]) {
        let reader = reader
        let finish = onFinish

        for location in locations where lists[location] == nil && tasks[location] == nil {
            tasks[location] = Task { [weak self] in
                // 不是用户发起的读取：服务器仓库只用已存的凭据，取不到按读取失败处理
                let worktrees = try? await RemoteCallbackRequest.$allowsInteraction.withValue(false) {
                    try await reader(location)
                }

                finish?(location)

                guard let self, !Task.isCancelled else {
                    return
                }

                tasks[location] = nil
                lists[location] = worktrees.map { RepositoryWorktreeState.others(of: $0) }
                onLoad?(location)
            }
        }
    }

    /// 不再列出工作树：停止进行中的读取，丢掉读到的结果。
    func reset() {
        for task in tasks.values {
            task.cancel()
        }

        tasks = [:]
        lists = [:]
    }

    /// 书签上次是否展开着工作树。
    func isExpanded(_ id: Bookmark.ID) -> Bool {
        defaults.stringArray(forKey: Self.expandedKey)?.contains(id.uuidString) ?? false
    }

    /// 记下书签展开或收起了工作树；没有变化时不写偏好。
    ///
    /// - Parameters:
    ///   - id: 仓库书签。
    ///   - expanded: 是否展开着。
    func setExpanded(_ id: Bookmark.ID, _ expanded: Bool) {
        var ids = Set(defaults.stringArray(forKey: Self.expandedKey) ?? [])

        let changed = expanded
            ? ids.insert(id.uuidString).inserted
            : ids.remove(id.uuidString) != nil

        guard changed else {
            return
        }

        defaults.set(ids.sorted(), forKey: Self.expandedKey)
    }
}
