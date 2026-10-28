import CryptoKit
import Foundation

// MARK: - RepositoryOperationState

/// 仓库里进行到一半、等待提交或继续的 Git 操作。
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

    /// 进行中操作的两侧、序列进度与已解决的冲突；没有进行中的操作时为 nil。
    public let progress: OperationProgress?

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

    /// 当前文件的工作区、暂存区与状态联合摘要，生成时的显示选项一并计入。
    public let fingerprint: Data

    /// 生成这份 Diff 的显示选项，写入前按同一选项重新核对快照。
    public let options: DiffOptions

    /// 忽略空白后这一侧没有剩下任何改动，逐字节比较仍有差异。
    public let onlyWhitespaceChanges: Bool
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
    static let pathInputOptions = ["--pathspec-from-file=-", "--pathspec-file-nul"]

    /// 本机与服务器共用命令执行器。
    public let runner: GitRunner

    /// 创建服务，不进行隐式写入。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 不规范化实际路径字节，字面路径语义交由 Git 的全局开关保证。
    static func pathInput(_ paths: [String]) -> Data {
        Data(paths.flatMap { Array($0.utf8) + [0] })
    }

    /// 加载单文件补丁，先判断补丁字节数，再分配行模型。
    public func diff(
        for entry: StatusEntry,
        side: DiffSide,
        options: DiffOptions = DiffOptions(),
        warningKilobytes: Int = Self.defaultWarningKilobytes,
        showLarge: Bool = false
    ) async throws -> DiffSnapshot {
        let contents = try await snapshot(entry, options: options)
        let patch = side == .staged ? contents.staged : contents.unstaged
        let exact = side == .staged ? contents.exactStaged : contents.exactUnstaged
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
            fingerprint: contents.fingerprint,
            options: options,
            onlyWhitespaceChanges: patch.isEmpty && !exact.isEmpty
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
            snapshot.diff?.files.count == 1,
            !discard || snapshot.side == .unstaged
        else { throw WorkingCopyError.invalidSelection }

        let reverse = discard || snapshot.side == .staged

        try await runner.writeTransaction {
            guard try await isCurrent(snapshot) else {
                throw WorkingCopyError.staleSnapshot
            }

            // 补丁在写锁内生成：忽略空白时要读取同一时刻的逐字节 Diff。
            let patch = try await writablePatch(
                snapshot,
                file: file,
                hunk: hunk,
                lines: lines,
                reverse: reverse
            )

            var arguments = ["apply", "--whitespace=nowarn"]
            if !discard { arguments.append("--cached") }
            if reverse { arguments.append("--reverse") }

            // 不放宽空白或上下文匹配；预检失败保留 Git 原始输出。
            _ = try await runner.run(arguments + ["--check", "-"], input: patch)
            guard try await isCurrent(snapshot) else {
                throw WorkingCopyError.staleSnapshot
            }

            _ = try await runner.run(arguments + ["-"], input: patch)
        }
    }

    /// 丢弃选中文件的暂存与工作区改动：已跟踪的文件恢复到最后一次提交，未跟踪文件移进废纸篓；调用方必须先获得用户确认。
    ///
    /// - Parameters:
    ///   - entries: 要丢弃的文件。
    ///   - removal: 未跟踪文件的删除方式；服务器没有可用的废纸篓、用户确认后才永久删除。
    /// - Returns: 移进废纸篓的未跟踪文件；永久删除时为空。
    @discardableResult
    public func discard(_ entries: [StatusEntry], removal: FileRemoval = .trash) async throws -> [TrashedItem] {
        guard !entries.isEmpty else { return [] }
        guard entries.allSatisfy({ !$0.path.hasSuffix("/") }) else {
            throw WorkingCopyError.unsupportedFile
        }

        return try await runner.writeTransaction {
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

            // 本机与服务器的文件操作分开，远端绝对路径不会进入 A 的文件系统。
            let trackedPaths = Set(tracked.map(\.path))
            let deletions = untracked.filter { !trackedPaths.contains($0.path) }.map { runner.location.path + "/" + $0.path }
            let files = RepositoryFiles(runner: runner)

            switch removal {
            case .trash:
                return try await files.moveToTrash(deletions)

            case .permanent:
                try await files.remove(deletions)
                return []
            }
        }
    }

    /// 把所选文件的暂存区与工作区恢复到指定版本，版本中不存在的文件随之删除；调用方必须先获得用户确认。
    ///
    /// - Parameters:
    ///   - paths: 仓库内的相对路径，按字面匹配。
    ///   - revision: 提交哈希或引用名。
    public func restore(_ paths: [String], to revision: String) async throws {
        guard !paths.isEmpty else { return }

        // 版本作为 --source 的值整体传入，不会被解释成选项；路径经 NUL 输入，不受通配符和数量影响
        _ = try await runner.run(
            ["--literal-pathspecs", "restore", "--source=" + revision, "--staged", "--worktree"]
                + Self.pathInputOptions,
            input: Self.pathInput(Array(Set(paths)))
        )
    }

    /// NFC 与 UTF-8 只作用于提交信息，Git 路径保留原始表示；签名完全由仓库配置决定，不加签名参数。
    ///
    /// - Parameters:
    ///   - amend: 改写最近一次提交。
    ///   - signOff: 追加 `Signed-off-by` 尾注。
    ///   - skipHooks: 跳过 pre-commit 与 commit-msg 钩子。
    public func commit(
        subject: String,
        body: String,
        amend: Bool = false,
        signOff: Bool = false,
        skipHooks: Bool = false
    ) async throws {
        let message = CommitMessage.text(subject: subject, body: body)
        var arguments = ["-c", "i18n.commitencoding=UTF-8", "-c", "commit.verbose=false", "commit", "-F", "-"]

        if amend { arguments.append("--amend") }

        if signOff { arguments.append("--signoff") }

        if skipHooks { arguments.append("--no-verify") }

        _ = try await runner.run(arguments, input: Data(message.utf8))
    }

    /// 采用一侧后立即通过 Git 标记解决，缺失的一侧对应删除。
    ///
    /// - Parameters:
    ///   - entries: 要解决的文件，其中不是冲突的条目被忽略。
    ///   - theirs: 采用对方版本；否则采用我方版本。
    public func resolve(_ entries: [StatusEntry], theirs: Bool) async throws {
        try await runner.writeTransaction {
            let paths = Set(entries.map(\.path))
            let targets = try await runner.status().entries.filter { $0.kind == .conflicted && paths.contains($0.path) }

            // porcelain v2 的 stage 记录说明采用的一侧是否存在，不必逐个文件查询索引
            let kept = targets.filter { (theirs ? $0.conflict?.theirs : $0.conflict?.ours) != nil }
            let removed = targets.filter { (theirs ? $0.conflict?.theirs : $0.conflict?.ours) == nil }

            if !kept.isEmpty {
                _ = try await runner.run(
                    ["--literal-pathspecs", "checkout", theirs ? "--theirs" : "--ours"] + Self.pathInputOptions,
                    input: Self.pathInput(kept.map(\.path))
                )

                try await stage(kept, staged: true)
            }

            // 采用的一侧删除了文件，解决的结果就是删除
            if !removed.isEmpty {
                _ = try await runner.run(
                    ["--literal-pathspecs", "rm", "-f", "-q"] + Self.pathInputOptions,
                    input: Self.pathInput(removed.map(\.path))
                )
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

        try await runner.writeTransaction {
            // 序列的这一步没有可提交的改动时，继续表示保留一个空提交，再接着处理后面的步骤
            if action == "continue", try await commitEmptyStep(of: operation) {
                return
            }

            _ = try await runner.run(["-c", "core.editor=:", "-c", "core.trustctime=false", command, "--" + action])
        }
    }

    /// 一次读取状态文件快照，进行中模式不依赖人读的 git status 文案。
    ///
    /// - Parameter head: 状态快照中的 HEAD 提交；未出生分支为 nil。最近信息按该哈希复用。
    public func context(head: String?) async throws -> WorkingCopyContext {
        guard head.map(GitObjectID.isValid) ?? true else {
            throw RepositoryReadError.invalidQuery
        }

        // 三项读取互不依赖，并发执行；服务器上只占一次往返的等待时间。
        async let identity = runner.execute(["var", "GIT_COMMITTER_IDENT"], acceptedExitCodes: [0, 128])
        async let message = lastMessage(of: head)
        async let state = stateFiles(OperationProgress.stateFiles)

        let rawIdentity = String(decoding: try await identity.standardOutput, as: UTF8.self)
        let committer = rawIdentity.lastIndex(of: ">")
            .map { String(rawIdentity[...$0]) } ?? ""
        let lastMessage = try await message
        let files = try await state

        // 进行中的操作与它的两侧、步数和已解决的冲突都从同一份状态文件快照算出
        let progress = try await OperationProgress.read(files: files, head: head, runner: runner)

        // Git 生成的冲突清单不属于提交正文，预填时移除其注释行。
        let mergeMessage = (files["SQUASH_MSG"] ?? files["MERGE_MSG"] ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("#") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
        return WorkingCopyContext(
            committer: committer,
            lastMessage: lastMessage,
            operation: progress?.state,
            progress: progress,
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
    ///
    /// 逐字节的两侧补丁始终计入摘要；忽略空白时另取显示用的补丁，同样计入，外部只改空白也能察觉。
    func snapshot(_ entry: StatusEntry, options: DiffOptions = DiffOptions()) async throws -> DiffContents {
        let statusArguments = ["--literal-pathspecs", "status", "--porcelain=v2", "-z", "--untracked-files=all", "--"]
            + entry.operationPaths
        var exactOptions = options
        exactOptions.ignoresWhitespace = false

        let before = try await runner.run(statusArguments)
        let staged = try await patch(for: entry, side: .staged, options: exactOptions)
        let unstaged = try await patch(for: entry, side: .unstaged, options: exactOptions)
        var shown = (staged: staged, unstaged: unstaged)

        if options.ignoresWhitespace {
            shown = (
                try await patch(for: entry, side: .staged, options: options),
                try await patch(for: entry, side: .unstaged, options: options)
            )
        }

        guard try await runner.run(statusArguments) == before else { throw WorkingCopyError.staleSnapshot }
        var hash = SHA256()

        // 选项不同的快照即使补丁恰好相同也不互相冒充
        hash.update(data: Data(options.arguments.joined(separator: " ").utf8))

        for data in [before, staged, unstaged] + (options.ignoresWhitespace ? [shown.staged, shown.unstaged] : []) {
            hash.update(data: Data("\(data.count):".utf8))
            hash.update(data: data)
        }

        return DiffContents(
            staged: shown.staged,
            unstaged: shown.unstaged,
            exactStaged: staged,
            exactUnstaged: unstaged,
            fingerprint: Data(hash.finalize())
        )
    }

    /// 按快照生成时的选项重新读取，摘要相同说明文件与暂存区都没有变化。
    func isCurrent(_ snapshot: DiffSnapshot) async throws -> Bool {
        try await self.snapshot(snapshot.entry, options: snapshot.options).fingerprint == snapshot.fingerprint
    }
}
