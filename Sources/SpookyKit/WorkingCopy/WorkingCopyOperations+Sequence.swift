import Foundation

// MARK: - Sequence

extension WorkingCopyOperations {
    /// 用信息框里编辑后的信息提交序列的这一步，再交给 Git 处理后面的步骤。
    ///
    /// 信息经 `commit -F -` 送到仓库所在机器，不写 Git 目录下的文件，也不启动编辑器；后面的步骤仍由 Git 按默认方式处理。
    /// 后面的步骤停在冲突上时正常返回，由读到的状态显示下一步的冲突。
    ///
    /// - Parameters:
    ///   - operation: 进行中的变基、摘取或反转。
    ///   - subject: 已按注释设置整理的标题。
    ///   - body: 已按注释设置整理的正文。
    ///   - allowEmpty: 这一步没有改动时保留为空提交，用于用户确认过的空步骤。
    public func continueSequence(
        _ operation: RepositoryOperationState,
        subject: String,
        body: String,
        allowEmpty: Bool = false
    ) async throws {
        guard [.rebase, .cherryPick, .revert].contains(operation) else {
            throw WorkingCopyError.invalidSelection
        }

        let message = Data(CommitMessage.text(subject: subject, body: body).utf8)
        let commit = Self.sequenceCommit + (allowEmpty ? ["--allow-empty"] : [])

        try await runner.writeTransaction {
            if operation == .rebase {
                try await continueRebase(commit: commit, message: message)
                return
            }

            // 摘取的作者由 Git 从 CHERRY_PICK_HEAD 取，反转的作者是当前身份；钩子照常运行，与 Git 自己继续时相同
            _ = try await runner.run(commit + ["-F", "-"], input: message)

            // 冲突在最后一步时，提交即结束序列、Git 删掉 sequencer，不能再继续
            guard try await stateFiles(["sequencer/todo"])["sequencer/todo"] != nil else {
                return
            }

            try await proceedSequence(operation, action: "continue")
        }
    }

    /// 让 Git 接着处理序列后面的步骤，不启动编辑器；下一步停在待解决的冲突上时不当作失败。
    ///
    /// 下一步变成空提交、钩子失败等同样以 1 退出：只有留下了这种操作停在冲突上的状态文件、且有未合并的文件，才是停在了冲突上。
    ///
    /// - Parameters:
    ///   - operation: 进行中的变基、摘取或反转。
    ///   - action: `continue` 或 `skip`。
    func proceedSequence(_ operation: RepositoryOperationState, action: String) async throws {
        let (command, marker): (String, String) =
            switch operation {
            case .rebase: ("rebase", "REBASE_HEAD")
            case .cherryPick: ("cherry-pick", "CHERRY_PICK_HEAD")
            case .revert: ("revert", "REVERT_HEAD")
            case .merge, .squash: throw WorkingCopyError.invalidSelection
            }

        do {
            _ = try await runner.run(Self.continuing + [command, "--" + action])
        } catch let error as GitError where error.exitCode == 1 {
            guard try await stoppedOnConflicts(marker: marker) else {
                throw error
            }
        }
    }

    /// 操作是否停在待解决的冲突上：Git 留下了表示停顿的状态文件，且有未合并的文件；须在写事务中调用。
    ///
    /// - Parameter marker: 相对 Git 目录的状态文件，如合并的 MERGE_HEAD、摘取的 CHERRY_PICK_HEAD。
    func stoppedOnConflicts(marker: String) async throws -> Bool {
        guard try await stateFiles([marker])[marker] != nil else {
            return false
        }

        return try await runner.status().entries.contains { $0.kind == .conflicted }
    }
}

// MARK: - Private

extension WorkingCopyOperations {
    /// 提交序列中的一步：注释行已按注释设置处理过，不再让仓库的 commit.cleanup 剥掉。
    private static let sequenceCommit = [
        "-c", "i18n.commitencoding=UTF-8", "-c", "commit.verbose=false",
        "commit", "--cleanup=whitespace", "-q",
    ]

    /// 让 Git 接着处理后面的步骤，不启动编辑器。
    private static let continuing = ["-c", "core.editor=:", "-c", "core.trustctime=false"]

    /// 提交变基的这一步再继续；Git 自己继续变基时不跑提交钩子，这里同样跳过。
    ///
    /// - Parameters:
    ///   - commit: 提交命令的前半段。
    ///   - message: 送进标准输入的提交信息。
    private func continueRebase(commit: [String], message: Data) async throws {
        let files = try await stateFiles(["rebase-merge/amend", "rebase-apply/head-name"])

        if files["rebase-merge/amend"] != nil {
            // squash / fixup 停下时改写正在合成的提交，作者随它保留。
            // 后面还有 squash / fixup 时，Git 继续时用自己在 message-squash 里累积的信息重建下一步，这里编辑的信息不会带过去，与命令行 Git 相同
            _ = try await runner.run(commit + ["--amend", "--no-verify", "-F", "-"], input: message)
        } else {
            // 冲突停下时没有 CHERRY_PICK_HEAD，作者与作者日期要从这一步的原提交取
            let author = try await runner.run([
                "log", "-1", "--no-show-signature", "--format=%an%x00%ae%x00%ad", "--date=raw", "REBASE_HEAD", "--",
            ])
            let fields = String(decoding: author, as: UTF8.self)
                .trimmingCharacters(in: .newlines)
                .components(separatedBy: "\0")

            guard fields.count == 3 else {
                throw RepositoryReadError.malformedOutput("rebase author")
            }

            let identity = [
                "--no-verify",
                "--author=\(fields[0]) <\(fields[1])>",
                "--date=@\(fields[2])",
            ]

            _ = try await runner.run(commit + identity + ["-F", "-"], input: message)
        }

        // apply 后端自行提交后再 --continue 会报没有改动并停住，改为跳过这一步
        let apply = files["rebase-apply/head-name"] != nil
        try await proceedSequence(.rebase, action: apply ? "skip" : "continue")
    }
}
