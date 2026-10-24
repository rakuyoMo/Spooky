import Foundation

// MARK: - Execution

extension RepositoryRewrite {
    /// 交互式变基的完整参数：内联的序列编辑器与信息编辑器，并固定会改变 todo 形态的配置，不受用户配置影响。
    static func rebaseArguments(_ plan: RewritePlan, instructions: [RebaseInstruction], skipHooks: Bool) -> [String] {
        let autosquash = plan.action == .autosquash

        // 改信息时编辑器把文件整个换成新信息；其余步骤沿用 Git 准备好的信息，不打开编辑器
        let editor =
            if case .reword(_, let message) = plan.action {
                "printf '%s' " + GitRunner.shellQuoted(message) + " >"
            } else {
                ":"
            }

        let sequence = sequenceEditor(
            expected: plan.commits.map(\.id),
            instructions: instructions,
            ordered: !autosquash
        )

        var arguments = [
            "-c", "core.trustctime=false",
            "-c", "core.commentChar=#",
            "-c", "rebase.updateRefs=false",
            "-c", "rebase.rebaseMerges=false",
            "-c", "sequence.editor=" + sequence,
            "-c", "core.editor=" + editor,
        ]

        // 新信息已按提交区的规则处理过注释行，只整理空白
        if case .reword = plan.action { arguments += ["-c", "commit.cleanup=whitespace"] }

        // 暂存的改动已经写进 fixup 提交，剩下的本地改动由变基自己储藏并在结束时恢复
        let amend = if case .amend = plan.action { true } else { false }

        arguments += [
            "rebase", "--interactive",
            autosquash ? "--autosquash" : "--no-autosquash",
            amend ? "--autostash" : "--no-autostash",
        ]

        if skipHooks { arguments.append("--no-verify") }

        if let onto = plan.onto { arguments += ["--onto", onto] }

        arguments.append(plan.base ?? "--root")
        return arguments
    }

    /// 解析 `for-each-ref` 的四个 NUL 分隔字段：引用名、上游、符号引用的目标与是否为当前分支。
    static func parseContainingReferences(_ output: Data) throws -> [ContainingReference] {
        try String(decoding: output, as: UTF8.self)
            .split(separator: "\n")
            .map { line in
                let fields = line.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)

                guard fields.count == 4, fields[0].hasPrefix("refs/") else {
                    throw RepositoryReadError.malformedOutput("for-each-ref")
                }

                return ContainingReference(
                    name: fields[0],
                    upstream: fields[1],
                    isSymbolic: !fields[2].isEmpty,
                    isHead: fields[3] == "*"
                )
            }
    }

    /// 范围里已在上游与已并入其它分支的提交：先列出包含最旧提交的分支，再分别求出范围里它们够不到的提交。
    func impact(of range: [HistoryCommit], base: String?) async throws -> (pushed: Set<String>, merged: Set<String>) {
        guard let oldest = range.first else {
            return ([], [])
        }

        let output = try await runner.run([
            "for-each-ref", "--format=%(refname)%00%(upstream)%00%(symref)%00%(HEAD)",
            "--contains", oldest.id, "refs/heads", "refs/remotes",
        ])
        let references = try Self.parseContainingReferences(output)
        let current = references.first { $0.isHead }
        let upstream = current.flatMap { head in references.first { $0.name == head.upstream }?.name }

        // 远端的 HEAD 只是指向某个远端分支的符号引用，不单独计算
        let others = references
            .filter { !$0.isSymbolic && $0.name != current?.name && $0.name != upstream }
            .map(\.name)

        let ids = Set(range.map(\.id))
        var pushed: Set<String> = []
        var merged: Set<String> = []

        if let upstream {
            pushed = ids.subtracting(try await unreachable(from: [upstream], base: base))
        }

        if !others.isEmpty {
            merged = ids.subtracting(try await unreachable(from: others, base: base))
        }

        return (pushed, merged)
    }

    /// 写一个不挂在分支上的 fixup 提交：树取自暂存区，父提交是 HEAD；它会被并进目标，不签名。
    func fixupCommit(for target: HistoryCommit, head: String) async throws -> String {
        let staged = try await runner.execute(["diff", "--cached", "--quiet", "HEAD", "--"], acceptedExitCodes: [0, 1])

        guard staged.exitCode == 1 else {
            throw RewriteError.noStagedChanges
        }

        let tree = Self.trimmed(try await runner.run(["write-tree"]))
        let message = Data(("fixup! " + target.subject + "\n").utf8)
        let commit = Self.trimmed(
            try await runner.run(
                ["-c", "i18n.commitencoding=UTF-8", "commit-tree", "--no-gpg-sign", tree, "-p", head],
                input: message
            )
        )

        guard GitObjectID.isValid(commit) else {
            throw RepositoryReadError.malformedOutput("commit-tree")
        }

        return commit
    }

    /// 变基没有开始时，把暂存区恢复成并入前的内容；变基已经停下时保持原样，交给进行中横幅处理。
    func restoreIndex(from fixup: String, head: String) async throws {
        let state = try await WorkingCopyOperations(runner: runner).stateFiles(["rebase-merge/head-name"])

        guard state.isEmpty, try await resolve("HEAD") == head else {
            return
        }

        _ = try await runner.run(["read-tree", fixup])
    }

    /// 停在 edit 上之后撤下这个提交，让它的改动回到工作区；没有停在 edit 上时不做任何事。
    func reopenEditedCommit() async throws {
        let state = try await WorkingCopyOperations(runner: runner).stateFiles(["rebase-merge/amend"])

        guard state["rebase-merge/amend"] != nil else {
            return
        }

        _ = try await runner.run(["reset", "-q", "HEAD^", "--"])
    }
}

// MARK: - ContainingReference

/// 包含某个提交的分支。
struct ContainingReference: Equatable {
    /// 完整引用名。
    let name: String

    /// 上游的完整引用名；没有上游时为空。
    let upstream: String

    /// 是否是指向别的引用的符号引用，如远端的 HEAD。
    let isSymbolic: Bool

    /// 是否是当前检出的分支。
    let isHead: Bool
}

// MARK: - Private

extension RepositoryRewrite {
    /// 范围里从这些引用够不到的提交；修订经标准输入传入，分支再多也不受参数长度限制。
    private func unreachable(from references: [String], base: String?) async throws -> Set<String> {
        let revisions = ["HEAD"] + (base.map { ["^" + $0] } ?? []) + references.map { "^" + $0 }
        let output = try await runner.run(["rev-list", "--stdin"], input: Data((revisions.joined(separator: "\n") + "\n").utf8))

        return Set(String(decoding: output, as: UTF8.self).split(separator: "\n").map(String.init))
    }
}

extension RepositoryRewrite {
    /// 去掉命令输出末尾的换行。
    private static func trimmed(_ output: Data) -> String {
        String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
