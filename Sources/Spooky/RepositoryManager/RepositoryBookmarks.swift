import Foundation
import Observation
import SpookyKit

// MARK: - RepositoryBookmarks

/// 仓库管理的书签：本机与服务器仓库、文件夹、手动顺序与最近打开时间，以及哪些仓库已失效。
///
/// 全部窗口共用一份；失效的书签只做标记，从不自动删除。
@MainActor
@Observable
final class RepositoryBookmarks {
    /// 书签树在偏好里的键。
    static let key = "repositoryBookmarks"

    /// 最外层的书签，按手动顺序排列。
    private(set) var items: [Bookmark]

    /// 最近一次检查或打开失败的仓库位置。
    private(set) var missing: Set<RepositoryLocation> = []

    /// 存储只有名称、位置、顺序与打开时间，不含仓库内容或凭据。
    private let defaults: UserDefaults

    /// 本机仓库的后台检查。
    private var validationTask: Task<Void, Never>? = nil

    /// 读取保存的书签；还没有书签时把旧版本的最近记录迁移过来，迁移不连接服务器，也不删除失效的记录。
    ///
    /// - Parameter defaults: 偏好域，测试使用独立的临时域。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.key) {
            items = (try? JSONDecoder().decode([Bookmark].self, from: data)) ?? []
            return
        }

        items = Self.legacyLocations(in: defaults).map(Bookmark.repository)

        // 没有旧记录时等第一次修改再写入
        guard defaults.object(forKey: Self.legacyKey) != nil || defaults.object(forKey: Self.legacyPathsKey) != nil else {
            return
        }

        // 迁移结果立即写入新键，旧键随之删除，之后不再重复迁移。
        save()
        defaults.removeObject(forKey: Self.legacyKey)
        defaults.removeObject(forKey: Self.legacyPathsKey)
    }
}

// MARK: - Queries

extension RepositoryBookmarks {
    /// 按树的先序排列的全部仓库书签。
    var repositories: [Bookmark] { items.repositories }

    /// 打开过的仓库书签，最近打开的在前。
    var recentlyOpened: [Bookmark] {
        repositories
            .filter { $0.lastOpened != nil }
            .sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
    }

    /// 找到指定的书签。
    func bookmark(_ id: Bookmark.ID) -> Bookmark? {
        items.bookmark(id)
    }

    /// 指向某个仓库位置的书签。
    func bookmark(for location: RepositoryLocation) -> Bookmark? {
        repositories.first { $0.location == location }
    }

    /// 书签所在的文件夹；在最外层或找不到时为 nil。
    func parent(of id: Bookmark.ID) -> Bookmark.ID? {
        items.parent(of: id) ?? nil
    }

    /// 仓库是否已失效。
    func isMissing(_ location: RepositoryLocation) -> Bool {
        missing.contains(location)
    }
}

// MARK: - Validity

extension RepositoryBookmarks {
    /// 标记打开或检查失败的仓库，书签仍保留供重试。
    func markMissing(_ location: RepositoryLocation) {
        guard bookmark(for: location) != nil else {
            return
        }

        missing.insert(location)
    }

    /// 仓库重新可用时去掉失效标记。
    func markAvailable(_ location: RepositoryLocation) {
        missing.remove(location)
    }

    /// 检查本机仓库是否仍可打开；服务器仓库只在用户选中或打开时检查，不在后台批量连接。
    func validate() {
        validationTask?.cancel()
        let locations = repositories.compactMap(\.location).filter { $0.host == nil }

        validationTask = Task { [weak self] in
            for location in locations {
                let available: Bool

                do {
                    _ = try await GitRunner(location: location).openLocalRepository()
                    available = true
                } catch {
                    available = false
                }

                guard !Task.isCancelled else {
                    return
                }

                if available {
                    self?.markAvailable(location)
                } else {
                    self?.markMissing(location)
                }
            }
        }
    }

    /// 退出时停止后台检查；返回被取消的任务，调用方等待它回收子进程。
    func stopValidation() -> Task<Void, Never>? {
        let task = validationTask
        task?.cancel()
        validationTask = nil
        return task
    }
}

// MARK: - Persistence

extension RepositoryBookmarks {
    /// 旧版本最近记录的键：位置列表，最近使用的在前。
    private static let legacyKey = "recentRepositories"

    /// 更早版本最近记录的键：本机路径列表。
    private static let legacyPathsKey = "recentRepositoryPaths"

    /// 旧版本的最近记录：先取带服务器位置的新格式，没有时取更早版本的本机路径。
    private static func legacyLocations(in defaults: UserDefaults) -> [RepositoryLocation] {
        if
            let data = defaults.data(forKey: legacyKey),
            let saved = try? JSONDecoder().decode([RepositoryLocation].self, from: data)
        {
            return saved
        }

        return (defaults.stringArray(forKey: legacyPathsKey) ?? []).map { .local(path: $0) }
    }

    /// 每次修改后整树写回偏好。
    func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.key)
    }

    /// 改写书签树并写回偏好。
    func change(_ edit: (inout [Bookmark]) -> Void) {
        edit(&items)
        save()

        // 已删除的仓库不再保留失效标记
        let locations = Set(repositories.compactMap(\.location))
        missing.formIntersection(locations)
    }
}
