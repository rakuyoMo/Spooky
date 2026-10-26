import SpookyKit
import SwiftUI

// MARK: - PullRequestFormDialog

/// 新建或修改请求：新建时选源与目标的远端和分支，修改时只改目标分支；两者都有标题与描述。
///
/// 远端只列出与所选账号在同一实例上的，源与目标在不同项目时就是来自 Fork 的请求。
struct PullRequestFormDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 要修改的请求；新建时为 nil。
    let request: PullRequest?

    /// 新建时预选的源分支。
    var preselectedBranch: String? = nil

    /// 关闭 sheet。
    let close: () -> Void

    /// 源远端。
    @State
    private var sourceRemote = ""

    /// 源分支。
    @State
    private var sourceBranch = ""

    /// 目标远端。
    @State
    private var targetRemote = ""

    /// 目标分支。
    @State
    private var targetBranch = ""

    /// 标题。
    @State
    private var title = ""

    /// 描述。
    @State
    private var description = ""

    /// 远端选择、分支、标题与描述。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: session.pullRequestText(request == nil ? "create.title" : "edit.title"),
            message: message,
            submitTitle: request == nil ? session.pullRequestText("create.title") : AppLocalization.text("pullRequests.save"),
            error: candidates.isEmpty ? AppLocalization.text("pullRequests.noProjects") : "",
            isValid: isValid,
            cancel: close,
            submit: submit
        ) {
            if request == nil {
                ReferenceDialogRows.row(AppLocalization.text("pullRequests.source")) {
                    branchPicker(remote: $sourceRemote, branch: $sourceBranch)
                }
            }

            ReferenceDialogRows.row(AppLocalization.text(request == nil ? "pullRequests.target" : "pullRequests.targetBranch")) {
                branchPicker(remote: $targetRemote, branch: $targetBranch)
            }

            ReferenceDialogRows.row(AppLocalization.text("pullRequests.titleField")) {
                TextField("", text: $title)
            }

            ReferenceDialogRows.row(AppLocalization.text("pullRequests.description")) {
                TextEditor(text: $description)
                    .font(.system(size: 13))
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
            }
        }
        .onAppear(perform: prepare)
        .onChange(of: session.pullRequests.target) { prepare() }
    }
}

// MARK: - Form

extension PullRequestFormDialog {
    /// 与所选账号在同一实例上的远端与它们的项目路径。
    private var candidates: [(remote: String, project: String)] {
        guard let account = session.pullRequests.account else {
            return []
        }

        return session.pullRequests.remotes.compactMap { remote in
            guard let url = remote.url else { return nil }

            // 选中的远端沿用它对应的项目，手动关联的项目也算
            if remote.name == session.pullRequests.remote, let project = session.pullRequests.project {
                return (remote.name, project)
            }

            return account.instance.projectPath(forRemote: url).map { (remote.name, $0) }
        }
    }

    /// 说明请求建在哪个实例上。
    private var message: String {
        guard let request else {
            return session.pullRequestText("create.message", session.pullRequests.account?.instance.displayName ?? "")
        }

        return session.pullRequestText("edit.message", request.id.reference)
    }

    /// 内容完整，新建时源与目标不能是同一项目的同一分支。
    private var isValid: Bool {
        let filled = !title.trimmingCharacters(in: .whitespaces).isEmpty && !targetBranch.isEmpty

        guard request == nil else {
            return filled
        }

        return filled && !sourceBranch.isEmpty && (sourceRemote != targetRemote || sourceBranch != targetBranch)
    }

    /// 远端下拉与它的远端分支下拉；修改时远端固定为请求的目标项目。
    private func branchPicker(remote: Binding<String>, branch: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Picker("", selection: remote) {
                ForEach(candidates, id: \.remote) { candidate in
                    Text(candidate.remote + " (" + candidate.project + ")").tag(candidate.remote)
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(request != nil)

            Picker("", selection: branch) {
                ForEach(branches(of: remote.wrappedValue), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
        }
    }

    /// 远端的远端分支短名，不含 HEAD 这类符号引用。
    private func branches(of remote: String) -> [String] {
        let prefix = "refs/remotes/" + remote + "/"

        return (session.history.snapshot?.references ?? [])
            .filter { $0.id.hasPrefix(prefix) && $0.symbolicTarget == nil }
            .map { String($0.id.dropFirst(prefix.count)) }
    }

    /// 修改时填入请求现有的内容；新建时源分支取预选或当前分支，目标取选中远端的默认分支。
    ///
    /// 请求视图还在读取时没有候选，读完后再填一次；已经填过的不再改动。
    private func prepare() {
        let selected = session.pullRequests.remote ?? candidates.first?.remote ?? ""

        guard !selected.isEmpty, targetRemote.isEmpty else {
            return
        }

        if let request {
            targetRemote = selected
            targetBranch = request.target.branch
            title = request.title
            description = request.body
            return
        }

        let branch = preselectedBranch ?? session.status?.branch.head ?? ""
        let upstream = session.history.branches.first { $0.isLocal && $0.name == branch }?.upstreamRemote
        let remotes = candidates.map(\.remote)

        sourceRemote = upstream.flatMap { remotes.contains($0) ? $0 : nil } ?? selected
        sourceBranch = branches(of: sourceRemote).contains(branch) ? branch : ""
        targetRemote = selected

        let snapshot = session.history.snapshot
        let remote = snapshot?.remotes.first { $0.name == selected }
        let fallback = remote.flatMap { snapshot?.defaultBranch(for: $0) }
            .map { String($0.dropFirst(("refs/remotes/" + selected + "/").count)) }
        targetBranch = fallback ?? branches(of: selected).first ?? ""
        title = sourceBranch
    }

    /// 新建或修改；请求开始后关闭。
    private func submit() {
        let title = title.trimmingCharacters(in: .whitespaces)

        if let request {
            if session.updatePullRequest(request, title: title, body: description, targetBranch: targetBranch) { close() }
            return
        }

        let projects = Dictionary(candidates.map { ($0.remote, $0.project) }, uniquingKeysWith: { first, _ in first })

        guard let source = projects[sourceRemote], let target = projects[targetRemote] else {
            return
        }

        let draft = PullRequestDraft(
            sourceProject: source,
            sourceBranch: sourceBranch,
            targetProject: target,
            targetBranch: targetBranch,
            title: title,
            body: description
        )

        if session.createPullRequest(draft) { close() }
    }
}

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
            let options = try await client.mergeOptions(for: request)
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

// MARK: - PullRequestTextDialog

/// 只有一个输入的对话框：发表评论，或检出时填本地分支名。
struct PullRequestTextDialog: View {
    /// 对话框的用途。
    enum Kind {
        /// 发表评论。
        case comment

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

    /// 评论的多行输入，或分支名的单行输入。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: kind == .comment
                ? AppLocalization.text("pullRequests.comment.title")
                : session.pullRequestText("checkout.title"),
            message: kind == .comment
                ? session.pullRequestText("comment.message", request.id.reference)
                : session.pullRequestText("checkout.message", request.id.reference, PullRequestText.source(of: request)),
            submitTitle: AppLocalization.text(kind == .comment ? "pullRequests.comment.title" : "pullRequests.checkout"),
            error: "",
            isValid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            cancel: close,
            submit: submit
        ) {
            switch kind {
            case .comment:
                ReferenceDialogRows.row(AppLocalization.text("pullRequests.comment")) {
                    TextEditor(text: $text)
                        .font(.system(size: 13))
                        .frame(height: 140)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
                }

            case .checkout:
                ReferenceDialogRows.row(AppLocalization.text("pullRequests.branchName")) {
                    TextField("", text: $text)
                }
            }
        }
        .onAppear {
            // 检出时预填源分支名
            if kind == .checkout { text = request.source.branch }
        }
    }

    /// 开始后关闭。
    private func submit() {
        let started =
            switch kind {
            case .comment: session.addComment(text, to: request)
            case .checkout: session.checkoutPullRequest(request, as: text.trimmingCharacters(in: .whitespaces))
            }

        if started { close() }
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
