import AppKit
import SpookyKit
import SwiftUI

// MARK: - IdentityProfileMenu

/// 头像弹出的身份档案菜单：档案逐项列出并勾选当前身份，随后是把当前身份存为档案与管理档案。
///
/// 提交区与仓库设置的头像共用；选中档案经会话确认后写进仓库的本地配置。
struct IdentityProfileMenu: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 当前身份的姓名；没有身份时为空。
    let name: String

    /// 当前身份的邮箱。
    let email: String

    /// 列在档案之后、分隔线之前的说明，如提交时的签名状态；为空时不显示。
    var note = ""

    /// 全部身份档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 档案逐项列出并勾选当前身份；没有对应档案时列出当前身份，随后是说明与档案管理入口。
    var body: some View {
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

        if current == nil, !name.isEmpty {
            Toggle(name + " <" + email + ">", isOn: .constant(true))
                .disabled(true)
        }

        if !note.isEmpty {
            Text(note)
        }

        Divider()

        if current == nil, !name.isEmpty {
            Button(AppLocalization.text("profiles.addCurrent", email)) {
                guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }

                UserProfiles.add(
                    name: name,
                    email: email,
                    signingKey: session.commitConfiguration?.signingKey,
                    in: window
                )
            }
        }

        Button(AppLocalization.text("profiles.manage")) { SettingsWindowController.show(.userProfiles) }
    }
}

// MARK: - Private

extension IdentityProfileMenu {
    /// 解码后的档案。
    private var profiles: [UserProfile] { UserProfiles.decode(storage) }

    /// 当前身份对应的档案。
    private var current: UserProfile? {
        profiles.first { $0.name == name && $0.email == email }
    }
}
