import SpookyKit
import SwiftUI

// MARK: - MergePullRequestDialog

/// 在托管服务上合并：GitHub 选合并方式，GitLab 显示项目的合并策略并可压缩；都可以合并后删除分支。
///
/// 选项按平台能力、项目设置与当前账号权限读取；不能合并时写出原因，主按钮不可用。
struct MergePullRequestDialog: View {
    /// 偏好：上次在 GitHub 上合并请求用的方式，下次合并时预选。
    static let methodKey = "pullRequestMergeMethod"

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

    /// 标题与说明写出服务与编号；读取选项时内容区是一个小的转圈，读到后是合并方式或策略、压缩与删除分支。
    ///
    /// 读到选项、没有挡住合并的原因且仓库可写时主按钮可用。
    var body: some View {
        let texts = Self.texts(for: request, in: session)

        DialogLayout(
            title: texts.title,
            message: texts.message,
            submitTitle: texts.submit,
            error: error,
            canSubmit: options != nil && options?.block == nil && session.canWrite,
            cancel: close,
            submit: submit
        ) {
            if let options {
                DialogForm {
                    rows(options)
                }
            } else if failure.isEmpty {
                DialogForm {
                    DialogFormRow(label: "") {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .task { await loadOptions() }
    }
}

// MARK: - Merge

extension MergePullRequestDialog {
    /// 错误区：读取失败或不能合并的原因，以及仓库暂不可写；都没有时为 nil。
    private var error: String? {
        let messages = [
            failure.isEmpty ? nil : failure,
            blockMessage,
            session.canWrite ? nil : AppLocalization.text("dialog.blocked"),
        ]

        let text = messages.compactMap(\.self).joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    /// 不能合并的原因；没有时为 nil。
    private var blockMessage: String? {
        guard let block = options?.block else {
            return nil
        }

        return switch block {
        case .notOpen: AppLocalization.text("pullRequests.block.notOpen")
        case .permission: AppLocalization.text("pullRequests.block.permission")
        case .draft: AppLocalization.text("pullRequests.block.draft")
        case .conflicts: AppLocalization.text("pullRequests.block.conflicts")
        case .checking: AppLocalization.text("pullRequests.block.checking")
        case .policy(let status): AppLocalization.text("pullRequests.block.policy", status)
        }
    }

    /// 标题、说明与主按钮：标题写出账号所在的服务，说明写出请求的编号。
    ///
    /// - Parameters:
    ///   - request: 要合并的请求。
    ///   - session: 窗口会话，按选中远端的服务决定叫 Pull Request 还是 Merge Request。
    static func texts(
        for request: PullRequest,
        in session: RepositorySession
    ) -> (title: String, message: String, submit: String) {
        (
            session.pullRequestText("accept.title", AccountsSettingsView.serviceTitle(request.id.instance)),
            session.pullRequestText("accept.message", request.id.reference),
            session.pullRequestText("accept.submit")
        )
    }

    /// 预选的合并方式：仓库允许上次用的方式时选它，否则选第一种。
    ///
    /// - Parameters:
    ///   - methods: 仓库允许的方式。
    ///   - defaults: 读取偏好的域。
    static func preselectedMethod(
        in methods: [PullRequestMergeMethod],
        defaults: UserDefaults = .standard
    ) -> PullRequestMergeMethod {
        let remembered = defaults.string(forKey: methodKey).flatMap(PullRequestMergeMethod.init(rawValue:))

        guard let remembered, methods.contains(remembered) else {
            return methods.first ?? .merge
        }

        return remembered
    }

    /// 按服务给出的选项行：GitHub 是宽 180 的合并方式下拉，GitLab 是项目的合并策略与压缩；勾选框都在输入列。
    @ViewBuilder
    private func rows(_ options: PullRequestMergeOptions) -> some View {
        if let strategy = options.projectMergeMethod {
            DialogFormRow(label: AppLocalization.text("pullRequests.mergeStrategy")) {
                Text(Self.strategyTitle(strategy))
            }

            if options.allowsSquashOption {
                DialogFormOption(
                    title: AppLocalization.text("pullRequests.squash"),
                    isOn: $squash
                )
                .disabled(options.requiresSquash)
            }
        } else {
            DialogFormRow(label: AppLocalization.text("pullRequests.mergeType")) {
                Picker("", selection: $method) {
                    ForEach(options.methods, id: \.self) { method in
                        Text(Self.methodTitle(method)).tag(method)
                    }
                }
                .labelsHidden()
                .buttonSizing(.flexible)
                .frame(width: 180)
            }
        }

        DialogFormOption(
            title: AppLocalization.text("pullRequests.deleteBranch"),
            isOn: $deletesBranch
        )
        .disabled(!options.canDeleteSourceBranch)
    }

    /// 读取合并选项，按默认值预选：GitHub 的方式取上次用的，压缩与删除分支按项目设置。
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

            // 转圈一行换成 1–3 行选项，对话框高度随之同步变化
            DialogAnimation.perform {
                self.options = options
                method = Self.preselectedMethod(in: options.methods)
                squash = options.squashesByDefault
                deletesBranch = options.deletesSourceBranchByDefault && options.canDeleteSourceBranch
            }
        } catch {
            failure = AppFailure(error: error, opening: false, location: nil).details
        }
    }

    /// 合并开始后关闭；GitHub 记住这次用的方式。
    private func submit() {
        guard let options else {
            return
        }

        // GitLab 按项目的合并策略合并，只决定是否压缩；GitHub 用选中的方式
        let usesStrategy = options.projectMergeMethod != nil
        let chosen: PullRequestMergeMethod = usesStrategy ? (squash ? .squash : .merge) : method

        guard session.mergePullRequest(request, method: chosen, deletesSourceBranch: deletesBranch) else {
            return
        }

        // 下次在 GitHub 上合并时预选这次用的方式
        if !usesStrategy {
            UserDefaults.standard.set(method.rawValue, forKey: Self.methodKey)
        }

        close()
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
        guard ["merge", "rebase_merge", "ff"].contains(strategy) else {
            return strategy
        }

        return AppLocalization.text("pullRequests.strategy." + strategy)
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

    /// 账号下拉与项目路径，从对齐线开始，项目路径占满输入列。
    ///
    /// 还没有账号或仓库暂不可写时，错误区写出原因。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("pullRequests.associate.title"),
            message: AppLocalization.text("pullRequests.associate.message", remote),
            submitTitle: AppLocalization.text("pullRequests.associate.submit"),
            error: error,
            canSubmit: account != nil
                && project.split(separator: "/").count >= 2
                && session.canWrite,
            cancel: close,
            submit: submit
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("pullRequests.account")) {
                    Picker("", selection: $account) {
                        ForEach(session.pullRequests.accounts.items) { account in
                            Text(account.username + " – " + account.instance.displayName).tag(Optional(account.id))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                DialogFormRow(label: AppLocalization.text("pullRequests.project")) {
                    TextField("", text: $project, prompt: Text(verbatim: "group/project"))
                }
            }
        }
        .onAppear {
            account = session.pullRequests.accounts.items.first?.id

            // 预填地址里的路径，别名写法的地址同样能取到
            let path = RemoteConfiguration.webURL(for: url)?.path(percentEncoded: false) ?? ""
            project = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }

    /// 错误区：还没有账号，以及仓库暂不可写；都没有时为 nil。
    private var error: String? {
        let messages = [
            session.pullRequests.accounts.items.isEmpty
                ? AppLocalization.text("pullRequests.associate.noAccounts")
                : nil,
            session.canWrite ? nil : AppLocalization.text("dialog.blocked"),
        ]

        let text = messages.compactMap(\.self).joined(separator: "\n")
        return text.isEmpty ? nil : text
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
