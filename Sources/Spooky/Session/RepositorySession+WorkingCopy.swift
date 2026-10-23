import Foundation
import SpookyKit

// MARK: - Working Copy

extension RepositorySession {
    /// 勾选框先更新，再执行命令；任何失败都会撤回临时状态。
    func stage(_ entries: [StatusEntry], staged: Bool) {
        guard canWrite, !entries.isEmpty else { return }
        stagingOverrides = Dictionary(uniqueKeysWithValues: entries.map {
            (StatusRowID(path: $0.path, kind: $0.kind), staged)
        })
        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).stage(entries, staged: staged)
            },
            title: AppLocalization.text(staged ? "working.stage" : "working.unstage"),
            recordsActivity: false
        )
    }

    /// 全部动作同时供主菜单、工具栏与提交区调用。
    func stageAll(staged: Bool) {
        stage(status?.entries.filter { staged ? $0.hasUnstagedChanges : $0.hasStagedChanges } ?? [], staged: staged)
    }

    /// 丢弃确认点名目标机器，关闭 sheet 后才开始 Git 操作。
    func discard(_ entries: [StatusEntry]) {
        guard canWrite, !entries.isEmpty else { return }
        let request = generation
        let message = AppLocalization.text(
            repository?.host == nil ? "working.discard.message" : "working.discard.remote",
            entries.count,
            repository?.displayPath ?? ""
        )
        onConfirm?(
            AppLocalization.text("working.discard"),
            message,
            { [weak self] in
                guard let self, generation == request else { return }
                performGit(
                    { runner, _ in
                        try await WorkingCopyOperations(runner: runner).discard(entries)
                    },
                    title: AppLocalization.text("working.discard"),
                    recordsActivity: false
                )
            },
            nil
        )
    }

    /// 暂存与丢弃使用正在显示的快照，确认期间的变化由核心库拒绝。
    func apply(file: Int, hunk: Int, lines: Set<Int>, discard: Bool) {
        guard canWrite, let snapshot = diffSnapshot else { return }
        let request = generation

        // 中断报告沿用块头按钮的动作名称。
        let action = discard ? "discard" : (snapshot.side == .staged ? "unstage" : "stage")
        let title = AppLocalization.text(
            "working." + action + (lines.isEmpty ? "Chunk" : (lines.count == 1 ? "Line" : "Lines"))
        )
        let perform: () -> Void = { [weak self] in
            guard let self, generation == request else { return }
            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .apply(
                            snapshot,
                            file: file,
                            hunk: hunk,
                            lines: lines,
                            discard: discard
                        )
                },
                title: title,
                recordsActivity: false
            )
        }

        if discard {
            onConfirm?(
                AppLocalization.text("working.discard"),
                AppLocalization.text(
                    repository?.host == nil ? "working.discard.lines" : "working.discard.remoteLines",
                    repository?.displayPath ?? ""
                ),
                perform,
                nil
            )
        } else {
            perform()
        }
    }

    /// 修补载入最近信息，退出修补时恢复普通提交草稿。
    func setAmend(_ enabled: Bool) {
        guard enabled != amend else { return }

        if enabled {
            guard status?.branch.oid != nil, context?.operation == nil, let context else { return }
            originalDraft = (commitSubject, commitBody)
            setMessage(context.lastMessage)
        } else if let originalDraft {
            commitSubject = originalDraft.subject
            commitBody = originalDraft.body
            self.originalDraft = nil
        }

        amend = enabled
    }

    /// 提交失败保留草稿，修补必须先明确确认改写最近提交；注释行先按 Editor 设置询问或删除。
    func commit() {
        guard canCommit else { return }
        let amend = amend
        let signOff = CommitEditorSettings.signOff
        let skipHooks = skipHooks
        let request = generation

        // 询问注释行与确认修补都使用此刻的选项，⌥ 快速修补松开后也不会改变这次提交。
        prepareCommitMessage { [weak self] message in
            guard let self, generation == request else { return }
            confirmCommit(
                CommitMessage.parts(of: message),
                amend: amend,
                signOff: signOff,
                skipHooks: skipHooks
            )
        }
    }

    /// 确认修补或空合并后提交整理好的信息。
    ///
    /// - Parameters:
    ///   - message: 已按折行与注释设置整理的标题与正文。
    ///   - amend: 改写最近一次提交。
    ///   - signOff: 追加 Signed-off-by 尾注。
    ///   - skipHooks: 跳过 pre-commit 与 commit-msg 钩子。
    func confirmCommit(
        _ message: (subject: String, body: String),
        amend: Bool,
        signOff: Bool,
        skipHooks: Bool
    ) {
        let request = generation
        let action: () -> Void = { [weak self] in
            guard let self, generation == request else { return }
            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .commit(
                            subject: message.subject,
                            body: message.body,
                            amend: amend,
                            signOff: signOff,
                            skipHooks: skipHooks
                        )
                },
                title: AppLocalization.text(amend ? "working.amend" : "working.commit"),
                recordsActivity: false
            ) { [weak self] in
                self?.commitSubject = ""
                self?.commitBody = ""
                self?.amend = false
                self?.originalDraft = nil

                #warning(
                    "TODO: 提交成功后是否取消 Skip Hooks 未核实：当前随标题与正文一起清除，避免之后的提交意外跳过钩子。核实方式：勾选 Skip Hooks 提交一次，再写下一次提交时查看勾选状态；影响连续提交时钩子是否运行。"
                )
                self?.skipHooks = false
            }
        }

        if amend {
            onConfirm?(
                AppLocalization.text("working.amend"),
                AppLocalization.text("working.amend.confirm"),
                action,
                nil
            )
        } else if context?.operation == .merge, status?.entries.contains(where: \.hasStagedChanges) != true {
            onConfirm?(
                AppLocalization.text("working.emptyMerge"),
                AppLocalization.text("working.emptyMerge.message"),
                action,
                { [weak self] in
                    guard let self, generation == request else { return }
                    finishOperation("abort")
                }
            )
        } else {
            action()
        }
    }

    /// 采用 Git 的 ours / theirs 语义，界面用两侧的引用名说明；偏好开启时先保留冲突文件的备份。
    func resolve(_ entries: [StatusEntry], theirs: Bool) {
        let backup = conflictBackupRecorder()

        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).resolve(entries, theirs: theirs, backup: backup)
            },
            title: AppLocalization.text("conflict.resolveUsingVersion", theirs ? theirsName : oursName),
            recordsActivity: false
        )
    }

    /// 横幅仅暴露当前操作的收尾动作。
    func finishOperation(_ action: String) {
        guard let operation = context?.operation else { return }
        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).finish(operation, action: action)
            },
            title: AppLocalization.text("working." + action),
            recordsActivity: false
        )
    }

    /// 第一行成为标题，正文保留内部换行。
    func setMessage(_ message: String) {
        (commitSubject, commitBody) = CommitMessage.parts(of: message)
    }
}
