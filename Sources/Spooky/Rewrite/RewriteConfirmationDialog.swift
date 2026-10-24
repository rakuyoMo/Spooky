import SpookyKit
import SwiftUI

// MARK: - RewriteConfirmationDialog

/// 交互式变基执行前的确认：说明动作，列出会被改写的提交与它们的去向，提交已共享时给出警告。
struct RewriteConfirmationDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 待确认的计划。
    let plan: RewritePlan

    /// 关闭对话框。
    let close: () -> Void

    /// 警告、影响范围与 Reflog 的说明。
    var body: some View {
        RewriteDialogFrame(
            session: session,
            title: AppLocalization.text(RepositorySession.titleKey(of: plan.action)),
            help: question,
            primary: AppLocalization.text(RepositorySession.titleKey(of: plan.action) + ".button"),
            canSubmit: true,
            rewritesHistory: true,
            cancel: close,
            submit: perform
        ) {
            RewriteImpactView(plan: plan, notes: notes)
        } options: {
            EmptyView()
        }
    }
}

// MARK: - Layout

extension RewriteConfirmationDialog {
    /// 确认的问题，写出提交数或目标提交的标题。
    private var question: String {
        let key = RepositorySession.titleKey(of: plan.action) + ".confirm"
        switch plan.action {
        case .squash, .fixup:
            // 并入的提交紧跟在目标之后
            let folded = plan.instructions.filter { [.squash, .fixup].contains($0.command) }
            let index = plan.instructions.firstIndex { [.squash, .fixup].contains($0.command) } ?? 0
            let into = index > 0 ? plan.instructions[index - 1].subject : ""
            return AppLocalization.text(key, folded.count, into)

        case .edit(let commit), .amend(let commit):
            return AppLocalization.text(key, subject(of: commit))

        case .reword:
            return AppLocalization.text("rewrite.reword.help")

        case .drop(let commits), .move(let commits, _, _), .rebase(let commits, _):
            return AppLocalization.text(key, commits.count)

        case .autosquash:
            return AppLocalization.text(key)
        }
    }

    /// 每个提交的去向说明，按提交哈希。
    private var notes: [String: String] {
        switch plan.action {
        case .move(let commits, _, _):
            return Dictionary(commits.map { ($0, AppLocalization.text("rewrite.note.move")) }, uniquingKeysWith: { $1 })

        case .amend(let commit):
            return [commit: AppLocalization.text("rewrite.note.amend")]

        default:
            let keys: [RebaseInstruction.Command: String] = [
                .drop: "rewrite.note.drop", .squash: "rewrite.note.squash", .fixup: "rewrite.note.fixup",
                .edit: "rewrite.note.edit",
            ]

            return Dictionary(
                plan.instructions.compactMap { line in keys[line.command].map { (line.commit, AppLocalization.text($0)) } },
                uniquingKeysWith: { $1 }
            )
        }
    }

    /// 范围里某个提交的标题。
    private func subject(of commit: String) -> String {
        plan.commits.first { $0.id == commit }?.subject ?? String(commit.prefix(8))
    }

    /// 执行计划；仓库暂不可写时对话框保持打开。
    private func perform() {
        if session.perform(plan) { close() }
    }
}

// MARK: - RewriteImpactView

/// 改写的影响范围：已共享的警告、会被改写的提交数与列表，以及可从 Reflog 找回的说明。
struct RewriteImpactView: View {
    /// 计划。
    let plan: RewritePlan

    /// 每个提交的去向说明，按提交哈希。
    var notes: [String: String] = [:]

    /// 自上而下：警告、计数、列表与说明。
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RewriteWarnings(pushed: !plan.pushed.isEmpty, merged: !plan.merged.isEmpty)

            Text(AppLocalization.text("rewrite.affected", plan.commits.count))

            CommitSummaryList(
                rows: plan.commits.reversed().map {
                    CommitSummaryList.Row(
                        id: $0.id,
                        subject: $0.subject,
                        note: notes[$0.id] ?? "",
                        isShared: plan.pushed.contains($0.id) || plan.merged.contains($0.id)
                    )
                }
            )

            Text(AppLocalization.text("rewrite.reflog"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
