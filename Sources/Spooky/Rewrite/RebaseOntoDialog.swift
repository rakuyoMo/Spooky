import SpookyKit
import SwiftUI

// MARK: - RebaseOntoDialog

/// 变基到别处：把当前分支上当前基点之后的提交移到新基点上；给出所选提交时只移动它们，只需选新基点。
///
/// 两种情况都在执行前列出会被改写的提交，已推送或已并入其它分支时给出警告。
struct RebaseOntoDialog: View {
    /// 会被改写的提交。
    private enum Scope {
        /// 移动当前基点之后的全部提交时的影响范围。
        case range(RewriteImpact)

        /// 只移动所选提交时的计划。
        case plan(RewritePlan)
    }

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

    /// 会被改写的提交与输入校验、读取失败的说明，记着对应的两个基点；参数变化后仍显示上一次的，读完之前主按钮不可用。
    @State
    private var scope = RevisionPreview<[String], Scope>()

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
            error: scope.error,
            isValid: scope.value(for: bases) != nil,
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
        .task(id: bases) { await preview() }
    }
}

// MARK: - Layout

extension RebaseOntoDialog {
    /// 只移动所选提交。
    private var partial: Bool {
        !commits.isEmpty
    }

    /// 当前基点与新基点，影响范围按它们读取。
    private var bases: [String] {
        [currentBase, newBase]
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
        switch scope.value {
        case .range(let impact): (impact.pushed, impact.merged)
        case .plan(let plan): (plan.pushed, plan.merged)
        case nil: ([], [])
        }
    }

    /// 影响范围的行：只移动所选提交时，同一段里没选的提交标为删除。
    private var rows: [CommitSummaryList.Row]? {
        let all = shared.pushed.union(shared.merged)

        if case .range(let impact) = scope.value {
            return impact.commits.map { .init(id: $0.id, subject: $0.subject, isShared: all.contains($0.id)) }
        }

        if case .plan(let plan) = scope.value {
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

        return nil
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
        let input = bases
        let (current, new) = (currentBase, newBase)

        // 参数变化后保留上一次的影响范围与错误，新结果出来后一次替换
        guard let runner = session.runner, !new.isEmpty, partial || !current.isEmpty else {
            show(nil, error: AppLocalization.text("rewrite.rebaseOnto.missing"), for: input)
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let rewrite = RepositoryRewrite(runner: runner)
            let references = RepositoryReferences(runner: runner)
            let head = session.status?.branch.oid

            if try await references.resolve(new) == head {
                show(nil, error: AppLocalization.text("rewrite.rebaseOnto.newIsHead"), for: input)
                return
            }

            let found: Scope

            if partial {
                found = try await .plan(rewrite.plan(.rebase(commits, onto: new)))
            } else if try await references.resolve(current) == head {
                show(nil, error: AppLocalization.text("rewrite.rebaseOnto.currentIsHead"), for: input)
                return
            } else {
                found = try await .range(rewrite.rebasePreview(from: current))
            }

            try Task.checkCancellation()

            show(found, for: input)
        } catch {
            if !Task.isCancelled {
                show(
                    nil,
                    error: AppFailure(error: error, opening: false, location: session.repository).title,
                    for: input
                )
            }
        }
    }

    /// 执行变基：只用按当前两个基点读完的结果；仓库暂不可写时对话框保持打开。
    private func perform() {
        guard let found = scope.value(for: bases) else {
            return
        }

        let started =
            switch found {
            case .plan(let plan): session.perform(plan, skipHooks: skipHooks)
            case .range: session.rebase(onto: newBase, from: currentBase, skipHooks: skipHooks)
            }

        if started { close() }
    }

    /// 某组基点读完：影响范围与错误随高度动画一次替换；读不出影响范围时收起它，错误区说明原因。
    ///
    /// - Parameters:
    ///   - found: 读到的影响范围；读不出时为 nil。
    ///   - error: 错误区的说明；没有错误时为空。
    ///   - input: 读取时的两个基点。
    private func show(_ found: Scope?, error: String = "", for input: [String]) {
        DialogAnimation.perform { scope.show(found, error: error, for: input) }
    }
}
