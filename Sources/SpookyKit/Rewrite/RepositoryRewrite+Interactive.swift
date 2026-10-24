import Foundation

// MARK: - Interactive Rebase

extension RepositoryRewrite {
    /// 读取会被改写的范围并算好 todo：HEAD 必须已有提交，所选提交都在 HEAD 的同一条历史线上，范围里没有合并提交。
    public func plan(_ action: RewriteAction) async throws -> RewritePlan {
        let head = try await resolve("HEAD")
        let requested = Self.selection(of: action)
        let selection = try await commits(requested).map(\.id)

        // 重复的提交会让读回的列表变短，与动作里的位置对不上
        guard selection.count == requested.count, Set(selection).count == selection.count else {
            throw RewriteError.invalidSelection
        }

        let action = Self.normalized(action, with: selection)
        let oldest = try await oldestCommit(for: action, selection: selection)

        // 范围从最旧的那个提交开始，它的父提交是变基的上游；根提交没有父提交，改用 --root
        guard let start = try await commits([oldest]).first, start.parents.count <= 1 else {
            throw RewriteError.mergeCommitsInRange
        }

        let range = try await rangeCommits(after: start.parents.first)

        guard range.allSatisfy({ $0.parents.count <= 1 }) else {
            throw RewriteError.mergeCommitsInRange
        }

        let ids = Set(range.map(\.id))

        guard selection.allSatisfy(ids.contains) else {
            throw RewriteError.notInHead
        }

        try await checkPreconditions(of: action, in: range)

        let impact = try await impact(of: range, base: start.parents.first)
        let onto: String? = if case .rebase(_, let target) = action { try await resolve(target) } else { nil }

        return RewritePlan(
            action: action,
            head: head,
            base: start.parents.first,
            onto: onto,
            commits: range,
            instructions: try Self.instructions(for: action, in: range),
            pushed: impact.pushed,
            merged: impact.merged
        )
    }

    /// 按计划执行交互式变基；HEAD 在计划之后被移动过，或 Git 给出的提交序列与计划不一致时，不改写任何提交。
    ///
    /// - Parameter skipHooks: 跳过 pre-rebase 钩子，变基到别处的对话框提供这个选项。
    public func perform(
        _ plan: RewritePlan,
        skipHooks: Bool = false,
        onOutput: (@Sendable (GitOutputEvent) -> Void)? = nil
    ) async throws {
        try await runner.writeTransaction {
            guard try await resolve("HEAD") == plan.head else {
                throw RewriteError.sequenceChanged(nil)
            }

            var instructions = plan.instructions
            var fixup: String? = nil

            // 暂存的改动先写成一个不挂在分支上的 fixup 提交，再在 todo 里紧跟目标
            if case .amend(let target) = plan.action, let commit = plan.commits.first(where: { $0.id == target }) {
                let created = try await fixupCommit(for: commit, head: plan.head)
                let index = (instructions.firstIndex { $0.commit == target } ?? instructions.count - 1) + 1
                instructions.insert(
                    RebaseInstruction(command: .fixup, commit: created, subject: "fixup! " + commit.subject),
                    at: index
                )
                fixup = created
            }

            do {
                _ = try await runner.execute(
                    Self.rebaseArguments(plan, instructions: instructions, skipHooks: skipHooks),
                    onOutput: onOutput
                )
            } catch {
                if let fixup { try await restoreIndex(from: fixup, head: plan.head) }

                if let git = error as? GitError, Self.isSequenceChange(git.result) {
                    throw RewriteError.sequenceChanged(git.result)
                }

                throw error
            }

            if case .edit = plan.action { try await reopenEditedCommit() }
        }
    }
}

// MARK: - Todo

extension RepositoryRewrite {
    /// 去掉标题开头连续的 `fixup! `、`squash! `、`amend! ` 标记；没有标记时为 nil。
    static func autosquashReference(of subject: String) -> String? {
        var reference = subject
        let markers = ["fixup! ", "squash! ", "amend! "]

        while let marker = markers.first(where: reference.hasPrefix) {
            reference = String(reference.dropFirst(marker.count))
        }

        return reference == subject || reference.isEmpty ? nil : reference
    }

    /// 所给动作的 todo：除 Autosquash 外，范围里的每个提交都有一行，删除的提交写成显式的 drop。
    static func instructions(for action: RewriteAction, in range: [HistoryCommit]) throws -> [RebaseInstruction] {
        let line = { (commit: HistoryCommit, command: RebaseInstruction.Command) in
            RebaseInstruction(command: command, commit: commit.id, subject: commit.subject)
        }

        switch action {
        case .drop(let selected):
            return range.map { line($0, selected.contains($0.id) ? .drop : .pick) }

        case .edit(let target):
            return range.map { line($0, $0.id == target ? .edit : .pick) }

        case .reword(let target, _):
            return range.map { line($0, $0.id == target ? .reword : .pick) }

        case .amend:
            return range.map { line($0, .pick) }

        case .autosquash:
            return []

        case .rebase(let selected, _):
            return range.map { line($0, selected.contains($0.id) ? .pick : .drop) }

        case .squash(let selected, let target):
            return try combined(selected, into: target, command: .squash, in: range)

        case .fixup(let selected, let target):
            return try combined(selected, into: target, command: .fixup, in: range)

        case .move(let selected, let target, let position):
            return try moved(selected, to: target, position: position, in: range)
        }
    }

    /// 内联的序列编辑器：先核对 Git 生成的 todo 里的提交，一致时整份换成事先算好的指令。
    ///
    /// 核对按前缀比对，Git 写的缩写哈希也能对上；`ordered` 为假时只比集合，供 Git 自己重排的 Autosquash 使用。
    /// 不一致时把标记写到标准错误并以 1 退出，Git 随即中止变基、不改动任何提交。
    static func sequenceEditor(expected: [String], instructions: [RebaseInstruction], ordered: Bool) -> String {
        let program = [
            #"BEGIN { n = split(e, x, " ") }"#,
            #"/^[[:space:]]*(#|$)/ { next }"#,
            #"{ h = ($2 ~ /^-/) ? $3 : $2; c++; m = 0"#,
            #"for (k = 1; k <= n; k++) if (!u[k] && (!o || k == c) && length(h) >= 4 && index(x[k], h) == 1) { u[k] = 1; m = 1; break }"#,
            #"if (!m) f = 1 }"#,
            #"END { exit (f || c != n) }"#,
        ]
        .joined(separator: "\n")

        let check = "awk -v o=\(ordered ? 1 : 0) -v e='\(expected.joined(separator: " "))' '\(program)' \"$1\""
        let failure = "{ echo '\(sequenceChangedMarker)' >&2; return 1; }"
        let lines = instructions.map { GitRunner.shellQuoted($0.line) }.joined(separator: " ")
        let write = instructions.isEmpty ? "" : "; printf '%s\\n' \(lines) > \"$1\""

        return "spooky_todo() { \(check) || \(failure)\(write); }; spooky_todo"
    }

    /// 是否是序列编辑器发现提交序列被改变而中止的失败。
    static func isSequenceChange(_ result: GitCommandResult) -> Bool {
        String(decoding: result.standardError, as: UTF8.self).contains(sequenceChangedMarker)
    }
}

// MARK: - Private

extension RepositoryRewrite {
    /// 范围里最旧的提交：所选提交在一条线上时，它们的公共祖先就是其中最旧的一个。
    private func oldestCommit(for action: RewriteAction, selection: [String]) async throws -> String {
        if case .autosquash = action {
            return try await autosquashOldest()
        }

        guard let first = selection.first else {
            throw RewriteError.invalidSelection
        }

        guard selection.count > 1 else {
            return first
        }

        let output = try await runner.execute(["merge-base", "--octopus"] + selection, acceptedExitCodes: [0, 1])
        let oldest = String(decoding: output.standardOutput, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard selection.contains(oldest) else {
            throw RewriteError.notInHead
        }

        return oldest
    }

    /// 从 HEAD 往回最多 1000 个提交里找带标记的提交，返回它们的目标里最旧的一个。
    ///
    /// 目标是标记提交之前第一个标题相同、标题以引用开头或哈希以引用开头的提交。
    private func autosquashOldest() async throws -> String {
        let output = try await runner.run([
            "log", "--no-color", "--no-decorate", "--no-patch", "--topo-order", "-z", "--max-count=1000",
            HistoryCommit.format, "HEAD", "--",
        ])
        let history = try HistoryCommit.parse(output)
        var oldest: Int?

        for (index, commit) in history.enumerated() {
            guard let reference = Self.autosquashReference(of: commit.subject) else { continue }

            let target = history[(index + 1)...].firstIndex {
                $0.subject == reference || $0.subject.hasPrefix(reference) || $0.id.hasPrefix(reference)
            }

            if let target { oldest = max(oldest ?? target, target) }
        }

        guard let oldest else {
            throw RewriteError.nothingToAutosquash
        }

        return history[oldest].id
    }

    /// 上游之后到 HEAD 的提交，从旧到新；上游为 nil 时是 HEAD 的全部历史。
    private func rangeCommits(after base: String?) async throws -> [HistoryCommit] {
        let output = try await runner.run([
            "log", "--no-color", "--no-decorate", "--no-patch", "--topo-order", "--reverse", "-z",
            HistoryCommit.format, base.map { $0 + "..HEAD" } ?? "HEAD", "--",
        ])

        return try HistoryCommit.parse(output)
    }

    /// 动作自己的前提：根提交不能编辑，并入暂存改动需要有暂存的改动。
    private func checkPreconditions(of action: RewriteAction, in range: [HistoryCommit]) async throws {
        switch action {
        case .edit(let target):
            if range.first(where: { $0.id == target })?.parents.isEmpty ?? true {
                throw RewriteError.rootCommit
            }

        case .amend:
            let staged = try await runner.execute(["diff", "--cached", "--quiet", "HEAD", "--"], acceptedExitCodes: [0, 1])

            if staged.exitCode == 0 {
                throw RewriteError.noStagedChanges
            }

        default:
            break
        }
    }
}

extension RepositoryRewrite {
    /// 动作涉及的提交：所选提交与目标，目标排在最后。
    private static func selection(of action: RewriteAction) -> [String] {
        switch action {
        case .squash(let selected, let target), .fixup(let selected, let target):
            selected + (target.map { [$0] } ?? [])

        case .drop(let selected), .rebase(let selected, _):
            selected

        case .move(let selected, let target, _):
            selected + [target]

        case .edit(let target), .reword(let target, _), .amend(let target):
            [target]

        case .autosquash:
            []
        }
    }

    /// 把调用方给的提交换成读回的完整哈希；读回的顺序与 ``selection(of:)`` 一致。
    private static func normalized(_ action: RewriteAction, with ids: [String]) -> RewriteAction {
        let last = ids.last ?? ""
        let selected = Array(ids.dropLast())

        switch action {
        case .squash(_, let target): return .squash(target == nil ? ids : selected, into: target == nil ? nil : last)
        case .fixup(_, let target): return .fixup(target == nil ? ids : selected, into: target == nil ? nil : last)
        case .drop: return .drop(ids)
        case .rebase(_, let onto): return .rebase(ids, onto: onto)
        case .move(_, _, let position): return .move(selected, to: last, position: position)
        case .edit: return .edit(last)
        case .reword(_, let message): return .reword(last, message: message)
        case .amend: return .amend(last)
        case .autosquash: return .autosquash
        }
    }

    /// 压缩或 fixup：目标保持原位，其余所选提交按历史顺序紧跟其后；不指定目标时以所选提交里最旧的为目标。
    private static func combined(
        _ selected: [String],
        into target: String?,
        command: RebaseInstruction.Command,
        in range: [HistoryCommit]
    ) throws -> [RebaseInstruction] {
        let selected = Set(selected)

        guard let target = target ?? range.first(where: { selected.contains($0.id) })?.id else {
            throw RewriteError.invalidSelection
        }

        let members = range.filter { selected.contains($0.id) && $0.id != target }

        guard !members.isEmpty else {
            throw RewriteError.invalidSelection
        }

        var result: [RebaseInstruction] = []

        for commit in range where !members.contains(commit) {
            result.append(RebaseInstruction(command: .pick, commit: commit.id, subject: commit.subject))

            if commit.id == target {
                result += members.map { RebaseInstruction(command: command, commit: $0.id, subject: $0.subject) }
            }
        }

        return result
    }

    /// 移动：所选提交保持相对顺序，整体放到目标之前（下方）或之后（上方）。
    private static func moved(
        _ selected: [String],
        to target: String,
        position: MovePosition,
        in range: [HistoryCommit]
    ) throws -> [RebaseInstruction] {
        let selected = Set(selected)
        let members = range.filter { selected.contains($0.id) }

        guard !members.isEmpty, !selected.contains(target) else {
            throw RewriteError.invalidSelection
        }

        let group = members.map { RebaseInstruction(command: .pick, commit: $0.id, subject: $0.subject) }
        var result: [RebaseInstruction] = []

        for commit in range where !selected.contains(commit.id) {
            if commit.id == target, position == .below { result += group }

            result.append(RebaseInstruction(command: .pick, commit: commit.id, subject: commit.subject))

            if commit.id == target, position == .above { result += group }
        }

        return result
    }
}
