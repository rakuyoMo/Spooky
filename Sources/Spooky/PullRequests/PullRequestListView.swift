import SpookyKit
import SwiftUI

// MARK: - PullRequestListView

/// 请求列表：40 pt 头部的远端下拉、读取转圈与新建按钮，下面是打开着的请求或对应不上账号的说明。
///
/// 远端不属于支持的服务时说明不支持并提供手动关联；没有账号时说明要登录哪个服务并可打开 Accounts 页。
struct PullRequestListView: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 头部、分隔线与内容。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 260)
    }
}

// MARK: - Layout

extension PullRequestListView {
    /// 列表的状态。
    private var state: RepositoryPullRequestState { session.pullRequests }

    /// 远端下拉、转圈与新建按钮。
    private var header: some View {
        HStack(spacing: 8) {
            Text(AppLocalization.text("sync.remote"))
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(get: { state.remote ?? "" }, set: { selectRemote($0) })) {
                ForEach(state.remotes) { remote in
                    Text(remote.name).tag(remote.name)
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(state.remotes.isEmpty)
            .accessibilityLabel(AppLocalization.text("sync.remote"))

            if state.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer(minLength: 0)

            Button {
                session.requestPullRequest(.create(sourceBranch: nil))
            } label: {
                Image(systemName: "plus")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .disabled(state.client == nil)
            .help(session.pullRequestText("create.menu"))
            .accessibilityLabel(session.pullRequestText("create.menu"))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    /// 列表或对应不上时的说明。
    @ViewBuilder
    private var content: some View {
        if state.isLoaded, state.remotes.isEmpty {
            EmptyStateView(
                title: AppLocalization.text("pullRequests.noRemotes.title"),
                message: AppLocalization.text("pullRequests.noRemotes.message"),
                symbol: "arrow.triangle.pull"
            )
            .padding(20)
        } else if let target = state.target {
            switch target {
            case .resolved(let account, _):
                resolvedContent(account)

            case .noAccount(let instance):
                notice(
                    title: AppLocalization.text("pullRequests.noAccount.title", AccountsSettingsView.serviceTitle(instance)),
                    message: session.pullRequestText("noAccount.message", state.remote ?? "", instance.displayName),
                    action: AppLocalization.text("pullRequests.openAccounts")
                ) { SettingsWindowController.show(.accounts) }

            case .chooseAccount(let accounts, _):
                PullRequestAccountChoice(session: session, accounts: accounts)

            case .unsupported:
                notice(
                    title: AppLocalization.text("pullRequests.unsupported.title"),
                    message: AppLocalization.text("pullRequests.unsupported.message", state.remote ?? ""),
                    action: AppLocalization.text("pullRequests.associate")
                ) { associate() }
            }
        }
    }

    /// 请求列表；滚到最后一行时读取下一页。
    private var list: some View {
        List(selection: Binding(get: { state.selectedID }, set: { select($0) })) {
            ForEach(state.items) { request in
                PullRequestRow(request: request)
                    .tag(request.id)
                    .onAppear {
                        if request.id == state.items.last?.id {
                            state.loadMore()
                        }
                    }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds(.disabled)
    }

    /// 对应到账号后的内容：令牌缺失、读取失败、空列表或请求列表。
    @ViewBuilder
    private func resolvedContent(_ account: HostingAccount) -> some View {
        if state.client == nil {
            notice(
                title: AppLocalization.text("pullRequests.missingToken.title"),
                message: AppLocalization.text("pullRequests.missingToken.message", account.username),
                action: AppLocalization.text("accounts.reauthenticate")
            ) { SettingsWindowController.show(.accounts) }
        } else if let failure = state.failure {
            VStack(alignment: .leading, spacing: 12) {
                FailureDetailsView(failure: failure)

                // 令牌被拒绝时提供重新认证的入口
                if case .unauthorized = state.failureError {
                    Button(AppLocalization.text("accounts.reauthenticate")) { SettingsWindowController.show(.accounts) }
                }
            }
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
        } else if state.isLoaded, state.items.isEmpty {
            EmptyStateView(
                title: session.pullRequestText("empty.title"),
                message: session.pullRequestText("empty.message"),
                symbol: "arrow.triangle.pull"
            )
            .padding(20)
        } else {
            list
        }
    }

    /// 居中的标题、说明与一个按钮。
    private func notice(title: String, message: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            EmptyStateView(title: title, message: message, symbol: "arrow.triangle.pull")

            Button(action, action: perform)
        }
        .padding(20)
    }
}

// MARK: - Actions

extension PullRequestListView {
    /// 换一个远端。
    private func selectRemote(_ name: String) {
        guard let runner = session.runner, !name.isEmpty else { return }
        state.select(remote: name, runner: runner)
    }

    /// 选中一个请求。
    private func select(_ id: PullRequestID?) {
        guard let runner = session.runner else { return }
        state.select(id, runner: runner)
    }

    /// 手动关联选中的远端。
    private func associate() {
        guard let remote = state.remote, let url = state.remoteURL else { return }
        session.requestPullRequest(.associate(remote: remote, url: url))
    }
}

// MARK: - PullRequestRow

/// 列表的一行：标题与草稿标记、编号与作者、源分支到目标分支。
private struct PullRequestRow: View {
    /// 显示的请求。
    let request: PullRequest

    /// Settings → General 选的日期格式。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 三行文字。
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(request.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if request.isDraft {
                    Text(AppLocalization.text("pullRequests.state.draft"))
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.quaternary))
                }
            }

            Text(request.id.reference + " · " + request.author + " · " + dateFormat.string(from: request.updatedAt))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(PullRequestText.branches(of: request))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PullRequestAccountChoice

/// 同一实例上有多个账号时选一个，选定后记在这个远端地址上。
private struct PullRequestAccountChoice: View {
    /// 所在窗口的会话。
    let session: RepositorySession

    /// 候选账号。
    let accounts: [HostingAccount]

    /// 选中的账号。
    @State
    private var selection: UUID?

    /// 说明、账号下拉与确认按钮。
    var body: some View {
        VStack(spacing: 12) {
            EmptyStateView(
                title: AppLocalization.text("pullRequests.chooseAccount.title"),
                message: AppLocalization.text("pullRequests.chooseAccount.message", session.pullRequests.remote ?? ""),
                symbol: "person.2"
            )

            Picker(AppLocalization.text("pullRequests.account"), selection: $selection) {
                ForEach(accounts) { account in
                    Text(account.username).tag(Optional(account.id))
                }
            }
            .fixedSize()

            Button(AppLocalization.text("pullRequests.chooseAccount.submit")) {
                guard let selection, let url = session.pullRequests.remoteURL else { return }

                PullRequestAssociations.set(PullRequestAssociation(account: selection), for: url)
                session.reloadPullRequests()
            }
            .disabled(selection == nil)
        }
        .padding(20)
        .onAppear { selection = accounts.first?.id }
    }
}

// MARK: - PullRequestText

/// 请求的几处共用写法。
enum PullRequestText {
    /// 源分支到目标分支；来自 Fork 时源分支前写出项目路径。
    static func branches(of request: PullRequest) -> String {
        source(of: request) + " → " + request.target.branch
    }

    /// 源分支；来自 Fork 时写成 `项目:分支`。
    static func source(of request: PullRequest) -> String {
        request.isFromFork ? (request.source.project ?? "?") + ":" + request.source.branch : request.source.branch
    }
}
