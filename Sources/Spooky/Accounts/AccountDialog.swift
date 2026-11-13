import AppKit
import SpookyKit
import SwiftUI

// MARK: - AccountDialog

/// 添加或重新认证托管账号：github.com 可以经浏览器授权或填个人访问令牌，GitLab 填个人访问令牌；
/// 私有部署的 GitLab 另填地址，也可以用用户名与密码换令牌。
///
/// 令牌先经 API 读到对应的用户才保存；重新认证时令牌必须属于原来的用户，添加时同一实例上不能已有这个用户。
/// 校验与授权的失败弹出提示框，对话框留着。
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

        /// 正在等用户在浏览器里授权；还没取到验证码时为 nil。
        case authorizing(GitHubDeviceFlow.Authorization?)
    }

    /// 要添加的账号已经在列表里：错误区写明，不弹提示框。
    private struct ExistingAccount: Error { }

    /// 对话框的用途。
    let purpose: Purpose

    /// 保存账号的地方。
    let accounts: HostingAccounts

    /// 关闭 sheet。
    let close: () -> Void

    /// 认证方式：github.com 与私有部署的 GitLab 在下拉里选，GitLab.com 只有个人访问令牌。
    @State
    private var authentication: HostingAuthentication

    /// 私有部署 GitLab 的地址。
    @State
    private var host = ""

    /// 个人访问令牌。
    @State
    private var token = ""

    /// 用户名与密码登录时的用户名。
    @State
    private var username = ""

    /// 用户名与密码登录时的密码；只用来换令牌，不保存。
    @State
    private var password = ""

    /// 等待中的步骤。
    @State
    private var progress = Progress.idle

    /// 上一次提交读到的用户已经在列表里。
    @State
    private var isExisting = false

    /// 校验或授权的失败，弹出提示框。
    @State
    private var failure: AppFailure?

    /// 校验或授权的任务，按取消或关闭对话框时取消。
    @State
    private var task: Task<Void, Never>?

    /// 表单、错误区与底栏的等待中的步骤；失败弹出挂在对话框上的提示框。
    var body: some View {
        DialogLayout(
            title: title,
            message: message,
            submitTitle: AppLocalization.text(isReauthentication ? "accounts.update.submit" : "accounts.add.submit"),
            error: inputError,
            progress: progressMessage,
            canSubmit: canSubmit,
            cancel: cancel,
            submit: submit
        ) {
            DialogForm {
                if kind != .gitlab {
                    authenticationRow
                }

                if kind == .gitlabSelfManaged {
                    DialogFormRow(label: AppLocalization.text("accounts.host")) {
                        TextField("", text: $host, prompt: Text(verbatim: "https://example.com"))
                            .disabled(isBusy || isReauthentication)
                    }
                }

                credentialRows
                codeRow
            }
        }
        .alert(
            failure?.title ?? "",
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            ),
            presenting: failure
        ) { _ in
            Button(AppLocalization.text("action.ok")) { failure = nil }
        } message: { failure in
            Text(failure.message + "\n\n" + failure.details)
        }
        .onAppear(perform: prepare)
        .onDisappear { task?.cancel() }
    }

    /// 创建对话框：重新认证时沿用账号原来的认证方式，新账号取下拉的第一项。
    ///
    /// - Parameters:
    ///   - purpose: 对话框的用途。
    ///   - accounts: 保存账号的地方。
    ///   - close: 关闭 sheet。
    init(purpose: Purpose, accounts: HostingAccounts, close: @escaping () -> Void) {
        self.purpose = purpose
        self.accounts = accounts
        self.close = close

        switch purpose {
        case .add(.github): _authentication = State(initialValue: .oauth)
        case .add: _authentication = State(initialValue: .personalAccessToken)
        case .reauthenticate(let account): _authentication = State(initialValue: account.authentication)
        }
    }
}

// MARK: - Layout

extension AccountDialog {
    /// 认证方式的下拉，占满输入列：github.com 是浏览器授权与个人访问令牌，私有部署的 GitLab 是个人访问令牌与用户名和密码。
    private var authenticationRow: some View {
        DialogFormRow(label: AppLocalization.text("accounts.authentication")) {
            Picker("", selection: $authentication.animation(DialogAnimation.current)) {
                ForEach(methods, id: \.self) { method in
                    Text(AppLocalization.text(Self.titleKey(of: method))).tag(method)
                }
            }
            .labelsHidden()
            .buttonSizing(.flexible)
            .disabled(isBusy)
        }
    }

    /// 按认证方式要填的内容：个人访问令牌一行，用户名与密码两行，浏览器授权不用填。
    @ViewBuilder
    private var credentialRows: some View {
        switch authentication {
        case .oauth:
            EmptyView()

        // GitLab 的令牌框带占位文字，github.com 的不带
        case .personalAccessToken:
            DialogFormRow(label: AppLocalization.text("accounts.token")) {
                SecureField(
                    "",
                    text: $token,
                    prompt: kind == .github ? nil : Text(AppLocalization.text("accounts.authentication.token"))
                )
                .disabled(isBusy)
            }

        case .password:
            DialogFormRow(label: AppLocalization.text("accounts.username.label")) {
                TextField("", text: $username, prompt: Text(AppLocalization.text("accounts.username")))
                    .disabled(isBusy)
            }

            DialogFormRow(label: AppLocalization.text("accounts.password.label")) {
                SecureField("", text: $password, prompt: Text(AppLocalization.text("accounts.password")))
                    .disabled(isBusy)
            }
        }
    }

    /// 浏览器授权时的验证码与复制它、打开 GitHub 的按钮；等待中的步骤写在底栏。
    @ViewBuilder
    private var codeRow: some View {
        if case .authorizing(let authorization?) = progress {
            DialogFormRow(label: AppLocalization.text("accounts.code")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: authorization.userCode)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)

                    Button(AppLocalization.text("accounts.openGitHub")) { openVerificationPage(authorization) }
                }
            }
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

    /// 下拉里的认证方式。
    private var methods: [HostingAuthentication] {
        kind == .github ? [.oauth, .personalAccessToken] : [.personalAccessToken, .password]
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

    /// 内容完整且没有在等待时可以提交；密码原样使用，不去掉首尾空白。
    private var canSubmit: Bool {
        guard !isBusy, instance != nil else {
            return false
        }

        switch authentication {
        case .oauth:
            return true

        case .personalAccessToken:
            return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        case .password:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        }
    }

    /// 底栏左侧的等待中的步骤：校验时写 “Validating…”，等浏览器授权时写 “Authorizing…”。
    private var progressMessage: String? {
        switch progress {
        case .idle: nil
        case .validating: AppLocalization.text("accounts.validating")
        case .authorizing: AppLocalization.text("accounts.authorizing")
        }
    }

    /// 错误区：私有部署的地址不合法，或上一次提交读到的用户已经在列表里。
    private var inputError: String? {
        if kind == .gitlabSelfManaged, let error = Self.hostError(host) {
            return error
        }

        return isExisting ? AppLocalization.text("accounts.exists") : nil
    }

    /// 标题写出服务，重新认证时写 “Update”；两种 GitLab 的重新认证同一个标题。
    var title: String {
        switch (kind, isReauthentication) {
        case (.github, false): AppLocalization.text("accounts.add.github.title")
        case (.github, true): AppLocalization.text("accounts.update.github.title")
        case (.gitlab, false): AppLocalization.text("accounts.add.gitlab.title")
        case (.gitlabSelfManaged, false): AppLocalization.text("accounts.add.gitlabSelfManaged.title")
        case (_, true): AppLocalization.text("accounts.update.gitlab.title")
        }
    }

    /// 说明这种认证方式要做什么、令牌要哪些权限；用户名与密码登录另写出能用的前提。
    private var message: String {
        switch (kind, authentication) {
        case (.github, .oauth): AppLocalization.text("accounts.message.oauth")
        case (.github, _): AppLocalization.text("accounts.message.githubToken")
        case (.gitlab, _): AppLocalization.text("accounts.message.gitlab")
        case (.gitlabSelfManaged, .password): AppLocalization.text("accounts.message.gitlabPassword")
        case (.gitlabSelfManaged, _): AppLocalization.text("accounts.message.gitlabSelfManaged")
        }
    }
}

// MARK: - Actions

extension AccountDialog {
    /// 重新认证时沿用原来的地址与用户名。
    private func prepare() {
        guard case .reauthenticate(let account) = purpose else {
            return
        }

        host = account.instance.webURL.absoluteString
        username = account.username
    }

    /// 校验或授权进行中时只停止，回到可以编辑的状态，对话框留着；不在进行时关闭。
    private func cancel() {
        guard isBusy else {
            close()
            return
        }

        task?.cancel()
    }

    /// github.com 的浏览器授权先取验证码再轮询，用户名与密码先换令牌，个人访问令牌直接校验。
    private func submit() {
        guard let instance else {
            return
        }

        isExisting = false

        task = Task {
            do {
                switch authentication {
                case .oauth:
                    DialogAnimation.perform { progress = .authorizing(nil) }
                    let credential = try await authorize()
                    DialogAnimation.perform { progress = .validating }
                    try await save(credential, on: instance, authentication: .oauth)

                case .personalAccessToken:
                    DialogAnimation.perform { progress = .validating }
                    try await save(
                        token.trimmingCharacters(in: .whitespacesAndNewlines),
                        on: instance,
                        authentication: .personalAccessToken
                    )

                case .password:
                    DialogAnimation.perform { progress = .validating }
                    try await signIn(on: instance)
                }

                close()
            } catch is CancellationError {
                DialogAnimation.perform { progress = .idle }
            } catch is ExistingAccount {
                DialogAnimation.perform { progress = .idle }
                isExisting = true
            } catch {
                DialogAnimation.perform { progress = .idle }
                failure = AppFailure(error: error, opening: false, location: nil)
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

        DialogAnimation.perform { progress = .authorizing(authorization) }
        openVerificationPage(authorization)

        return try await flow.token(for: authorization)
    }

    /// 校验令牌对应的用户，能保存时保存。校验记进 Activity 的 Service 页，不属于任何仓库。
    private func save(_ token: String, on instance: HostingInstance, authentication: HostingAuthentication) async throws {
        let user = try await RepositoryActivities.shared.recordHosting(
            title: AppLocalization.text("accounts.verify.title"),
            repository: nil
        ) {
            try await HostingClient(instance: instance, token: token).currentUser()
        }

        try requireSavable(user, on: instance)
        try accounts.save(user, on: instance, authentication: authentication, token: token)
    }

    /// 用用户名与密码换令牌，再用换来的令牌读到对应的用户后保存；两步记在同一条 Activity 里，密码不保存。
    private func signIn(on instance: HostingInstance) async throws {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = password

        let (user, token) = try await RepositoryActivities.shared.recordHosting(
            title: AppLocalization.text("accounts.verify.title"),
            repository: nil
        ) {
            let token = try await GitLabPasswordGrant(instance: instance).token(username: username, password: password)
            let client = HostingClient(instance: instance, authentication: .password) { token.accessToken }

            return (try await client.currentUser(), token)
        }

        try requireSavable(user, on: instance)
        try accounts.save(user, on: instance, token: token)
    }

    /// 读到的用户能否保存：校验期间按了取消的不保存；重新认证时必须是原来的用户；添加时同一实例上不能已有这个用户名的账号。
    private func requireSavable(_ user: HostingUser, on instance: HostingInstance) throws {
        try Task.checkCancellation()

        if case .reauthenticate(let account) = purpose, account.username != user.username {
            throw HostingError.differentUser(user.username)
        }

        if Self.isExisting(user.username, on: instance, for: purpose, among: accounts.items) {
            throw ExistingAccount()
        }
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
    /// 下拉里认证方式的名称。
    private static func titleKey(of method: HostingAuthentication) -> String {
        switch method {
        case .oauth: "accounts.authentication.oauth"
        case .personalAccessToken: "accounts.authentication.token"
        case .password: "accounts.authentication.password"
        }
    }

    /// 私有部署地址的错误：为空时只禁用主按钮，不写原因；不为空而认不出时写 “Host is not valid”。
    static func hostError(_ host: String) -> String? {
        guard
            !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            HostingInstance.gitlab(address: host) == nil
        else {
            return nil
        }

        return AppLocalization.text("accounts.host.invalid")
    }

    /// 添加时同一实例上已有这个用户名的账号；重新认证换的就是已有账号的令牌，不算。
    ///
    /// - Parameters:
    ///   - username: 令牌对应的用户名。
    ///   - instance: 账号所在的实例。
    ///   - purpose: 对话框的用途。
    ///   - accounts: 已登录的账号。
    static func isExisting(
        _ username: String,
        on instance: HostingInstance,
        for purpose: Purpose,
        among accounts: [HostingAccount]
    ) -> Bool {
        guard case .add = purpose else {
            return false
        }

        return accounts.contains { $0.instance == instance && $0.username == username }
    }
}
