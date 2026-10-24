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

    /// 版本、档位与影响范围。
    var body: some View {
        RewriteDialogFrame(
            session: session,
            title: AppLocalization.text("rewrite.reset.title"),
            help: AppLocalization.text("rewrite.reset.help"),
            primary: AppLocalization.text("rewrite.reset.button"),
            canSubmit: resolved,
            rewritesHistory: true,
            error: error,
            cancel: close,
            submit: perform
        ) {
            form
        } options: {
            EmptyView()
        }
        .onAppear { target = revision ?? "" }
        .task(id: target) { await preview() }
    }
}

// MARK: - Layout

extension ResetDialog {
    /// 版本组合框、三档单选与影响范围。
    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            GridRow {
                Text(AppLocalization.text("rewrite.revision")).gridColumnAlignment(.trailing)

                RevisionComboBox(
                    text: $target,
                    items: session.revisionCandidates,
                    label: AppLocalization.text("rewrite.revision")
                )
                .frame(maxWidth: 350)
            }

            modeRow

            if mode == .hard, hasLocalChanges {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

                    Label(AppLocalization.text("rewrite.reset.discards"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !leaving.isEmpty {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalization.text("rewrite.reset.leaving", leaving.count))

                        CommitSummaryList(rows: leaving.map { .init(id: $0.id, subject: $0.subject) })
                    }
                }
            }
        }
    }

    /// 三档单选，每档下面写明暂存区与工作区会怎样。
    private var modeRow: some View {
        GridRow(alignment: .top) {
            Text(AppLocalization.text("rewrite.reset.mode"))

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
            .accessibilityLabel(AppLocalization.text("rewrite.reset.mode"))
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
        leaving = []

        guard !target.isEmpty, let runner = session.runner else {
            error = ""
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
            let commits = try await RepositoryRewrite(runner: runner).commitsLeaving(to: target)
            try Task.checkCancellation()

            leaving = commits
            resolved = true
            error = ""
        } catch {
            if !Task.isCancelled { self.error = AppLocalization.text("rewrite.error.revision") }
        }
    }

    /// 执行重置；仓库暂不可写时对话框保持打开。
    private func perform() {
        if session.reset(to: target, mode: mode) { close() }
    }
}
