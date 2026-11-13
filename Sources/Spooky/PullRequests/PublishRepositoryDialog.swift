import SpookyKit
import SwiftUI

// MARK: - PublishRepositoryDialog

/// 发布仓库：填远端名，在 Account 下拉里选新建仓库用的账号或组织，填名称、描述与可见性；
/// 发布前写出将要添加的 HTTPS 地址与推送目标。
///
/// 同名仓库已在托管服务上、或本仓库已有同名远端时不能发布，免得覆盖已有的仓库或远端。
struct PublishRepositoryDialog: View {
    /// 发起动作的窗口会话。
    let session: RepositorySession

    /// 关闭 sheet。
    let close: () -> Void

    /// 各账号可以在其下新建仓库的所有者；读到一个账号加一个。
    @State
    private var owners: [UUID: [HostingOwner]] = [:]

    /// 用户在 Account 下拉里选的项；还没选过时为 nil，选中项跟着下拉的第一项走。
    @State
    private var chosenID: String?

    /// 仓库名。
    @State
    private var name = ""

    /// 描述。
    @State
    private var description = ""

    /// 可见性；新仓库默认私有，换选中项时回到私有。
    @State
    private var visibility = HostingVisibility.`private`

    /// 远端名。
    @State
    private var remote = ""

    /// 同名仓库已经存在。
    @State
    private var exists = false

    /// 读取所有者的失败，按账号记。
    @State
    private var ownerFailures: [UUID: String] = [:]

    /// 检查同名仓库的失败。
    @State
    private var checkFailure = ""

    /// Account 与 Access 两个下拉按内容的宽度，取较宽的一个；量出来之前为 nil。
    @State
    private var popUpWidth: CGFloat?

    /// 480 宽的对话框骨架：远端名、账号、名称、描述、可见性与将要添加的地址；输入列至少从对齐线开始，标签长时随之右移。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("publish.title"),
            message: AppLocalization.text("publish.message"),
            submitTitle: AppLocalization.text("publish.submit"),
            error: error,
            canSubmit: canSubmit,
            cancel: close,
            submit: submit
        ) {
            DialogForm {
                remoteRow

                accountRow

                repositoryRows

                targetRow
            }
        }
        .task { await loadOwners() }
        .task(id: [selection?.id ?? "", name]) { await checkExistence() }
        .onChange(of: selection?.id) { visibility = .private }
        .onAppear(perform: prepare)
    }
}

// MARK: - Rules

extension PublishRepositoryDialog {
    /// 预填的远端名：`origin` 没被占用时用它，否则依次试 `origin-2`、`origin-3`……，取第一个没被占用的。
    ///
    /// - Parameter names: 仓库已有的远端名。
    static func remoteName(avoiding names: [String]) -> String {
        guard names.contains("origin") else {
            return "origin"
        }

        var suffix = 2

        while names.contains("origin-" + String(suffix)) {
            suffix += 1
        }

        return "origin-" + String(suffix)
    }

    /// Account 下拉的项：按账号列表的顺序，每个账号先是本人，再是它的组织，组织按路径升序；还没读到所有者的账号没有项。
    ///
    /// - Parameters:
    ///   - accounts: 已登录的账号。
    ///   - owners: 已读到的各账号的所有者。
    static func items(of accounts: [HostingAccount], owners: [UUID: [HostingOwner]]) -> [PublishOwner] {
        accounts.flatMap { account in
            let loaded = owners[account.id] ?? []
            let users = loaded.filter(\.isUser)
            let organizations = loaded
                .filter { !$0.isUser }
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

            return (users + organizations).map { PublishOwner(account: account, owner: $0) }
        }
    }
}

// MARK: - Layout

extension PublishRepositoryDialog {
    /// 远端名，占满输入列。
    private var remoteRow: some View {
        DialogFormRow(label: AppLocalization.text("publish.remote")) {
            TextField("", text: $remote)
        }
    }

    /// 账号与组织在同一个下拉里，按内容宽、不超过输入列；一项也没有时不可用。
    ///
    /// 背后量一份不可见、按内容宽的 Account 与 Access 下拉，取较宽的一个作为两者共用的宽度。
    private var accountRow: some View {
        DialogFormRow(label: AppLocalization.text("pullRequests.account")) {
            accountPicker
                .buttonSizing(.flexible)
                .frame(maxWidth: popUpWidth, alignment: .leading)
                .disabled(items.isEmpty)
                .background(alignment: .leading) {
                    VStack(alignment: .leading) {
                        accountPicker

                        accessPicker
                    }
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                        popUpWidth = width
                    }
                }
        }
    }

    /// 名称、描述与可见性；可见性与 Account 下拉同宽。
    @ViewBuilder
    private var repositoryRows: some View {
        DialogFormRow(label: AppLocalization.text("publish.name")) {
            TextField(
                "",
                text: $name.animation(DialogAnimation.current),
                prompt: Text(AppLocalization.text("publish.name.placeholder"))
            )
        }

        DialogFormRow(label: AppLocalization.text("pullRequests.description")) {
            descriptionField
        }

        DialogFormRow(label: AppLocalization.text("publish.visibility")) {
            accessPicker
                .buttonSizing(.flexible)
                .frame(maxWidth: popUpWidth, alignment: .leading)
        }
    }

    /// 将要添加的地址与推送目标，宽度固定为输入列：从输入列到对话框右边 20。
    ///
    /// 不固定宽度时，表格按较窄的宽度量多行文字的高度，这一行会比文字高出一截。
    private var targetRow: some View {
        DialogFormRow(label: AppLocalization.text("publish.target")) {
            DialogInputColumnReader { inputColumn in
                Text(target)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 480 - inputColumn - 20, alignment: .leading)
            }
        }
    }

    /// 描述：高 64、自动折行，带边框，回车按下主按钮。
    ///
    /// 系统边框的文字框只能按整行增高，这里用无边框的文字框留出上下边距，再画边框，与新建请求对话框的描述一致。
    private var descriptionField: some View {
        TextField(
            "",
            text: $description,
            prompt: Text(AppLocalization.text("publish.description.placeholder")),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .lineLimit(3, reservesSpace: true)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppPalette.color("general_border_color")))
    }

    /// 各账号本人与它们的组织。
    private var accountPicker: some View {
        let chosen = Binding(
            get: { selection?.id },
            set: { id in
                // 目标地址随所有者变化，折行数跟着变时对话框高度同步变化
                DialogAnimation.perform { chosenID = id }
            }
        )

        return Picker("", selection: chosen) {
            ForEach(items) { item in
                Text(item.title).tag(Optional(item.id))
            }
        }
        .labelsHidden()
    }

    /// 选中项所在服务支持的可见性。
    private var accessPicker: some View {
        Picker("", selection: $visibility) {
            ForEach(visibilities, id: \.self) { visibility in
                Text(AppLocalization.text("publish.visibility." + visibility.rawValue)).tag(visibility)
            }
        }
        .labelsHidden()
    }
}

// MARK: - State

extension PublishRepositoryDialog {
    /// 已登录的账号。
    private var accounts: [HostingAccount] {
        session.pullRequests.accounts.items
    }

    /// Account 下拉的项。
    private var items: [PublishOwner] {
        Self.items(of: accounts, owners: owners)
    }

    /// 选中项：用户选过且还在下拉里时是它，否则是下拉的第一项。
    private var selection: PublishOwner? {
        items.first { $0.id == chosenID } ?? items.first
    }

    /// 服务支持的可见性：GitHub 没有 Internal。
    private var visibilities: [HostingVisibility] {
        selection?.account.instance.service == .gitlab ? HostingVisibility.allCases : [.private, .public]
    }

    /// 将要添加的 HTTPS 地址与推送目标；新建后以托管服务给出的地址为准。
    private var target: String {
        guard let selection, !name.isEmpty else {
            return ""
        }

        let path = selection.owner.path + "/" + name + ".git"
        let url = selection.account.instance.webURL.absoluteString + "/" + path

        return url + "\n" + AppLocalization.text("publish.push", remote)
    }

    /// 错误区依次取第一条：仓库暂不可写、同名仓库已在托管服务上、与已有远端同名、读取所有者或检查同名的失败。
    private var error: String? {
        let failures = accounts.compactMap { ownerFailures[$0.id] } + [checkFailure]
        let remoteNames = session.history.snapshot?.remotes.map(\.name) ?? []

        let messages = [
            session.canWrite ? nil : AppLocalization.text("dialog.blocked"),
            exists ? existsMessage : nil,
            remoteNames.contains(remote) ? AppLocalization.text("remote.exists") : nil,
            failures.first { !$0.isEmpty },
        ]

        return messages.compactMap(\.self).first
    }

    /// 同名仓库已在托管服务上的说明。
    private var existsMessage: String? {
        guard let selection else {
            return nil
        }

        return AppLocalization.text(
            "publish.exists",
            selection.owner.path + "/" + name,
            selection.account.instance.displayName
        )
    }

    /// 选中了所有者、名称与远端名不为空，且错误区为空时才能发布。
    private var canSubmit: Bool {
        selection != nil
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !remote.isEmpty
            && error == nil
    }
}

// MARK: - Actions

extension PublishRepositoryDialog {
    /// 远端名避开已有的远端，仓库名取工作区的目录名。
    private func prepare() {
        if remote.isEmpty {
            remote = Self.remoteName(avoiding: session.history.snapshot?.remotes.map(\.name) ?? [])
        }

        if name.isEmpty {
            name = session.repository?.name ?? ""
        }
    }

    /// 为每个账号并发读一次可以在其下新建仓库的所有者，读到一个账号就把它的项加进下拉；失败的账号没有项。
    private func loadOwners() async {
        let repository = session.repository
        let title = AppLocalization.text("publish.loadOwners.title")
        let clients = accounts.compactMap { account in
            session.pullRequests.accounts.client(for: account).map { (account.id, $0) }
        }

        await withTaskGroup(of: (UUID, Result<[HostingOwner], any Error>).self) { group in
            for (id, client) in clients {
                group.addTask {
                    await (id, Self.owners(using: client, title: title, repository: repository))
                }
            }

            for await (id, result) in group {
                switch result {
                case .success(let loaded):
                    owners[id] = loaded

                case .failure(let error):
                    guard !Task.isCancelled else { continue }
                    ownerFailures[id] = AppFailure(error: error, opening: false, location: nil).details
                }
            }
        }
    }

    /// 输入停下片刻后检查同名仓库是否已经存在。
    private func checkExistence() async {
        exists = false
        checkFailure = ""

        guard
            let selection,
            !name.isEmpty,
            let client = session.pullRequests.accounts.client(for: selection.account)
        else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(400))

            exists = try await RepositoryActivities.shared.recordHosting(
                title: AppLocalization.text("publish.checkName.title"),
                repository: session.repository
            ) {
                try await client.repositoryExists(selection.owner.path + "/" + name)
            }
        } catch {
            guard !Task.isCancelled else { return }
            checkFailure = AppFailure(error: error, opening: false, location: nil).details
        }
    }

    /// 开始发布后关闭。
    private func submit() {
        guard let selection else { return }

        let started = session.publishRepository(
            RepositoryPublication(
                account: selection.account,
                owner: selection.owner,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description,
                visibility: visibility,
                remote: remote
            )
        )

        if started { close() }
    }
}

// MARK: - Owner Loading

extension PublishRepositoryDialog {
    /// 用一个账号的客户端读所有者，记一条 Activity；失败作为结果返回，供并发读取时按账号收集。
    ///
    /// - Parameters:
    ///   - client: 账号的 API 客户端。
    ///   - title: Activity 的标题。
    ///   - repository: Activity 所属的仓库。
    private static func owners(
        using client: HostingClient,
        title: String,
        repository: RepositoryLocation?
    ) async -> Result<[HostingOwner], any Error> {
        do {
            let owners = try await RepositoryActivities.shared.recordHosting(title: title, repository: repository) {
                try await client.owners()
            }

            return .success(owners)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - PublishOwner

/// Account 下拉的一项：新建仓库用的账号，与仓库建在其下的所有者。
struct PublishOwner: Hashable, Identifiable {
    /// 新建仓库用的账号。
    let account: HostingAccount

    /// 账号本人或它的组织。
    let owner: HostingOwner

    /// 账号与所有者合起来的标识。
    var id: String {
        account.id.uuidString + "/" + owner.id
    }

    /// 本人写 “用户名 – 实例”，组织写路径。
    var title: String {
        owner.isUser ? account.username + " – " + account.instance.displayName : owner.path
    }
}
