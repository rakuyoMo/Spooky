import SpookyKit
import SwiftUI

// MARK: - PullRequestConversationView

/// Conversation 段：标题、谁想把哪个分支合并进哪个分支、指派，描述与修改入口，评论与发表评论的入口。
///
/// 描述与评论按 Markdown 的行内格式显示；GitLab 的系统记录用次级色写成一行。
struct PullRequestConversationView: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 显示的请求。
    let request: PullRequest

    /// Settings → General 选的日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 头部、描述、评论与发表评论的按钮依次排列。
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary

                entry(
                    author: request.author,
                    date: request.createdAt,
                    body: request.body.isEmpty ? nil : request.body,
                    action: (AppLocalization.text("pullRequests.edit"), { session.requestPullRequest(.edit(request)) })
                )

                ForEach(session.pullRequests.comments) { comment in
                    if comment.isSystem {
                        systemNote(comment)
                    } else {
                        entry(author: comment.author, date: comment.createdAt, body: comment.body, action: nil)
                    }
                }

                Button(AppLocalization.text("pullRequests.addComment")) { session.requestPullRequest(.comment(request)) }
                    .disabled(session.pullRequests.client == nil)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Layout

extension PullRequestConversationView {
    /// 标题、合并方向与指派。
    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(request.title)
                .font(.system(size: 18, weight: .semibold))
                .textSelection(.enabled)

            Text(
                AppLocalization.text(
                    "pullRequests.summary",
                    request.author,
                    PullRequestText.source(of: request),
                    request.target.branch
                )
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)

            if !request.assignees.isEmpty {
                Text(AppLocalization.text("pullRequests.assignees", request.assignees.joined(separator: ", ")))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 描述或一条评论：作者与时间、内容；描述没有内容时写出没有描述。
    private func entry(author: String, date: Date, body: String?, action: (String, () -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(author)
                    .font(.system(size: 12, weight: .semibold))

                Text(dateFormat.string(from: date))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let action {
                    Button(action.0, action: action.1)
                        .controlSize(.small)
                        .disabled(session.pullRequests.client == nil)
                }
            }

            Text(Self.markdown(body ?? AppLocalization.text("pullRequests.noDescription")))
                .font(.system(size: 13))
                .foregroundStyle(body == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(AppPalette.color("general_secondary_background_color")))
    }

    /// GitLab 的系统记录：作者、内容与时间写成一行。
    private func systemNote(_ comment: PullRequestComment) -> some View {
        Text(comment.author + " " + comment.body + " · " + dateFormat.string(from: comment.createdAt))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
    }
}

// MARK: - Markdown

extension PullRequestConversationView {
    /// 按 Markdown 的行内格式解析，保留原有的换行；解析不了时原样显示。
    fileprivate static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
