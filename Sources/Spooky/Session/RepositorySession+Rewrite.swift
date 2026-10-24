import Foundation
import SpookyKit

// MARK: - RewriteRequest

/// 改写操作需要用户填写或确认的内容，由仓库窗口以 sheet 呈现。
enum RewriteRequest {
    /// 反转所选提交。
    case revert([String])

    /// 摘取所选提交。
    case cherryPick([String])

    /// 重置 HEAD，预填所选版本。
    case reset(String?)

    /// 检出版本，预填所选版本。
    case checkout(String?)

    /// 变基到别处；所选提交为空时把当前分支从当前基点移到新基点，否则只移动所选提交。
    case rebaseOnto([String])

    /// 确认交互式变基的计划。
    case confirm(RewritePlan)

    /// 编辑提交信息后改写。
    case reword(RewritePlan)
}

// MARK: - Availability

extension RepositorySession {
    /// 反转、摘取、重置与改写历史需要 HEAD 已有提交，且没有进行中的操作。
    var canRewrite: Bool {
        canWrite && status?.branch.oid != nil && context?.operation == nil
    }

    /// 检出版本只要求没有进行中的操作。
    var canCheckoutRevision: Bool {
        canWrite && context?.operation == nil
    }

    /// 版本组合框的候选：当前分支在前，其后是本地分支、远端分支与标签。
    var revisionCandidates: [String] {
        WorkingCopyFileDialog.revisions(in: history.snapshot?.references ?? [], currentBranch: status?.branch.head)
    }
}

// MARK: - Requests

extension RepositorySession {
    /// 请求反转若干提交，先呈现选项对话框。
    func requestRevert(_ commits: [String]) {
        guard canRewrite, !commits.isEmpty else { return }

        onRewriteRequest?(.revert(listOrdered(commits)))
    }

    /// 请求摘取若干提交，先呈现选项对话框。
    func requestCherryPick(_ commits: [String]) {
        guard canRewrite, !commits.isEmpty else { return }

        onRewriteRequest?(.cherryPick(listOrdered(commits)))
    }

    /// 请求把 HEAD 重置到某个版本；版本为 nil 时由对话框填写。
    func requestReset(to revision: String? = nil) {
        guard canRewrite else { return }

        onRewriteRequest?(.reset(revision))
    }

    /// 请求检出任意版本；版本为 nil 时由对话框填写。
    func requestCheckout(_ revision: String? = nil) {
        guard canCheckoutRevision else { return }

        onRewriteRequest?(.checkout(revision))
    }

    /// 请求变基到别处；给出提交时只移动这些提交。
    func requestRebaseOnto(_ commits: [String] = []) {
        guard canRewrite else { return }

        onRewriteRequest?(.rebaseOnto(listOrdered(commits)))
    }

    /// 先计划交互式变基的动作，再请求确认；改信息的动作改为呈现编辑 sheet，计划失败时报告原因。
    ///
    /// 动作按提交哈希指定，如 `.squash([a, b], into: nil)`、`.move([a], to: b, position: .above)`。
    func requestRewrite(_ action: RewriteAction) {
        guard canRewrite, let runner else { return }

        let request = generation

        Task { [weak self] in
            do {
                let plan = try await RepositoryRewrite(runner: runner).plan(action)
                guard let self, generation == request else { return }

                if case .reword = action {
                    onRewriteRequest?(.reword(plan))
                } else {
                    onRewriteRequest?(.confirm(plan))
                }
            } catch {
                guard let self, generation == request else { return }

                onFailure?(AppFailure(error: error, opening: false, location: repository))
            }
        }
    }

    /// 请求编辑某个提交的信息：编辑 sheet 预填它原来的信息。
    func requestReword(_ commit: String) {
        requestRewrite(.reword(commit, message: ""))
    }
}

// MARK: - Execution

extension RepositorySession {
    /// 反转提交，从新到旧依次反转；被本地改动挡住时询问是否先储藏。
    ///
    /// - Returns: 是否已开始执行。
    @discardableResult
    func revert(_ commits: [String], options: PickOptions) -> Bool {
        let commits = listOrdered(commits)

        return performGit(
            { runner, output in
                try await RepositoryRewrite(runner: runner).revert(commits, options: options, onOutput: output)
            },
            title: AppLocalization.text("rewrite.revert"),
            offersAutoStash: true
        )
    }

    /// 摘取提交，从旧到新依次应用；被本地改动挡住时询问是否先储藏。
    @discardableResult
    func cherryPick(_ commits: [String], options: PickOptions) -> Bool {
        let commits = Array(listOrdered(commits).reversed())

        return performGit(
            { runner, output in
                try await RepositoryRewrite(runner: runner).cherryPick(commits, options: options, onOutput: output)
            },
            title: AppLocalization.text("rewrite.cherryPick"),
            offersAutoStash: true
        )
    }

    /// 把 HEAD 重置到指定版本。
    @discardableResult
    func reset(to revision: String, mode: ResetMode) -> Bool {
        performGit(
            { runner, _ in try await RepositoryRewrite(runner: runner).reset(to: revision, mode: mode) },
            title: AppLocalization.text("rewrite.reset")
        )
    }

    /// 检出任意版本；被本地改动挡住时询问是否先储藏。
    @discardableResult
    func checkout(revision: String) -> Bool {
        performGit(
            { runner, _ in try await RepositoryRewrite(runner: runner).checkout(revision: revision) },
            title: AppLocalization.text("rewrite.checkout"),
            offersAutoStash: true
        )
    }

    /// 把当前分支从当前基点移到新基点；被本地改动挡住时询问是否先储藏。
    @discardableResult
    func rebase(onto newBase: String, from currentBase: String, skipHooks: Bool) -> Bool {
        performGit(
            { runner, output in
                try await RepositoryRewrite(runner: runner)
                    .rebase(onto: newBase, from: currentBase, skipHooks: skipHooks, onOutput: output)
            },
            title: AppLocalization.text("rewrite.rebaseOnto"),
            offersAutoStash: true
        )
    }

    /// 执行已确认的交互式变基计划。
    ///
    /// 并入暂存改动的计划由变基自己储藏其余改动：先储藏会把要并入的暂存改动一起收走，所以不询问自动储藏。
    @discardableResult
    func perform(_ plan: RewritePlan) -> Bool {
        let amends = if case .amend = plan.action { true } else { false }

        return performGit(
            { runner, output in try await RepositoryRewrite(runner: runner).perform(plan, onOutput: output) },
            title: AppLocalization.text(Self.titleKey(of: plan.action)),
            offersAutoStash: !amends
        )
    }

    /// 改写提交信息：编辑后的信息先按提交区的规则处理注释行与折行，再执行。
    func reword(_ plan: RewritePlan, subject: String, body: String) {
        let request = generation

        prepareCommitMessage(CommitMessage.text(subject: subject, body: body)) { [weak self] message in
            guard let self, generation == request else { return }

            perform(plan.rewording(message))
        }
    }
}

// MARK: - Titles

extension RepositorySession {
    /// 交互式变基各动作的名称键，用作 Activity 与确认 sheet 的标题。
    static func titleKey(of action: RewriteAction) -> String {
        switch action {
        case .squash: "rewrite.squash"
        case .fixup: "rewrite.fixup"
        case .edit: "rewrite.edit"
        case .reword: "rewrite.reword"
        case .drop: "rewrite.drop"
        case .move: "rewrite.move"
        case .amend: "rewrite.amend"
        case .autosquash: "rewrite.autosquash"
        case .rebase: "rewrite.rebaseOnto"
        }
    }
}

// MARK: - Private

extension RepositorySession {
    /// 按历史列表的顺序（从新到旧）排列提交；列表里还没有的提交保持原来的先后，排在最后。
    private func listOrdered(_ commits: [String]) -> [String] {
        let positions = Dictionary(
            history.commits.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )

        return commits.enumerated()
            .sorted { (positions[$0.element] ?? .max, $0.offset) < (positions[$1.element] ?? .max, $1.offset) }
            .map(\.element)
    }
}
