import Foundation

// MARK: - RewriteError

/// 改写操作在执行前或执行中发现、Git 自己不会报告的问题。
public enum RewriteError: Error, Sendable {
    /// Git 给出的提交序列与计划时读到的不一致：分支在这期间被其它操作改变，变基没有开始；结果是 Git 的原始输出。
    case sequenceChanged(GitCommandResult?)

    /// 要改写的范围里有合并提交；交互式变基重放时会把它们拍平。
    case mergeCommitsInRange

    /// 所选提交不在当前 HEAD 的历史里，或不在同一条线上。
    case notInHead

    /// 根提交没有父提交，不能撤回到工作区编辑。
    case rootCommit

    /// 并入所选提交需要已暂存的改动。
    case noStagedChanges

    /// 没有带 `fixup!`、`squash!` 或 `amend!` 标记、并能找到目标的提交。
    case nothingToAutosquash

    /// 所选动作缺少必要的提交，或目标与所选提交重合。
    case invalidSelection
}

// MARK: - PickOptions

/// 反转与摘取的选项。
public struct PickOptions: Sendable, Equatable {
    /// 直接提交；关闭时只把改动写进工作区与暂存区（`--no-commit`）。
    public var commit = true

    /// 合并提交的主线父提交序号，从 1 开始；不涉及合并提交时为 nil。
    public var mainline: Int? = nil

    /// 能快进时直接快进（`--ff`），只对直接提交的摘取有效。
    public var fastForward = false

    /// 默认直接提交、不指定主线、不快进。
    public init() { }
}

// MARK: - ResetMode

/// 重置 HEAD 的三档：决定暂存区与工作区是否跟着回到目标版本。
public enum ResetMode: String, Sendable, CaseIterable {
    /// 只移动 HEAD，被撤下的提交的改动留在暂存区。
    case soft

    /// 移动 HEAD 并重置暂存区，改动留在工作区。
    case mixed

    /// 移动 HEAD 并让暂存区、工作区都回到目标版本，未提交的改动会被丢弃。
    case hard
}

// MARK: - CheckoutTarget

/// 检出版本的去向：切换到本地分支，或让 HEAD 分离在某个提交上。
public enum CheckoutTarget: Sendable, Equatable {
    /// 本地分支的完整引用名。
    case branch(String)

    /// 分离 HEAD 所在的提交。
    case detached(String)
}

// MARK: - RewriteImpact

/// 改写前的影响范围：会被改写的提交，以及其中已推送到上游或已并入其它分支的提交。
public struct RewriteImpact: Sendable {
    /// 会被改写的提交，从新到旧。
    public let commits: [HistoryCommit]

    /// 已在上游分支中的提交。
    public let pushed: Set<String>

    /// 已并入其它分支的提交。
    public let merged: Set<String>
}

// MARK: - RepositoryRewrite

/// 反转、摘取、重置、检出版本、变基到别处与交互式变基；写入都经 Git 在仓库所在的机器上执行。
public struct RepositoryRewrite: Sendable {
    /// 交互式变基中止时，序列编辑器写到标准错误的标记。
    static let sequenceChangedMarker = "spooky-rewrite: commit sequence changed"

    /// 目标仓库的执行器。
    let runner: GitRunner

    /// 创建在指定仓库上执行改写操作的实例。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 提交标识必须是完整或缩写的十六进制哈希，拒绝空列表、选项与修订表达式。
    static func validate(_ commits: [String]) throws {
        guard !commits.isEmpty, commits.allSatisfy(GitObjectID.isValid) else {
            throw RepositoryReadError.invalidQuery
        }
    }

    /// 按给定顺序读取提交的元信息，供对话框显示标题与判断合并提交。
    public func commits(_ ids: [String]) async throws -> [HistoryCommit] {
        guard !ids.isEmpty else {
            return []
        }

        try Self.validate(ids)

        let output = try await runner.run(
            ["log", "--no-color", "--no-decorate", "--no-patch", "--no-walk=unsorted", "-z", HistoryCommit.format]
                + ids
        )

        return try HistoryCommit.parse(output)
    }

    /// 在当前 HEAD 上生成抵消所给提交的提交；多个提交按给定顺序反转，信息使用 Git 生成的默认文字。
    public func revert(
        _ commits: [String],
        options: PickOptions,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try Self.validate(commits)

        var arguments = ["-c", "core.trustctime=false", "revert", "--no-edit"]

        if let mainline = options.mainline { arguments += ["--mainline", String(mainline)] }

        if !options.commit { arguments.append("--no-commit") }

        _ = try await runner.execute(arguments + commits, onOutput: onOutput)
    }

    /// 把所给提交的改动按给定顺序应用到当前 HEAD。
    public func cherryPick(
        _ commits: [String],
        options: PickOptions,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try Self.validate(commits)

        var arguments = ["-c", "core.trustctime=false", "cherry-pick"]

        if let mainline = options.mainline { arguments += ["--mainline", String(mainline)] }

        if !options.commit {
            arguments.append("--no-commit")
        } else if options.fastForward {
            arguments.append("--ff")
        }

        _ = try await runner.execute(arguments + commits, onOutput: onOutput)
    }

    /// 把 HEAD 重置到指定版本；版本先解析成提交，末尾的 `--` 让 Git 不把它当作路径。
    public func reset(to revision: String, mode: ResetMode) async throws {
        try await runner.writeTransaction {
            let commit = try await resolve(revision)
            _ = try await runner.run(["reset", "-q", "--" + mode.rawValue, commit, "--"])
        }
    }

    /// 重置后离开当前分支的提交，从新到旧，最多 `limit` 个；目标在 HEAD 之后时为空。
    public func commitsLeaving(to revision: String, limit: Int = 100) async throws -> [HistoryCommit] {
        let commit = try await resolve(revision)
        let output = try await runner.run([
            "log", "--no-color", "--no-decorate", "--no-patch", "--topo-order", "-z", "--max-count=\(limit)",
            HistoryCommit.format, "HEAD", "^" + commit, "--",
        ])

        return try HistoryCommit.parse(output)
    }

    /// 判断检出的去向：完整的本地分支引用或本地分支名切换分支，其余版本解析成提交后分离 HEAD。
    public func checkoutTarget(for revision: String) async throws -> CheckoutTarget {
        let reference = revision.hasPrefix("refs/heads/") ? revision : "refs/heads/" + revision

        // 只认已存在的本地分支，名字不是合法引用时同样按版本解析
        let branch = try await runner.execute(
            ["rev-parse", "--verify", "--quiet", "--end-of-options", reference],
            acceptedExitCodes: [0, 1, 128]
        )

        if branch.exitCode == 0 {
            return .branch(reference)
        }

        return .detached(try await resolve(revision))
    }

    /// 检出任意版本：本地分支照常切换，其余版本分离 HEAD；判断与切换在同一个写事务里完成。
    public func checkout(revision: String) async throws {
        try await runner.writeTransaction {
            switch try await checkoutTarget(for: revision) {
            case .branch(let reference):
                try await RepositoryReferences(runner: runner).checkout(reference)

            case .detached(let commit):
                _ = try await runner.run(["switch", "--detach", commit])
            }
        }
    }

    /// 把当前分支上不在 `currentBase` 里的提交重放到 `newBase` 之上（`rebase --onto`）。
    ///
    /// - Parameters:
    ///   - newBase: 新的基点。
    ///   - currentBase: 当前的基点，它之后的提交会被移走。
    ///   - skipHooks: 跳过 pre-rebase 钩子。
    public func rebase(
        onto newBase: String,
        from currentBase: String,
        skipHooks: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let onto = try await resolve(newBase)
            let upstream = try await resolve(currentBase)

            var arguments = [
                "-c", "core.trustctime=false", "-c", "core.editor=:",
                "rebase", "--no-autostash", "--no-autosquash",
            ]

            if skipHooks { arguments.append("--no-verify") }

            _ = try await runner.execute(arguments + ["--onto", onto, upstream], onOutput: onOutput)
        }
    }

    /// 变基到别处会移动的提交（当前基点之后、HEAD 之前），最多 `limit` 个，并标出已推送与已并入其它分支的。
    public func rebasePreview(from currentBase: String, limit: Int = 200) async throws -> RewriteImpact {
        let base = try await resolve(currentBase)
        let commits = try await commitsLeaving(to: base, limit: limit)
        let impact = try await impact(of: Array(commits.reversed()), base: base)

        return RewriteImpact(commits: commits, pushed: impact.pushed, merged: impact.merged)
    }

    /// 把版本解析成一个提交；`--end-of-options` 阻止输入被当成 Git 选项。
    func resolve(_ revision: String) async throws -> String {
        try await RepositoryReferences(runner: runner).resolve(revision)
    }
}
