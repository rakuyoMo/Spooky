import AppKit
import SpookyKit
import SwiftUI

// MARK: - AccountDialog

/// 添加或重新认证托管账号：github.com 可以经浏览器授权或填个人访问令牌，GitLab 填个人访问令牌，私有部署的 GitLab 另填地址。
///
/// 令牌先经 API 读到对应的用户才保存；重新认证时令牌必须属于原来的用户。
struct AccountDialog: View {
    /// 能添加的账号种类。
    enum Kind: CaseIterable, Hashable {
        /// github.com。
        case github

        /// GitLab.com。
        case gitlab

        /// 私有部署的 GitLab。
        case gitlabSelfManaged

        /// 添加菜单里的标题。
        var menuTitle: String {
            switch self {
            case .github: AppLocalization.text("accounts.add.github")
            case .gitlab: AppLocalization.text("accounts.add.gitlab")
            case .gitlabSelfManaged: AppLocalization.text("accounts.add.gitlabSelfManaged")
            }
        }

        /// 账号所在实例的种类。
        init(_ instance: HostingInstance) {
            switch instance.service {
            case .github: self = .github
            case .gitlab: self = instance.isSelfManaged ? .gitlabSelfManaged : .gitlab
            }
        }
    }

    /// 对话框的用途。
    enum Purpose: Identifiable {
        /// 添加一个新账号。
        case add(Kind)

        /// 给已有账号换上新令牌。
        case reauthenticate(HostingAccount)

        /// sheet 的身份。
        var id: String {
            switch self {
            case .add(let kind): "add-\(kind)"
            case .reauthenticate(let account): account.id.uuidString
            }
        }
    }

    /// 等待中的步骤。
    private enum Progress {
        /// 没有在进行。
        case idle

        /// 正在经 API 校验令牌。
        case validating

        /// 正在等用户在浏览器里授权。
        case authorizing(GitHubDeviceFlow.Authorization)
    }

    /// 对话框的用途。
    let purpose: Purpose

    /// 保存账号的地方。
    let accounts: HostingAccounts

    /// 关闭 sheet。
    let close: () -> Void

    /// github.com 的认证方式。
    @State
    private var authentication = HostingAuthentication.oauth

    /// 私有部署 GitLab 的地址。
    @State
    private var host = ""

    /// 个人访问令牌。
    @State
    private var token = ""

    /// 等待中的步骤。
    @State
    private var progress = Progress.idle

    /// 上一次失败的说明。
    @State
    private var error: String?

    /// 校验或授权的任务，关闭对话框时取消。
    @State
    private var task: Task<Void, Never>?

    /// 表单、等待中的步骤与失败说明。
    var body: some View {
        DialogLayout(
            title: title,
            message: message,
            submitTitle: AppLocalization.text(isReauthentication ? "accounts.update.submit" : "accounts.add.submit"),
            error: error,
            canSubmit: canSubmit,
            cancel: cancel,
            submit: submit
        ) {
            DialogForm {
                if kind == .github {
                    DialogFormRow(label: AppLocalization.text("accounts.authentication")) {
                        Picker("", selection: $authentication) {
                            Text(AppLocalization.text("accounts.authentication.oauth")).tag(HostingAuthentication.oauth)
                            Text(AppLocalization.text("accounts.authentication.token"))
                                .tag(HostingAuthentication.personalAccessToken)
                        }
                        .labelsHidden()
                        .fixedSize()
                        .disabled(isBusy)
                    }
                }

                if kind == .gitlabSelfManaged {
                    DialogFormRow(label: AppLocalization.text("accounts.host")) {
                        TextField("", text: $host, prompt: Text(verbatim: "https://gitlab.example.com"))
                            .disabled(isBusy || isReauthentication)
                    }
                }

                if usesToken {
                    DialogFormRow(label: AppLocalization.text("accounts.token")) {
                        SecureField("", text: $token)
                            .disabled(isBusy)
                    }
                }

                progressRows
            }
        }
        .onAppear(perform: prepare)
        .onDisappear { task?.cancel() }
    }
}

// MARK: - Layout

extension AccountDialog {
    /// 等待中的提示：校验时只有转圈，浏览器授权时还有验证码与打开网页的按钮。
    @ViewBuilder
    private var progressRows: some View {
        switch progress {
        case .idle:
            EmptyView()

        case .validating:
            DialogFormRow(label: "") {
                waiting(AppLocalization.text("accounts.validating"))
            }

        case .authorizing(let authorization):
            DialogFormRow(label: AppLocalization.text("accounts.code")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: authorization.userCode)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)

                    Button(AppLocalization.text("accounts.openGitHub")) { openVerificationPage(authorization) }

                    waiting(AppLocalization.text("accounts.authorizing"))
                }
            }
        }
    }

    /// 小号转圈与说明。
    private func waiting(_ text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)

            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - State

extension AccountDialog {
    /// 账号种类。
    private var kind: Kind {
        switch purpose {
        case .add(let kind): kind
        case .reauthenticate(let account): Kind(account.instance)
        }
    }

    /// 是重新认证。
    private var isReauthentication: Bool {
        if case .reauthenticate = purpose { true } else { false }
    }

    /// 需要填个人访问令牌：GitLab 总是，github.com 选了令牌时。
    private var usesToken: Bool {
        kind != .github || authentication == .personalAccessToken
    }

    /// 正在校验或等待授权。
    private var isBusy: Bool {
        if case .idle = progress { false } else { true }
    }

    /// 私有部署 GitLab 的实例；地址不合法时为 nil。
    private var instance: HostingInstance? {
        switch kind {
        case .github: .github
        case .gitlab: .gitlabCom
        case .gitlabSelfManaged: HostingInstance.gitlab(address: host)
        }
    }

    /// 内容完整且没有在等待时可以提交。
    private var canSubmit: Bool {
        !isBusy && instance != nil && (!usesToken || !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// 标题写出服务，重新认证时写 “Update”。
    private var title: String {
        switch (kind, isReauthentication) {
        case (.github, false): AppLocalization.text("accounts.add.github.title")
        case (.github, true): AppLocalization.text("accounts.update.github.title")
        case (_, false): AppLocalization.text("accounts.add.gitlab.title")
        case (_, true): AppLocalization.text("accounts.update.gitlab.title")
        }
    }

    /// 说明这种认证方式要做什么、令牌要哪些权限。
    private var message: String {
        switch kind {
        case .github: AppLocalization.text(authentication == .oauth ? "accounts.message.oauth" : "accounts.message.githubToken")
        case .gitlab: AppLocalization.text("accounts.message.gitlab")
        case .gitlabSelfManaged: AppLocalization.text("accounts.message.gitlabSelfManaged")
        }
    }
}

// MARK: - Actions

extension AccountDialog {
    /// 重新认证时沿用原来的认证方式与地址。
    private func prepare() {
        guard case .reauthenticate(let account) = purpose else {
            return
        }

        authentication = account.authentication
        host = account.instance.webURL.absoluteString
    }

    /// 取消进行中的校验或授权并关闭。
    private func cancel() {
        task?.cancel()
        close()
    }

    /// github.com 的浏览器授权先取验证码再轮询，其余直接校验令牌。
    private func submit() {
        guard let instance else {
            return
        }

        error = nil

        task = Task {
            do {
                let method: HostingAuthentication = kind == .github ? authentication : .personalAccessToken
                let credential = method == .oauth ? try await authorize() : token

                progress = .validating
                try await save(credential.trimmingCharacters(in: .whitespacesAndNewlines), on: instance, authentication: method)
                close()
            } catch is CancellationError {
                progress = .idle
            } catch {
                progress = .idle
                self.error = Self.describe(error)
            }
        }
    }

    /// 浏览器授权：取验证码、复制它并打开 GitHub 的验证页，再等用户授权。
    private func authorize() async throws -> String {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "SpookyGitHubClientID") as? String else {
            throw HostingError.incompatible("SpookyGitHubClientID")
        }

        let flow = GitHubDeviceFlow(clientID: clientID)
        let authorization = try await flow.start()

        progress = .authorizing(authorization)
        openVerificationPage(authorization)

        return try await flow.token(for: authorization)
    }

    /// 校验令牌对应的用户后保存；重新认证时用户必须相同。
    private func save(_ token: String, on instance: HostingInstance, authentication: HostingAuthentication) async throws {
        let user = try await HostingClient(instance: instance, token: token).currentUser()

        if case .reauthenticate(let account) = purpose, account.username != user.username {
            throw HostingError.differentUser(user.username)
        }

        try accounts.save(user, on: instance, authentication: authentication, token: token)
    }

    /// 把验证码放进剪贴板并打开验证页。
    private func openVerificationPage(_ authorization: GitHubDeviceFlow.Authorization) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(authorization.userCode, forType: .string)
        NSWorkspace.shared.open(authorization.verificationURL)
    }
}

// MARK: - Helpers

extension AccountDialog {
    /// 失败的标题、修复方向与服务端原文。
    private static func describe(_ error: any Error) -> String {
        let failure = AppFailure(error: error, opening: false, location: nil)
        return failure.title + "\n" + failure.message + "\n\n" + failure.details
    }
}
