import Foundation

// MARK: - MergeToolFiles

/// 交给外部合并工具的四个本机文件：共同祖先、我方、对方，以及工具写入结果的文件。
///
/// 三方内容取自索引的 stage 1 / 2 / 3，结果文件的初值是工作区里带冲突标记的文件；
/// 工具退出后按结果文件的修改时间与内容判断是否产生了结果。
public struct MergeToolFiles: Sendable {
    /// 冲突文件在仓库内的路径。
    public let path: String

    /// 共同祖先版本；两侧各自新增同名文件时是空文件。
    public let base: URL

    /// 是否有共同祖先版本。
    public let hasBase: Bool

    /// 我方版本。
    public let local: URL

    /// 对方版本。
    public let remote: URL

    /// 工具写入合并结果的文件，与原文件同名。
    public let merged: URL

    /// 准备时工作区里的文件内容，写回前据此核对文件没有在别处改过；文件不在工作区时为 nil。
    let original: Data?

    /// 写进结果文件的初值。
    let preparedContent: Data

    /// 写好初值后结果文件的修改时间。
    let preparedDate: Date

    /// 工具产生的合并结果：结果文件的修改时间晚于准备时，或内容与初值不同；都没有变化时为 nil。
    public func result() throws -> Data? {
        let attributes = try FileManager.default.attributesOfItem(atPath: merged.path)
        let modified = attributes[.modificationDate] as? Date ?? preparedDate
        let content = try Data(contentsOf: merged)

        guard modified > preparedDate || content != preparedContent else {
            return nil
        }

        return content
    }
}

// MARK: - Merge Tool

extension ExternalToolFiles {
    /// 带版本标记的副本名：`<文件名>.<标记>.<扩展名>`，没有扩展名时标记放在最后。
    ///
    /// - Parameters:
    ///   - path: 文件在仓库内的路径，只取最后一段。
    ///   - marker: 版本标记，如 `LOCAL`。
    static func name(_ path: String, marker: String) -> String {
        let name = path.split(separator: "/").last.map(String.init) ?? path

        // 以点开头的文件名（如 .gitignore）整个当作主名
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return name + "." + marker
        }

        return name[..<dot] + "." + marker + name[dot...]
    }

    /// 为冲突文件准备合并工具的四个文件：三方版本经一次读取取到本机缓存，结果文件写入工作区的当前内容。
    ///
    /// 只支持两侧都是普通文件的冲突；删除与修改的冲突没有可合并的两侧，抛出 ``ConflictResolutionError/versionUnavailable``。
    ///
    /// - Parameter entry: 冲突文件的状态条目，带有三方 stage 的对象哈希。
    public func prepareMerge(_ entry: StatusEntry) async throws -> MergeToolFiles {
        guard
            let stages = entry.conflict,
            stages.hasRegularFilesOnBothSides,
            let ours = stages.ours,
            let theirs = stages.theirs
        else {
            throw ConflictResolutionError.versionUnavailable
        }

        // 三方对象与工作区文件互不依赖，并发读取
        let absolute = runner.location.path + "/" + entry.path

        async let baseData = contents(of: entry.path, at: .blob(stages.base))
        async let oursData = blob(ours)
        async let theirsData = blob(theirs)
        async let worktree = RepositoryFiles(runner: runner).read([absolute])[absolute]

        let original = try await worktree
        let prepared = original ?? Data()

        // 三方副本带上版本标记、保留扩展名，工具据此显示标题并选择语法着色
        let base = try cache.store(try await baseData ?? Data(), named: Self.name(entry.path, marker: "BASE"))
        let local = try cache.store(try await oursData, named: Self.name(entry.path, marker: "LOCAL"))
        let remote = try cache.store(try await theirsData, named: Self.name(entry.path, marker: "REMOTE"))
        let merged = try cache.store(prepared, named: entry.path)

        let attributes = try FileManager.default.attributesOfItem(atPath: merged.path)

        return MergeToolFiles(
            path: entry.path,
            base: base,
            hasBase: stages.base != nil,
            local: local,
            remote: remote,
            merged: merged,
            original: original,
            preparedContent: prepared,
            preparedDate: attributes[.modificationDate] as? Date ?? .distantPast
        )
    }
}

// MARK: - Merge Result

extension WorkingCopyOperations {
    /// 把合并工具的结果写回工作区并标记解决：先核对工作区文件仍是准备时的内容，再按需留下备份，写入后 `git add`。
    ///
    /// 核对、备份、写入与暂存在同一个仓库写锁里完成；服务器上的文件经 SFTP 读写。
    ///
    /// - Parameters:
    ///   - result: 合并工具写出的内容。
    ///   - files: 准备合并工具时的文件，带有当时工作区里的内容。
    ///   - keepBackup: 是否把被覆盖的工作区文件留作 `<文件>.orig`。
    ///   - overwrite: 工作区文件已在别处改过时仍然覆盖；为 false 时抛出 ``ExternalToolError/fileChanged``。
    public func applyMergeResult(
        _ result: Data,
        for files: MergeToolFiles,
        keepBackup: Bool,
        overwrite: Bool = false
    ) async throws {
        try await runner.writeTransaction {
            let service = RepositoryFiles(runner: runner)
            let absolute = runner.location.path + "/" + files.path
            let current = try await service.read([absolute])[absolute]

            guard overwrite || current == files.original else {
                throw ExternalToolError.fileChanged
            }

            // 备份的是这次写入覆盖掉的内容，通常是带冲突标记的文件
            if keepBackup, let current {
                try await service.write(current, to: absolute + ".orig")
            }

            try await service.write(result, to: absolute)
            try await stage([StatusEntry(kind: .conflicted, path: files.path)], staged: true)
        }
    }
}
