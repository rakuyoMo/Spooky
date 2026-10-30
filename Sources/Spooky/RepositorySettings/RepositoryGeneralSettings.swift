import SpookyKit
import SwiftUI

// MARK: - RepositoryGeneralSettings

/// 仓库设置的 General 段：名称、路径、服务器仓库的本机目录、描述与提交人身份，正文折行，以及提交签名。
///
/// 配置只写进这个仓库的本地配置；本仓库没有设置的项沿用全局设置，字数上限显示 “–”。
struct RepositoryGeneralSettings: View {
    /// 正在编辑的项。
    private enum Editor: String, Identifiable {
        /// 仓库描述。
        case description

        /// 提交人身份。
        case identity

        /// 正文每行字数上限。
        case lineLimit

        /// 服务器仓库的 allowed signers 文件，填写服务器上的路径。
        case allowedSigners

        /// sheet 的身份。
        var id: String { rawValue }
    }

    /// 服务器仓库在 Allowed Signers File 菜单里列出的文件，由服务器上的 Git 展开 `~`。
    private static let serverAllowedSigners = "~/.ssh/allowed_signers"

    /// 所在窗口的会话。
    let session: RepositorySession

    /// 本地配置与规则文件。
    let settings: RepositorySettings

    /// 描述与提交人身份。
    let summary: RepositorySummary

    /// Editor 设置页的参考线开关，本仓库没有设置时沿用。
    @AppStorage(CommitEditorSettings.showsGuideKey)
    private var showsGuide = true

    /// 正在编辑的项。
    @State
    private var editor: Editor?

    /// 本机的签名密钥，供 Signing Key 菜单列出。
    @State
    private var keys: [SigningKey] = []

    /// 三组设置依次排列。
    var body: some View {
        generalRows

        wrappingRows

        signingRows
            .sheet(item: $editor) { editor in
                dialog(for: editor)
            }
    }
}

// MARK: - Rows

extension RepositoryGeneralSettings {
    /// 名称、带主机前缀的路径、服务器仓库在这台 Mac 上的本机目录、描述与提交人身份。
    @ViewBuilder
    private var generalRows: some View {
        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.general"))

        RemoteSettingRow(label: AppLocalization.text("repositorySettings.name"), value: session.repository?.name ?? "")

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.path"),
            value: session.repository?.displayPath ?? "",
            small: true
        )

        if session.repository?.host != nil {
            RepositoryLocalFolderRow(session: session)
        }

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.description"),
            value: summary.description?.trimmingCharacters(in: .newlines) ?? "",
            actions: [action("bookmarks.detail.edit") { editor = .description }]
        )

        identityRow
    }

    /// 提交人身份：点头像换用或新建身份档案，Edit 把姓名与邮箱写进本地配置。
    private var identityRow: some View {
        IdentitySettingRow(
            identity: summary.committer,
            isMenuEnabled: true,
            actions: [action("bookmarks.detail.edit") { editor = .identity }]
        ) {
            IdentityProfileMenu(
                session: session,
                name: summary.committer?.name ?? "",
                email: summary.committer?.email ?? ""
            )
        }
    }

    /// 正文参考线的开关与每行字数上限；Unset 在本地配置里没有字数上限时禁用。
    @ViewBuilder
    private var wrappingRows: some View {
        let unset = RemoteSettingAction(
            title: AppLocalization.text("bookmarks.detail.unset"),
            isEnabled: session.canWrite && settings.bodyLineLimit != nil,
            perform: { setConfig(RepositorySettings.Key.bodyLineLimit, to: nil) }
        )

        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.wrapping"))

        RepositorySettingToggle(
            label: AppLocalization.text("repositorySettings.wrapping"),
            title: AppLocalization.text("repositorySettings.pageGuide"),
            isOn: settings.showsBodyGuide ?? showsGuide,
            isEnabled: session.canWrite
        ) { isOn in
            setConfig(RepositorySettings.Key.showsBodyGuide, to: isOn ? "true" : "false")
        }

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.lineLimit"),
            value: settings.bodyLineLimit.map(String.init) ?? "–",
            actions: [action("remote.action.set") { editor = .lineLimit }, unset]
        )
    }

    /// 是否签名提交，以及签名密钥与 allowed signers 文件的弹出菜单，选中即写进本地配置。
    @ViewBuilder
    private var signingRows: some View {
        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.signing"))

        RepositorySettingToggle(
            label: AppLocalization.text("repositorySettings.signing"),
            title: AppLocalization.text("repositorySettings.signCommits"),
            isOn: settings.signsCommits ?? session.commitConfiguration?.signsCommits ?? false,
            isEnabled: session.canWrite
        ) { isOn in
            setConfig(RepositorySettings.Key.signsCommits, to: isOn ? "true" : "false")
        }

        RepositorySettingMenu(
            label: AppLocalization.text("repositorySettings.signingKey"),
            isEnabled: session.canWrite
        ) {
            signingKeyPicker
        }
        .task { keys = await SigningKeys.local() }

        RepositorySettingMenu(
            label: AppLocalization.text("repositorySettings.allowedSigners"),
            isEnabled: session.canWrite
        ) {
            allowedSignersPicker
        }
    }
}

// MARK: - Signing Menus

extension RepositoryGeneralSettings {
    /// 签名密钥：本机的 GPG 与 SSH 密钥、本机找不到的已配置密钥，最后是不带密钥；选中密钥时同时写入签名格式。
    private var signingKeyPicker: some View {
        let configured = settings.signingKey
        let unknown = configured.flatMap { value in keys.contains { $0.matches(value) } ? nil : value }

        let selection = Binding<String?>(
            get: { configured.map { value in keys.first { $0.matches(value) }?.value ?? value } },
            set: { key in
                write {
                    try await $0.setLocalConfig(RepositorySettings.Key.signingKey, to: key)

                    if let key {
                        try await $0.setLocalConfig(
                            RepositorySettings.Key.signingFormat,
                            to: SigningFormat(key: key).rawValue
                        )
                    }
                }
            }
        )

        return Picker("", selection: selection) {
            ForEach(keys, id: \.value) { key in
                Text(UserProfiles.title(of: key))
                    .tag(Optional(key.value))
            }

            if let unknown {
                Text(UserProfiles.keyDescription(unknown))
                    .tag(Optional(unknown))
                    .disabled(true)
            }

            Text(AppLocalization.text("signing.none"))
                .tag(String?.none)
        }
    }

    /// allowed signers 文件：不使用、找到的文件与配置里的其它文件，最后是选择文件。
    ///
    /// 本机仓库写本机的路径，Select 打开文件面板；服务器仓库的文件在服务器上，Select 打开输入路径的对话框。
    private var allowedSignersPicker: some View {
        let configured = settings.allowedSignersFile
        let isServer = session.repository?.host != nil
        let files: [String] =
            if isServer {
                [Self.serverAllowedSigners]
                    + [configured].compactMap(\.self).filter { $0 != Self.serverAllowedSigners }
            } else {
                SigningPrograms.allowedSignersFiles(configured: configured)
            }

        let selection = Binding<String>(
            get: { configured ?? "" },
            set: { selected in
                guard selected == SigningPrograms.chooseTag else {
                    setConfig(RepositorySettings.Key.allowedSignersFile, to: selected.isEmpty ? nil : selected)
                    return
                }

                chooseAllowedSigners(isServer: isServer)
            }
        )

        return Picker("", selection: selection) {
            Text(AppLocalization.text("gitConfig.allowedSigners.none"))
                .tag("")

            ForEach(files, id: \.self) { path in
                Text(isServer ? path : HomePath.abbreviated(HomePath.expanded(path)))
                    .tag(path)
            }

            Divider()

            Text(AppLocalization.text("gitConfig.allowedSigners.select"))
                .tag(SigningPrograms.chooseTag)
        }
        .help(configured ?? "")
    }

    /// 选择 allowed signers 文件：本机仓库打开文件面板，服务器仓库打开输入服务器上路径的对话框。
    private func chooseAllowedSigners(isServer: Bool) {
        guard !isServer else {
            editor = .allowedSigners
            return
        }

        SigningPrograms.chooseFile { setConfig(RepositorySettings.Key.allowedSignersFile, to: $0) }
    }
}

// MARK: - Dialogs

extension RepositoryGeneralSettings {
    /// 编辑一项的对话框；提交后写进仓库，结束后设置页重新读取。
    @ViewBuilder
    private func dialog(for editor: Editor) -> some View {
        let close = { self.editor = nil }

        switch editor {
        case .description:
            EditDescriptionDialog(text: summary.description ?? "", close: close) { text in
                write { try await $0.setRepositoryDescription(text) }
            }

        case .identity:
            EditIdentityDialog(
                name: summary.committer?.name ?? "",
                email: summary.committer?.email ?? "",
                close: close
            ) { name, email in
                write {
                    try await WorkingCopyOperations(runner: $0).applyIdentity(name: name, email: email, signingKey: nil)
                }
            }

        case .lineLimit:
            SettingValueDialog(
                label: AppLocalization.text("repositorySettings.lineLimit"),
                value: settings.bodyLineLimit.map(String.init) ?? "",
                problem: { value in
                    Int(value).map { $0 > 0 } ?? false ? nil : AppLocalization.text("repositorySettings.lineLimit.invalid")
                },
                close: close
            ) { value in
                setConfig(RepositorySettings.Key.bodyLineLimit, to: value)
            }

        case .allowedSigners:
            SettingValueDialog(
                label: AppLocalization.text("repositorySettings.allowedSigners"),
                value: settings.allowedSignersFile ?? "",
                problem: { _ in nil },
                close: close
            ) { value in
                setConfig(RepositorySettings.Key.allowedSignersFile, to: value)
            }
        }
    }
}

// MARK: - Private

extension RepositoryGeneralSettings {
    /// 一行的操作按钮；仓库不可写时禁用。
    private func action(_ title: String, perform: @escaping () -> Void) -> RemoteSettingAction {
        RemoteSettingAction(title: AppLocalization.text(title), isEnabled: session.canWrite, perform: perform)
    }

    /// 写入或删除本地配置的一项。
    private func setConfig(_ key: String, to value: String?) {
        write { try await $0.setLocalConfig(key, to: value) }
    }

    /// 在仓库写队列里执行一次写入；结束后会话完整刷新，设置页随之重新读取。
    private func write(_ operation: @escaping @Sendable (GitRunner) async throws -> Void) {
        _ = session.performGit(
            { runner, _ in try await operation(runner) },
            title: AppLocalization.text("repositorySettings.write")
        )
    }
}

// MARK: - RepositorySettingToggle

/// 设置表格里的一个勾选框：240 pt 宽的次级色标签与右侧带标题的勾选框。
private struct RepositorySettingToggle: View {
    /// 左侧标签。
    let label: String

    /// 勾选框的标题。
    let title: String

    /// 当前是否勾选。
    let isOn: Bool

    /// 仓库不可写时禁用。
    let isEnabled: Bool

    /// 勾选状态改变。
    let change: (Bool) -> Void

    /// 标签与勾选框横向排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 240, alignment: .leading)

            Toggle(title, isOn: Binding(get: { isOn }, set: change))
                .toggleStyle(.checkbox)
                .disabled(!isEnabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 30)
    }
}

// MARK: - RepositorySettingMenu

/// 设置表格里的一个弹出菜单：240 pt 宽的次级色标签与右侧按内容定宽的弹出菜单。
private struct RepositorySettingMenu<Content: View>: View {
    /// 左侧标签，也是弹出菜单的辅助功能名称。
    let label: String

    /// 仓库不可写时禁用。
    let isEnabled: Bool

    /// 弹出菜单。
    @ViewBuilder
    let menu: () -> Content

    /// 标签与弹出菜单横向排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 240, alignment: .leading)

            menu()
                .labelsHidden()
                .fixedSize()
                .disabled(!isEnabled)
                .accessibilityLabel(label)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 30)
    }
}
