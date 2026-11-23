import SpookyKit
import SwiftUI

// MARK: - PullRequestChecksView

/// CI/CD 段：顶部 28 pt 的整体状态，下面是各项检查或作业；没有检查或流水线时是空状态。
///
/// 这一段显示期间读取所选请求的状态，还有等待中或运行中的项时自动刷新。
struct PullRequestChecksView: View {
    /// 重新读取的条件。
    private struct ReloadKey: Hashable {
        /// 所选的请求。
        let id: PullRequestID

        /// 源分支的提交。
        let sha: String

        /// 详情读到的次数。
        let revision: Int
    }

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 所选的请求。
    let request: PullRequest

    /// 换一个请求、源分支有了新提交或详情重新读到时重新读取。
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .task(id: ReloadKey(id: request.id, sha: request.source.sha, revision: state.detailRevision)) {
                await state.watchChecks(of: request)
            }
    }
}

// MARK: - Layout

extension PullRequestChecksView {
    /// 请求视图的状态。
    private var state: RepositoryPullRequestState { session.pullRequests }

    /// 读到之前留空；读取失败时说明原因，已经读到的状态留在下面。
    @ViewBuilder
    private var content: some View {
        if let checks = state.checks.selected {
            VStack(spacing: 0) {
                if let failure = state.checks.failure {
                    FailureDetailsView(failure: failure)
                        .padding(20)

                    Divider()
                }

                loaded(checks)
            }
        } else if let failure = state.checks.failure {
            FailureDetailsView(failure: failure)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear
        }
    }

    /// 整体状态与各项；一项都没有、也没有整体状态时是空状态。
    @ViewBuilder
    private func loaded(_ checks: PullRequestChecks) -> some View {
        if checks.state == nil, checks.items.isEmpty {
            EmptyStateView(
                title: AppLocalization.text("pullRequests.checks.empty.title"),
                message: session.pullRequestText("checks.empty.message"),
                symbol: "checklist"
            )
        } else {
            if let overall = checks.state {
                summary(overall)

                Divider()
            }

            List(checks.items) {
                PullRequestCheckRow(check: $0)
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds(.disabled)
        }
    }

    /// 28 pt 的整体状态：图标与状态名，与下面各项的图标、名称对齐。
    private func summary(_ overall: PullRequestCheckState) -> some View {
        HStack(spacing: 8) {
            Image(systemName: overall.symbol)
                .foregroundStyle(overall.color)
                .accessibilityHidden(true)

            Text(overall.title)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 28)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PullRequestCheckRow

/// 一项检查或一个作业：状态图标、名称、所属的一组，右侧是状态名。
private struct PullRequestCheckRow: View {
    /// 显示的一项。
    let check: PullRequestCheck

    /// 名称放不下时从中间截断，所属的一组先让出位置。
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: check.state.symbol)
                .foregroundStyle(check.state.color)
                .accessibilityHidden(true)

            Text(check.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)

            if let group = check.group, !group.isEmpty {
                Text(group)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(check.state.title)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .font(.system(size: 13))
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PullRequestCheckIcon

/// 请求 CI/CD 整体状态的图标，提示与无障碍标签写出状态名。
struct PullRequestCheckIcon: View {
    /// 整体状态。
    let state: PullRequestCheckState

    /// 按状态取符号与颜色。
    var body: some View {
        Image(systemName: state.symbol)
            .foregroundStyle(state.color)
            .help(AppLocalization.text("pullRequests.checks.status", state.title))
            .accessibilityLabel(AppLocalization.text("pullRequests.checks.status", state.title))
    }
}

// MARK: - PullRequestCheckState

extension PullRequestCheckState {
    /// 状态名。
    var title: String {
        AppLocalization.text("pullRequests.checks.state." + rawValue)
    }

    /// 表示状态的系统符号。
    var symbol: String {
        switch self {
        case .failure: "xmark.circle.fill"
        case .cancelled: "slash.circle.fill"
        case .manual: "exclamationmark.circle.fill"
        case .running: "play.circle.fill"
        case .pending: "clock.fill"
        case .success: "checkmark.circle.fill"
        case .neutral: "minus.circle.fill"
        case .skipped: "forward.circle.fill"
        }
    }

    /// 符号的颜色：通过是绿，没通过是红，运行中是蓝，等待中与等人处理是橙，其余是灰。
    var color: Color {
        switch self {
        case .failure: .red
        case .running: .blue
        case .pending, .manual: .orange
        case .success: .green
        case .cancelled, .neutral, .skipped: .gray
        }
    }
}
