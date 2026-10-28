import AppKit
import SpookyKit
import SwiftUI

// MARK: - CommitIdentityView

/// 提交人的姓名、邮箱与头像；点头像弹出身份菜单：档案、签名状态、把当前身份存为档案与管理档案。
struct CommitIdentityView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 全部身份档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 姓名与邮箱右对齐叠放在 45 pt 头像左侧，提示显示签名状态。
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(session.committer.name)
                Text(session.committer.email)
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(minWidth: 50, alignment: .trailing)
            .textSelection(.enabled)
            .help(session.repository?.displayPath ?? "")

            Menu {
                menuItems
            } label: {
                InitialsAvatar(name: session.committer.name, size: 45)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(signingStatus)
            .accessibilityLabel(AppLocalization.text("profiles.menu"))
        }
    }
}

// MARK: - Private

extension CommitIdentityView {
    /// 解码后的档案。
    private var profiles: [UserProfile] { UserProfiles.decode(storage) }

    /// 当前身份对应的档案。
    private var current: UserProfile? {
        profiles.first { $0.name == session.committer.name && $0.email == session.committer.email }
    }

    /// 档案逐项列出并勾选当前身份；没有对应档案时列出当前身份，随后是签名状态与档案管理入口。
    @ViewBuilder
    private var menuItems: some View {
        #warning("TODO: 档案菜单项括号内显示档案标题是推断，也可能是签名密钥。核实方式：建两个带不同签名密钥的同名身份档案后打开身份菜单比对；只影响菜单项文字。")
        ForEach(profiles) { profile in
            Toggle(
                profile.menuTitle,
                isOn: Binding(get: { profile == current }, set: { _ in session.applyProfile(profile) })
            )
            .disabled(!session.canWrite || profile == current)
            .help(
                profile.signingKey.map { AppLocalization.text("signing.key", $0, SigningFormat(key: $0).displayName) }
                    ?? AppLocalization.text("signing.none")
            )
        }

        if current == nil, !session.committer.name.isEmpty {
            Toggle(session.committer.name + " <" + session.committer.email + ">", isOn: .constant(true))
                .disabled(true)
        }

        if !signingStatus.isEmpty {
            Text(signingStatus)
        }

        Divider()

        if current == nil, !session.committer.name.isEmpty {
            Button(AppLocalization.text("profiles.addCurrent", session.committer.email)) {
                guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }

                UserProfiles.add(
                    name: session.committer.name,
                    email: session.committer.email,
                    signingKey: session.commitConfiguration?.signingKey,
                    in: window
                )
            }
        }

        Button(AppLocalization.text("profiles.manage")) { SettingsWindowController.show(.userProfiles) }
    }

    /// 提交时会不会签名，以及使用的密钥与格式。
    private var signingStatus: String {
        guard let configuration = session.commitConfiguration else {
            return ""
        }

        guard configuration.signsCommits else {
            return AppLocalization.text("signing.off")
        }

        let format = configuration.signingFormat.displayName

        if let key = configuration.signingKey {
            return AppLocalization.text("signing.key", key, format)
        }

        // OpenPGP 没有配置密钥时由 gpg 按提交人邮箱选择密钥，其它格式必须配置密钥。
        return configuration.signingFormat == .openpgp
            ? AppLocalization.text("signing.defaultKey", format)
            : AppLocalization.text("signing.none")
    }
}

// MARK: - SigningFormat

extension SigningFormat {
    /// 界面显示的格式名，与 Git 文档中的写法一致。
    var displayName: String {
        switch self {
        case .openpgp: "OpenPGP"
        case .x509: "X.509"
        case .ssh: "SSH"
        }
    }
}
