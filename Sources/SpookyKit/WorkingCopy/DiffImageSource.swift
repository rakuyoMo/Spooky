import Foundation

// MARK: - DiffImageSource

/// 图片 Diff 两侧的原始字节：对象库里的版本按对象哈希读取，工作区版本读取工作区所在机器上的文件。
///
/// 服务器仓库的对象经 Git 输出取回，工作区文件经 SFTP 取回；单侧内容受 256 MiB 的读取上限约束。
public struct DiffImageSource: Sendable {
    /// 本机或服务器执行器。
    public let runner: GitRunner

    /// 创建读取服务，不立即访问磁盘或网络。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 读取一个文件段两侧的内容。
    ///
    /// - Parameters:
    ///   - file: 带 `index` 头的文件段，新增与删除的一侧为空。
    ///   - path: 仓库内的相对路径，读取工作区版本时使用。
    ///   - newFromWorkingTree: 新的一侧是工作区文件，即工作区相对暂存区的 Diff。
    /// - Returns: 旧、新两侧的字节；不存在的一侧为空。
    public func contents(
        of file: DiffFile,
        path: String,
        newFromWorkingTree: Bool
    ) async throws -> (old: Data?, new: Data?) {
        let ids = file.objectIDs
        var old: Data?

        if file.addedMode == nil, let id = ids.old {
            old = try await blob(id)
        }

        guard file.deletedMode == nil else {
            return (old, nil)
        }

        guard newFromWorkingTree else {
            guard let id = ids.new else {
                return (old, nil)
            }

            return (old, try await blob(id))
        }

        // 工作区路径只作为数据交给文件访问层，服务器上的路径不进入本机文件 API
        let absolute = runner.location.path + "/" + path
        let new = try await RepositoryFiles(runner: runner).read([absolute])[absolute]
        return (old, new)
    }

    /// 对象内容只由哈希决定，按哈希复用。
    private func blob(_ id: String) async throws -> Data {
        guard GitObjectID.isValid(id) else { throw RepositoryReadError.invalidQuery }
        return try await runner.immutableRun(["cat-file", "blob", id])
    }
}
