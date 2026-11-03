import SpookyKit
import SwiftUI

// MARK: - RewordDialog

/// 改写某个提交的信息：标题与正文预填原信息，下方列出会被改写的提交；保存时按提交区的规则处理注释行。
struct RewordDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 改信息的计划，范围从这个提交开始。
    let plan: RewritePlan

    /// 关闭对话框。
    let close: () -> Void

    /// 新标题。
    @State
    private var subject = ""

    /// 新正文。
    @State
    private var messageBody = ""

    /// 标题框、正文框与影响范围占满内容区的宽度；服务器仓库在说明后写明在哪台服务器上执行。
    var body: some View {
        RepositoryDialogLayout(
            session: session,
            title: AppLocalization.text("rewrite.reword.title", String(commit?.shortID ?? "")),
            message: session.rewriteDialogMessage(AppLocalization.text("rewrite.reword.help")),
            submitTitle: AppLocalization.text("rewrite.reword.button"),
            error: "",
            isValid: !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            cancel: close,
            submit: perform
        ) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("", text: $subject, prompt: Text(AppLocalization.text("working.subject")))
                    .accessibilityLabel(AppLocalization.text("working.subject"))

                TextEditor(text: $messageBody)
                    .font(.system(size: 13))
                    .frame(height: 180)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppPalette.color("general_border_color")))
                    .accessibilityLabel(AppLocalization.text("working.body"))

                RewriteImpactView(plan: plan)
            }
        }
        .onAppear {
            (subject, messageBody) = CommitMessage.parts(of: commit?.message ?? "")
        }
    }
}

// MARK: - Private

extension RewordDialog {
    /// 要改信息的提交。
    private var commit: HistoryCommit? {
        guard case .reword(let id, _) = plan.action else {
            return nil
        }

        return plan.commits.first { $0.id == id }
    }

    /// 先关闭对话框，注释行的询问与执行都交给仓库窗口。
    private func perform() {
        close()
        session.reword(plan, subject: subject, body: messageBody)
    }
}
