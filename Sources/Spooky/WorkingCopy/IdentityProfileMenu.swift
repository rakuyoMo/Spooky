import AppKit
import SpookyKit
import SwiftUI

// MARK: - IdentityProfileMenu

/// 头像弹出的身份档案菜单：档案逐项列出并勾选当前身份，随后是把当前身份存为档案与管理档案。
///
/// 每项写姓名、邮箱与签名密钥的简述。提交区、仓库设置与仓库管理详情的头像共用；选中档案后由调用方确认并写进仓库的本地配置。
struct IdentityProfileMenu: View {
    /// 菜单里的一项。
    enum Item: Equatable {
        /// 一个档案；与当前身份一致时打勾。
        case profile(UserProfile, isCurrent: Bool)

        /// 没有对应档案的当前身份，打勾且不可选。
        case identity

        /// 分隔线。
        case separator

        /// 把当前身份存为档案。
        case addCurrent

        /// 打开 User Profiles 设置页。
        case manage
    }

    /// 当前身份的姓名；没有身份时为空。
    let name: String

    /// 当前身份的邮箱。
    let email: String

    /// 当前身份的签名密钥，存为档案时一并带上。
    let signingKey: String?

    /// 本机可用的签名密钥，用来写出各项签名密钥的简述。
    let keys: [SigningKey]

    /// 仓库可写时才能选用档案。
    let canApply: Bool

    /// 选用一个档案。
    let apply: (UserProfile) -> Void

    /// 全部身份档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 按 `items(profiles:name:email:signingKey:)` 的顺序列出各项。
    var body: some View {
        let items = Self.items(
            profiles: UserProfiles.decode(storage),
            name: name,
            email: email,
            signingKey: signingKey
        )

        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            view(for: item)
        }
    }

    /// 菜单的各项：档案在前；当前身份没有对应档案时列出它，并在分隔线后提供存为档案；前面有项目时才有分隔线，最后是管理档案。
    ///
    /// 姓名、邮箱与签名密钥都相同的档案才对应当前身份；签名密钥转成小写后比较，两边都没有密钥也算相同。
    ///
    /// - Parameters:
    ///   - profiles: 全部身份档案。
    ///   - name: 当前身份的姓名。
    ///   - email: 当前身份的邮箱。
    ///   - signingKey: 当前身份的签名密钥。
    static func items(profiles: [UserProfile], name: String, email: String, signingKey: String?) -> [Item] {
        let current = profiles.first {
            $0.name == name
                && $0.email == email
                && ($0.signingKey ?? "").lowercased() == (signingKey ?? "").lowercased()
        }

        let listsIdentity = current == nil && !name.isEmpty

        var items = profiles.map { Item.profile($0, isCurrent: $0 == current) }

        if listsIdentity {
            items.append(.identity)
        }

        if !items.isEmpty {
            items.append(.separator)
        }

        if listsIdentity {
            items.append(.addCurrent)
        }

        return items + [.manage]
    }

    /// 一项的文字：`姓名 <邮箱> (签名密钥简述)`；没有签名密钥写 No Signing Key，本机认不出的写 Unknown signing key。
    ///
    /// - Parameters:
    ///   - name: 姓名。
    ///   - email: 邮箱。
    ///   - signingKey: 签名密钥。
    ///   - keys: 本机可用的签名密钥。
    static func title(name: String, email: String, signingKey: String?, keys: [SigningKey]) -> String {
        let description = signingKey.map { value in
            keys.first { $0.matches(value) }.map(UserProfiles.shortTitle) ?? AppLocalization.text("signing.unknown")
        }

        return "\(name) <\(email)> (\(description ?? AppLocalization.text("signing.none")))"
    }
}

// MARK: - Private

extension IdentityProfileMenu {
    /// 一项对应的菜单项。
    @ViewBuilder
    private func view(for item: Item) -> some View {
        switch item {
        case .profile(let profile, let isCurrent):
            let title = Self.title(
                name: profile.name,
                email: profile.email,
                signingKey: profile.signingKey,
                keys: keys
            )

            Toggle(title, isOn: Binding(get: { isCurrent }, set: { _ in apply(profile) }))
                .disabled(!canApply || isCurrent)
                .help(
                    profile.signingKey.map { AppLocalization.text("signing.key", $0, SigningFormat(key: $0).displayName) }
                        ?? AppLocalization.text("signing.none")
                )

        case .identity:
            Toggle(Self.title(name: name, email: email, signingKey: signingKey, keys: keys), isOn: .constant(true))
                .disabled(true)

        case .separator:
            Divider()

        case .addCurrent:
            Button(AppLocalization.text("profiles.addCurrent", email)) {
                guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }

                UserProfiles.add(name: name, email: email, signingKey: signingKey, in: window)
            }

        case .manage:
            Button(AppLocalization.text("profiles.manage")) { SettingsWindowController.show(.userProfiles) }
        }
    }
}
