import Foundation

// MARK: - RepositoryUndo

/// 撤销与重做的命令层：记下仓库状态，并在核对现状后把仓库恢复成另一份记录。
///
/// 快照建在仓库所在的机器上（`write-tree`、`stash create` 只写对象库），调用方只保存哈希。
public struct RepositoryUndo: Sendable {
    /// 共享的本机或服务器执行器。
    public let runner: GitRunner

    /// 创建撤销服务。
    public init(runner: GitRunner) {
        self.runner = runner
    }

    /// 记下当前状态；有进行中的操作或未解决的冲突时拒绝，这时的状态不能安全恢复。
    public func capture() async throws -> RepositoryState {
        // 三项读取互不依赖，并发执行
        async let loadedStatus = runner.status()
        async let loadedReferences = runner.run([
            "for-each-ref", RepositoryState.referenceFormat, "refs/heads", "refs/tags", "refs/stash",
        ])
        async let loadedFiles = WorkingCopyOperations(runner: runner).stateFiles(OperationProgress.stateFiles)

        let status = try await loadedStatus
        let parsed = try RepositoryState.parseReferences(await loadedReferences)
        let files = try await loadedFiles

        guard OperationProgress(files: files, head: status.branch.oid) == nil else {
            throw RepositoryUndoError.operationInProgress
        }

        guard !status.entries.contains(where: { $0.kind == .conflicted }) else {
            throw RepositoryUndoError.unresolvedConflicts
        }

        let stashes = parsed.hasStash ? try await stashList() : []
        let index = try await objectID(["write-tree"])

        // 只有已跟踪文件在工作区里还有未暂存的改动时，工作区才与索引不同
        let dirty = status.entries.contains { $0.kind == .tracked && $0.unstaged != nil }

        return RepositoryState(
            headBranch: status.branch.head.map { "refs/heads/" + $0 },
            head: status.branch.oid,
            references: parsed.references,
            peeledReferences: parsed.peeled,
            stashes: stashes,
            index: index,
            worktree: dirty ? try await worktreeTree(index: index) : index,
            entries: status.entries
        )
    }

    /// 把仓库从 `expected` 恢复成 `target`：先完整核对现状仍是 `expected`，不一致时不做任何改动。
    ///
    /// - Parameters:
    ///   - target: 要回到的状态。
    ///   - expected: 记录时仓库应处的状态，即撤销时的操作后状态、重做时的操作前状态。
    ///   - message: 写进引用日志的说明。
    public func restore(_ target: RepositoryState, expecting expected: RepositoryState, message: String) async throws {
        try await runner.writeTransaction {
            let current = try await capture()

            guard current == expected else {
                throw RepositoryUndoError.repositoryChanged
            }

            let plan = try await plan(from: current, to: target)
            try await checkHiddenChanges()

            // 文件最容易失败，先恢复；引用与储藏随后一次更新
            try await restoreFiles(target, plan: plan)
            try await restoreReferences(from: current, to: target, message: message)
            try await restoreStashes(from: current, to: target)
        }
    }

    /// 只判断能否从 `current` 恢复到 `target`，不改动仓库；未跟踪文件找不回内容时返回 false。
    public func canRestore(_ target: RepositoryState, from current: RepositoryState) async throws -> Bool {
        do {
            _ = try await plan(from: current, to: target)
            return true
        } catch RepositoryUndoError.untrackedFiles {
            return false
        }
    }
}

// MARK: - Capture

extension RepositoryUndo {
    /// 储藏列表，从新到旧；屏蔽用户的签名与编码配置。
    private func stashList() async throws -> [StashRecord] {
        let output = try await runner.run([
            "-c", "log.showSignature=false", "-c", "i18n.logOutputEncoding=UTF-8",
            "stash", "list", "-z", "--no-color", RepositoryState.stashFormat,
        ])

        return try RepositoryState.parseStashes(output)
    }

    /// 已跟踪文件在工作区里的内容：`stash create` 不改动工作区、索引与储藏列表，只写出储藏提交。
    ///
    /// 工作区与 HEAD 没有差别时它不输出任何内容，这时工作区就是索引。
    private func worktreeTree(index: String) async throws -> String {
        let output = try await runner.run(["stash", "create"])
        let commit = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !commit.isEmpty else {
            return index
        }

        guard GitObjectID.isValid(commit) else {
            throw RepositoryReadError.malformedOutput("stash create")
        }

        return try await objectID(["rev-parse", "--verify", "-q", commit + "^{tree}"])
    }

    /// 执行只输出一个对象哈希的命令。
    func objectID(_ arguments: [String]) async throws -> String {
        let output = try await runner.run(arguments)
        let value = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard GitObjectID.isValid(value) else {
            throw RepositoryReadError.malformedOutput(arguments.first ?? "")
        }

        return value
    }
}

// MARK: - References

extension RepositoryUndo {
    /// 分支与标签在一个 `update-ref --stdin` 事务里更新，旧值不符时整体失败；HEAD 随后单独指回。
    private func restoreReferences(
        from current: RepositoryState,
        to target: RepositoryState,
        message: String
    ) async throws {
        var commands = Data()

        for name in Set(current.references.keys).union(target.references.keys).sorted() {
            let command: String? =
                switch (current.references[name], target.references[name]) {
                case (let old?, let new?) where old != new: "update " + name + "\0" + new + "\0" + old + "\0"
                case (nil, let new?): "create " + name + "\0" + new + "\0"
                case (let old?, nil): "delete " + name + "\0" + old + "\0"
                default: nil
                }

            if let command { commands.append(Data(command.utf8)) }
        }

        if !commands.isEmpty {
            _ = try await runner.run(["update-ref", "-m", message, "-z", "--stdin"], input: commands)
        }

        // 指向的分支没变时，HEAD 已随分支一起回到原处
        if let branch = target.headBranch, branch != current.headBranch {
            _ = try await runner.run(["symbolic-ref", "-m", message, "HEAD", branch])
        } else if target.headBranch == nil, let head = target.head, current.headBranch != nil || current.head != head {
            _ = try await runner.run(["update-ref", "--no-deref", "-m", message, "HEAD", head])
        }
    }

    /// 储藏列表保留两边共同的较旧部分：先删掉现状多出的较新储藏，再从旧到新登记目标里的较新储藏。
    private func restoreStashes(from current: RepositoryState, to target: RepositoryState) async throws {
        let now = current.stashes.map(\.id)
        let wanted = target.stashes.map(\.id)
        var shared = 0

        while
            shared < now.count, shared < wanted.count,
            now[now.count - 1 - shared] == wanted[wanted.count - 1 - shared]
        {
            shared += 1
        }

        for _ in 0 ..< (now.count - shared) {
            _ = try await runner.run(["stash", "drop", "-q", "stash@{0}"])
        }

        for record in target.stashes.prefix(wanted.count - shared).reversed() {
            _ = try await runner.run(["stash", "store", "-q", "-m", record.message, record.id])
        }
    }
}
