import Foundation
import Synchronization

// MARK: - EditingCopy

/// 交给编辑器的服务器文件副本：放在会话缓存里，记着最近一次与仓库所在机器一致的内容。
///
/// 编辑器保存副本后写回原文件；写回前比对原文件的当前内容，原文件已在别处改过时不覆盖，交给用户决定。
public final class EditingCopy: Sendable {
    /// 原文件在仓库所在机器上的绝对路径。
    public let path: String

    /// 本机副本，交给编辑器打开。
    public let file: URL

    /// 最近一次取回或写回后，原文件应有的内容。
    private let base: Mutex<Data>

    /// 最近一次与原文件一致的内容。
    var baseContent: Data {
        base.withLock { $0 }
    }

    /// 记下取回的副本与当时的内容。
    init(path: String, file: URL, base: Data) {
        self.path = path
        self.file = file
        self.base = Mutex(base)
    }

    /// 写回或覆盖后更新一致的内容。
    func update(_ content: Data) {
        base.withLock { $0 = content }
    }
}

// MARK: - Editing Copies

extension RepositoryFileCache {
    /// 把仓库所在机器上的文件取到缓存，作为交给编辑器的副本。
    ///
    /// - Parameter path: 文件在仓库所在机器上的路径；相对路径按工作区根目录解析，如 `.gitignore`。
    public func editingCopy(of path: String) async throws -> EditingCopy {
        let absolute = path.hasPrefix("/") ? path : runner.location.path + "/" + path

        guard let data = try await RepositoryFiles(runner: runner).read([absolute])[absolute] else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        return EditingCopy(path: absolute, file: try store(data, named: absolute), base: data)
    }

    /// 编辑器保存后把副本写回原文件。
    ///
    /// 核对与写入在同一个仓库写锁里完成：原文件仍是最近一次一致的内容才写入；
    /// 原文件已在别处改过时抛出 ``ExternalToolError/fileChanged``，用户确认覆盖后以 `overwrite` 重试。
    ///
    /// - Parameters:
    ///   - copy: 编辑器打开的副本。
    ///   - overwrite: 原文件已在别处改过时仍然覆盖。
    /// - Returns: 是否写入了原文件；副本与原文件内容相同时不写入。
    @discardableResult
    public func writeBack(_ copy: EditingCopy, overwrite: Bool = false) async throws -> Bool {
        let content = try Data(contentsOf: copy.file)

        guard content != copy.baseContent else {
            return false
        }

        return try await runner.writeTransaction {
            let service = RepositoryFiles(runner: runner)
            let current = try await service.read([copy.path])[copy.path]

            guard overwrite || current == copy.baseContent else {
                throw ExternalToolError.fileChanged
            }

            try await service.write(content, to: copy.path)
            copy.update(content)
            return true
        }
    }
}
