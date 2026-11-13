import SpookyKit
import SwiftUI

// MARK: - ResetDialog

/// 把 HEAD 重置到某个版本：选择版本与三档之一，每档写明暂存区与工作区会怎样，并列出离开当前分支的提交。
struct ResetDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 预填的版本；为 nil 时为空。
    let revision: String?

    /// 关闭对话框。
    let close: () -> Void

    /// 输入或选中的版本。
    @State
    private var target = ""

    /// 重置的档位，每次打开都从不丢改动的 mixed 开始。
    @State
    private var mode = ResetMode.mixed

    /// 重置后离开当前分支的提交，从新到旧。
    @State
    private var leaving: [HistoryCommit] = []

    /// 版本已解析成一个提交。
    @State
    private var resolved = false

    /// 版本解析失败的说明。
    @State
    private var error = ""

    /// 版本、档位与影响范围；服务器仓库在说明后写明在哪台服务器上执行。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("rewrite.reset.title"),
            message: session.rewriteDialogMessage(AppLocalization.text("rewrite.reset.help")),
            submitTitle: AppLocalization.text("rewrite.reset.button"),
            error: error,
            isValid: resolved,
            cancel: close,
            submit: perform
        ) {
            form
        }
        .onAppear { target = revision ?? "" }
        .task(id: target) { await preview() }
    }
}

// MARK: - Layout

extension ResetDialog {
    /// 填满输入列的版本组合框、三档单选与影响范围。
    @ViewBuilder
    private var form: some View {
        // 组合框是 AppKit 控件，没有文字基线可对，标签与它按竖直居中对齐
        DialogFormRow(label: AppLocalization.text("rewrite.revision"), alignment: .center) {
            RevisionComboBox(
                text: $target,
                items: session.revisionCandidates,
                label: AppLocalization.text("rewrite.revision")
            )
        }

        modeRow

        if mode == .hard, hasLocalChanges {
            DialogFormField {
                Label(AppLocalization.text("rewrite.reset.discards"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if !leaving.isEmpty {
            DialogFormField {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalization.text("rewrite.reset.leaving", leaving.count))

                    CommitSummaryList(rows: leaving.map { .init(id: $0.id, subject: $0.subject) })
                }
            }
        }
    }

    /// 占满输入列的三档单选，每档下面写明暂存区与工作区会怎样；标签与第一档的顶边对齐。
    ///
    /// 单选组不占满输入列时，量出的高度按较宽的说明折行，比实际排出的矮。
    private var modeRow: some View {
        DialogFormRow(label: AppLocalization.text("rewrite.reset.mode"), alignment: .top) {
            Picker("", selection: $mode) {
                ForEach(ResetMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLocalization.text("rewrite.reset." + mode.rawValue))

                        Text(AppLocalization.text("rewrite.reset." + mode.rawValue + ".help"))
                            .font(.system(size: 11))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .dialogFieldWidth(.infinity)
        }
    }

    /// 已跟踪的文件有改动；hard 会丢掉它们。
    private var hasLocalChanges: Bool {
        session.status?.entries.contains { $0.kind == .tracked || $0.kind == .conflicted } ?? false
    }
}

// MARK: - Actions

extension ResetDialog {
    /// 输入停顿后解析版本并读出离开当前分支的提交；解析失败时说明原因，主按钮不可用。
    private func preview() async {
        resolved = false

        // 输入停顿期间保留上一次的提交列表与错误，新结果出来后一次替换
        guard !target.isEmpty, let runner = session.runner else {
            DialogAnimation.perform {
                leaving = []
                error = ""
            }

            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let commits = try await RepositoryRewrite(runner: runner).commitsLeaving(to: target)
            try Task.checkCancellation()

            DialogAnimation.perform {
                leaving = commits
                resolved = true
                error = ""
            }
        } catch {
            if !Task.isCancelled {
                DialogAnimation.perform {
                    leaving = []
                    self.error = AppLocalization.text("rewrite.error.revision")
                }
            }
        }
    }

    /// 执行重置；仓库暂不可写时对话框保持打开。
    private func perform() {
        if session.reset(to: target, mode: mode) { close() }
    }
}
