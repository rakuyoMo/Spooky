import Foundation

// MARK: - ConflictStages

/// 冲突文件在索引中的三方版本，取自 porcelain v2 的 `u` 记录；stage 1 / 2 / 3 依次是共同祖先、我方与对方。
public struct ConflictStages: Sendable, Equatable {
    /// 共同祖先版本的对象哈希；两侧各自新增同名文件时没有共同祖先。
    public let base: String?

    /// 我方版本的对象哈希；我方删除了文件时为 nil。
    public let ours: String?

    /// 对方版本的对象哈希；对方删除了文件时为 nil。
    public let theirs: String?

    /// 工作区里是否还有这个文件。
    public let existsInWorktree: Bool
}

extension ConflictStages {
    /// 解析 `u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>` 的模式与哈希；模式为 000000 的一侧不存在。
    ///
    /// - Parameters:
    ///   - fields: 已按空格切好的 11 个字段。
    ///   - record: 原始记录，格式错误时随错误返回。
    init(unmerged fields: [String], record: String) throws {
        let modes = Array(fields[3 ... 6])
        let hashes = Array(fields[7 ... 9])

        // 模式是 6 位八进制数；哈希长度随仓库的对象格式变化，只校验是十六进制
        guard
            modes.allSatisfy({ $0.count == 6 && $0.allSatisfy { ("0" ... "7").contains($0) } }),
            hashes.allSatisfy(GitObjectID.isValid)
        else {
            throw StatusParseError(record: record)
        }

        /// 模式为 000000 的 stage 不在索引中。
        func stage(_ index: Int) -> String? {
            modes[index] == "000000" ? nil : hashes[index]
        }

        self.init(
            base: stage(0),
            ours: stage(1),
            theirs: stage(2),
            existsInWorktree: modes[3] != "000000"
        )
    }
}

// MARK: - ConflictKind

/// 冲突的类型，对应 porcelain 记录里未合并文件的七种 XY。
public enum ConflictKind: String, Sendable, CaseIterable {
    /// `UU`：两侧都修改了文件。
    case bothModified

    /// `AA`：两侧各自新增了同名文件。
    case bothAdded

    /// `DD`：两侧都删除了文件。
    case bothDeleted

    /// `AU`：只有我方新增了文件。
    case addedByUs

    /// `UA`：只有对方新增了文件。
    case addedByThem

    /// `DU`：我方删除了文件，对方修改了它。
    case deletedByUs

    /// `UD`：对方删除了文件，我方修改了它。
    case deletedByThem
}

extension StatusEntry {
    /// 冲突文件的冲突类型；XY 的 X 是我方的变化，Y 是对方的变化。非冲突文件为 nil。
    public var conflictKind: ConflictKind? {
        guard kind == .conflicted else {
            return nil
        }

        switch (staged, unstaged) {
        case (.added, .added): return .bothAdded
        case (.deleted, .deleted): return .bothDeleted
        case (.added, .unmerged): return .addedByUs
        case (.unmerged, .added): return .addedByThem
        case (.deleted, .unmerged): return .deletedByUs
        case (.unmerged, .deleted): return .deletedByThem
        default: return .bothModified
        }
    }
}

// MARK: - ConflictContents

/// 冲突向导显示的三方原文与工作区里的当前文件；缺少的一侧为 nil。
public struct ConflictContents: Sendable, Equatable {
    /// 共同祖先版本。
    public let base: Data?

    /// 我方版本。
    public let ours: Data?

    /// 对方版本。
    public let theirs: Data?

    /// 工作区里的当前文件，通常带着 Git 写入的冲突标记；文件已不在工作区时为 nil。
    public let worktree: Data?
}

// MARK: - ConflictVersion

/// 冲突文件可以恢复到的版本；恢复只改工作区，文件仍是未解决的冲突。
public enum ConflictVersion: Sendable {
    /// 由三方版本重新生成带冲突标记的合并结果，撤回已做的编辑或解决。
    case unmerged

    /// 我方版本。
    case ours

    /// 对方版本。
    case theirs

    /// 共同祖先版本。
    case base
}

// MARK: - ConflictResolutionError

/// 冲突向导的写入不满足前提，界面负责本地化。
public enum ConflictResolutionError: Error, Sendable, Equatable {
    /// 文件在载入之后被其它程序改动，手动编辑的结果不会覆盖它。
    case fileChanged

    /// 所选文件都没有要恢复的那个版本。
    case versionUnavailable
}

// MARK: - Conflict Operations

extension WorkingCopyOperations {
    /// 冲突向导的三方原文与工作区文件：三个对象经一次 `cat-file --batch` 取回，工作区文件服务器上走 SFTP。
    public func conflictContents(of entry: StatusEntry) async throws -> ConflictContents {
        guard let stages = entry.conflict else {
            throw WorkingCopyError.unsupportedFile
        }

        let hashes = [stages.base, stages.ours, stages.theirs].compactMap { $0 }
        let path = runner.location.path + "/" + entry.path

        // 对象与工作区文件互不依赖，并发读取；服务器上只占一次往返的等待时间
        async let objects = blobs(hashes)
        async let worktree = stages.existsInWorktree
            ? RepositoryFiles(runner: runner).read([path])[path]
            : nil

        let found = try await objects

        return ConflictContents(
            base: stages.base.flatMap { found[$0] },
            ours: stages.ours.flatMap { found[$0] },
            theirs: stages.theirs.flatMap { found[$0] },
            worktree: try await worktree
        )
    }

    /// 把冲突文件的工作区恢复到指定版本，索引里的冲突保持不变；调用方负责确认。
    ///
    /// - Parameters:
    ///   - entries: 要恢复的文件；重新生成冲突也接受已经标记解决、仍有 resolve-undo 记录的文件。
    ///   - version: 恢复到的版本；缺少该版本的文件跳过，全部缺少时抛出 ``ConflictResolutionError/versionUnavailable``。
    ///   - backup: 传入时先把当前文件另存为备份，再把备份路径交给它。
    public func restoreConflicts(
        _ entries: [StatusEntry],
        to version: ConflictVersion,
        backup: (@Sendable ([String]) async -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let paths = try await restorablePaths(entries, version: version)

            guard !paths.isEmpty else {
                throw ConflictResolutionError.versionUnavailable
            }

            if let backup {
                await backup(try await backUp(paths))
            }

            // 路径都经 NUL 输入传递；checkout-index 不认路径规格，按字面读取 stdin 里的路径
            let arguments: [String] =
                switch version {
                case .unmerged: ["--literal-pathspecs", "checkout", "--merge"] + Self.pathInputOptions
                case .ours: ["--literal-pathspecs", "checkout", "--ours"] + Self.pathInputOptions
                case .theirs: ["--literal-pathspecs", "checkout", "--theirs"] + Self.pathInputOptions
                case .base: ["checkout-index", "-f", "--stage=1", "-z", "--stdin"]
                }

            _ = try await runner.run(arguments, input: Self.pathInput(paths))
        }
    }

    /// 把手动编辑的结果写回冲突文件；写入前核对文件仍是载入时的内容，被其它程序改过就拒绝覆盖。
    ///
    /// - Parameters:
    ///   - data: 编辑后的完整文件内容。
    ///   - entry: 冲突文件。
    ///   - expected: 载入时读到的工作区内容；载入时文件不存在为 nil。
    ///   - backup: 传入时先把当前文件另存为备份，再把备份路径交给它。
    public func saveResolution(
        _ data: Data,
        for entry: StatusEntry,
        replacing expected: Data?,
        backup: (@Sendable ([String]) async -> Void)? = nil
    ) async throws {
        let path = runner.location.path + "/" + entry.path
        let files = RepositoryFiles(runner: runner)

        try await runner.writeTransaction {
            let current = try await files.read([path])[path]

            guard current == expected else {
                throw ConflictResolutionError.fileChanged
            }

            if let backup, let current {
                await backup(try await writeBackups([entry.path: current]))
            }

            try await files.write(data, to: path)
        }
    }

    /// 删除冲突向导生成的备份文件；已经不存在的路径直接跳过。
    ///
    /// - Parameter paths: 备份文件在仓库内的相对路径。
    public func removeBackups(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }

        let absolute = paths.map { runner.location.path + "/" + $0 }

        try await runner.writeTransaction {
            try await RepositoryFiles(runner: runner).remove(try await existing(absolute))
        }
    }

    /// 把文件当前的内容另存为同目录的备份，不在工作区的文件跳过；须在调用方的写事务中执行。
    ///
    /// - Parameter paths: 仓库内的相对路径。
    /// - Returns: 新建的备份文件的相对路径。
    func backUp(_ paths: [String]) async throws -> [String] {
        let absolute = paths.map { runner.location.path + "/" + $0 }
        let contents = try await RepositoryFiles(runner: runner).read(absolute)

        let current = Dictionary(uniqueKeysWithValues: zip(paths, absolute).compactMap { path, absolute in
            contents[absolute].map { (path, $0) }
        })

        return try await writeBackups(current)
    }
}

// MARK: - Batch Output

extension WorkingCopyOperations {
    /// 解析 `cat-file --batch` 的输出：每个对象是 `<oid> <type> <size>\n<内容>\n`，不存在的对象是 `<oid> missing\n`。
    static func parseBatch(_ output: Data) throws -> [String: Data] {
        var objects: [String: Data] = [:]
        var index = output.startIndex

        while index < output.endIndex {
            guard let newline = output[index...].firstIndex(of: 10) else {
                throw RepositoryReadError.malformedOutput("cat-file")
            }

            let header = String(decoding: output[index ..< newline], as: UTF8.self).split(separator: " ")
            index = output.index(after: newline)

            // 子模块等不在本仓库对象库里的对象报告为 missing，这一侧没有可显示的内容
            if header.count == 2, header[1] == "missing" {
                continue
            }

            // 内容按声明的字节数截取，内容里的换行与 NUL 都不影响切分
            guard
                header.count == 3,
                GitObjectID.isValid(String(header[0])),
                let size = Int(header[2]), size >= 0,
                output.distance(from: index, to: output.endIndex) > size,
                output[output.index(index, offsetBy: size)] == 10
            else {
                throw RepositoryReadError.malformedOutput("cat-file")
            }

            let end = output.index(index, offsetBy: size)
            objects[String(header[0])] = Data(output[index ..< end])
            index = output.index(after: end)
        }

        return objects
    }
}

// MARK: - Private

extension WorkingCopyOperations {
    /// 按哈希一次取回多个对象；对象内容不可变，结果按哈希复用。
    private func blobs(_ hashes: [String]) async throws -> [String: Data] {
        guard !hashes.isEmpty else {
            return [:]
        }

        let input = Data(hashes.map { $0 + "\n" }.joined().utf8)
        return try Self.parseBatch(try await runner.immutableRun(["cat-file", "--batch"], input: input))
    }

    /// 当前状态中可以恢复到指定版本的冲突文件路径。
    private func restorablePaths(_ entries: [StatusEntry], version: ConflictVersion) async throws -> [String] {
        let wanted = Set(entries.map(\.path))
        let conflicted = try await runner.status().entries.filter { $0.kind == .conflicted && wanted.contains($0.path) }

        let available = conflicted.filter { entry in
            switch version {
            case .unmerged: true
            case .ours: entry.conflict?.ours != nil
            case .theirs: entry.conflict?.theirs != nil
            case .base: entry.conflict?.base != nil
            }
        }

        guard version == .unmerged else {
            return available.map(\.path)
        }

        // 已经标记解决的文件靠 Git 的 resolve-undo 记录重新生成冲突
        let resolved = try OperationProgress.parseResolveUndo(
            try await runner.run(["ls-files", "--resolve-undo", "-z"])
        )

        let resolvedOnly = wanted
            .subtracting(conflicted.map(\.path))
            .filter(resolved.contains)

        return available.map(\.path) + resolvedOnly.sorted()
    }

    /// 为每个文件选一个尚不存在的备份名并写入内容，不覆盖任何已有文件。
    ///
    /// - Parameter contents: 相对路径与要备份的内容。
    /// - Returns: 新建的备份文件的相对路径。
    private func writeBackups(_ contents: [String: Data]) async throws -> [String] {
        let files = RepositoryFiles(runner: runner)
        var created: [String] = []

        for (path, data) in contents.sorted(by: { $0.key < $1.key }) {
            let name = try await freeBackupName(for: path, excluding: Set(created))
            try await files.write(data, to: runner.location.path + "/" + name)
            created.append(name)
        }

        return created
    }

    /// 备份依次尝试 `<文件>.orig`、`<文件>.1.orig`、`<文件>.2.orig`…，每次往返检查一批候选。
    private func freeBackupName(for path: String, excluding taken: Set<String>) async throws -> String {
        var start = 0

        while true {
            let names = (start ..< start + 10)
                .map { $0 == 0 ? path + ".orig" : path + ".\($0).orig" }
                .filter { !taken.contains($0) }

            let used = Set(try await existing(names.map { runner.location.path + "/" + $0 }))

            if let free = names.first(where: { !used.contains(runner.location.path + "/" + $0) }) {
                return free
            }

            start += 10
        }
    }

    /// 实际存在的路径；本机不跟随最后一级符号链接，服务器经包装器一次往返检查。
    private func existing(_ paths: [String]) async throws -> [String] {
        guard let remote = runner.remote else {
            return paths.filter { (try? FileManager.default.attributesOfItem(atPath: $0)) != nil }
        }

        guard !paths.isEmpty else {
            return []
        }

        return zip(paths, try await remote.inspect(paths)).filter(\.1).map(\.0)
    }
}
