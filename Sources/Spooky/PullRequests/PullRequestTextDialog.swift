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

    /// 检出时分支名的问题。
    enum BranchNameProblem: Equatable {
        /// 不合法，带原因；不能检出。
        case invalid(String)

        /// 同名的本地分支指向别的提交；只提醒，仍可检出。
        case taken

        /// 错误区写出的说明。
        var message: String {
            switch self {
            case .invalid(let reason): reason
            case .taken: AppLocalization.text("pullRequests.error.branchMismatch.help")
            }
        }
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

    /// 检出时分支名的问题；没有问题或还没校验完时为 nil。
    @State
    private var nameProblem: BranchNameProblem? = nil

    /// 评论与描述是占满宽度、高 300 的多行输入，检出是从对齐线开始的分支名，删除评论没有内容区。
    ///
    /// 仓库暂不可写时主按钮禁用，错误区写出原因。
    var body: some View {
        DialogLayout(
            title: title,
            message: message,
            submitTitle: submitTitle,
            error: error,
            canSubmit: canSubmit,
            cancel: close,
            submit: submit
        ) {
            switch kind {
            case .comment, .editComment, .reply:
                editor(label: AppLocalization.text("pullRequests.comment"))

            case .editDescription:
                editor(label: AppLocalization.text("pullRequests.description"))

            case .checkout:
                DialogForm {
                    DialogFormRow(label: AppLocalization.text("pullRequests.branchName")) {
                        TextField("", text: $text)
                    }
                }

            case .deleteComment:
                EmptyView()
            }
        }
        .onAppear(perform: prefill)
        .task(id: text) { await validateBranchName() }
    }
}

// MARK: - Checkout

extension PullRequestTextDialog {
    /// 检出说明里的源分支：来自 Fork 时写成 `作者:分支`。
    static func checkoutSource(of request: PullRequest) -> String {
        guard request.isFromFork else {
            return request.source.branch
        }

        return request.author.username + ":" + request.source.branch
    }

    /// 检出时预填的本地分支名：同一项目的请求是源分支名，来自 Fork 时是 `pullrequests/<作者>/<源分支>`。
    static func checkoutBranchName(for request: PullRequest) -> String {
        guard request.isFromFork else {
            return request.source.branch
        }

        return "pullrequests/" + request.author.username + "/" + request.source.branch
    }

    /// 检出时分支名的问题：按 Git 的分支规则不合法时带原因，同名的本地分支指向别的提交时是提醒；没有问题时为 nil。
    ///
    /// - Parameters:
    ///   - name: 去掉首尾空格的分支名。
    ///   - request: 要检出的请求。
    ///   - session: 仓库的会话，提供执行器与已读到的引用。
    static func branchNameProblem(
        _ name: String,
        for request: PullRequest,
        in session: RepositorySession
    ) async -> BranchNameProblem? {
        guard !name.isEmpty, let runner = session.runner else {
            return nil
        }

        do {
            try await RepositoryReferences(runner: runner).validate(name: name)
        } catch {
            return .invalid(ReferenceDialogRows.validationMessage(error, in: session))
        }

        let existing = session.history.snapshot?.references
            .first { $0.id == "refs/heads/" + name }?
            .objectID

        let source = request.source.sha.lowercased()

        // 没有同名分支、源分支提交未知，或同名分支就在源分支提交上时没有问题
        guard let existing, !source.isEmpty, existing.lowercased() != source else {
            return nil
        }

        return .taken
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
            AppLocalization.text("pullRequests.checkout.message", Self.checkoutSource(of: request))
        }
    }

    /// 错误区：分支名不合法的原因、同名分支指向别的提交的提醒，以及仓库暂不可写；都没有时为 nil。
    private var error: String? {
        let messages = [
            nameProblem?.message,
            session.canWrite ? nil : AppLocalization.text("dialog.blocked"),
        ]

        let text = messages.compactMap(\.self).joined(separator: "\n")
        return text.isEmpty ? nil : text
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
    /// 描述可以清空，删除没有输入；其余要有不全是空白的内容。
    private var isValid: Bool {
        switch kind {
        case .editDescription, .deleteComment: true
        default: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// 内容有效、仓库可写，且分支名没有不合法时才能提交；同名分支指向别的提交只是提醒，不挡提交。
    private var canSubmit: Bool {
        guard isValid, session.canWrite else {
            return false
        }

        if case .invalid = nameProblem {
            return false
        }

        return true
    }

    /// 评论与描述的多行输入：四周留 20、占满对话框的宽度、高 300，带边框；没有可见的标签，VoiceOver 读出去掉冒号的标签。
    private func editor(label: String) -> some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .frame(height: 300)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
            .accessibilityLabel(label.trimmingCharacters(in: CharacterSet(charactersIn: ":：")))
            .padding(20)
    }

    /// 修改评论与描述预填原文，检出预填本地分支名。
    private func prefill() {
        switch kind {
        case .editComment(let comment): text = comment.body
        case .editDescription: text = request.body
        case .checkout: text = Self.checkoutBranchName(for: request)
        default: break
        }
    }

    /// 检出时输入停下后校验分支名，较早的输入的结果不覆盖较新的。
    private func validateBranchName() async {
        guard case .checkout = kind else {
            return
        }

        try? await Task.sleep(for: .milliseconds(150))

        guard !Task.isCancelled else {
            return
        }

        let problem = await Self.branchNameProblem(
            text.trimmingCharacters(in: .whitespaces),
            for: request,
            in: session
        )

        guard !Task.isCancelled else {
            return
        }

        nameProblem = problem
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
