import SpookyKit
import SwiftUI

// MARK: - PublishRepositoryDialog

/// 发布仓库：选账号与所有者，填名称、描述与可见性，选远端名与地址协议；发布前写出远端地址、推送目标与覆盖风险。
///
/// 同名仓库已在托管服务上、或本仓库已有同名远端时不能发布，免得覆盖已有的仓库或远端。
struct PublishRepositoryDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 关闭 sheet。
    let close: () -> Void

    /// 选中的账号。
    @State
    private var accountID: UUID?

    /// 账号可以在其下新建仓库的所有者。
    @State
    private var owners: [HostingOwner] = []

    /// 选中的所有者。
    @State
    private var ownerID = ""

    /// 仓库名。
    @State
    private var name = ""

    /// 描述。
    @State
    private var description = ""

    /// 可见性；新仓库默认私有。
    @State
    private var visibility = HostingVisibility.`private`

    /// 远端名。
    @State
    private var remote = "origin"

    /// 远端用 SSH 地址。
    @State
    private var usesSSH = false

    /// 同名仓库已经存在。
    @State
    private var exists = false

    /// 读取所有者或检查是否存在的失败。
    @State
    private var failure = ""

    /// 账号、所有者、名称、描述、可见性、远端与将要发生的事。
    var body: some View {
        ReferenceDialogLayout(
            session: session,
            title: AppLocalization.text("publish.title"),
            message: AppLocalization.text("publish.message"),
            submitTitle: AppLocalization.text("publish.title"),
            error: error,
            isValid: isValid,
            cancel: close,
            submit: submit
        ) {
            accountRows

            repositoryRows

            remoteRows
        }
        .task(id: accountID) { await loadOwners() }
        .task(id: [accountID?.uuidString ?? "", ownerID, name]) { await checkExistence() }
        .onAppear(perform: prepare)
    }
}

// MARK: - Layout

extension PublishRepositoryDialog {
    /// 账号与所有者。
    @ViewBuilder
    private var accountRows: some View {
        ReferenceDialogRows.row(AppLocalization.text("pullRequests.account")) {
            Picker("", selection: $accountID) {
                ForEach(accounts) { account in
                    Text(account.username + " – " + account.instance.displayName).tag(Optional(account.id))
                }
            }
            .labelsHidden()
            .fixedSize()
        }

        ReferenceDialogRows.row(AppLocalization.text("publish.owner")) {
            Picker("", selection: $ownerID) {
                ForEach(owners) { owner in
                    Text(owner.path).tag(owner.id)
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(owners.isEmpty)
        }
    }

    /// 名称、描述与可见性。
    @ViewBuilder
    private var repositoryRows: some View {
        ReferenceDialogRows.row(AppLocalization.text("publish.name")) {
            TextField("", text: $name)
        }

        ReferenceDialogRows.row(AppLocalization.text("pullRequests.description")) {
            TextField("", text: $description)
        }

        ReferenceDialogRows.row(AppLocalization.text("publish.visibility")) {
            Picker("", selection: $visibility) {
                ForEach(visibilities, id: \.self) { visibility in
                    Text(AppLocalization.text("publish.visibility." + visibility.rawValue)).tag(visibility)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    /// 远端名与地址协议，以及将要添加的地址与推送目标。
    @ViewBuilder
    private var remoteRows: some View {
        ReferenceDialogRows.row(AppLocalization.text("publish.remote")) {
            HStack(spacing: 6) {
                TextField("", text: $remote)

                Picker("", selection: $usesSSH) {
                    Text(verbatim: "HTTPS").tag(false)
                    Text(verbatim: "SSH").tag(true)
                }
                .labelsHidden()
                .fixedSize()
            }
        }

        ReferenceDialogRows.row(AppLocalization.text("publish.target")) {
            Text(target)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - State

extension PublishRepositoryDialog {
    /// 已登录的账号。
    private var accounts: [HostingAccount] {
        session.pullRequests.accounts.items
    }

    /// 选中的账号。
    private var account: HostingAccount? {
        accounts.first { $0.id == accountID }
    }

    /// 选中的所有者。
    private var owner: HostingOwner? {
        owners.first { $0.id == ownerID }
    }

    /// 服务支持的可见性：GitHub 没有 Internal。
    private var visibilities: [HostingVisibility] {
        account?.instance.service == .gitlab ? HostingVisibility.allCases : [.private, .public]
    }

    /// 将要添加的远端地址与推送目标；新建后以托管服务给出的地址为准。
    private var target: String {
        guard let account, let owner, !name.isEmpty else {
            return ""
        }

        let host = account.instance.webURL.host() ?? ""
        let path = owner.path + "/" + name + ".git"
        let url = usesSSH ? "git@" + host + ":" + path : account.instance.webURL.absoluteString + "/" + path

        guard let branch = session.status?.branch.head else {
            return url + "\n" + AppLocalization.text("publish.noBranch")
        }

        return url + "\n" + AppLocalization.text("publish.push", branch, remote)
    }

    /// 覆盖风险或读取失败的说明。
    private var error: String {
        if accounts.isEmpty {
            return AppLocalization.text("pullRequests.associate.noAccounts")
        }

        if exists, let owner, let account {
            return AppLocalization.text("publish.exists", owner.path + "/" + name, account.instance.displayName)
        }

        if session.history.snapshot?.remotes.contains(where: { $0.name == remote }) ?? false {
            return AppLocalization.text("publish.remoteExists", remote)
        }

        return failure
    }

    /// 内容完整且没有覆盖风险。
    private var isValid: Bool {
        account != nil && owner != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty && !remote.isEmpty
            && error.isEmpty
    }
}

// MARK: - Actions

extension PublishRepositoryDialog {
    /// 预选第一个账号，仓库名取工作区的目录名。
    private func prepare() {
        accountID = accountID ?? accounts.first?.id
        name = name.isEmpty ? session.repository?.name ?? "" : name
    }

    /// 读取账号可以在其下新建仓库的所有者，预选账号本人。
    private func loadOwners() async {
        owners = []
        ownerID = ""

        guard let account, let client = session.pullRequests.accounts.client(for: account) else {
            return
        }

        do {
            owners = try await client.owners()
            ownerID = owners.first?.id ?? ""
            failure = ""
        } catch {
            guard !Task.isCancelled else { return }
            failure = AppFailure(error: error, opening: false, location: nil).details
        }
    }

    /// 输入停下片刻后检查同名仓库是否已经存在。
    private func checkExistence() async {
        exists = false

        guard let account, let owner, !name.isEmpty, let client = session.pullRequests.accounts.client(for: account) else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(400))
            exists = try await client.repositoryExists(owner.path + "/" + name)
        } catch {
            guard !Task.isCancelled else { return }
            failure = AppFailure(error: error, opening: false, location: nil).details
        }
    }

    /// 开始发布后关闭。
    private func submit() {
        guard let account, let owner else { return }

        let started = session.publishRepository(
            RepositoryPublication(
                account: account,
                owner: owner,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description,
                visibility: visibility,
                remote: remote,
                usesSSH: usesSSH
            )
        )

        if started { close() }
    }
}
