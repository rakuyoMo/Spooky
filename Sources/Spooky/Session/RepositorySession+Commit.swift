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
    /// 读取提交配置；读取失败时保留上一次的结果，断线与身份错误由同一次刷新的身份读取报告。
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

    /// 切换或关闭仓库时清空提交配置与只对本仓库有效的提交选项。
    func resetCommitConfiguration() {
        configurationTask?.cancel()
        configurationTask = nil
        commitConfiguration = nil
        skipHooks = false
    }

    /// 补全的候选：提交取自 HEAD 起的最近历史，文件取自当前工作区状态；读取失败时没有候选。
    func completions(for trigger: CompletionTrigger) async -> [CommitCompletion] {
        let wantsCommits = if case .file = trigger { false } else { true }
        var commits: [HistoryCommit] = []

        if wantsCommits, let runner, let head = status?.branch.oid {
            commits = (try? await RepositoryHistory(runner: runner).page(roots: [head], limit: 100).commits) ?? []
        }

        return CommitCompletion.matches(for: trigger, commits: commits, paths: status?.entries.map(\.path) ?? [])
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

        onConfirm?(
            AppLocalization.text("profiles.apply"),
            message,
            { [weak self] in
                guard let self, generation == request else { return }

                performGit(
                    { runner, _ in
                        try await WorkingCopyOperations(runner: runner)
                            .applyIdentity(name: profile.name, email: profile.email, signingKey: profile.signingKey)
                    },
                    title: AppLocalization.text("profiles.apply"),
                    recordsActivity: false
                )
            },
            nil
        )
    }

    /// 按折行与注释设置整理当前草稿，确定提交信息后回调；需要用户决定注释行时先询问，取消则不回调。
    ///
    /// 硬折行时正文按字数上限断行；注释行按 Editor 设置询问、删除或保留，去掉注释后为空时只能保留注释提交。
    func resolveComments(_ completion: @escaping (String) -> Void) {
        #warning(
            "TODO: 硬折行在输入时是否自动插入换行未核实：当前在上限列与视图宽度中较窄处显示折行，提交时按上限把正文断行。核实方式：选 Hard Wrap 后输入超过上限的段落，确认期望在输入时还是提交时换行；影响硬折行模式下提交的正文与编辑区的折行位置。"
        )
        let body = CommitEditorSettings.wrapping == .hard
            ? CommitMessage.hardWrapped(commitBody, limit: CommitEditorSettings.bodyLineLimit)
            : commitBody
        let message = CommitMessage.text(subject: commitSubject, body: body)
        let prefix = commitConfiguration?.commentPrefix ?? "#"

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
