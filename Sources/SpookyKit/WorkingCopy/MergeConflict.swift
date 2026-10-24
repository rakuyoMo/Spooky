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

    /// 共同祖先版本的文件模式，如 `100644`；没有共同祖先时为 nil。
    public let baseMode: String?

    /// 我方版本的文件模式；我方删除了文件时为 nil。
    public let oursMode: String?

    /// 对方版本的文件模式；对方删除了文件时为 nil。
    public let theirsMode: String?
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

        /// 在索引中的 stage 的文件模式。
        func mode(_ index: Int) -> String? {
            modes[index] == "000000" ? nil : modes[index]
        }

        self.init(
            base: stage(0),
            ours: stage(1),
            theirs: stage(2),
            existsInWorktree: modes[3] != "000000",
            baseMode: mode(0),
            oursMode: mode(1),
            theirsMode: mode(2)
        )
    }
}

extension ConflictStages {
    /// 我方与对方都是普通文件；删除了文件、符号链接或子模块的一侧不能逐行合并。
    public var hasRegularFilesOnBothSides: Bool {
        [oursMode, theirsMode].allSatisfy { $0?.hasPrefix("100") ?? false }
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

extension ConflictContents {
    /// 冲突块的开始标记。
    private static let openingMarker = Array("<<<<<<<".utf8)

    /// 冲突块的结束标记。
    private static let closingMarker = Array(">>>>>>>".utf8)

    /// 工作区文件已是手动编辑或合并工具得到的结果：文件还在、与两侧版本都不同，且不再含有冲突标记。
    public var isManuallyEdited: Bool {
        #warning("TODO: 在外部编辑器改动冲突文件后核对 “Manually Edited or Merged Version” 何时出现，目前要求与两侧都不同且没有冲突标记；只影响这张卡片的显示")

        guard let worktree, worktree != ours, worktree != theirs else {
            return false
        }

        let lines = worktree.split(separator: 10, omittingEmptySubsequences: false)

        // 冲突块以 <<<<<<< 行开始、以 >>>>>>> 行结束；两者先后都在，文件里就还有未处理的冲突
        guard let opening = lines.firstIndex(where: { $0.starts(with: Self.openingMarker) }) else {
            return true
        }

        return !lines[opening...].contains { $0.starts(with: Self.closingMarker) }
    }
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
    /// 所选文件都没有要恢复或采用的那个版本。
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

    /// 把冲突文件的工作区恢复到指定版本，索引里的冲突保持不变。
    ///
    /// - Parameters:
    ///   - entries: 要恢复的文件；重新生成冲突也接受已经标记解决、仍有 resolve-undo 记录的文件。
    ///   - version: 恢复到的版本；缺少该版本的文件跳过，全部缺少时抛出 ``ConflictResolutionError/versionUnavailable``。
    public func restoreConflicts(_ entries: [StatusEntry], to version: ConflictVersion) async throws {
        try await runner.writeTransaction {
            let paths = try await restorablePaths(entries, version: version)

            guard !paths.isEmpty else {
                throw ConflictResolutionError.versionUnavailable
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

    /// 采用两侧版本并标记解决：在仓库所在的机器上逐个冲突块保留两侧的行，我方在前；结果写入索引后再检出到工作区。
    ///
    /// 两侧中有一方不是普通文件时抛出 ``ConflictResolutionError/versionUnavailable``。
    public func resolveUsingBoth(_ entry: StatusEntry) async throws {
        try await runner.writeTransaction {
            let current = try await runner.status().entries.first {
                $0.kind == .conflicted && $0.path == entry.path
            }

            guard
                let stages = current?.conflict,
                stages.hasRegularFilesOnBothSides,
                let oursMode = stages.oursMode,
                let theirsMode = stages.theirsMode
            else {
                throw ConflictResolutionError.versionUnavailable
            }

            let object = try await unionMerge(of: entry.path)

            // 文件模式按三方取：我方没有改动模式时沿用对方的
            let mode = oursMode == stages.baseMode ? theirsMode : oursMode

            // stage 0 的条目替换三个冲突 stage，Git 同时留下 resolve-undo 记录；路径经 stdin 原样传递
            _ = try await runner.run(
                ["update-index", "-z", "--index-info"],
                input: Data("\(mode) \(object)\t\(entry.path)".utf8) + [0]
            )

            // 由索引检出到工作区，照常经过过滤与换行转换
            _ = try await runner.run(["checkout-index", "-f", "-z", "--stdin"], input: Self.pathInput([entry.path]))
        }
    }
}

// MARK: - Stage Files

extension WorkingCopyOperations {
    /// 解析 `checkout-index --stage=all -z` 的输出：`<s1> <s2> <s3>\t<路径>\0`，缺少的 stage 为 `.`。
    ///
    /// - Returns: 共同祖先、我方与对方的临时文件名，相对仓库根目录；缺少的一侧为 nil。
    static func parseStageFiles(_ output: Data) throws -> [String?] {
        guard output.last == 0, let tab = output.firstIndex(of: 9) else {
            throw RepositoryReadError.malformedOutput("checkout-index")
        }

        let names = String(decoding: output[..<tab], as: UTF8.self)
            .split(separator: " ", omittingEmptySubsequences: false)
            .map(String.init)

        guard names.count == 3, names.allSatisfy({ !$0.isEmpty && !$0.contains("/") }) else {
            throw RepositoryReadError.malformedOutput("checkout-index")
        }

        return names.map { $0 == "." ? nil : $0 }
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

    /// 两侧版本按冲突块合并后的对象哈希：三方版本先检出成仓库根目录下的临时文件，union 合并写回我方那份，
    /// 再按文件在仓库里的路径过滤后写入对象库；临时文件无论成败都删除。
    ///
    /// - Parameter path: 冲突文件在仓库内的路径。
    private func unionMerge(of path: String) async throws -> String {
        #warning("TODO: 对两侧都修改的文件选 “Resolve Using Both Versions”，核对结果是逐个冲突块保留两侧、我方在前，还是整份拼接两侧；只影响这个动作写入的内容")

        let output = try await runner.run(["checkout-index", "--stage=all", "-z", "--stdin"], input: Self.pathInput([path]))
        let names = try Self.parseStageFiles(output)
        let created = names.compactMap { $0 }.map { runner.location.path + "/" + $0 }
        let files = RepositoryFiles(runner: runner)

        do {
            let object = try await mergeStageFiles(names, path: path)
            try await files.remove(created)
            return object
        } catch {
            // 失败时先清掉临时文件，再报告原来的错误
            try? await files.remove(created)
            throw error
        }
    }

    /// 把对方的临时文件按冲突块并入我方的临时文件，没有共同祖先时以空文件作祖先，再写入对象库。
    ///
    /// - Parameters:
    ///   - names: 共同祖先、我方与对方的临时文件名。
    ///   - path: 冲突文件在仓库内的路径，决定写入对象库时的过滤与换行转换。
    private func mergeStageFiles(_ names: [String?], path: String) async throws -> String {
        guard let ours = names[1], let theirs = names[2] else {
            throw ConflictResolutionError.versionUnavailable
        }

        _ = try await runner.run(["merge-file", "--union", ours, names[0] ?? "/dev/null", theirs])

        // 临时文件是检出后的工作区形式，按真实路径做与 git add 相同的过滤
        let output = try await runner.run(["hash-object", "-w", "--path=" + path, "--", ours])
        let object = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard GitObjectID.isValid(object) else {
            throw RepositoryReadError.malformedOutput("hash-object")
        }

        return object
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
}
