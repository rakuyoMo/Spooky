import Foundation

// MARK: - TrackedIndexEntries

/// 一组路径下已跟踪文件的索引项与 assume-unchanged 标记，撤销删除时据此原样恢复暂存区。
public struct TrackedIndexEntries: Sendable {
    /// `ls-files -s` 的记录：模式、对象、阶段与路径，可以原样交给 `update-index --index-info`。
    let records: [String]

    /// 各记录的路径，与 ``records`` 一一对应。
    public let paths: [String]

    /// 其中标为 assume-unchanged 的路径。
    let assumedUnchanged: [String]

    /// 解析 `ls-files -s -v -z` 的输出：每条记录是 “标记、空格、模式、对象、阶段、制表符、路径”，小写标记表示 assume-unchanged。
    init(parsing output: Data) throws {
        var records: [String] = []
        var paths: [String] = []
        var assumedUnchanged: [String] = []

        for record in output.split(separator: 0) {
            let text = String(decoding: record, as: UTF8.self)

            guard
                let tag = text.first,
                text.dropFirst().first == " ",
                let tab = text.firstIndex(of: "\t")
            else {
                throw RepositoryReadError.malformedOutput("ls-files")
            }

            let path = String(text[text.index(after: tab)...])

            records.append(String(text.dropFirst(2)))
            paths.append(path)

            if tag.isLowercase {
                assumedUnchanged.append(path)
            }
        }

        self.records = records
        self.paths = paths
        self.assumedUnchanged = assumedUnchanged
    }
}

// MARK: - FileDeletionError

/// 删除没有全部完成：已经移走的项留在废纸篓或已永久删除，其余的项没有动。
public struct FileDeletionError: Error, Sendable {
    /// 已从磁盘移走的项，仓库内的相对路径。
    public let removed: [String]

    /// 要删除的项都已移走，失败在之后把其中的已跟踪文件从索引移除时；为 false 时失败在移走这一步，删除都没有暂存。
    public let removedAll: Bool

    /// 中断删除的原始错误。
    public let underlying: any Error
}

// MARK: - Deletion

extension WorkingCopyOperations {
    /// 删除工作区里的文件与目录，其中已跟踪的文件同时从索引移除，删除成为待提交的改动：移进工作区所在机器的废纸篓；
    /// 服务器没有可用的废纸篓时，用户确认后永久删除。
    ///
    /// 未跟踪与被忽略的文件没有索引项，只从磁盘移走。assume-unchanged 的文件同样从索引移除，不依赖状态扫描发现删除。
    ///
    /// - Parameters:
    ///   - paths: 仓库内的相对路径；以 `/` 结尾的是整个未跟踪或被忽略的目录。
    ///   - removal: 删除方式。
    /// - Returns: 移进废纸篓的各项；永久删除时为空。
    /// - Throws: 已移走一部分后失败或被取消时抛出 ``FileDeletionError``，一项都没移走时抛出原始错误。
    @discardableResult
    public func delete(_ paths: [String], removal: FileRemoval = .trash) async throws -> [TrashedItem] {
        guard !paths.isEmpty else { return [] }

        return try await runner.writeTransaction {
            // 移走之前记下其中的已跟踪文件，目录展开成其中的文件
            let tracked = try await trackedIndexEntries(under: paths).paths
            let trashed: [TrashedItem]

            do {
                trashed = try await remove(paths, removal: removal)
            } catch {
                let removed = await removedPaths(among: paths)

                guard let removed, !removed.isEmpty else { throw error }

                throw FileDeletionError(removed: removed, removedAll: false, underlying: error)
            }

            // --force-remove 不递归进目录，交给它的是展开后的已跟踪文件
            guard !tracked.isEmpty else { return trashed }

            do {
                _ = try await runner.run(
                    ["update-index", "-z", "--force-remove", "--stdin"],
                    input: Self.pathInput(tracked)
                )
            } catch {
                throw FileDeletionError(removed: paths, removedAll: true, underlying: error)
            }

            return trashed
        }
    }

    /// 这些路径下已跟踪文件的索引项与 assume-unchanged 标记，路径按字面值匹配，目录展开成其中的文件。
    ///
    /// - Parameter paths: 仓库内的相对路径。
    public func trackedIndexEntries(under paths: [String]) async throws -> TrackedIndexEntries {
        let normalized = paths.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
        let output = try await runner.run(
            ["--literal-pathspecs", "ls-files", "-s", "-v", "-z", "--"] + normalized
        )

        return try TrackedIndexEntries(parsing: output)
    }

    /// 撤销删除：先核对删除的已跟踪文件仍不在索引里、原位置也没有新文件，再把废纸篓里的项移回原处，
    /// 按删除前的记录恢复索引项与 assume-unchanged 标记。
    ///
    /// 已暂存的内容随索引项一起回来；工作区里的内容来自废纸篓，永久删除的已跟踪文件按删除前的工作区快照写回。
    ///
    /// - Parameters:
    ///   - trashed: 删除时移进废纸篓的项。
    ///   - entries: 删除前读出的索引项。
    ///   - contents: 永久删除时，删除前已跟踪文件在工作区里的内容所在的树；移进废纸篓时为 nil。
    /// - Throws: 文件已重新出现在索引或原位置时抛出 ``RepositoryUndoError/repositoryChanged``；
    ///   废纸篓里的项移不回来时抛出 ``RepositoryUndoError/trashedItemsUnavailable``；两种情况都不做任何改动。
    public func restoreDeleted(
        _ trashed: [TrashedItem],
        entries: TrackedIndexEntries,
        contents: String? = nil
    ) async throws {
        try await runner.writeTransaction {
            if !entries.paths.isEmpty {
                let present = try await runner.run(
                    ["--literal-pathspecs", "ls-files", "-z", "--cached", "--others", "--"] + entries.paths
                )

                guard present.isEmpty else {
                    throw RepositoryUndoError.repositoryChanged
                }
            }

            do {
                try await RepositoryFiles(runner: runner).putBack(trashed)
            } catch RepositoryFileError.trashedItemsUnavailable {
                throw RepositoryUndoError.trashedItemsUnavailable
            }

            guard !entries.records.isEmpty else { return }

            _ = try await runner.run(
                ["update-index", "-z", "--index-info"],
                input: Self.pathInput(entries.records)
            )

            // 永久删除的文件只写回工作区，索引已按记录恢复
            if let contents {
                _ = try await runner.run(
                    ["--literal-pathspecs", "restore", "--source=" + contents, "--worktree"] + Self.pathInputOptions,
                    input: Self.pathInput(entries.paths)
                )
            }

            // 重新登记的索引项不带 assume-unchanged 标记，原来有的补上
            if !entries.assumedUnchanged.isEmpty {
                _ = try await runner.run(
                    ["update-index", "--assume-unchanged", "-z", "--stdin"],
                    input: Self.pathInput(entries.assumedUnchanged)
                )
            }
        }
    }
}

// MARK: - Private

extension WorkingCopyOperations {
    /// 把这些项从磁盘移走：移进废纸篓，或永久删除。
    private func remove(_ paths: [String], removal: FileRemoval) async throws -> [TrashedItem] {
        let files = RepositoryFiles(runner: runner)
        let root = runner.location.path

        guard removal == .permanent else {
            // 目录去掉末尾的 “/”，整个移进废纸篓
            return try await files.moveToTrash(
                paths.map { root + "/" + ($0.hasSuffix("/") ? String($0.dropLast()) : $0) }
            )
        }

        // SFTP 的 rm 只删除文件；整个目录交给 git clean，嵌套的仓库会被 git 跳过
        let directories = paths.filter { $0.hasSuffix("/") }

        try await files.remove(
            paths
                .filter { !$0.hasSuffix("/") }
                .map { root + "/" + $0 }
        )

        if !directories.isEmpty {
            _ = try await runner.run(
                ["--literal-pathspecs", "clean", "-q", "-f", "-d", "-x", "--"] + directories
            )
        }

        return []
    }

    /// 删除中途失败后，要删除的项里已从磁盘移走的；读不出时为 nil。
    ///
    /// 删除被取消时同样要核对：服务器在新任务里检查，它不继承取消，仍在同一个写事务里。
    private func removedPaths(among paths: [String]) async -> [String]? {
        let root = runner.location.path
        let absolute = paths.map { root + "/" + ($0.hasSuffix("/") ? String($0.dropLast()) : $0) }

        guard let remote = runner.remote else {
            // 符号链接本身就是删除的项，按链接自身判断是否存在
            return zip(paths, absolute)
                .filter { (try? FileManager.default.attributesOfItem(atPath: $0.1)) == nil }
                .map(\.0)
        }

        let check = Task { try await remote.inspect(absolute) }

        guard let flags = try? await check.value else {
            return nil
        }

        return zip(paths, flags)
            .filter { !$0.1 }
            .map(\.0)
    }
}
