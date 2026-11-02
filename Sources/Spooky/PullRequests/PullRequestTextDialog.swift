import SpookyKit
import SwiftUI

// MARK: - PullRequestTextDialog

/// 至多一个输入的对话框：发表、修改、回复与删除评论，只改描述，或检出时填本地分支名。
struct PullRequestTextDialog: View {
    /// 对话框的用途。
    enum Kind {
        /// 发表评论。
        case comment

        /// 修改一条评论，预填原文。
        case editComment(PullRequestComment)

        /// 回复一条评论。
        case reply(PullRequestComment)

        /// 删除一条评论，没有输入。
        case deleteComment(PullRequestComment)

        /// 只修改描述，预填原文。
        case editDescription

        /// 检出成本地分支。
        case checkout
    }

    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 请求。
    let request: PullRequest

    /// 对话框的用途。
    let kind: Kind

    /// 关闭 sheet。
    let close: () -> Void

    /// 输入的内容。
    @State
    private var text = ""

    /// 评论与描述是 300 高的多行输入，检出是单行的分支名，删除评论没有输入。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: title,
            message: message,
            submitTitle: submitTitle,
            error: "",
            isValid: isValid,
            cancel: close,
            submit: submit
        ) {
            switch kind {
            case .comment, .editComment, .reply:
                ReferenceDialogRows.row(AppLocalization.text("pullRequests.comment")) {
                    editor
                }

            case .editDescription:
                ReferenceDialogRows.row(AppLocalization.text("pullRequests.description")) {
                    editor
                }

            case .checkout:
                ReferenceDialogRows.row(AppLocalization.text("pullRequests.branchName")) {
                    TextField("", text: $text)
                }

            case .deleteComment:
                EmptyView()
            }
        }
        .onAppear(perform: prefill)
    }
}

// MARK: - Text

extension PullRequestTextDialog {
    /// 标题；发表与删除评论写出账号所在的服务。
    private var title: String {
        let service = AccountsSettingsView.serviceTitle(request.id.instance)

        return switch kind {
        case .comment: session.pullRequestText("comment.title", service)
        case .editComment: session.pullRequestText("editComment.title")
        case .reply: session.pullRequestText("replyComment.title")
        case .deleteComment: session.pullRequestText("deleteComment.title", service)
        case .editDescription: session.pullRequestText("editDescription.title")
        case .checkout: session.pullRequestText("checkout.title")
        }
    }

    /// 标题下的说明。
    private var message: String {
        switch kind {
        case .comment:
            session.pullRequestText(
                "comment.message",
                request.id.reference,
                AccountsSettingsView.serviceTitle(request.id.instance)
            )

        case .editComment: AppLocalization.text("pullRequests.editComment.message")

        case .reply: AppLocalization.text("pullRequests.replyComment.message")

        case .deleteComment: session.pullRequestText("deleteComment.message")

        case .editDescription: session.pullRequestText("editDescription.message")

        case .checkout:
            session.pullRequestText(
                "checkout.message",
                request.id.reference,
                PullRequestText.source(of: request)
            )
        }
    }

    /// 主按钮的标题。
    private var submitTitle: String {
        switch kind {
        case .comment: AppLocalization.text("pullRequests.addComment")
        case .editComment, .editDescription: AppLocalization.text("pullRequests.save")
        case .reply: AppLocalization.text("pullRequests.replyComment.submit")
        case .deleteComment: AppLocalization.text("pullRequests.deleteComment.submit")
        case .checkout: AppLocalization.text("pullRequests.checkout")
        }
    }
}

// MARK: - Private

extension PullRequestTextDialog {
    /// 评论与描述的多行输入，带边框。
    private var editor: some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .frame(height: 300)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
    }

    /// 描述可以清空，删除没有输入；其余要有不全是空白的内容。
    private var isValid: Bool {
        switch kind {
        case .editDescription, .deleteComment: true
        default: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// 修改评论与描述预填原文，检出预填源分支名。
    private func prefill() {
        switch kind {
        case .editComment(let comment): text = comment.body
        case .editDescription: text = request.body
        case .checkout: text = request.source.branch
        default: break
        }
    }

    /// 开始后关闭。
    private func submit() {
        let started =
            switch kind {
            case .comment: session.addComment(text, to: request)
            case .editComment(let comment): session.editComment(comment, body: text, on: request)
            case .reply(let comment): session.replyToComment(comment, body: text, on: request)
            case .deleteComment(let comment): session.deleteComment(comment, on: request)
            case .editDescription: session.updateDescription(text, of: request)
            case .checkout: session.checkoutPullRequest(request, as: text.trimmingCharacters(in: .whitespaces))
            }

        if started { close() }
    }
}
