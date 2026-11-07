import AppKit
import SpookyKit
import SwiftUI

// MARK: - PullRequestConversationTextRow

/// 讨论里高度随正文变化的行：描述与评论，行高按列宽量出。
///
/// 位置从单元格左缘算：40 × 40 的作者头像左 0、上 20；标题一行左 60、与头像顶对齐；
/// 正文左 60、上 46、右 20、下 20，头像下至少留 20。正文按完整的 Markdown 显示。
struct PullRequestConversationTextRow: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 显示的请求。
    let request: PullRequest

    /// 这一行：描述或评论。
    let item: PullRequestConversationItem

    /// Settings → General 选的日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 头像在左，标题一行与正文在右。
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            HostingUserAvatar(user: author, size: 40)

            VStack(alignment: .leading, spacing: 0) {
                // 标题一行占 26，正文从上 46 起
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)

                    // 评论上的动作条右缘与正文对齐，与右键菜单打开同样的对话框
                    if case .comment(let comment) = item {
                        let actions = commentActions(comment)

                        if !actions.isEmpty {
                            FileActionBar(actions: actions, hovering: true, segmented: false)
                        }
                    }

                    // 描述上的 Edit 只在能修改描述时出现，打开修改描述的对话框
                    if case .description = item, session.canEditDescription(of: request) {
                        Button(AppLocalization.text("pullRequests.edit")) {
                            session.requestPullRequest(.editDescription(request))
                        }
                    }
                }
                .frame(height: 26, alignment: .topLeading)

                content
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
    }
}

// MARK: - Layout

extension PullRequestConversationTextRow {
    /// 描述是请求的作者，评论是评论的作者。
    private var author: HostingUser {
        guard case .comment(let comment) = item else {
            return request.author
        }

        return comment.author
    }

    /// 描述写创建请求的日期；评论在更新时间晚于发表时间时写编辑的日期，否则写发表的日期。
    private var title: String {
        guard case .comment(let comment) = item else {
            return session.pullRequestText(
                "description.title",
                request.author.username,
                dateFormat.string(from: request.createdAt)
            )
        }

        guard let updatedAt = comment.updatedAt, updatedAt > comment.createdAt else {
            return AppLocalization.text(
                "pullRequests.comment.commented",
                comment.author.username,
                dateFormat.string(from: comment.createdAt)
            )
        }

        return AppLocalization.text(
            "pullRequests.comment.edited",
            comment.author.username,
            dateFormat.string(from: updatedAt)
        )
    }

    /// 正文；没有描述时写出没有描述，与正文同色；内容为空的评论写出已删除，用次级色。
    @ViewBuilder
    private var content: some View {
        switch item {
        case .description where request.body.isEmpty:
            Text(AppLocalization.text("pullRequests.noDescription"))

        case .description:
            PullRequestMarkdownView(text: request.body)

        case .comment(let comment) where comment.body.isEmpty:
            Text(AppLocalization.text("pullRequests.comment.deleted"))
                .foregroundStyle(.secondary)

        case .comment(let comment):
            PullRequestMarkdownView(text: comment.body)

        default:
            EmptyView()
        }
    }

    /// 评论上的动作：能修改时是 Edit 与 Delete，能回复时再加 Reply；都不能时为空。
    private func commentActions(_ comment: PullRequestComment) -> [FileViewAction] {
        var actions: [FileViewAction] = []

        if session.canModify(comment) {
            actions.append(FileViewAction(title: AppLocalization.text("pullRequests.comment.edit")) {
                session.requestPullRequest(.editComment(request, comment))
            })

            actions.append(FileViewAction(title: AppLocalization.text("pullRequests.comment.delete")) {
                session.requestPullRequest(.deleteComment(request, comment))
            })
        }

        if session.canReplyToComments {
            actions.append(FileViewAction(title: AppLocalization.text("pullRequests.comment.reply")) {
                session.requestPullRequest(.replyToComment(request, comment))
            })
        }

        return actions
    }
}

// MARK: - PullRequestCommitGroupRow

/// 34 pt 的提交组标题：单元格左缘起 32 是 20 × 20 的历史图标，60 起是几个提交在哪天加入。
struct PullRequestCommitGroupRow: View {
    /// 这一组提交。
    let group: PullRequestCommitGroup

    /// 日期跟随 Settings → General 的日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 图标与 13 pt 的三级色标题，标题放不下时在末尾截断。
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            Text(group.title(format: dateFormat))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 2)
        }
        .padding(.leading, 32)
        .frame(height: 34)
    }
}

// MARK: - PullRequestConversationCommitRow

/// 24 pt 的提交行：单元格左缘起 44 是 17 × 17 的作者头像，其后是短哈希与标题，行尾是签名按钮。
struct PullRequestConversationCommitRow: View {
    /// 这一行的提交。
    let commit: HistoryCommit

    /// 窗口的签名结果。
    let signatures: CommitSignatureStore

    /// 校验签名用的执行器。
    let runner: GitRunner?

    /// 头像后 8 是等宽的短哈希，再后 4 是标题；签名按钮距右 16，没有有效签名时留空。
    var body: some View {
        HStack(spacing: 0) {
            InitialsAvatar(name: commit.author, email: commit.authorEmail, size: 17)
                .padding(.trailing, 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(commit.shortID)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()

                Text(commit.subject)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            CommitSignatureButton(store: signatures, commit: commit.id, runner: runner, small: false)
                .frame(width: 16, height: 16)
        }
        .padding(.leading, 44)
        .padding(.trailing, 16)
        .frame(height: 24)
    }
}

// MARK: - PullRequestAddCommentCell

/// 讨论末尾发表评论的一行：“Add Comment” 按钮水平居中，上下各留 20，⌘S 同样按下它。
final class PullRequestAddCommentCell: NSView {
    /// 发表评论的按钮。
    let button = NSButton()

    /// 按下按钮时的动作。
    var perform: () -> Void = { }

    /// 建立居中的按钮。
    init() {
        super.init(frame: .zero)

        button.title = AppLocalization.text("pullRequests.addComment")
        button.bezelStyle = .toolbar
        button.keyEquivalent = "s"
        button.keyEquivalentModifierMask = .command
        button.target = self
        button.action = #selector(press)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            trailingAnchor.constraint(greaterThanOrEqualTo: button.trailingAnchor, constant: 20),
        ])
    }

    /// 单元格由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("PullRequestAddCommentCell 不从归档恢复")
    }

    /// 执行发表评论的动作。
    @objc
    private func press() {
        perform()
    }
}

// MARK: - PullRequestConversationRowView

/// 讨论的行底：选中时整行填讨论的选中色，单元格的文字颜色不随选中改变。
final class PullRequestConversationRowView: NSTableRowView {
    /// 行底的样式。
    enum Style {
        /// 头部：没有分隔线。
        case plain

        /// 描述、评论与发表评论：顶边一条分隔线。
        case separated

        /// 提交与组末的空白：交替行的底色。
        case event

        /// 提交组：交替行的底色，顶边一条 1 pt 的分隔线。
        case eventGroup
    }

    /// 这一行的样式。
    let style: Style

    /// 选中时单元格仍按普通底色显示文字。
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }

    /// 按样式创建行底。
    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
    }

    /// 行底由代码创建。
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("PullRequestConversationRowView 不从归档恢复")
    }

    /// 提交组、提交与空白用交替行的底色，其余用列表的底色。
    override func drawBackground(in dirtyRect: NSRect) {
        guard style == .event || style == .eventGroup else {
            super.drawBackground(in: dirtyRect)

            return
        }

        AppPalette.nsColor("general_alternate_row_background_color").setFill()
        dirtyRect.fill()
    }

    /// 选中的行整行填讨论的选中色，不区分窗口是否在前台。
    override func drawSelection(in dirtyRect: NSRect) {
        AppPalette.nsColor("repository_pullrequests_conversation_selection_color").setFill()
        bounds.intersection(dirtyRect).fill()
    }

    /// 底色与选中色之上，按样式在顶边画分隔线。
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard style == .separated || style == .eventGroup else {
            return
        }

        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
}
