import SpookyKit
import SwiftUI

// MARK: - PullRequestFormDialog

/// 新建或修改请求：Source、Target 两行各是远端与它的远端分支，下面是标题与描述。
///
/// 远端只列出与所选账号在同一实例上的，源与目标在不同项目时就是来自 Fork 的请求。
/// 修改时 Source 一行与目标远端不可改，只改目标分支、标题与描述。
struct PullRequestFormDialog: View {
    /// 输入控件的宽度；Source 与 Target 两行里远端、分支两个下拉合起来也是这么宽。
    private static let fieldWidth: CGFloat = 320

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

    /// 480 宽的对话框骨架：标题与说明写出服务名与目标项目，表单的输入列从对齐线开始、宽 320。
    var body: some View {
        let texts = Self.texts(editing: request, instance: instance, project: targetProject, in: session)

        DialogLayout(
            title: texts.title,
            message: texts.message,
            submitTitle: texts.submit,
            error: error,
            canSubmit: canSubmit,
            cancel: close,
            submit: submit
        ) {
            DialogForm {
                DialogFormRow(label: AppLocalization.text("pullRequests.source")) {
                    if let request {
                        fixedSource(request)
                    } else {
                        branchPickers(remote: $sourceRemote, branch: $sourceBranch)
                    }
                }

                DialogFormRow(label: AppLocalization.text("pullRequests.target")) {
                    branchPickers(remote: $targetRemote, branch: $targetBranch)
                }

                DialogFormRow(label: AppLocalization.text("pullRequests.titleField")) {
                    TextField("", text: $title, prompt: Text(AppLocalization.text("pullRequests.required")))
                        .frame(width: Self.fieldWidth)
                }

                DialogFormRow(label: AppLocalization.text("pullRequests.description"), alignment: .top) {
                    descriptionEditor
                }
            }
        }
        .onAppear(perform: prepare)
        .onChange(of: session.pullRequests.target) { prepare() }
    }
}

// MARK: - Rules

extension PullRequestFormDialog {
    /// 标题、说明与主按钮的文案：写出服务名与目标项目，修改时还写出编号。
    ///
    /// - Parameters:
    ///   - request: 要修改的请求；新建时为 nil。
    ///   - instance: 请求所在的实例；新建时没有所选的账号则为 nil。
    ///   - project: 目标项目的路径。
    ///   - session: 按它选中远端的服务取 Pull Request 或 Merge Request 的叫法。
    static func texts(
        editing request: PullRequest?,
        instance: HostingInstance?,
        project: String,
        in session: RepositorySession
    ) -> (title: String, message: String, submit: String) {
        let service = instance.map(AccountsSettingsView.serviceTitle) ?? ""

        guard let request else {
            return (
                session.pullRequestText("create.title", service),
                session.pullRequestText("create.message", service, project),
                session.pullRequestText("create.submit")
            )
        }

        return (
            session.pullRequestText("edit.title", service, request.id.reference),
            session.pullRequestText("edit.message", request.id.reference, service, project),
            session.pullRequestText("edit.submit")
        )
    }

    /// 两侧是同一个分支：新建时是同一远端的同名分支，修改时是同一项目的请求把目标分支选成了源分支。
    ///
    /// - Parameters:
    ///   - source: 新建时选的源远端与分支；修改时不用。
    ///   - target: 选的目标远端与分支。
    ///   - request: 要修改的请求；新建时为 nil。
    static func isIdentical(
        source: (remote: String, branch: String),
        target: (remote: String, branch: String),
        editing request: PullRequest?
    ) -> Bool {
        guard !target.branch.isEmpty else {
            return false
        }

        guard let request else {
            return source.remote == target.remote && source.branch == target.branch
        }

        return !request.isFromFork && target.branch == request.source.branch
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

    /// 请求所在的实例：修改时是请求的实例，新建时是所选账号的实例。
    private var instance: HostingInstance? {
        request?.id.instance ?? session.pullRequests.account?.instance
    }

    /// 目标项目的路径：修改时是请求所在的项目，新建时随 Target 的远端变化。
    private var targetProject: String {
        if let request {
            return request.id.project
        }

        return candidates.first { $0.remote == targetRemote }?.project ?? ""
    }

    /// 两侧是同一个分支。
    private var isIdentical: Bool {
        Self.isIdentical(
            source: (sourceRemote, sourceBranch),
            target: (targetRemote, targetBranch),
            editing: request
        )
    }

    /// 错误区：没有可用的远端、两侧是同一个分支，以及仓库暂不可写；都没有时为 nil。
    private var error: String? {
        let messages = [
            candidates.isEmpty ? AppLocalization.text("pullRequests.noProjects") : nil,
            isIdentical ? AppLocalization.text("pullRequests.error.sameBranch") : nil,
            session.canWrite ? nil : AppLocalization.text("dialog.blocked"),
        ]

        let text = messages.compactMap(\.self).joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    /// 两侧分支都选了、标题不全是空白、两侧不是同一个分支，且仓库可写时才能提交。
    private var canSubmit: Bool {
        let hasBranches = !targetBranch.isEmpty && (request != nil || !sourceBranch.isEmpty)
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty

        return hasBranches && hasTitle && !isIdentical && session.canWrite
    }

    /// 320 × 64 的描述，带边框，回车换行；内容为空时叠上 “Optional” 的占位文字。
    private var descriptionEditor: some View {
        TextEditor(text: $description)
            .font(.system(size: 13))
            .frame(width: Self.fieldWidth, height: 64)
            .overlay(alignment: .topLeading) {
                if description.isEmpty {
                    Text(AppLocalization.text("pullRequests.optional"))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: .placeholderTextColor))
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
    }

    /// 修改时的 Source 一行：远端与分支两个下拉平分 320 的宽度，各只有一项，不可改；有远端对应源项目时写 “远端 (项目)”，否则只写项目路径。
    private func fixedSource(_ request: PullRequest) -> some View {
        let project = request.source.project ?? ""
        let remote = candidates.first { $0.project == project }?.remote

        return HStack(spacing: 8) {
            Picker("", selection: .constant(0)) {
                Text(remote.map { $0 + " (" + project + ")" } ?? project).tag(0)
            }
            .labelsHidden()

            Picker("", selection: .constant(0)) {
                Text(request.source.branch).tag(0)
            }
            .labelsHidden()
        }
        .buttonSizing(.flexible)
        .frame(width: Self.fieldWidth)
        .disabled(true)
    }

    /// 远端下拉与它的远端分支下拉，平分 320 的宽度；修改时远端固定为请求的目标项目。
    private func branchPickers(remote: Binding<String>, branch: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: remote) {
                ForEach(candidates, id: \.remote) { candidate in
                    Text(candidate.remote + " (" + candidate.project + ")").tag(candidate.remote)
                }
            }
            .labelsHidden()
            .disabled(request != nil)

            Picker("", selection: branch) {
                ForEach(branches(of: remote.wrappedValue), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
        }
        .buttonSizing(.flexible)
        .frame(width: Self.fieldWidth)
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
