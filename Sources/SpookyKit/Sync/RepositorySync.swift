import Foundation

// MARK: - RepositorySyncError

/// 发起同步前的仓库条件错误，不伪造 Git 输出。
public enum RepositorySyncError: Error, Sendable, Equatable {
    /// 合并和拉取必须从干净工作区开始。
    case dirtyWorkingCopy

    /// 当前操作需要已出生且附着的本地分支。
    case requiresBranch

    /// 选择的远端已不存在。
    case missingRemote

    /// 不弹对话框的快速操作以跟踪分支为对象，分支没有跟踪分支时无法执行。
    case missingUpstream
}

// MARK: - RemoteReferenceUpdate

/// Fetch / Push porcelain 的引用更新结果，原始输出仍留在命令结果中。
public struct RemoteReferenceUpdate: Sendable, Equatable {
    /// Git 协议中的状态标志。
    public let flag: Character

    /// 更新的完整目标引用。
    public let reference: String

    /// Fetch 前的对象标识。
    public let oldObject: String?

    /// Fetch 后的对象标识。
    public let newObject: String?

    /// Push 的源引用。
    public let source: String?

    /// Push 的结果说明原文。
    public let summary: String?

    /// Fetch 使用空格分隔的机器格式，首字符本身可能是空格。
    static func parseFetch(_ data: Data) throws -> [Self] {
        try String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { line in
                guard
                    line.count > 2,
                    let flag = line.first,
                    " *+-=!t".contains(flag),
                    line.dropFirst().first == " "
                else {
                    throw RepositoryReadError.malformedOutput("fetch --porcelain")
                }

                let fields = line.dropFirst(2).split(separator: " ", omittingEmptySubsequences: false)

                guard
                    fields.count == 3,
                    GitObjectID.isValid(String(fields[0])),
                    GitObjectID.isValid(String(fields[1])),
                    !fields[2].isEmpty
                else {
                    throw RepositoryReadError.malformedOutput("fetch --porcelain")
                }

                return Self(
                    flag: flag,
                    reference: String(fields[2]),
                    oldObject: String(fields[0]),
                    newObject: String(fields[1]),
                    source: nil,
                    summary: nil
                )
            }
    }

    /// Push 的 tab 字段与 Fetch 独立解析，不把 stderr 进度混入协议。
    static func parsePush(_ data: Data) throws -> [Self] {
        var updates: [Self] = []

        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            if line.hasPrefix("To ") || line == "Done" || line.hasPrefix("branch '") {
                continue
            }

            let fields = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)

            guard
                fields.count == 3,
                fields[0].count == 1,
                let flag = fields[0].first,
                " *+-=!".contains(flag)
            else {
                throw RepositoryReadError.malformedOutput("push --porcelain")
            }

            let refs = fields[1].split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

            guard refs.count == 2, !refs[1].isEmpty else {
                throw RepositoryReadError.malformedOutput("push --porcelain")
            }

            updates.append(
                Self(
                    flag: flag,
                    reference: String(refs[1]),
                    oldObject: nil,
                    newObject: nil,
                    source: String(refs[0]),
                    summary: String(fields[2])
                )
            )
        }

        return updates
    }
}

// MARK: - MergePreview

/// 合并预览以退出状态判定，检查失败保留原始诊断。
public enum MergePreview: Sendable {
    /// 目标已是 HEAD 的祖先。
    case unchanged

    /// Git 预览没有冲突。
    case clean

    /// Git 预览发现冲突，路径按 NUL 读取。
    case conflicts([String])

    /// 当前环境无法计算预览，不能当作可干净合并。
    case unavailable(String)
}

// MARK: - MergeOptions

/// 合并对话框的显式选项，不依赖用户的 merge.ff 等全局默认。
public struct MergeOptions: Sendable {
    /// 把改动放入暂存区，随后由提交区创建压缩提交。
    public var squash = false

    /// 即使能够快进也创建合并提交。
    public var alwaysCreateCommit = false

    /// 非快进合并完成后立即提交。
    public var commit = true

    /// 要求目标提交有可信签名。
    public var verifySignatures = false

    /// 用户明确要求跳过相关钩子。
    public var skipHooks = false

    /// 默认允许快进，普通合并自动提交。
    public init() { }
}

// MARK: - SubmodulePushMode

/// 推送时对子模块的处理，对应 `push --recurse-submodules` 的两种取值。
public enum SubmodulePushMode: String, Sendable, CaseIterable {
    /// 先推送子模块里远端还没有的提交。
    case onDemand = "on-demand"

    /// 推送前确认子模块引用的提交都已在远端，否则拒绝推送。
    case check
}

// MARK: - PushOptions

/// 推送对话框的附带选项；默认不推标签、不处理子模块、照常运行钩子。
public struct PushOptions: Sendable, Equatable {
    /// 在本次 refspec 之外推送全部标签。
    public var allTags = false

    /// 递归处理子模块的方式；nil 表示不处理子模块。
    public var submodules: SubmodulePushMode? = nil

    /// 用户明确要求跳过 pre-push 钩子。
    public var skipHooks = false

    /// 默认的推送选项。
    public init() { }
}

// MARK: - RepositorySync

/// 获取、拉取、推送与合并在统一仓库写队列内完成。
public struct RepositorySync: Sendable {
    /// 仓库所在机器的命令执行器。
    public let runner: GitRunner

    /// 创建同步服务；认证由执行器提供。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// nil 表示全部远端，跳过设了 `skipFetchAll` 的远端；每个远端都使用 porcelain，并持续转发 stderr 进度。
    ///
    /// - Parameters:
    ///   - remote: 指定的远端；明确指定时即使设了 `skipFetchAll` 也照常获取。
    ///   - prune: 清理远端已删除的跟踪引用。
    ///   - allTags: 在默认 refspec 之外获取全部标签。
    ///   - submodules: 同时获取全部已检出子模块的新提交。
    public func fetch(
        remote: String? = nil,
        prune: Bool = false,
        allTags: Bool = false,
        submodules: Bool = false,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws -> [RemoteReferenceUpdate] {
        try await runner.writeTransaction {
            let selected = try await fetchTargets(remote)
            var updates: [RemoteReferenceUpdate] = []

            for name in selected {
                try Task.checkCancellation()

                var arguments = [
                    "fetch", "--porcelain", "--progress", "--no-recurse-submodules", "--no-auto-maintenance",
                    prune ? "--prune" : "--no-prune",
                ]

                if allTags {
                    arguments.append("--tags")
                }

                let result = try await runner.execute(arguments + ["--", name], onOutput: onOutput)
                updates += try RemoteReferenceUpdate.parseFetch(result.standardOutput)
            }

            if submodules, !selected.isEmpty {
                try await fetchSubmodules(onOutput: onOutput)
            }

            return updates
        }
    }

    /// 获取选定分支后显式执行 merge 或 rebase，两个阶段共用同一写锁。
    public func pull(
        remote: String? = nil,
        branch: String? = nil,
        rebase: Bool,
        verifySignatures: Bool = false,
        skipHooks: Bool = false,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            let status = try await runner.status()

            guard let current = status.branch.head, status.branch.oid != nil else {
                throw RepositorySyncError.requiresBranch
            }

            guard status.entries.isEmpty else {
                throw RepositorySyncError.dirtyWorkingCopy
            }

            let target = try await pullTarget(remote: remote, branch: branch, current: current)
            let fetched = try await fetchPullTarget(target, onOutput: onOutput)

            guard rebase else {
                var options = MergeOptions()
                options.verifySignatures = verifySignatures
                options.skipHooks = skipHooks
                try await merge(fetched, options: options, onOutput: onOutput)
                return
            }

            // 变基没有 merge 的签名校验参数，先单独校验取回的提交
            if verifySignatures {
                _ = try await runner.execute(["verify-commit", fetched], onOutput: onOutput)
            }

            try await rebaseCurrentBranch(onto: fetched, skipHooks: skipHooks, onOutput: onOutput)
        }
    }

    /// 预览不改动工作树；merge-tree 生成的临时树对象仍由仓库队列串行调度。
    public func previewMerge(_ revision: String) async throws -> MergePreview {
        do {
            let references = RepositoryReferences(runner: runner)
            let head = try await references.resolve("HEAD")
            let target = try await references.resolve(revision)

            let ancestor = try await runner.execute(
                ["merge-base", "--is-ancestor", target, head],
                acceptedExitCodes: [0, 1]
            )

            if ancestor.exitCode == 0 {
                return .unchanged
            }

            let result = try await runner.execute(
                ["merge-tree", "--write-tree", "--name-only", "-z", "--no-messages", head, target],
                acceptedExitCodes: [0, 1]
            )

            let fields = result.standardOutput
                .split(separator: 0)
                .map { String(decoding: $0, as: UTF8.self) }

            guard let tree = fields.first, GitObjectID.isValid(tree) else {
                throw RepositoryReadError.malformedOutput("merge-tree")
            }

            return result.exitCode == 0 ? .clean : .conflicts(Array(fields.dropFirst()))
        } catch {
            if Task.isCancelled || ((error as? GitError)?.isCancelled ?? false) || error is CancellationError {
                throw CancellationError()
            }

            if error is RemoteConnectionError {
                throw error
            }

            let details =
                (error as? GitError)
                    .map { String(decoding: $0.result.standardError + $0.result.standardOutput, as: UTF8.self) }
                    ?? String(describing: error)

            return .unavailable(details)
        }
    }

    /// 合并前再次读取工作区，避免对话框打开期间新增的改动被覆盖。
    public func merge(
        _ revision: String,
        options: MergeOptions = MergeOptions(),
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            guard try await runner.status().entries.isEmpty else {
                throw RepositorySyncError.dirtyWorkingCopy
            }

            let target = try await RepositoryReferences(runner: runner).resolve(revision)
            var arguments = ["-c", "merge.autoStash=false", "merge", "--no-edit", "--no-autostash"]

            // 压缩合并留下暂存区，普通合并明确指定快进与提交策略。
            if options.squash {
                arguments += ["--squash", "--ff", "--no-commit"]
            } else {
                arguments += [options.alwaysCreateCommit ? "--no-ff" : "--ff"]
                arguments += [options.commit ? "--commit" : "--no-commit"]
            }

            arguments.append(
                options.verifySignatures && !options.squash ? "--verify-signatures" : "--no-verify-signatures"
            )

            if options.skipHooks {
                arguments.append("--no-verify")
            }

            _ = try await runner.execute(arguments + [target], onOutput: onOutput)
        }
    }
}

// MARK: - Helpers

extension RepositorySync {
    /// 解析 `config -z --get-regexp` 读出的 `remote.<名称>.skipFetchAll`，返回自动获取与获取全部远端时跳过的远端。
    ///
    /// 键的第一个点与最后一个点之间是远端名，名字本身可以含点；只写键不写值同样表示真。
    static func skippedRemotes(in data: Data) throws -> Set<String> {
        var skipped = Set<String>()

        for record in data.split(separator: 0) {
            let key = String(decoding: record.prefix { $0 != 10 }, as: UTF8.self)
            let value = record.firstIndex(of: 10).map { String(decoding: record[($0 + 1)...], as: UTF8.self) }

            guard
                key.hasPrefix("remote."),
                let last = key.lastIndex(of: "."),
                last > key.index(key.startIndex, offsetBy: 6),
                key[key.index(after: last)...].lowercased() == "skipfetchall"
            else {
                throw RepositoryReadError.malformedOutput("remote config")
            }

            // 同一个键出现多次时，Git 采用最后一次的值
            let name = String(key[key.index(key.startIndex, offsetBy: 7) ..< last])

            if ["true", "yes", "on", "1", ""].contains(value?.lowercased() ?? "") {
                skipped.insert(name)
            } else {
                skipped.remove(name)
            }
        }

        return skipped
    }

    /// 把当前分支变基到指定提交上；关掉自动储藏与编辑器，钩子按选择运行。
    func rebaseCurrentBranch(
        onto target: String,
        skipHooks: Bool,
        onOutput: (@Sendable (GitOutputEvent) -> Void)?
    ) async throws {
        _ = try await runner.execute(
            [
                "-c", "core.editor=:",
                "-c", "rebase.autoStash=false",
                "rebase", "--merge", "--no-autostash", "--no-rebase-merges", "--no-update-refs",
                skipHooks ? "--no-verify" : "--verify",
                target,
            ],
            onOutput: onOutput
        )
    }

    /// 未显式指定来源时读取当前分支的跟踪信息，缺失时保留 Git 的原始错误。
    func pullTarget(
        remote: String?,
        branch: String?,
        current: String
    ) async throws -> (remote: String, branch: String) {
        let references = RepositoryReferences(runner: runner)
        let snapshot = try await references.snapshot()
        let head = snapshot.references.first { $0.id == "refs/heads/" + current }

        guard
            let remote = remote ?? head?.upstreamRemote,
            let branch = branch ?? head?.upstreamBranch
        else {
            _ = try await runner.run(["rev-parse", "--verify", "@{upstream}"])
            throw RepositorySyncError.requiresBranch
        }

        guard remote == "." || snapshot.remotes.contains(where: { $0.name == remote }) else {
            throw RepositorySyncError.missingRemote
        }

        guard branch.hasPrefix("refs/heads/") else {
            throw RepositoryReadError.invalidQuery
        }

        try await references.validate(name: String(branch.dropFirst(11)))
        return (remote, branch)
    }

    /// 只获取拉取目标这一个分支，返回本次获取写入 FETCH_HEAD 的提交。
    func fetchPullTarget(
        _ target: (remote: String, branch: String),
        onOutput: (@Sendable (GitOutputEvent) -> Void)?
    ) async throws -> String {
        let result = try await runner.execute(
            [
                "fetch", "--porcelain", "--progress", "--no-recurse-submodules", "--no-auto-maintenance",
                "--no-tags", "--", target.remote, target.branch,
            ],
            onOutput: onOutput
        )

        _ = try RemoteReferenceUpdate.parseFetch(result.standardOutput)

        // FETCH_HEAD 固定为本次单分支获取结果，不能复用可能陈旧的跟踪引用。
        return try await RepositoryReferences(runner: runner).resolve("FETCH_HEAD")
    }

    /// 要获取的远端：指定的远端必须存在；未指定时是全部远端，去掉设了 `skipFetchAll` 的。
    private func fetchTargets(_ remote: String?) async throws -> [String] {
        let remotes = try await RepositoryReferences(runner: runner).snapshot().remotes.map(\.name)

        guard !remotes.isEmpty, remote.map(remotes.contains) ?? true else {
            throw RepositorySyncError.missingRemote
        }

        if let remote {
            return [remote]
        }

        // 没有任何记录时 config 以 1 退出，是正常的空结果
        let result = try await runner.execute(
            ["config", "-z", "--get-regexp", "^remote\\..*\\.skipfetchall$"],
            acceptedExitCodes: [0, 1]
        )

        let skipped = try Self.skippedRemotes(in: result.standardOutput)
        return remotes.filter { !skipped.contains($0) }
    }

    /// porcelain 输出不能与递归子模块同用，子模块在仓库本身获取完之后逐个获取。
    private func fetchSubmodules(onOutput: (@Sendable (GitOutputEvent) -> Void)?) async throws {
        _ = try await runner.execute(
            [
                "submodule", "--quiet", "foreach", "--recursive",
                "git fetch --progress --no-auto-maintenance",
            ],
            onOutput: onOutput
        )
    }
}
