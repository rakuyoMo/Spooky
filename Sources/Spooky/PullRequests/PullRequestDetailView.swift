import SpookyKit
import SwiftUI

// MARK: - PullRequestDetailView

/// 所选请求的详情：头部是编号与 Conversation | Commits | Changeset 分段，底部是检出、关闭与合并。
///
/// 提交与改动在仓库所在的机器上比较；源分支的提交还不在仓库里时先获取。
struct PullRequestDetailView: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 没有选中时是空状态，否则是头部、内容与底栏。
    var body: some View {
        Group {
            if let request = state.detail {
                VStack(spacing: 0) {
                    header(request)

                    Divider()

                    content(request)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    actions(request)
                }
            } else if let failure = state.detailFailure {
                FailureDetailsView(failure: failure)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if state.isLoadingDetail {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    title: session.pullRequestText("noSelection"),
                    message: "",
                    symbol: "arrow.triangle.pull"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 420)
    }
}

// MARK: - Layout

extension PullRequestDetailView {
    /// 详情的状态。
    private var state: RepositoryPullRequestState { session.pullRequests }

    /// 40 pt 头部：编号与分段；状态在讨论的头部。
    private func header(_ request: PullRequest) -> some View {
        HStack(spacing: 8) {
            Text(request.id.reference)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            if state.isLoadingDetail {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer(minLength: 8)

            Picker("", selection: Binding(get: { state.page }, set: { select($0) })) {
                Text(AppLocalization.text("pullRequests.conversation")).tag(RepositoryPullRequestState.Page.conversation)
                Text(AppLocalization.text("pullRequests.commits")).tag(RepositoryPullRequestState.Page.commits)
                Text(AppLocalization.text("pullRequests.changeset")).tag(RepositoryPullRequestState.Page.changeset)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    /// 当前分段的内容；提交与改动在源分支提交不在仓库里时说明并提供获取，Commits 段的顶部是参与者条。
    @ViewBuilder
    private func content(_ request: PullRequest) -> some View {
        switch state.page {
        case .conversation:
            PullRequestConversationView(
                session: session,
                request: request,
                comments: state.comments,
                commits: state.conversation.commits,
                canComment: state.client != nil
            )

        case .commits, .changeset:
            if state.needsFetch {
                VStack(spacing: 12) {
                    EmptyStateView(
                        title: AppLocalization.text("pullRequests.fetch.title"),
                        message: AppLocalization.text("pullRequests.fetch.message", request.id.reference, state.remote ?? ""),
                        symbol: "arrow.down.circle"
                    )

                    Button(AppLocalization.text("pullRequests.fetch")) { session.fetchPullRequestHead(request) }
                        .disabled(!session.canWrite)
                }
                .padding(20)
            } else {
                VStack(spacing: 0) {
                    if state.page == .commits {
                        PullRequestContributorsBar(
                            contributors: state.conversation.contributors,
                            commitCount: state.conversation.commits?.count
                        )

                        Divider()
                    }

                    RevisionComparisonView(state: state.comparison, session: session, showsHeader: false)
                }
            }
        }
    }

    /// 40 pt 底栏：检出、关闭与合并；请求不再打开时后两项不可用。
    private func actions(_ request: PullRequest) -> some View {
        HStack(spacing: 8) {
            Button(AppLocalization.text("pullRequests.checkout")) { session.requestPullRequest(.checkout(request)) }
                .disabled(!session.canWrite)

            Spacer(minLength: 8)

            Button(AppLocalization.text("pullRequests.close")) { session.closePullRequest(request) }
                .disabled(request.state != .open)

            Button(AppLocalization.text("pullRequests.merge")) { session.requestPullRequest(.merge(request)) }
                .disabled(request.state != .open)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    /// 切换分段：提交与改动两段共用一份比较，只换显示的部分。
    private func select(_ page: RepositoryPullRequestState.Page) {
        state.page = page
        state.comparison.showsChangeset = page == .changeset
    }
}

// MARK: - PullRequestContributorsBar

/// Commits 段顶部 28 pt 的参与者条：左边是人数与参与者的头像，右边是提交数。
///
/// 头像排不下时从右侧去掉，能放下几个就完整显示几个。
struct PullRequestContributorsBar: View {
    /// 头像的直径。
    private static let avatarSize: CGFloat = 20

    /// 相邻头像的间距。
    private static let avatarSpacing: CGFloat = 2

    /// 比较范围里提交的作者，按提交数从多到少；还没读完时为 nil。
    let contributors: [FileContributor]?

    /// 比较范围里的提交数；还没读完时为 nil。
    let commitCount: Int?

    /// 人数左 20，其后 8 是头像排；提交数距右 20，左边距头像排至少 8。三者竖直居中。
    var body: some View {
        HStack(spacing: 8) {
            label(contributorsText)

            avatars

            label(commitsText)
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
    }
}

// MARK: - Contributors Layout

extension PullRequestContributorsBar {
    /// 人数的文案，读取完成前为空。
    private var contributorsText: String {
        switch contributors?.count {
        case nil: ""
        case 0: AppLocalization.text("pullRequests.contributors.none")
        case 1: AppLocalization.text("pullRequests.contributors.one")
        case let count?: AppLocalization.text("pullRequests.contributors", count)
        }
    }

    /// 提交数的文案；没有提交或还没读完时为空。
    private var commitsText: String {
        guard let commitCount, commitCount > 0 else {
            return ""
        }

        return AppLocalization.text("pullRequests.contributors.commits", commitCount)
    }

    /// 高 22 的头像排：Gravatar 头像，提示是 “姓名 <邮箱>”；按可用宽度算出放得下的个数。
    private var avatars: some View {
        GeometryReader { proxy in
            let step = Self.avatarSize + Self.avatarSpacing
            let fitting = Int((proxy.size.width + Self.avatarSpacing) / step)

            HStack(spacing: Self.avatarSpacing) {
                ForEach(Array((contributors ?? []).prefix(fitting).enumerated()), id: \.offset) {
                    let contributor = $0.element
                    let title = contributor.name + " <" + contributor.email + ">"

                    InitialsAvatar(name: contributor.name, email: contributor.email, size: Self.avatarSize)
                        .help(title)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(title)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 22)
    }

    /// 13 pt、不可用控件文字色的一段文字，不截断。
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .disabledControlTextColor))
            .fixedSize()
    }
}
