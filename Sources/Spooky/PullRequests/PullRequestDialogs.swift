import SpookyKit
import SwiftUI

// MARK: - MergePullRequestDialog

/// 在托管服务上合并：GitHub 选合并方式，GitLab 显示项目的合并策略并可压缩；都可以合并后删除源分支。
///
/// 选项按平台能力、项目设置与当前账号权限读取；不能合并时写出原因，主按钮不可用。
struct MergePullRequestDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要合并的请求。
    let request: PullRequest

    /// 关闭 sheet。
    let close: () -> Void

    /// 读到的合并选项。
    @State
    private var options: PullRequestMergeOptions?

    /// 读取选项的失败。
    @State
    private var failure = ""

    /// 选中的合并方式。
    @State
    private var method = PullRequestMergeMethod.merge

    /// GitLab 合并时压缩。
    @State
    private var squash = false

    /// 合并后删除源分支。
    @State
    private var deletesBranch = false

    /// 合并方式或策略、压缩与删除源分支。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: session.pullRequestText("accept.title"),
            message: session.pullRequestText(
                "accept.message",
                request.id.reference,
                request.target.branch,
                request.id.instance.displayName,
                session.pullRequests.remote ?? ""
            ),
            submitTitle: AppLocalization.text("pullRequests.merge"),
            error: error,
            isValid: options != nil && options?.block == nil,
            cancel: close,
            submit: submit
        ) {
            if let options {
                rows(options)
            } else if failure.isEmpty {
                ReferenceDialogRows.row("") {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .task { await loadOptions() }
    }
}

// MARK: - Merge

extension MergePullRequestDialog {
    /// 读取失败或不能合并的原因。
    private var error: String {
        guard failure.isEmpty else {
            return failure
        }

        guard let block = options?.block else {
            return ""
        }

        switch block {
        case .notOpen: return AppLocalization.text("pullRequests.block.notOpen")
        case .permission: return AppLocalization.text("pullRequests.block.permission")
        case .draft: return AppLocalization.text("pullRequests.block.draft")
        case .conflicts: return AppLocalization.text("pullRequests.block.conflicts")
        case .checking: return AppLocalization.text("pullRequests.block.checking")
        case .policy(let status): return AppLocalization.text("pullRequests.block.policy", status)
        }
    }

    /// 按服务给出的选项行。
    @ViewBuilder
    private func rows(_ options: PullRequestMergeOptions) -> some View {
        if let strategy = options.projectMergeMethod {
            ReferenceDialogRows.row(AppLocalization.text("pullRequests.mergeStrategy")) {
                Text(Self.strategyTitle(strategy))
            }

            if options.allowsSquashOption {
                ReferenceDialogRows.option(AppLocalization.text("pullRequests.squash"), help: "", isOn: $squash)
                    .disabled(options.requiresSquash)
            }
        } else {
            ReferenceDialogRows.row(AppLocalization.text("pullRequests.mergeType")) {
                Picker("", selection: $method) {
                    ForEach(options.methods, id: \.self) { method in
                        Text(Self.methodTitle(method)).tag(method)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }

        ReferenceDialogRows.option(AppLocalization.text("pullRequests.deleteBranch"), help: "", isOn: $deletesBranch)
            .disabled(!options.canDeleteSourceBranch)
    }

    /// 读取合并选项，按默认值预选。
    private func loadOptions() async {
        guard let client = session.pullRequests.client else {
            return
        }

        do {
            let options = try await RepositoryActivities.shared.recordHosting(
                title: AppLocalization.text("pullRequests.loadMergeOptions.title"),
                repository: session.repository
            ) {
                try await client.mergeOptions(for: request)
            }

            self.options = options
            method = options.methods.first ?? .merge
            squash = options.squashesByDefault
            deletesBranch = options.deletesSourceBranchByDefault && options.canDeleteSourceBranch
        } catch {
            failure = AppFailure(error: error, opening: false, location: nil).details
        }
    }

    /// 合并开始后关闭。
    private func submit() {
        let chosen: PullRequestMergeMethod = options?.projectMergeMethod == nil ? method : (squash ? .squash : .merge)

        if session.mergePullRequest(request, method: chosen, deletesSourceBranch: deletesBranch) {
            close()
        }
    }

}

// MARK: - Merge Titles

extension MergePullRequestDialog {
    /// GitHub 合并方式的名称。
    fileprivate static func methodTitle(_ method: PullRequestMergeMethod) -> String {
        AppLocalization.text("pullRequests.method." + method.rawValue)
    }

    /// GitLab 项目合并策略的名称；认不出的写出原值。
    fileprivate static func strategyTitle(_ strategy: String) -> String {
        ["merge", "rebase_merge", "ff"].contains(strategy) ? AppLocalization.text("pullRequests.strategy." + strategy) : strategy
    }
}

// MARK: - AssociateRemoteDialog

/// 把远端手动关联到一个账号与项目：别名、克隆地址与实例不一致时使用。
struct AssociateRemoteDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 远端名。
    let remote: String

    /// 远端的获取地址，关联记在它上面。
    let url: String

    /// 关闭 sheet。
    let close: () -> Void

    /// 选中的账号。
    @State
    private var account: UUID?

    /// 项目路径。
    @State
    private var project = ""

    /// 账号下拉与项目路径。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("pullRequests.associate.title"),
            message: AppLocalization.text("pullRequests.associate.message", remote),
            submitTitle: AppLocalization.text("pullRequests.associate.submit"),
            error: session.pullRequests.accounts.items.isEmpty ? AppLocalization.text("pullRequests.associate.noAccounts") : "",
            isValid: account != nil && project.split(separator: "/").count >= 2,
            cancel: close,
            submit: submit
        ) {
            ReferenceDialogRows.row(AppLocalization.text("pullRequests.account")) {
                Picker("", selection: $account) {
                    ForEach(session.pullRequests.accounts.items) { account in
                        Text(account.username + " – " + account.instance.displayName).tag(Optional(account.id))
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            ReferenceDialogRows.row(AppLocalization.text("pullRequests.project")) {
                TextField("", text: $project, prompt: Text(verbatim: "group/project"))
            }
        }
        .onAppear {
            account = session.pullRequests.accounts.items.first?.id

            // 预填地址里的路径，别名写法的地址同样能取到
            let path = RemoteConfiguration.webURL(for: url)?.path(percentEncoded: false) ?? ""
            project = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }

    /// 保存关联并重新读取。
    private func submit() {
        guard let account else { return }

        let path = project.split(separator: "/").joined(separator: "/")
        PullRequestAssociations.set(PullRequestAssociation(account: account, project: path), for: url)
        close()
        session.reloadPullRequests()
    }
}
