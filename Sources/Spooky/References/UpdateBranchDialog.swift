import SpookyKit
import SwiftUI

// MARK: - UpdateBranchDialog

/// Update Branch：选一个设了父分支的本地分支，用合并或变基并入父分支的新提交；执行时先检出这个分支。
///
/// 默认设置是合并、不强制生成合并提交、不校验签名、不跳过钩子，Quick Update 不开对话框，直接按这组设置更新。
struct UpdateBranchDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 入口预选的分支。
    let branch: RepositoryReference

    /// 关闭对话框。
    let close: () -> Void

    /// 所选分支的完整引用名。
    @State
    private var selection = ""

    /// 为 true 时变基到父分支上，否则合并父分支。
    @State
    private var rebase = false

    /// 能快进时也生成合并提交。
    @State
    private var alwaysCommit = false

    /// 要求父分支的提交有可信签名。
    @State
    private var verify = false

    /// 跳过合并或变基的钩子。
    @State
    private var skipHooks = false

    /// 所选分支与父分支的比较；换了分支后、读到之前为 nil。
    @State
    private var comparison: HistoryBaseComparison? = nil

    /// 冲突预览读取失败，不显示预览。
    @State
    private var previewFailed = false

    /// 490 宽的骨架：分支与提交数、合并方式、合并提交与冲突预览，选项区是签名校验与跳过钩子。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("review.updateBranch"),
            message: AppLocalization.text("review.update.message"),
            width: 490,
            submitTitle: AppLocalization.text("review.update.button"),
            error: "",
            isValid: selectedBranch.map(session.canUpdateBranch) ?? false,
            cancel: close,
            submit: submit
        ) {
            form
        } options: {
            DialogFormOption(
                title: AppLocalization.text("merge.verify"),
                help: AppLocalization.text("merge.verify.help"),
                isOn: $verify
            )
            .disabled(rebase)

            DialogFormOption(
                title: AppLocalization.text("sync.skipHooks"),
                help: AppLocalization.text("sync.skipHooks.help"),
                isOn: $skipHooks
            )
        }
        .onAppear { selection = branch.id }
        .task(id: selectedBranch) { await loadPreview() }
    }
}

// MARK: - Layout

extension UpdateBranchDialog {
    /// 可选的分支：设了仍存在的父分支的本地分支，按版本候选的顺序。
    var candidates: [RepositoryReference] {
        let branches = session.history.branches.filter { $0.isLocal && session.parentBranch(of: $0) != nil }
        return ReferenceOrder.candidates(branches, in: session.history.snapshot)
    }

    /// 所选分支；分支已不在候选里时为 nil。
    private var selectedBranch: RepositoryReference? {
        candidates.first { $0.id == selection }
    }

    /// 分支与提交数、合并方式、合并提交，以及冲突预览。
    @ViewBuilder
    private var form: some View {
        RepositoryDialogRows.row(AppLocalization.text("review.update.branch")) {
            Picker("", selection: $selection) {
                ForEach(candidates) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .frame(maxWidth: .infinity)
        }

        if let selectedBranch, let parent = session.parentBranch(of: selectedBranch) {
            DialogFormField {
                Text(
                    Self.summary(
                        behind: session.history.parentDivergence[selectedBranch.id]?.behind ?? 0,
                        parent: parent.name
                    )
                )
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        RepositoryDialogRows.row(AppLocalization.text("review.update.strategy")) {
            Picker("", selection: $rebase) {
                Text(AppLocalization.text("review.update.merge")).tag(false)
                Text(AppLocalization.text("review.update.rebase")).tag(true)
            }
            .labelsHidden()
            .fixedSize()
        }

        DialogFormOption(
            title: AppLocalization.text("merge.alwaysCommit"),
            help: AppLocalization.text("merge.alwaysCommit.help"),
            isOn: $alwaysCommit
        )
        .disabled(rebase)

        if let comparison, !previewFailed {
            DialogFormField {
                preview(comparison)
            }
        }
    }

    /// 分支下面的一行：会从父分支并入多少个提交，按单复数取文案。
    ///
    /// - Parameters:
    ///   - behind: 落后父分支的提交数。
    ///   - parent: 父分支名。
    static func summary(behind: Int, parent: String) -> String {
        behind == 1
            ? AppLocalization.text("review.update.integrates.one", parent)
            : AppLocalization.text("review.update.integrates", behind, parent)
    }

    /// 冲突预览：图标与结果，没有冲突时下面再写一句说明。
    private func preview(_ comparison: HistoryBaseComparison) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            UpdateBranchStatus(comparison: comparison)

            // 能干净并入时补一句说明
            if comparison.integratesCleanly {
                Text(AppLocalization.text("review.update.clean.help"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Actions

extension UpdateBranchDialog {
    /// 关闭对话框后按所选设置更新；冲突与本地改动由仓库窗口承接。
    private func submit() {
        guard let selectedBranch else {
            return
        }

        var options = MergeOptions()
        options.alwaysCreateCommit = alwaysCommit
        options.verifySignatures = verify
        options.skipHooks = skipHooks

        close()
        session.updateBranch(selectedBranch, rebase: rebase, options: options)
    }

    /// 读出所选分支与父分支的比较，作为冲突预览；读取失败时不显示预览。
    private func loadPreview() async {
        comparison = nil
        previewFailed = false

        guard
            let runner = session.runner,
            let selectedBranch,
            let parent = session.parentBranch(of: selectedBranch)
        else {
            return
        }

        // 先显示 “正在检查”，读完再换成结果
        comparison = HistoryBaseComparison(branch: selectedBranch, base: parent)

        do {
            let result = try await RepositoryReferences(runner: runner)
                .compare([selectedBranch.id: selectedBranch.objectID], toBase: parent.objectID)

            guard !Task.isCancelled else {
                return
            }

            comparison?.comparison = result[selectedBranch.id]
        } catch {
            previewFailed = !Task.isCancelled
        }
    }
}
