import Foundation

// MARK: - StashError

/// 储藏操作中 Git 退出码不能表达的失败；储藏始终保留，原始输出随错误带回。
public enum StashError: Error, Sendable {
    /// 没有可储藏的改动；Git 此时以 0 退出，结果中保留它的原文。
    case noLocalChanges(GitCommandResult)

    /// 列表里的序号已不再指向同一个储藏，可能有终端或其它工具同时改动了储藏列表。
    case stashChanged

    /// 储藏已应用但产生冲突，冲突留在工作区，储藏保留。
    case conflicts(GitCommandResult)

    /// 自动储藏之后原操作失败；本地改动保存在说明为 `stash` 的储藏里。
    case operationFailed(stash: String, underlying: any Error)

    /// 原操作已完成，但恢复自动储藏失败；储藏保留。
    case reapplyFailed(stash: String, underlying: any Error)
}

// MARK: - StashFileChange

/// 储藏详情中的一个文件；已跟踪文件的改动在储藏提交里，未跟踪文件在第三个父提交里。
public struct StashFileChange: Sendable, Equatable, Identifiable {
    /// 读取这个文件补丁时使用的提交。
    public let commit: String

    /// 文件的变更记录。
    public let file: CommitFileChange

    /// 文件是否随 “包含未跟踪文件” 一起保存。
    public let isUntracked: Bool

    /// 同一个储藏中路径唯一。
    public var id: String { file.path }
}

// MARK: - RepositoryStashes

/// 储藏的读取与写入都在仓库所在的机器上执行；按序号的写入先核对序号与哈希。
public struct RepositoryStashes: Sendable {
    /// 生成要套用的单文件补丁：二进制可还原，不使用外部 diff 与文本转换。
    private static let patchOptions = [
        "--binary", "--no-color", "--no-ext-diff", "--no-textconv", "--full-index",
        "--src-prefix=a/", "--dst-prefix=b/",
    ]

    /// 本机或服务器的命令执行器。
    public let runner: GitRunner

    /// 创建储藏服务，不进行隐式写入。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 读取全部储藏，序号来自 Git 的引用日志选择器，不按位置推算。
    public func list() async throws -> [StashEntry] {
        let output = try await runner.run([
            "-c", "log.showSignature=false", "-c", "i18n.logOutputEncoding=UTF-8", "-c", "log.date=default",
            "stash", "list", "-z", "--no-color", "--format=tformat:%gd%x00%H%x00%P%x00%ct%x00%s",
        ])

        return try StashEntry.parse(output)
    }

    /// 储藏详情的文件列表：已跟踪文件对比基准提交，未跟踪文件全部列为新增。
    public func changes(in stash: StashEntry) async throws -> [StashFileChange] {
        let history = RepositoryHistory(runner: runner)
        let tracked = try await history.changes(in: stash.id)
            .map { StashFileChange(commit: stash.id, file: $0, isUntracked: false) }

        guard let untracked = stash.untrackedCommit else {
            return tracked
        }

        return try await tracked + history.changes(in: untracked)
            .map { StashFileChange(commit: untracked, file: $0, isUntracked: true) }
    }

    /// 保存全部或所选文件的改动并清理工作区，返回新储藏的哈希。
    ///
    /// - Parameters:
    ///   - message: 储藏说明；为空时由 Git 生成 `WIP on …`。
    ///   - includeUntracked: 是否一并储藏未跟踪文件；部分储藏只收入所选的未跟踪文件。
    ///   - entries: 部分储藏的文件；nil 表示全部改动。
    @discardableResult
    public func save(message: String, includeUntracked: Bool, entries: [StatusEntry]? = nil) async throws -> String {
        try await runner.writeTransaction {
            var arguments = ["stash", "push"]
            if includeUntracked { arguments.append("--include-untracked") }
            if !message.isEmpty { arguments += ["-m", message] }

            // 部分储藏的路径经 NUL 输入，按字面匹配，不受通配符、数量与远端命令行长度影响。
            // 储藏全部改动时不能加 --literal-pathspecs：Git 清理未跟踪文件用的内部路径会被当成字面路径，未跟踪文件留在原处。
            var input: Data?
            if let entries {
                guard !entries.isEmpty else { throw WorkingCopyError.invalidSelection }
                arguments = ["--literal-pathspecs"] + arguments + ["--pathspec-from-file=-", "--pathspec-file-nul"]
                input = Self.pathInput(Set(entries.flatMap(\.operationPaths)))
            }

            let result = try await runner.execute(arguments, input: input)
            if Self.hasNoLocalChanges(result) { throw StashError.noLocalChanges(result) }

            return try await latest()
        }
    }

    /// 把改动存成储藏但保留工作区。
    ///
    /// 全部已跟踪改动用 `stash create` 与 `stash store` 生成，不触碰任何文件；
    /// 包含未跟踪文件或只取所选文件时先储藏，再以 `--index` 把同一个储藏原样应用回工作区，因为 `stash create` 不支持这两种情形。
    public func snapshot(message: String, includeUntracked: Bool, entries: [StatusEntry]? = nil) async throws {
        guard entries == nil, !includeUntracked else {
            try await runner.writeTransaction {
                let stash = try await save(message: message, includeUntracked: includeUntracked, entries: entries)
                _ = try await runner.run(["stash", "apply", "--index", stash])
            }
            return
        }

        try await runner.writeTransaction {
            let result = try await runner.execute(["stash", "create"] + (message.isEmpty ? [] : [message]))
            let stash = String(decoding: result.standardOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard GitObjectID.isValid(stash) else { throw StashError.noLocalChanges(result) }

            // 引用日志沿用储藏提交的标题，终端里的 git stash list 与其它储藏显示一致
            let subject = try await runner.run([
                "-c", "log.showSignature=false", "-c", "i18n.logOutputEncoding=UTF-8",
                "log", "-1", "--format=%s", stash, "--",
            ])
            let title = String(decoding: subject, as: UTF8.self).trimmingCharacters(in: .newlines)
            _ = try await runner.run(["stash", "store", "-m", title, stash])
        }
    }

    /// 应用一个储藏；`drop` 为真时成功后删除它，即 Pop。冲突时 Git 保留储藏，以 ``StashError/conflicts(_:)`` 报告。
    ///
    /// - Parameters:
    ///   - stash: 列表中的储藏，执行前核对序号仍指向它。
    ///   - restoreIndex: 是否同时恢复暂存区状态。
    ///   - drop: 应用成功后是否删除储藏。
    public func apply(_ stash: StashEntry, restoreIndex: Bool, drop: Bool) async throws {
        try await runner.writeTransaction {
            try await verify([stash])

            var arguments = ["stash", drop ? "pop" : "apply"]
            if restoreIndex { arguments.append("--index") }

            do {
                _ = try await runner.run(arguments + [stash.reference])
            } catch let error as GitError where Self.hasConflicts(error.result) {
                throw StashError.conflicts(error.result)
            }
        }
    }

    /// 删除所选储藏；先核对全部序号，再从大到小删除，删除较新的储藏不会改变较旧储藏的序号。
    public func drop(_ stashes: [StashEntry]) async throws {
        guard !stashes.isEmpty else { return }

        try await runner.writeTransaction {
            try await verify(stashes)

            for stash in stashes.sorted(by: { $0.index > $1.index }) {
                _ = try await runner.run(["stash", "drop", stash.reference])
            }
        }
    }

    /// 只把储藏里一个文件的改动套用到工作区，不改暂存区；套用不上时整体失败，工作区保持不变。
    ///
    /// 补丁按储藏提交的哈希生成，储藏列表随后的变化不影响结果。
    public func apply(_ change: StashFileChange, from stash: StashEntry) async throws {
        let paths = [change.file.path] + (change.file.originalPath.map { [$0] } ?? [])
        let arguments: [String] =
            if change.isUntracked {
                ["--literal-pathspecs", "show", "--format="] + Self.patchOptions + [change.commit, "--"] + paths
            } else {
                ["--literal-pathspecs", "diff"] + Self.patchOptions + [stash.base, stash.id, "--"] + paths
            }

        try await runner.writeTransaction {
            let patch = try await runner.run(arguments)
            guard !patch.isEmpty else { throw WorkingCopyError.invalidSelection }

            _ = try await runner.run(["apply", "--whitespace=nowarn", "-"], input: patch)
        }
    }

    /// 先储藏全部本地改动（含未跟踪文件），再执行被本地改动挡住的操作，按需在完成后恢复。
    ///
    /// 任何一步失败都停在当前状态：储藏保留，原操作与恢复的失败分别包装成 ``StashError``，原始错误随之带回。
    /// 断线与取消不包装，交给调用方的断线核对与取消处理，也不自动重试。
    ///
    /// - Parameters:
    ///   - message: 储藏说明。
    ///   - reapply: 操作完成后是否恢复储藏（连同暂存区状态）并在成功后删除它。
    ///   - operation: 原操作，在同一仓库写锁中执行。
    public func stashingLocalChanges(
        message: String,
        reapply: Bool,
        operation: @Sendable () async throws -> Void
    ) async throws {
        try await runner.writeTransaction {
            let stash = try await save(message: message, includeUntracked: true)

            do {
                try await operation()
            } catch {
                throw Self.wrapped(error) { StashError.operationFailed(stash: message, underlying: $0) }
            }

            guard reapply else {
                return
            }

            do {
                guard let entry = try await list().first(where: { $0.id == stash }) else {
                    throw StashError.stashChanged
                }

                try await apply(entry, restoreIndex: true, drop: true)
            } catch {
                throw Self.wrapped(error) { StashError.reapplyFailed(stash: message, underlying: $0) }
            }
        }
    }
}

// MARK: - Private

extension RepositoryStashes {
    /// 断线、取消与储藏自身的错误原样抛出，其余失败包装成说明储藏去向的错误。
    private static func wrapped(_ error: any Error, as wrap: (any Error) -> StashError) -> any Error {
        if error is RemoteConnectionError || error is CancellationError || error is StashError {
            return error
        }

        if let git = error as? GitError, git.isCancelled {
            return error
        }

        return wrap(error)
    }

    /// Git 以 0 退出但没有生成储藏时，标准输出单独一行写着这句话。
    private static func hasNoLocalChanges(_ result: GitCommandResult) -> Bool {
        String(decoding: result.standardOutput, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .contains("No local changes to save")
    }

    /// 合并储藏产生冲突时，Git 为每个冲突文件输出一行 `CONFLICT (…)`。
    private static func hasConflicts(_ result: GitCommandResult) -> Bool {
        [result.standardOutput, result.standardError].contains {
            String(decoding: $0, as: UTF8.self)
                .split(whereSeparator: \.isNewline)
                .contains { $0.hasPrefix("CONFLICT (") }
        }
    }

    /// 路径按原始 UTF-8 字节以 NUL 分隔，交给 `--pathspec-from-file=-`。
    private static func pathInput(_ paths: Set<String>) -> Data {
        Data(paths.sorted().flatMap { Array($0.utf8) + [0] })
    }

    /// 核对每个储藏的序号仍指向列表里的哈希；只读一次最新列表，多个储藏共用。
    private func verify(_ stashes: [StashEntry]) async throws {
        let current = Dictionary(try await list().map { ($0.index, $0.id) }) { first, _ in first }

        guard stashes.allSatisfy({ current[$0.index] == $0.id }) else {
            throw StashError.stashChanged
        }
    }

    /// 刚保存的储藏总在 `refs/stash` 的顶端。
    private func latest() async throws -> String {
        let output = try await runner.run(["rev-parse", "--verify", "refs/stash"])
        let stash = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard GitObjectID.isValid(stash) else { throw RepositoryReadError.malformedOutput("rev-parse") }

        return stash
    }
}
