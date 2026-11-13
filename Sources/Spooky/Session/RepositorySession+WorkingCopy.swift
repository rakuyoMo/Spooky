import Foundation
import SpookyKit

// MARK: - Working Copy

extension RepositorySession {
    /// 受影响的行先显示目标状态，再执行命令；暂存正在执行时排在它后面，在同一个写操作里接着执行。
    /// 任何失败都会撤回临时状态，排在后面的请求一并丢弃。
    func stage(_ entries: [StatusEntry], staged: Bool) {
        guard !entries.isEmpty else { return }

        let targets = entries.map { (StatusRowID(path: $0.path, kind: $0.kind), staged) }

        // 暂存正在执行：这些行先显示目标状态，请求排在后面
        if isStaging {
            stagingOverrides.merge(targets) { $1 }
            queuedStaging.append((entries, staged))
            return
        }

        guard canWrite else { return }

        stagingOverrides = Dictionary(uniqueKeysWithValues: targets)
        isStaging = true

        let request = generation

        performGit(
            { [weak self] runner, _ in
                var next: (entries: [StatusEntry], staged: Bool)? = (entries, staged)

                // 一次执行一个请求，做完再取排在后面的；失败时后面的请求不再执行
                do {
                    while let current = next {
                        try await WorkingCopyOperations(runner: runner)
                            .stage(current.entries, staged: current.staged)

                        next = await self?.nextStaging(request)
                    }
                } catch {
                    await self?.endStaging(request)
                    throw error
                }
            },
            title: AppLocalization.text(staged ? "working.stage" : "working.unstage"),
            recordsActivity: false,
            undo: .reversible
        )
    }

    /// 全部动作同时供主菜单、工具栏与提交区调用。
    func stageAll(staged: Bool) {
        stage(status?.entries.filter { staged ? $0.hasUnstagedChanges : $0.hasStagedChanges } ?? [], staged: staged)
    }

    /// 丢弃先确认，确认对话框关闭后才开始 Git 操作：已跟踪的改动恢复到最后一次提交，未跟踪文件移进废纸篓。
    ///
    /// 服务器仓库的确认写明在服务器上覆盖，没有可用的废纸篓时写明永久删除未跟踪文件，并可以勾选不再提醒。
    ///
    /// - Parameters:
    ///   - entries: 要丢弃的文件。
    ///   - all: 是否丢弃全部改动，确认的标题与主按钮随之不同。
    func discard(_ entries: [StatusEntry], all: Bool = false) {
        guard canWrite, !entries.isEmpty, let repository else { return }

        let request = generation
        let removal = fileRemoval

        // Activity 与撤销记录用动作名，确认对话框按丢弃所选还是全部取标题与主按钮
        let activityTitle = AppLocalization.text("working.discard")
        let title = AppLocalization.text(all ? "working.discardAll.title" : "working.discard.title")
        let submitTitle = AppLocalization.text(all ? "working.discardAll.submit" : "working.discard")
        let message = Self.discardMessage(entries, in: repository, removal: removal)

        let perform = { [weak self] in
            guard let self, generation == request else { return }

            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner).discard(entries, removal: removal)
                },
                title: activityTitle,
                recordsActivity: false,
                undo: .reversible
            )
        }

        guard repository.host != nil else {
            onConfirm?(ConfirmationRequest(
                title: title,
                message: message,
                submitTitle: submitTitle,
                action: perform
            ))
            return
        }

        confirmOnServer(
            .discardChanges,
            title: title,
            submitTitle: submitTitle,
            message: message,
            action: perform
        )
    }

    /// 暂存与丢弃使用正在显示的快照，确认期间的变化由核心库拒绝。
    func apply(file: Int, hunk: Int, lines: Set<Int>, discard: Bool) {
        guard canWrite, let snapshot = diffSnapshot else { return }
        let request = generation
        let selectedBlock = lines.isEmpty ? nil : diffSelections.target(file: file, hunk: hunk)

        // 中断报告沿用块头按钮的动作名称。
        let action = discard ? "discard" : (snapshot.side == .staged ? "unstage" : "stage")
        let title = AppLocalization.text(
            "working." + action + (lines.isEmpty ? "Chunk" : (lines.count == 1 ? "Line" : "Lines"))
        )
        let perform: () -> Void = { [weak self] in
            guard let self, generation == request else { return }
            let accepted = performGit(
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
                recordsActivity: false,
                undo: .reversible
            )
            if accepted { diffSelections.clear(selectedBlock) }
        }

        // 丢弃块或行默认先确认；General 设置里关掉警告或在确认对话框里勾选不再提醒后直接丢弃。
        guard discard, ServerConfirmation.discardChunks.isEnabled, let repository else {
            perform()
            return
        }

        let message = AppLocalization.text(
            repository.host == nil ? "working.discard.lines" : "working.discard.remoteLines",
            repository.displayPath
        )

        // 本机与服务器仓库的确认都可以勾选不再提醒，与 General 设置里的警告是同一项
        onConfirm?(ConfirmationRequest(
            title: AppLocalization.text("working.discardContent.title"),
            message: message,
            submitTitle: AppLocalization.text("working.discard"),
            suppression: .discardChunks,
            action: perform
        ))
    }

    /// 修补载入最近信息，退出修补时恢复普通提交草稿。
    ///
    /// 提交进行中不进入修补，提交后等待重置期间不切换修补：保存的普通草稿只留给成功后的重置。
    /// 进入修补按 ``canAmend``：edit 停顿时载入的是当前 HEAD 的信息。
    func setAmend(_ enabled: Bool) {
        guard enabled != amend, commitResetTask == nil else { return }

        if enabled {
            guard !isCommitting, canAmend, let context else { return }

            originalDraft = (commitSubject, commitBody)
            setMessage(context.lastMessage)
        } else if let originalDraft {
            commitSubject = originalDraft.subject
            commitBody = originalDraft.body
            self.originalDraft = nil
        }

        amend = enabled
    }

    /// 提交失败保留草稿；注释行先按 Editor 设置询问或删除。
    func commit() {
        guard canCommit else { return }
        let amend = amend
        let signOff = CommitEditorSettings.signOff
        let skipHooks = skipHooks
        let request = generation

        // 询问注释行时使用此刻的选项，⌥ 快速修补松开后也不会改变这次提交。
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

    /// 提交整理好的信息；进行中的操作没有任何改动时，按警告设置先确认建空提交还是中止。
    ///
    /// - Parameters:
    ///   - message: 已按注释设置整理的标题与正文。
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

        // 修补成功后回到的普通草稿：还在修补里时是进入修补前存下的，⌥ 快速修补已经退出时就是信息框里恢复的内容
        let draft = amend ? (originalDraft ?? (commitSubject, commitBody)) : nil

        let action: (_ allowEmpty: Bool) -> Void = { [weak self] allowEmpty in
            guard let self, generation == request else { return }

            let started = performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .commit(
                            subject: message.subject,
                            body: message.body,
                            amend: amend,
                            signOff: signOff,
                            skipHooks: skipHooks,
                            allowEmpty: allowEmpty
                        )
                },
                title: AppLocalization.text(amend ? "working.amend" : "working.commit"),
                recordsActivity: false,
                undo: .reversible
            ) { [weak self] in
                self?.finishSuccessfulCommit(restoring: draft)
            }

            // 只有真正开始的提交才进入提交中状态；仓库不可写时什么也不变
            if started {
                beginCommitProgress()
            }
        }

        // 修补改写的是已有的提交，不是空提交
        guard commitsEmpty, !amend else {
            action(false)
            return
        }

        confirmEmptyCommit(isSequence: false) {
            action(true)
        } alternate: { [weak self] in
            guard let self, generation == request else { return }

            finishOperation("abort")
        }
    }

    /// 按编辑模式重置已经提交的信息并清除这次的提交选项，结束提交后的锁定。
    ///
    /// 修补回到进入修补前的普通草稿；普通提交与合并收尾清空，合并前的草稿不再恢复。
    func resetCommittedMessage() {
        commitResetTask?.cancel()
        commitResetTask = nil
        commitSubject = originalDraft?.subject ?? ""
        commitBody = originalDraft?.body ?? ""
        amend = false
        originalDraft = nil

        #warning(
            "TODO: 提交成功后是否取消 Skip Hooks 未核实：当前随标题与正文一起清除，避免之后的提交意外跳过钩子。核实方式：勾选 Skip Hooks 提交一次，再写下一次提交时查看勾选状态；影响连续提交时钩子是否运行。"
        )
        skipHooks = false
    }

    /// 采用 Git 的 ours / theirs 语义，界面用两侧的引用名说明。
    func resolve(_ entries: [StatusEntry], theirs: Bool) {
        performGit(
            { runner, _ in
                try await WorkingCopyOperations(runner: runner).resolve(entries, theirs: theirs)
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

    /// 用信息框里编辑后的信息继续序列；注释行先按 Editor 设置询问或删除。
    ///
    /// 这一步没有任何改动且信息非空时，按警告设置先确认保留空提交还是跳过这一步。
    func continueSequence() {
        guard canWrite, let operation = context?.operation else { return }

        let request = generation

        prepareCommitMessage { [weak self] message in
            guard let self, generation == request else { return }

            let (subject, body) = CommitMessage.parts(of: message)

            let perform: (_ allowEmpty: Bool) -> Void = { [weak self] allowEmpty in
                guard let self, generation == request else { return }

                performGit(
                    { runner, _ in
                        try await WorkingCopyOperations(runner: runner)
                            .continueSequence(operation, subject: subject, body: body, allowEmpty: allowEmpty)
                    },
                    title: AppLocalization.text("working.continue"),
                    recordsActivity: false
                )
            }

            // 信息为空时直接交给 Git，由它报告缺少提交信息
            guard commitsEmpty, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                perform(false)
                return
            }

            confirmEmptyCommit(isSequence: true) {
                perform(true)
            } alternate: { [weak self] in
                guard let self, generation == request else { return }

                finishOperation("skip")
            }
        }
    }

    /// 第一行成为标题，正文保留内部换行。
    func setMessage(_ message: String) {
        (commitSubject, commitBody) = CommitMessage.parts(of: message)
    }
}

// MARK: - Helpers

extension RepositorySession {
    /// 丢弃确认的说明：一个文件时点名它，多个时写文件数；服务器仓库写明在服务器上覆盖，
    /// 以及未跟踪文件移进服务器的废纸篓还是永久删除。
    ///
    /// - Parameters:
    ///   - entries: 要丢弃的文件，至少一个。
    ///   - repository: 文件所在的仓库。
    ///   - removal: 未跟踪文件的删除方式。
    static func discardMessage(
        _ entries: [StatusEntry],
        in repository: RepositoryLocation,
        removal: FileRemoval
    ) -> String {
        let keys: (single: String, multiple: String) =
            switch (repository.host, removal) {
            case (nil, _):
                ("working.discard.message.single", "working.discard.message")

            case (_, .trash):
                ("working.discard.remote.single", "working.discard.remote")

            default:
                ("working.discard.remotePermanent.single", "working.discard.remotePermanent")
            }

        guard entries.count == 1, let entry = entries.first else {
            return AppLocalization.text(keys.multiple, entries.count, repository.displayPath)
        }

        return AppLocalization.text(
            keys.single,
            WorkingCopyFileList.fileName(of: entry.path),
            repository.displayPath
        )
    }

    /// 空提交按警告设置先确认；关掉警告时直接保留空提交，不记住中止或跳过的选择。
    ///
    /// - Parameters:
    ///   - isSequence: 序列中的一步，备选是跳过；否则备选是中止当前操作。
    ///   - commit: 保留空提交。
    ///   - alternate: 中止或跳过。
    private func confirmEmptyCommit(
        isSequence: Bool,
        commit: @escaping () -> Void,
        alternate: @escaping () -> Void
    ) {
        let warns = UserDefaults.standard.object(forKey: WorkingCopyPreferences.warnsEmptyCommit) as? Bool ?? true

        guard warns else {
            commit()
            return
        }

        onEmptyCommitPrompt?(EmptyCommitRequest(isSequence: isSequence, commit: commit, alternate: alternate))
    }

    /// 取出排在后面的下一个暂存请求；没有时结束暂存，之后的请求按仓库是否可写处理。仓库已切换时不再取。
    ///
    /// - Parameter request: 暂存开始时的仓库代数。
    private func nextStaging(_ request: Int) -> (entries: [StatusEntry], staged: Bool)? {
        guard generation == request else { return nil }

        guard !queuedStaging.isEmpty else {
            isStaging = false
            return nil
        }

        return queuedStaging.removeFirst()
    }

    /// 暂存失败或被取消：结束暂存，排在后面的请求一并丢弃，它们的临时状态随之后的刷新撤回。
    ///
    /// - Parameter request: 暂存开始时的仓库代数。
    private func endStaging(_ request: Int) {
        guard generation == request else { return }

        isStaging = false
        queuedStaging = []
    }
}
