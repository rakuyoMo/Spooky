import Foundation
import Synchronization

// MARK: - PushResult

/// 推送一个远端引用的结果，由 `push --porcelain` 每行开头的标志得出。
public enum PushResult: Sendable, Equatable {
    /// 远端原来没有这个引用，推送新建了它（标志 `*`）。
    case created

    /// 远端原来就有这个引用，推送把它改指新的对象：快进（标志是空格）或强推（`+`）。
    case updated

    /// 远端的引用已经指向要推的对象，推送没有改动它（`=`）。
    case upToDate
}

// MARK: - RemoteReferenceUpdate

extension RemoteReferenceUpdate {
    /// 推送这个引用的结果；删除（`-`）与被拒（`!`）为 nil。
    public var pushResult: PushResult? {
        switch flag {
        case "*": .created
        case " ", "+": .updated
        case "=": .upToDate
        default: nil
        }
    }
}

// MARK: - PushLog

/// 一次写操作里推送分支与标签的逐条结果，按推送的先后排列；撤销记录经任务本地值收集，
/// 撤销发布时据此判断推送是否新建了远端引用，不必为此另外连接远端。
public final class PushLog: Sendable {
    /// 当前写操作的记录；不在收集时为 nil。
    @TaskLocal
    public static var current: PushLog?

    /// 已记下的结果与推送到的远端名。
    private let storage = Mutex<[(remote: String, update: RemoteReferenceUpdate)]>([])

    /// 创建空的记录。
    public init() { }

    /// 最近一次推送到 `remote` 时 `reference` 的结果；这次写操作没有推送过它时为 nil。
    ///
    /// - Parameters:
    ///   - reference: 远端上的完整引用名，如 `refs/heads/main`。
    ///   - remote: 远端名。
    public func result(of reference: String, on remote: String) -> PushResult? {
        storage.withLock { entries in
            entries.last { $0.remote == remote && $0.update.reference == reference }?.update.pushResult
        }
    }

    /// 记下一次推送的逐条结果。
    func append(_ updates: [RemoteReferenceUpdate], on remote: String) {
        storage.withLock { $0 += updates.map { (remote, $0) } }
    }
}
