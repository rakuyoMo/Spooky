import SpookyKit
import SwiftUI

// MARK: - PullRequestDetailView

/// 所选请求的详情：头部是编号、状态与 Conversation | Commits | Changeset 分段，底部是检出、关闭与合并。
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

    /// 40 pt 头部：编号、状态与分段。
    private func header(_ request: PullRequest) -> some View {
        HStack(spacing: 8) {
            Text(request.id.reference)
                .font(.system(size: 13, weight: .semibold))
                .textSelection(.enabled)

            PullRequestStateBadge(request: request)

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

    /// 当前分段的内容；提交与改动在源分支提交不在仓库里时说明并提供获取。
    @ViewBuilder
    private func content(_ request: PullRequest) -> some View {
        switch state.page {
        case .conversation:
            PullRequestConversationView(session: session, request: request)

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
                RevisionComparisonView(state: state.comparison, session: session, showsHeader: false)
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

// MARK: - PullRequestStateBadge

/// 状态标记：打开、草稿、关闭或已合并。
struct PullRequestStateBadge: View {
    /// 显示的请求。
    let request: PullRequest

    /// 圆角底色上的状态名。
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }

    /// 状态名。
    private var title: String {
        switch request.state {
        case .open: AppLocalization.text(request.isDraft ? "pullRequests.state.draft" : "pullRequests.state.open")
        case .closed: AppLocalization.text("pullRequests.state.closed")
        case .merged: AppLocalization.text("pullRequests.state.merged")
        }
    }

    /// 底色。
    private var color: Color {
        switch request.state {
        case .open: request.isDraft ? .gray : .green
        case .closed: .red
        case .merged: .purple
        }
    }
}
