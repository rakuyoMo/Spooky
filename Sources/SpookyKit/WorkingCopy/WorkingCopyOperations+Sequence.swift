import Foundation

// MARK: - Sequence

extension WorkingCopyOperations {
    /// 用信息框里编辑后的信息提交序列的这一步，再交给 Git 处理后面的步骤。
    ///
    /// 信息经 `commit -F -` 送到仓库所在机器，不写 Git 目录下的文件，也不启动编辑器；后面的步骤仍由 Git 按默认方式处理。
    ///
    /// - Parameters:
    ///   - operation: 进行中的变基、摘取或反转。
    ///   - subject: 已按注释设置整理的标题。
    ///   - body: 已按注释设置整理的正文。
    public func continueSequence(_ operation: RepositoryOperationState, subject: String, body: String) async throws {
        guard [.rebase, .cherryPick, .revert].contains(operation) else {
            throw WorkingCopyError.invalidSelection
        }

        let message = Data(CommitMessage.text(subject: subject, body: body).utf8)

        try await runner.writeTransaction {
            // 这一步没有可提交的改动时保留空提交再继续
            if try await commitEmptyStep(of: operation) {
                return
            }

            if operation == .rebase {
                try await continueRebase(message: message)
                return
            }

            // 摘取的作者由 Git 从 CHERRY_PICK_HEAD 取，反转的作者是当前身份；钩子照常运行，与 Git 自己继续时相同
            _ = try await runner.run(Self.sequenceCommit + ["-F", "-"], input: message)

            // 冲突在最后一步时，提交即结束序列、Git 删掉 sequencer，不能再继续
            guard try await stateFiles(["sequencer/todo"])["sequencer/todo"] != nil else {
                return
            }

            _ = try await runner.run(Self.continuing + [operation == .revert ? "revert" : "cherry-pick", "--continue"])
        }
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
    private func continueRebase(message: Data) async throws {
        let files = try await stateFiles(["rebase-merge/amend", "rebase-apply/head-name"])

        if files["rebase-merge/amend"] != nil {
            // squash / fixup 停下时改写正在合成的提交，作者随它保留。
            // 后面还有 squash / fixup 时，Git 继续时用自己在 message-squash 里累积的信息重建下一步，这里编辑的信息不会带过去，与命令行 Git 相同
            _ = try await runner.run(Self.sequenceCommit + ["--amend", "--no-verify", "-F", "-"], input: message)
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

            _ = try await runner.run(Self.sequenceCommit + identity + ["-F", "-"], input: message)
        }

        // apply 后端自行提交后再 --continue 会报没有改动并停住，改为跳过这一步
        let apply = files["rebase-apply/head-name"] != nil
        _ = try await runner.run(Self.continuing + ["rebase", apply ? "--skip" : "--continue"])
    }
}
