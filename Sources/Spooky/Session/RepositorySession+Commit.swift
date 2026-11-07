import Foundation
import SpookyKit

// MARK: - CommentHandling

/// 提交信息里注释行的处理方式。
enum CommentHandling {
    /// 注释行原样提交。
    case keep

    /// 提交前去掉注释行。
    case remove
}

// MARK: - Commit Experience

extension RepositorySession {
    /// 未解决冲突期间不允许提交或修补。
    var conflictCount: Int { status?.entries.filter { $0.kind == .conflicted }.count ?? 0 }

    /// 有标题、有暂存改动或可修补的 HEAD 时允许提交；合并可产生空树差异，进行中的操作没有任何改动时确认后建空提交。
    var canCommit: Bool {
        canWrite && commitResetTask == nil && conflictCount == 0
            && !commitSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (
                amend
                    || context?.operation == .merge
                    || commitsEmpty
                    || (status?.entries.contains(where: \.hasStagedChanges) ?? false)
            )
    }

    /// 提交区可以打开修补：HEAD 已有提交，且没有进行中的操作，或交互式变基停在 edit 步等待修补当前 HEAD。
    ///
    /// edit 停顿里 HEAD 是停下的提交、它的修补结果或停顿中新建的提交时可以修补；
    /// 撤下停下的提交后 HEAD 回到它的父提交，那是用户没有选中的提交，不能修补。
    var canAmend: Bool {
        guard canWrite, let head = status?.branch.oid else {
            return false
        }

        // 没有进行中的操作时照常修补
        guard let progress = context?.progress else {
            return true
        }

        return progress.stopsForEdit && head != progress.editedParent
    }

    /// 提交区显示的提交人：仓库所在机器上生效的 `user.name` 与 `user.email`；没有配置或还没读到时为空。
    var committer: (name: String, email: String) {
        (commitConfiguration?.userName ?? "", commitConfiguration?.userEmail ?? "")
    }

    /// 读取提交配置；读取失败时保留上一次的结果，断线由同一次刷新的其它读取报告。
    func loadCommitConfiguration() {
        guard configurationTask == nil, let runner else { return }

        let request = generation
        let service = WorkingCopyOperations(runner: runner)

        configurationTask = Task { [weak self] in
            let configuration = try? await service.commitConfiguration()
            guard let self, generation == request, !Task.isCancelled else { return }

            if let configuration {
                commitConfiguration = configuration
            }

            configurationTask = nil
        }
    }

    /// 提交命令已经开始：过了 `commitProgressDelay` 仍未结束才显示转圈；写操作结束时不论成败都结束提交状态。
    func beginCommitProgress() {
        let write = writeTask
        let delay = commitProgressDelay
        isCommitting = true

        let progress = Task { [weak self] in
            try? await Task.sleep(for: delay)

            guard !Task.isCancelled else { return }

            self?.showsCommitProgress = true
        }

        commitProgressTask = progress

        // 失败与取消没有成功回调，等写操作结束后收起；这期间已经开始的下一次提交不受影响
        Task { [weak self] in
            await write?.value

            guard let self, commitProgressTask == progress else { return }

            endCommitProgress()
        }
    }

    /// 结束提交中状态并停止转圈；还没到显示转圈的时间就结束的提交不会再显示。
    func endCommitProgress() {
        commitProgressTask?.cancel()
        commitProgressTask = nil
        isCommitting = false
        showsCommitProgress = false
    }

    /// 提交成功：立即停止转圈、收起正文并把焦点交给文件列表；过了 `commitResetDelay` 再按编辑模式重置信息，其间提交区保持锁定。
    ///
    /// - Parameter draft: 修补时进入修补前的普通草稿，重置时恢复它；普通提交与合并收尾为 nil，重置时清空。
    func finishSuccessfulCommit(restoring draft: (subject: String, body: String)?) {
        endCommitProgress()
        collapsesCommitBody = true
        fileListFocusRequest += 1

        // ⌥ 快速修补可能已经先恢复了草稿，这里重新记下，关闭仓库时的立即重置同样用它
        if let draft {
            originalDraft = draft
        }

        let delay = commitResetDelay
        commitResetTask = Task { [weak self] in
            try? await Task.sleep(for: delay)

            guard !Task.isCancelled else { return }

            self?.resetCommittedMessage()
        }
    }

    /// 读到新的上下文时按编辑模式更新信息：进入进行中操作即进入合并模式，用 Git 准备的信息替换草稿并退出修补，合并成功后信息为空。
    ///
    /// 序列进入下一步或停在另一个提交上时同样换成这一步的信息；同一步里重新读取不覆盖编辑中的内容。
    /// edit 停顿结束后退出停顿里打开的修补。
    /// 仓库刚打开时还没有上一份上下文，只在信息为空时填入，切回仓库时恢复的草稿保留。
    ///
    /// - Parameters:
    ///   - context: 刚读到的上下文。
    ///   - previous: 上一份上下文；仓库刚打开时为 nil。
    func updateMessage(for context: WorkingCopyContext, previous: WorkingCopyContext?) {
        guard let progress = context.progress else {
            // edit 停顿里打开的修补只针对停顿中的提交，变基结束或中止后退出修补，恢复进入修补前的草稿
            if previous?.progress?.stopsForEdit ?? false { setAmend(false) }

            return
        }

        // 变基的步号随每一步增加；摘取与反转的序列总是第 1 步，换的是正在处理的提交
        let last = previous?.progress
        let changed = progress.state != last?.state
            || progress.step != last?.step
            || progress.theirs != last?.theirs

        guard changed else { return }
        guard previous != nil || commitSubject.isEmpty else { return }

        // 合并成功后按合并模式清空，修补前存下的普通草稿不再恢复
        amend = false
        originalDraft = nil
        setMessage(context.preparedMessage)
    }

    /// 切换或关闭仓库时清空提交配置与只对本仓库有效的提交选项。
    func resetCommitConfiguration() {
        configurationTask?.cancel()
        configurationTask = nil
        commitConfiguration = nil
        skipHooks = false
    }

    /// 补全的候选：提交取自 HEAD 起的最近历史，文件取自当前工作区状态，Issue 取自远端对应账号的托管服务；读取失败或没有账号时没有候选。
    func completions(for trigger: CompletionTrigger) async -> [CommitCompletion] {
        guard let runner else {
            return []
        }

        switch trigger {
        case .issue:
            let issues = await pullRequests.openIssues(runner: runner, upstreamRemote: headBranch?.upstreamRemote)
            return CommitCompletion.matches(for: trigger, commits: [], paths: [], issues: issues)

        case .file:
            return CommitCompletion.matches(for: trigger, commits: [], paths: status?.entries.map(\.path) ?? [])

        case .commit, .fixup:
            guard let head = status?.branch.oid else {
                return []
            }

            let commits = (try? await RepositoryHistory(runner: runner).page(roots: [head], limit: 100).commits) ?? []
            return CommitCompletion.matches(for: trigger, commits: commits, paths: [])
        }
    }

    /// 选用身份档案：先说明会改写哪台机器上哪个仓库的哪些配置，确认后写入仓库的本地配置。
    func applyProfile(_ profile: UserProfile) {
        guard canWrite, let repository else { return }

        let request = generation
        let keys = profile.signingKey == nil
            ? "user.name, user.email"
            : "user.name, user.email, user.signingkey, gpg.format"
        let message = repository.host == nil
            ? AppLocalization.text("profiles.apply.local", keys, repository.displayPath)
            : AppLocalization.text("profiles.apply.remote", keys, repository.displayPath)

        let title = AppLocalization.text("profiles.apply")

        onConfirm?(ConfirmationRequest(
            title: title,
            message: message,
            submitTitle: AppLocalization.text("profiles.apply.submit")
        ) { [weak self] in
            guard let self, generation == request else { return }

            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .applyIdentity(name: profile.name, email: profile.email, signingKey: profile.signingKey)
                },
                title: title,
                recordsActivity: false
            )
        })
    }

    /// 把身份档案的姓名与邮箱写进仓库所在机器上的全局 Git 配置；先确认，说明写在哪台机器、影响哪些仓库。
    func applyGlobalProfile(_ profile: UserProfile) {
        guard canWrite, let repository else { return }

        #warning(
            "TODO: 服务器仓库的 Set as Global User 写的是服务器上的全局配置，依据是服务器仓库在服务器上提交；也可能应写本机的全局配置。核实方式：确认服务器仓库的快捷操作里这一项的预期作用范围；只影响服务器仓库的这一个动作。"
        )

        let request = generation
        let message = repository.host.map { AppLocalization.text("quickActions.setGlobalUser.remote", $0) }
            ?? AppLocalization.text("quickActions.setGlobalUser.local")

        let title = AppLocalization.text("quickActions.setGlobalUser")

        onConfirm?(ConfirmationRequest(
            title: title,
            message: message,
            submitTitle: AppLocalization.text("quickActions.setGlobalUser.submit")
        ) { [weak self] in
            guard let self, generation == request else { return }

            performGit(
                { runner, _ in
                    try await WorkingCopyOperations(runner: runner)
                        .applyGlobalIdentity(name: profile.name, email: profile.email)
                },
                title: title,
                recordsActivity: false
            )
        })
    }

    /// 按注释设置整理提交信息，确定后回调；需要用户决定注释行时先询问，取消则不回调。
    ///
    /// 注释行按 Editor 设置询问、删除或保留，去掉注释后为空时只能保留注释提交。
    ///
    /// - Parameter message: 要整理的信息；为 nil 时整理提交区的当前草稿，改写提交信息时传入编辑后的信息。
    func prepareCommitMessage(_ message: String? = nil, _ completion: @escaping (String) -> Void) {
        let message = message ?? CommitMessage.text(subject: commitSubject, body: commitBody)

        // 配置尚未读到时按 Git 的默认注释字符；读到 auto 时没有注释行。
        let prefix = commitConfiguration.map(\.commentPrefix) ?? "#"

        guard CommitMessage.hasComments(message, prefix: prefix) else {
            completion(message)
            return
        }

        let stripped = CommitMessage.removingComments(message, prefix: prefix)
        let empty = stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // 提示关闭时按 “总是删除” 直接处理，删除后为空仍要询问。
        if !CommitEditorSettings.warnsComments, !(CommitEditorSettings.stripsComments && empty) {
            completion(CommitEditorSettings.stripsComments ? stripped : message)
            return
        }

        onCommentPrompt?(empty) { completion($0 == .remove ? stripped : message) }
    }
}
