import SpookyKit
import SwiftUI

// MARK: - RebaseOntoDialog

/// 变基到别处：把当前分支上当前基点之后的提交移到新基点上；给出所选提交时只移动它们，只需选新基点。
///
/// 两种情况都在执行前列出会被改写的提交，已推送或已并入其它分支时给出警告。
struct RebaseOntoDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 只移动的提交，按历史列表从新到旧；为空时移动当前基点之后的全部提交。
    let commits: [String]

    /// 关闭对话框。
    let close: () -> Void

    /// 当前基点。
    @State
    private var currentBase = ""

    /// 新基点。
    @State
    private var newBase = ""

    /// 会被改写的提交与其中已共享的提交；参数不完整或读取失败时为 nil。
    @State
    private var impact: RewriteImpact?

    /// 只移动所选提交时的计划。
    @State
    private var plan: RewritePlan?

    /// 影响范围是否按当前参数读完；参数变化后仍显示上一次的结果，读完之前主按钮不可用。
    @State
    private var previewed = false

    /// 输入校验与读取失败的说明。
    @State
    private var error = ""

    /// 跳过 pre-rebase 钩子，只对本次有效。
    @State
    private var skipHooks = false

    /// 基点组合框与影响范围，选项区是 Skip Hooks；服务器仓库在说明后写明在哪台服务器上执行。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("rewrite.rebaseOnto"),
            message: session.rewriteDialogMessage(help),
            submitTitle: AppLocalization.text("rewrite.rebaseOnto.button"),
            error: error,
            isValid: previewed && (partial ? plan != nil : impact != nil),
            cancel: close,
            submit: perform
        ) {
            form
        } options: {
            DialogFormOption(
                title: AppLocalization.text("sync.skipHooks"),
                help: AppLocalization.text("sync.skipHooks.help"),
                isOn: $skipHooks
            )
        }
        .task(id: currentBase + "\u{0}" + newBase) { await preview() }
    }
}

// MARK: - Layout

extension RebaseOntoDialog {
    /// 只移动所选提交。
    private var partial: Bool {
        !commits.isEmpty
    }

    /// 说明：移动整段时说明基点，只移动所选提交时写出提交数。
    private var help: String {
        switch commits.count {
        case 0: AppLocalization.text("rewrite.rebaseOnto.help")
        case 1: AppLocalization.text("rewrite.rebaseOnto.partial.help.one")
        default: AppLocalization.text("rewrite.rebaseOnto.partial.help", commits.count)
        }
    }

    /// 当前基点（只移动所选提交时不需要）、新基点与影响范围。
    @ViewBuilder
    private var form: some View {
        if !partial {
            baseRow("rewrite.rebaseOnto.current", text: $currentBase)
        }

        baseRow("rewrite.rebaseOnto.new", text: $newBase)

        if let rows {
            DialogFormField {
                VStack(alignment: .leading, spacing: 6) {
                    RewriteWarnings(pushed: !shared.pushed.isEmpty, merged: !shared.merged.isEmpty)

                    CommitSummaryList(rows: rows)
                }
            }
        }
    }

    /// 已推送与已并入其它分支的提交。
    private var shared: (pushed: Set<String>, merged: Set<String>) {
        (plan?.pushed ?? impact?.pushed ?? [], plan?.merged ?? impact?.merged ?? [])
    }

    /// 影响范围的行：只移动所选提交时，同一段里没选的提交标为删除。
    private var rows: [CommitSummaryList.Row]? {
        let all = shared.pushed.union(shared.merged)

        if let plan {
            let commands = Dictionary(plan.instructions.map { ($0.commit, $0.command) }, uniquingKeysWith: { $1 })

            return plan.commits.reversed().map {
                CommitSummaryList.Row(
                    id: $0.id,
                    subject: $0.subject,
                    note: commands[$0.id] == .drop ? AppLocalization.text("rewrite.note.drop") : "",
                    isShared: all.contains($0.id)
                )
            }
        }

        return impact?.commits.map { .init(id: $0.id, subject: $0.subject, isShared: all.contains($0.id)) }
    }

    /// 一行填满输入列的基点组合框。
    private func baseRow(_ key: String, text: Binding<String>) -> some View {
        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐
        DialogFormRow(label: AppLocalization.text(key), alignment: .center) {
            RevisionComboBox(text: text, items: session.revisionCandidates, label: AppLocalization.text(key))
        }
    }
}

// MARK: - Actions

extension RebaseOntoDialog {
    /// 参数变化后重新读取影响范围；两个基点都不能是 HEAD 所在的提交。
    private func preview() async {
        previewed = false

        // 参数变化后保留上一次的影响范围与错误，新结果出来后一次替换
        guard let runner = session.runner, !newBase.isEmpty, partial || !currentBase.isEmpty else {
            clearPreview(reason: AppLocalization.text("rewrite.rebaseOnto.missing"))
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let rewrite = RepositoryRewrite(runner: runner)
            let references = RepositoryReferences(runner: runner)
            let head = session.status?.branch.oid

            if try await references.resolve(newBase) == head {
                clearPreview(reason: AppLocalization.text("rewrite.rebaseOnto.newIsHead"))
                return
            }

            var impact: RewriteImpact? = nil
            var plan: RewritePlan? = nil

            if partial {
                plan = try await rewrite.plan(.rebase(commits, onto: newBase))
            } else if try await references.resolve(currentBase) == head {
                clearPreview(reason: AppLocalization.text("rewrite.rebaseOnto.currentIsHead"))
                return
            } else {
                impact = try await rewrite.rebasePreview(from: currentBase)
            }

            try Task.checkCancellation()

            DialogAnimation.perform {
                self.impact = impact
                self.plan = plan
                previewed = true
                error = ""
            }
        } catch {
            if !Task.isCancelled {
                clearPreview(reason: AppFailure(error: error, opening: false, location: session.repository).title)
            }
        }
    }

    /// 执行变基；仓库暂不可写时对话框保持打开。
    private func perform() {
        let started =
            if let plan {
                session.perform(plan, skipHooks: skipHooks)
            } else {
                session.rebase(onto: newBase, from: currentBase, skipHooks: skipHooks)
            }

        if started { close() }
    }

    /// 读不出影响范围时收起它，错误区说明原因。
    private func clearPreview(reason: String) {
        DialogAnimation.perform {
            impact = nil
            plan = nil
            error = reason
        }
    }
}
