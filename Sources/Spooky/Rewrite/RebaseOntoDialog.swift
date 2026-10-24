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

    /// 输入校验与读取失败的说明。
    @State
    private var error = ""

    /// 跳过 pre-rebase 钩子，只对本次有效。
    @State
    private var skipHooks = false

    /// 基点组合框、影响范围与 Skip Hooks。
    var body: some View {
        RewriteDialogFrame(
            session: session,
            title: AppLocalization.text("rewrite.rebaseOnto"),
            help: help,
            primary: AppLocalization.text("rewrite.rebaseOnto.button"),
            canSubmit: partial ? plan != nil : impact != nil,
            rewritesHistory: true,
            error: error,
            cancel: close,
            submit: perform
        ) {
            form
        } options: {
            RewriteOption(key: "sync.skipHooks", isOn: $skipHooks)
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
    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            if !partial {
                baseRow("rewrite.rebaseOnto.current", text: $currentBase)
            }

            baseRow("rewrite.rebaseOnto.new", text: $newBase)

            if let rows {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

                    VStack(alignment: .leading, spacing: 6) {
                        RewriteWarnings(pushed: !shared.pushed.isEmpty, merged: !shared.merged.isEmpty)

                        CommitSummaryList(rows: rows)
                    }
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

    /// 一行基点组合框。
    private func baseRow(_ key: String, text: Binding<String>) -> some View {
        GridRow {
            Text(AppLocalization.text(key)).gridColumnAlignment(.trailing)

            RevisionComboBox(text: text, items: session.revisionCandidates, label: AppLocalization.text(key))
                .frame(maxWidth: 350)
        }
    }
}

// MARK: - Actions

extension RebaseOntoDialog {
    /// 参数变化后重新读取影响范围；两个基点都不能是 HEAD 所在的提交。
    private func preview() async {
        impact = nil
        plan = nil

        guard let runner = session.runner, !newBase.isEmpty, partial || !currentBase.isEmpty else {
            error = AppLocalization.text("rewrite.rebaseOnto.missing")
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let rewrite = RepositoryRewrite(runner: runner)
            let references = RepositoryReferences(runner: runner)
            let head = session.status?.branch.oid

            if try await references.resolve(newBase) == head {
                error = AppLocalization.text("rewrite.rebaseOnto.newIsHead")
                return
            }

            if partial {
                plan = try await rewrite.plan(.rebase(commits, onto: newBase))
            } else if try await references.resolve(currentBase) == head {
                error = AppLocalization.text("rewrite.rebaseOnto.currentIsHead")
                return
            } else {
                impact = try await rewrite.rebasePreview(from: currentBase)
            }

            try Task.checkCancellation()
            error = ""
        } catch {
            if !Task.isCancelled {
                self.error = AppFailure(error: error, opening: false, location: session.repository).title
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
}
