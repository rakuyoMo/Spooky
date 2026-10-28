import Foundation
import Synchronization

// MARK: - TrashedItem

/// 移进废纸篓的一项：原来的位置与它在废纸篓里的位置，撤销时据此移回原处。
public struct TrashedItem: Sendable, Equatable {
    /// 原来的绝对路径，在工作区所在的机器上。
    public let path: String

    /// 在废纸篓里的绝对路径；废纸篓命令不报告位置时为 nil，这一项不能由 Spooky 移回。
    public let location: String?

    /// 记下移进废纸篓的一项。
    ///
    /// - Parameters:
    ///   - path: 原来的绝对路径。
    ///   - location: 在废纸篓里的绝对路径；不知道时为 nil。
    public init(path: String, location: String?) {
        self.path = path
        self.location = location
    }
}

// MARK: - FileRemoval

/// 从工作区删除文件的方式。
public enum FileRemoval: Sendable {
    /// 移进工作区所在机器的废纸篓。
    case trash

    /// 永久删除；服务器没有可用的废纸篓、用户确认后才使用。
    case permanent
}

// MARK: - TrashLog

/// 一次写操作里移进废纸篓的项，按移进的先后排列；撤销记录经任务本地值收集，撤销时据此移回。
public final class TrashLog: Sendable {
    /// 当前写操作的记录；不在收集时为 nil。
    @TaskLocal
    public static var current: TrashLog?

    /// 已记下的项。
    private let storage = Mutex<[TrashedItem]>([])

    /// 按移进废纸篓的先后排列的全部项。
    public var items: [TrashedItem] {
        storage.withLock { $0 }
    }

    /// 创建空的记录。
    public init() { }

    /// 记下新移进废纸篓的项。
    func append(_ items: [TrashedItem]) {
        storage.withLock { $0 += items }
    }
}

// MARK: - Trash

extension RepositoryFiles {
    /// 把文件或目录移进工作区所在机器的废纸篓，并记进当前写操作的 ``TrashLog``。
    ///
    /// 服务器上使用连接体检找到的程序，远端路径只作为参数交给 B 上的程序。
    ///
    /// - Parameter paths: 绝对路径；目录连同其中的内容一起移进废纸篓。
    /// - Returns: 各项在废纸篓里的位置，与 `paths` 一一对应。
    /// - Throws: 服务器没有可用的废纸篓时抛出 ``RepositoryFileError/trashUnavailable``。
    @discardableResult
    func moveToTrash(_ paths: [String]) async throws -> [TrashedItem] {
        guard !paths.isEmpty else { return [] }

        let items: [TrashedItem] =
            if let remote = runner.remote {
                try await remote.moveToTrash(paths)
            } else {
                try paths.map { path in
                    // trashItem 只接受 NSURL 的输出参数
                    // swiftlint:disable:next legacy_objc_type
                    var trashed: NSURL? = nil
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashed)

                    return TrashedItem(path: path, location: trashed?.path)
                }
            }

        TrashLog.current?.append(items)
        return items
    }

    /// 把废纸篓里的项移回原处，缺少的上级目录一并建出。
    ///
    /// 先核对每一项都还在废纸篓里、原位置空着，任何一项不满足时一项也不移动。
    ///
    /// - Throws: 有的项位置不明、已不在废纸篓里或原位置已被占用时抛出 ``RepositoryFileError/trashedItemsUnavailable``。
    func putBack(_ items: [TrashedItem]) async throws {
        let moves = items.compactMap { item in item.location.map { (from: $0, to: item.path) } }

        guard moves.count == items.count else {
            throw RepositoryFileError.trashedItemsUnavailable
        }

        guard !moves.isEmpty else { return }

        if let remote = runner.remote {
            try await remote.putBack(moves)
            return
        }

        // 符号链接本身就是要移回的项，按链接自身判断是否存在
        let exists = { (path: String) in (try? FileManager.default.attributesOfItem(atPath: path)) != nil }

        guard moves.allSatisfy({ exists($0.from) && !exists($0.to) }) else {
            throw RepositoryFileError.trashedItemsUnavailable
        }

        for move in moves {
            let destination = URL(fileURLWithPath: move.to)

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: URL(fileURLWithPath: move.from), to: destination)
        }
    }
}
