import Foundation
import Observation
import SpookyKit

/// 最近打开的本机与服务器仓库及其当前可用状态；无效记录仍保留供重试。
@MainActor
@Observable
final class RecentRepositories {
    /// 按最近使用顺序排列的仓库位置。
    private(set) var locations: [RepositoryLocation]

    /// 最近一次校验失败的路径。
    private(set) var unavailable: Set<RepositoryLocation> = []

    /// 当前正在校验的记录。
    private(set) var checking: Set<RepositoryLocation> = []

    /// 存储仅包含主机别名和路径，不包含仓库内容或凭据。
    private let defaults: UserDefaults

    /// 记录校验任务。
    private var validationTask: Task<Void, Never>? = nil

    /// 隔离持久化域，测试使用独立的临时 suite。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: "recentRepositories"),
            let saved = try? JSONDecoder().decode([RepositoryLocation].self, from: data)
        {
            locations = saved
        } else {
            // 保留 M1 的本机记录，迁移时不触发网络连接或删除失效路径。
            locations = (defaults.stringArray(forKey: "recentRepositoryPaths") ?? [])
                .map { .local(path: $0) }
        }
    }

    /// 成功打开后前移记录并去重，不因失效而删除其他路径。
    func remember(_ location: RepositoryLocation) {
        locations.removeAll { $0 == location }
        locations.insert(location, at: 0)
        unavailable.remove(location)
        defaults.set(try? JSONEncoder().encode(locations), forKey: "recentRepositories")
    }

    /// 标记打开失败的既有记录，仍允许用户再次打开。
    func markUnavailable(_ location: RepositoryLocation) {
        guard locations.contains(location) else {
            return
        }

        unavailable.insert(location)
    }

    /// 退出时停止后台校验；返回被取消的任务，调用方等待它回收子进程。
    func stopValidation() -> Task<Void, Never>? {
        let task = validationTask
        task?.cancel()
        validationTask = nil
        checking = []
        return task
    }

    /// 管理页只检查本机记录；服务器记录由用户打开时体检，避免后台认证。
    func validate() {
        validationTask?.cancel()
        let locations = locations.filter { $0.host == nil }
        checking = Set(locations)

        validationTask = Task { [weak self] in
            for location in locations {
                do {
                    _ = try await GitRunner(location: location).openLocalRepository()

                    guard !Task.isCancelled else {
                        return
                    }

                    self?.unavailable.remove(location)
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    self?.unavailable.insert(location)
                }

                self?.checking.remove(location)
            }
        }
    }
}
