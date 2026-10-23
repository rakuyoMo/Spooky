import CryptoKit
import Foundation

// MARK: - RepositoryOperationState

/// 正在进行的 Git 操作，启动入口由对应里程碑提供。
public enum RepositoryOperationState: String, Sendable {
    /// 普通合并等待提交。
    case merge

    /// 压缩合并等待提交。
    case squash

    /// 变基等待处理。
    case rebase

    /// 摘取等待处理。
    case cherryPick

    /// 反转等待处理。
    case revert
}

// MARK: - WorkingCopyContext

/// 提交区需要的身份、最近提交与进行中状态。
public struct WorkingCopyContext: Sendable {
    /// 实际提交人的姓名与邮箱，由 Git var 返回。
    public let committer: String

    /// 最近一次提交信息，Amend 直接使用。
    public let lastMessage: String

    /// 已识别的进行中操作。
    public let operation: RepositoryOperationState?

    /// Git 准备的结论信息。
    public let mergeMessage: String
}

// MARK: - DiffSnapshot

/// 可写 Diff 连同生成时的完整文件快照。
public struct DiffSnapshot: Sendable {
    /// 用户选择的原始状态条目。
    public let entry: StatusEntry

    /// 当前显示的暂存侧。
    public let side: DiffSide

    /// 单次 Git 补丁的字节数，kB 按 1000 字节换算。
    public let byteCount: Int

    /// 超过警告阈值时保留空值，显式加载后才解析。
    public let diff: RepositoryDiff?

    /// 当前文件的工作区、暂存区与状态联合摘要。
    public let fingerprint: Data
}

extension StatusEntry {
    /// 冲突不视为普通的已暂存改动。
    public var hasStagedChanges: Bool { kind == .tracked && staged != nil }

    /// 未跟踪与冲突同样需要暂存动作。
    public var hasUnstagedChanges: Bool {
        kind == .untracked || kind == .conflicted || unstaged != nil
    }

    /// 重命名必须包含原路径，复制只处理新文件。
    var operationPaths: [String] {
        if staged == .renamed || unstaged == .renamed, let originalPath {
            return [originalPath, path]
        }

        return [path]
    }
}

// MARK: - WorkingCopyOperations

/// 工作区读写的业务边界，所有 Git 参数与写入编排集中在核心库。
public struct WorkingCopyOperations: Sendable {
    /// 按单次补丁计算的大 Diff 默认阈值。
    public static let defaultWarningKilobytes = 20_000

    /// 所有支持批量路径的写命令使用同一 NUL 输入协议。
    private static let pathInputOptions = ["--pathspec-from-file=-", "--pathspec-file-nul"]

    /// 本机与服务器共用命令执行器。
    public let runner: GitRunner

    /// 创建服务，不进行隐式写入。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 不规范化实际路径字节，字面路径语义交由 Git 的全局开关保证。
    private static func pathInput(_ paths: [String]) -> Data {
        Data(paths.flatMap { Array($0.utf8) + [0] })
    }

    /// 加载单文件补丁，先判断补丁字节数，再分配行模型。
    public func diff(
        for entry: StatusEntry,
        side: DiffSide,
        warningKilobytes: Int = Self.defaultWarningKilobytes,
        showLarge: Bool = false
    ) async throws -> DiffSnapshot {
        let contents = try await snapshot(entry)
        let patch = side == .staged ? contents.staged : contents.unstaged
        let threshold = max(0, min(warningKilobytes, Int.max / 1000)) * 1000

        // Foundation 的 range(of:) 与 contains 结果相同，在数十 MB 的补丁上快数百倍。
        // swiftlint:disable:next contains_over_range_nil_comparison
        let binary = patch.range(of: Data("\nBinary files ".utf8)) != nil
        let parsed = patch.count <= threshold || showLarge || binary ? try RepositoryDiff(patch: patch) : nil

        return DiffSnapshot(
            entry: entry,
            side: side,
            byteCount: patch.count,
            diff: parsed,
            fingerprint: contents.fingerprint
        )
    }

    /// 暂存与取消暂存都经 NUL 路径输入，覆盖大量路径及字面通配符。
    public func stage(_ entries: [StatusEntry], staged: Bool) async throws {
        guard !entries.isEmpty else { return }
        let paths = Array(Set(entries.flatMap(\.operationPaths)))
        let command = staged ? ["add", "--all"] : ["reset", "-q"]
        _ = try await runner.run(
            ["--literal-pathspecs"] + command + Self.pathInputOptions,
            input: Self.pathInput(paths)
        )
    }

    /// 操作全部改动时先取得当前条目，不把忽略文件或其它仓库纳入范围。
    public func stageAll(staged: Bool) async throws {
        try await runner.writeTransaction {
            let entries = try await runner.status().entries.filter {
                staged ? $0.hasUnstagedChanges : $0.hasStagedChanges
            }
            try await stage(entries, staged: staged)
        }
    }

    /// 按块或行应用补丁，校验和写入在同一仓库写锁中执行。
    public func apply(
        _ snapshot: DiffSnapshot,
        file: Int,
        hunk: Int,
        lines: Set<Int> = [],
        discard: Bool = false
    ) async throws {
        guard
            let diff = snapshot.diff,
            diff.files.count == 1,
            !discard || snapshot.side == .unstaged
        else { throw WorkingCopyError.invalidSelection }

        let reverse = discard || snapshot.side == .staged
        let patch = try diff.patch(
            path: snapshot.entry.path,
            file: file,
            hunk: hunk,
            selectedLines: lines,
            reverse: reverse
        )

        try await runner.writeTransaction {
            guard try await self.snapshot(snapshot.entry).fingerprint == snapshot.fingerprint else {
                throw WorkingCopyError.staleSnapshot
            }

            var arguments = ["apply", "--whitespace=nowarn"]
            if !discard { arguments.append("--cached") }
            if reverse { arguments.append("--reverse") }

            // 不放宽空白或上下文匹配；预检失败保留 Git 原始输出。
            _ = try await runner.run(arguments + ["--check", "-"], input: patch)
            guard try await self.snapshot(snapshot.entry).fingerprint == snapshot.fingerprint else {
                throw WorkingCopyError.staleSnapshot
            }

            _ = try await runner.run(arguments + ["-"], input: patch)
        }
    }

    /// 丢弃选中文件的暂存与工作区改动，调用方必须先获得用户确认。
    public func discard(_ entries: [StatusEntry]) async throws {
        guard !entries.isEmpty else { return }
        guard entries.allSatisfy({ !$0.path.hasSuffix("/") }) else {
            throw WorkingCopyError.unsupportedFile
        }

        try await runner.writeTransaction {
            let current = try await runner.status()
            let selected = Set(entries.map { $0.path.precomposedStringWithCanonicalMapping })
            let targets = current.entries.filter { selected.contains($0.path.precomposedStringWithCanonicalMapping) }
            let tracked = targets.filter { $0.kind != .untracked && $0.kind != .ignored }
            let untracked = targets.filter { $0.kind == .untracked }

            if !tracked.isEmpty {
                // 空仓库以真实空树为来源，新增文件也能恢复为未存在状态。
                let source: String =
                    if let oid = current.branch.oid {
                        oid
                    } else {
                        String(decoding: try await runner.run(
                            ["hash-object", "-w", "-t", "tree", "--stdin"], input: Data()
                        ), as: UTF8.self).trimmingCharacters(in: .newlines)
                    }

                _ = try await runner.run(
                    ["--literal-pathspecs", "restore", "--source=" + source, "--staged", "--worktree"]
                        + Self.pathInputOptions,
                    input: Self.pathInput(Array(Set(tracked.flatMap(\.operationPaths))))
                )
            }

            // SFTP 与本机文件 API 分开，远端绝对路径不会进入 A 的文件系统。
            let trackedPaths = Set(tracked.map(\.path))
            let deletions = untracked.filter { !trackedPaths.contains($0.path) }
            try await RepositoryFiles(runner: runner).remove(deletions.map { runner.location.path + "/" + $0.path })
        }
    }

    /// NFC 与 UTF-8 只作用于提交信息，Git 路径保留原始表示。
    public func commit(subject: String, body: String, amend: Bool = false) async throws {
        let message = (subject + (body.isEmpty ? "\n" : "\n\n" + body + "\n"))
            .precomposedStringWithCanonicalMapping
        var arguments = ["-c", "i18n.commitencoding=UTF-8", "-c", "commit.verbose=false", "commit", "-F", "-"]
        if amend { arguments.append("--amend") }
        _ = try await runner.run(arguments, input: Data(message.utf8))
    }

    /// 采用一侧后立即通过 Git 标记解决，缺失的一侧对应删除。
    public func resolve(_ entries: [StatusEntry], theirs: Bool) async throws {
        try await runner.writeTransaction {
            let current = try await runner.status()
            let paths = Set(entries.map(\.path))

            for entry in current.entries where entry.kind == .conflicted && paths.contains(entry.path) {
                let stages = try await runner.run(["--literal-pathspecs", "ls-files", "--stage", "-z", "--", entry.path])
                let wanted = theirs ? "3" : "2"
                let exists = stages.split(separator: 0).contains {
                    let prefix = $0.prefix(while: { $0 != 9 })
                    return String(decoding: prefix, as: UTF8.self).split(separator: " ").last == Substring(wanted)
                }

                if exists {
                    _ = try await runner.run(
                        ["--literal-pathspecs", "checkout", theirs ? "--theirs" : "--ours"] + Self.pathInputOptions,
                        input: Self.pathInput([entry.path])
                    )
                    try await stage([entry], staged: true)
                } else {
                    _ = try await runner.run(
                        ["--literal-pathspecs", "rm", "-f"] + Self.pathInputOptions,
                        input: Self.pathInput([entry.path])
                    )
                }
            }
        }
    }

    /// 中止、继续、跳过都由 Git 维护状态文件，远端不会启动本机编辑器。
    public func finish(_ operation: RepositoryOperationState, action: String) async throws {
        guard ["abort", "continue", "skip"].contains(action) else { throw WorkingCopyError.invalidSelection }
        let command: String

        switch operation {
        case .merge: command = "merge"

        case .squash:
            guard action == "abort" else { throw WorkingCopyError.invalidSelection }
            _ = try await runner.run(["reset", "--merge"])
            return

        case .rebase: command = "rebase"

        case .cherryPick: command = "cherry-pick"

        case .revert: command = "revert"
        }

        _ = try await runner.run(["-c", "core.editor=:", "-c", "core.trustctime=false", command, "--" + action])
    }

    /// 一次读取状态文件快照，进行中模式不依赖人读的 git status 文案。
    ///
    /// - Parameter head: 状态快照中的 HEAD 提交；未出生分支为 nil。最近信息按该哈希复用。
    public func context(head: String?) async throws -> WorkingCopyContext {
        guard head.map(GitObjectID.isValid) ?? true else {
            throw RepositoryReadError.invalidQuery
        }

        let names = [
            "MERGE_HEAD", "SQUASH_MSG", "CHERRY_PICK_HEAD", "REVERT_HEAD", "MERGE_MSG",
            "rebase-merge/head-name", "rebase-apply/head-name", "sequencer/todo",
        ]

        // 三项读取互不依赖，并发执行；服务器上只占一次往返的等待时间。
        async let identity = runner.execute(["var", "GIT_COMMITTER_IDENT"], acceptedExitCodes: [0, 128])
        async let message = lastMessage(of: head)
        async let located = runner.run(["rev-parse", "--path-format=absolute"] + names.flatMap { ["--git-path", $0] })

        let rawIdentity = String(decoding: try await identity.standardOutput, as: UTF8.self)
        let committer = rawIdentity.lastIndex(of: ">")
            .map { String(rawIdentity[...$0]) } ?? ""
        let lastMessage = try await message
        let paths = String(decoding: try await located, as: UTF8.self).split(separator: "\n").map(String.init)
        guard paths.count == names.count else { throw RepositoryFileError.unsupportedPath }
        let content = try await RepositoryFiles(runner: runner).read(paths)
        let files = Dictionary(uniqueKeysWithValues: zip(names, paths).compactMap { name, path in
            content[path].map { (name, String(decoding: $0, as: UTF8.self)) }
        })
        let operation: RepositoryOperationState? =
            if
                files["rebase-merge/head-name"] != nil
                || files["rebase-apply/head-name"] != nil
            {
                .rebase
            } else if files["REVERT_HEAD"] != nil || (files["sequencer/todo"]?.hasPrefix("revert ") ?? false) {
                .revert
            } else if files["CHERRY_PICK_HEAD"] != nil || (files["sequencer/todo"]?.hasPrefix("pick ") ?? false) {
                .cherryPick
            } else if files["MERGE_HEAD"] != nil {
                .merge
            } else if files["SQUASH_MSG"] != nil {
                .squash
            } else {
                nil
            }

        // Git 生成的冲突清单不属于提交正文，预填时移除其注释行。
        let mergeMessage = (files["SQUASH_MSG"] ?? files["MERGE_MSG"] ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("#") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
        return WorkingCopyContext(
            committer: committer,
            lastMessage: lastMessage,
            operation: operation,
            mergeMessage: mergeMessage
        )
    }

    /// 工作区文件内容的对象哈希，供服务器轮询判断已显示的 Diff 是否过期；文件不存在或无法读取时为 nil。
    public func worktreeHash(of entry: StatusEntry) async throws -> String? {
        let result = try await runner.execute(
            ["hash-object", "--no-filters", "--", entry.path],
            acceptedExitCodes: [0, 128]
        )

        guard result.exitCode == 0 else {
            return nil
        }

        return String(decoding: result.standardOutput, as: UTF8.self).trimmingCharacters(in: .newlines)
    }

}

// MARK: - Private

extension WorkingCopyOperations {
    /// 指定提交的完整信息；提交信息不可变，按哈希复用。
    private func lastMessage(of head: String?) async throws -> String {
        guard let head else {
            return ""
        }

        let output = try await runner.immutableRun([
            "-c", "i18n.logOutputEncoding=UTF-8", "log", "-1", "--format=%B", head, "--",
        ])
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
    }

    /// 两侧补丁与路径状态一起校验，暂存视图也会察觉外部工作区编辑。
    private func snapshot(_ entry: StatusEntry) async throws -> (staged: Data, unstaged: Data, fingerprint: Data) {
        let options = [
            "--no-color", "--word-diff=none", "--no-ext-diff", "--no-textconv", "--full-index",
            "--src-prefix=a/", "--dst-prefix=b/", "--no-relative", "--diff-algorithm=myers", "-U3", "-C", "-M",
        ]
        let statusArguments = ["--literal-pathspecs", "status", "--porcelain=v2", "-z", "--untracked-files=all", "--"]
            + entry.operationPaths
        let before = try await runner.run(statusArguments)
        let staged = try await runner.run(
            ["--literal-pathspecs", "diff", "--cached"] + options + ["--"] + entry.operationPaths
        )
        let unstaged: Data

        if entry.kind == .untracked {
            guard !entry.path.hasSuffix("/") else { throw WorkingCopyError.unsupportedFile }
            unstaged = try await runner.execute(
                ["diff", "--no-index"] + options + ["--", "/dev/null", entry.path],
                acceptedExitCodes: [0, 1]
            ).standardOutput
        } else {
            unstaged = try await runner.run(
                ["--literal-pathspecs", "diff"] + options + ["--", entry.path]
            )
        }

        guard try await runner.run(statusArguments) == before else { throw WorkingCopyError.staleSnapshot }
        var hash = SHA256()

        for data in [before, staged, unstaged] {
            hash.update(data: Data("\(data.count):".utf8))
            hash.update(data: data)
        }

        return (staged, unstaged, Data(hash.finalize()))
    }
}
