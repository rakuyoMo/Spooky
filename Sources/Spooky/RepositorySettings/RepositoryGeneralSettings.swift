import SpookyKit
import SwiftUI

// MARK: - RepositoryGeneralSettings

/// 仓库设置的 General 段：名称、路径与描述，Issue 追踪，提交人身份，正文折行，以及提交签名。
///
/// 配置只写进这个仓库的本地配置；没有在本仓库设置的项显示 “–”，沿用全局设置。
struct RepositoryGeneralSettings: View {
    /// 正在编辑的项。
    private enum Editor: String, Identifiable {
        /// 仓库描述。
        case description

        /// Issue 追踪的地址模板与编号前缀。
        case issueTracking

        /// 提交人身份。
        case identity

        /// 正文每行字数上限。
        case lineLimit

        /// 签名密钥。
        case signingKey

        /// allowed signers 文件。
        case allowedSigners

        /// sheet 的身份。
        var id: String { rawValue }
    }

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

    /// 五组设置依次排列。
    var body: some View {
        generalRows

        issueTrackingRows

        identityRows

        wrappingRows

        signingRows
            .sheet(item: $editor) { editor in
                dialog(for: editor)
            }
    }
}

// MARK: - Rows

extension RepositoryGeneralSettings {
    /// 名称、带主机前缀的路径与描述。
    @ViewBuilder
    private var generalRows: some View {
        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.general"))

        RemoteSettingRow(label: AppLocalization.text("repositorySettings.name"), value: session.repository?.name ?? "")

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.path"),
            value: session.repository?.displayPath ?? "",
            small: true
        )

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.description"),
            value: summary.description?.trimmingCharacters(in: .newlines) ?? "",
            actions: [action("bookmarks.detail.edit") { editor = .description }]
        )
    }

    /// Issue 追踪的地址模板与编号前缀；没有设置时写明。
    @ViewBuilder
    private var issueTrackingRows: some View {
        RemoteSettingsGroup(
            title: AppLocalization.text("repositorySettings.issueTracking"),
            actions: [action("bookmarks.detail.edit") { editor = .issueTracking }]
        )

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.issueTrackerURL"),
            value: settings.issueTrackerTemplate ?? AppLocalization.text("issueTracking.notConfigured"),
            small: settings.issueTrackerTemplate != nil,
            secondary: settings.issueTrackerTemplate == nil
        )

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.issueNumberPrefix"),
            value: settings.issueNumberPrefix ?? AppLocalization.text("issueTracking.notConfigured"),
            secondary: settings.issueNumberPrefix == nil
        )
    }

    /// 提交人身份：Edit 写进本地配置，本地配置里有身份时另有 Unset。
    @ViewBuilder
    private var identityRows: some View {
        let committer = summary.committer.map { $0.name + " <" + $0.email + ">" }
        let unset = action("bookmarks.detail.unset") {
            write("repositorySettings.write") { try await WorkingCopyOperations(runner: $0).clearIdentity() }
        }

        RemoteSettingsGroup(title: AppLocalization.text("bookmarks.detail.identity"))

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.identity"),
            value: committer ?? AppLocalization.text("bookmarks.detail.noIdentity"),
            actions: [action("bookmarks.detail.edit") { editor = .identity }] + (summary.hasRepositoryIdentity ? [unset] : [])
        )
    }

    /// 正文参考线的开关与每行字数上限。
    @ViewBuilder
    private var wrappingRows: some View {
        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.wrapping"))

        RepositorySettingToggle(
            label: AppLocalization.text("repositorySettings.pageGuide"),
            isOn: settings.showsBodyGuide ?? showsGuide,
            isEnabled: session.canWrite
        ) { isOn in
            setConfig(RepositorySettings.Key.showsBodyGuide, to: isOn ? "true" : "false")
        }

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.lineLimit"),
            value: settings.bodyLineLimit.map(String.init) ?? "–",
            actions: [action("bookmarks.detail.edit") { editor = .lineLimit }]
                + (settings.bodyLineLimit == nil ? [] : [unsetAction(RepositorySettings.Key.bodyLineLimit)])
        )
    }

    /// 是否签名提交、签名密钥与 allowed signers 文件。
    @ViewBuilder
    private var signingRows: some View {
        RemoteSettingsGroup(title: AppLocalization.text("repositorySettings.signing"))

        RepositorySettingToggle(
            label: AppLocalization.text("repositorySettings.signCommits"),
            isOn: settings.signsCommits ?? session.commitConfiguration?.signsCommits ?? false,
            isEnabled: session.canWrite
        ) { isOn in
            setConfig(RepositorySettings.Key.signsCommits, to: isOn ? "true" : "false")
        }

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.signingKey"),
            value: settings.signingKey ?? "–",
            small: true,
            actions: [action("bookmarks.detail.edit") { editor = .signingKey }]
                + (settings.signingKey == nil ? [] : [unsetAction(RepositorySettings.Key.signingKey)])
        )

        RemoteSettingRow(
            label: AppLocalization.text("repositorySettings.allowedSigners"),
            value: settings.allowedSignersFile ?? "–",
            small: true,
            actions: [action("bookmarks.detail.edit") { editor = .allowedSigners }]
                + (settings.allowedSignersFile == nil ? [] : [unsetAction(RepositorySettings.Key.allowedSignersFile)])
        )
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
                write("repositorySettings.write") { try await $0.setRepositoryDescription(text) }
            }

        case .issueTracking:
            IssueTrackingDialog(
                template: settings.issueTrackerTemplate ?? "",
                prefix: settings.issueNumberPrefix ?? "",
                save: saveIssueTracking,
                close: close
            )

        case .identity:
            EditIdentityDialog(
                name: summary.committer?.name ?? "",
                email: summary.committer?.email ?? "",
                close: close
            ) { name, email in
                write("repositorySettings.write") {
                    try await WorkingCopyOperations(runner: $0).applyIdentity(name: name, email: email, signingKey: nil)
                }
            }

        default:
            valueDialog(for: editor, close: close)
        }
    }

    /// 字数上限、签名密钥与 allowed signers 文件的单值对话框。
    private func valueDialog(for editor: Editor, close: @escaping () -> Void) -> some View {
        let (key, label, initial): (String, String, String) =
            switch editor {
            case .lineLimit:
                (
                    RepositorySettings.Key.bodyLineLimit,
                    "repositorySettings.lineLimit",
                    settings.bodyLineLimit.map(String.init) ?? ""
                )

            case .signingKey:
                (RepositorySettings.Key.signingKey, "repositorySettings.signingKey", settings.signingKey ?? "")

            default:
                (
                    RepositorySettings.Key.allowedSignersFile,
                    "repositorySettings.allowedSigners",
                    settings.allowedSignersFile ?? ""
                )
            }

        return SettingValueDialog(
            label: AppLocalization.text(label),
            value: initial,
            problem: { value in
                guard editor == .lineLimit else { return nil }
                return Int(value).map { $0 > 0 } ?? false ? nil : AppLocalization.text("repositorySettings.lineLimit.invalid")
            },
            close: close
        ) { value in
            setConfig(key, to: value)
        }
    }
}

// MARK: - Private

extension RepositoryGeneralSettings {
    /// 一行的操作按钮；仓库不可写时禁用。
    private func action(_ title: String, perform: @escaping () -> Void) -> RemoteSettingAction {
        RemoteSettingAction(title: AppLocalization.text(title), isEnabled: session.canWrite, perform: perform)
    }

    /// 删除本地配置里的一项，此后沿用全局设置。
    private func unsetAction(_ key: String) -> RemoteSettingAction {
        action("bookmarks.detail.unset") { setConfig(key, to: nil) }
    }

    /// 写入或删除本地配置的一项。
    private func setConfig(_ key: String, to value: String?) {
        write("repositorySettings.write") { try await $0.setLocalConfig(key, to: value) }
    }

    /// 保存 Issue 追踪：空的一项从本地配置里删除。
    private func saveIssueTracking(template: String, prefix: String) {
        write("repositorySettings.write") { runner in
            try await runner.setLocalConfig(RepositorySettings.Key.issueTrackerTemplate, to: template.isEmpty ? nil : template)
            try await runner.setLocalConfig(RepositorySettings.Key.issueNumberPrefix, to: prefix.isEmpty ? nil : prefix)
        }
    }

    /// 在仓库写队列里执行一次写入；结束后会话完整刷新，设置页随之重新读取。
    private func write(_ title: String, _ operation: @escaping @Sendable (GitRunner) async throws -> Void) {
        _ = session.performGit({ runner, _ in try await operation(runner) }, title: AppLocalization.text(title))
    }
}

// MARK: - RepositorySettingToggle

/// 设置表格里的一个勾选框：240 pt 宽的次级色标签与右侧的勾选框。
private struct RepositorySettingToggle: View {
    /// 左侧标签。
    let label: String

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

            Toggle("", isOn: Binding(get: { isOn }, set: change))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(!isEnabled)
                .accessibilityLabel(label)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 30)
    }
}
