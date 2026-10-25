import AppKit
import SpookyKit
import SwiftUI

// MARK: - GitIdentityRows

/// Git Config 页的身份组：全局姓名与邮箱，右侧是带身份档案菜单的头像，下方写明配置文件的位置与影响范围。
///
/// 输入框按回车或失去焦点时写入；清空即删除这个键。
struct GitIdentityRows: View {
    /// 全局配置的读写状态。
    let model: GlobalGitConfigModel

    /// 全部身份档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 姓名输入框里的内容。
    @State
    private var name = ""

    /// 邮箱输入框里的内容。
    @State
    private var email = ""

    /// 获得焦点的输入框对应的配置键。
    @FocusState
    private var focusedKey: String?

    /// 两行输入框共用 52 pt 的头像，头像盖住两行的高度；说明在控件列下方。
    var body: some View {
        GridRow {
            label("gitConfig.userName")

            field($name, key: GlobalGitConfiguration.Key.userName, label: "gitConfig.userName")
                .overlay(alignment: .topTrailing) {
                    avatar
                }
        }

        GridRow {
            label("gitConfig.email")

            field($email, key: GlobalGitConfiguration.Key.userEmail, label: "gitConfig.email")
        }

        GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])

            Text(AppLocalization.text("gitConfig.scope", HomePath.abbreviated(GlobalGitConfig.filePath())))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 278, alignment: .leading)
        }
        .onChange(of: model.configuration, initial: true) {
            name = model.configuration.userName ?? ""
            email = model.configuration.userEmail ?? ""
        }
    }
}

// MARK: - Private

extension GitIdentityRows {
    /// 头像的边长，正好是两行输入框加行距的高度。
    private static let avatarSize = 52.0

    /// 解码后的档案。
    private var profiles: [UserProfile] { UserProfiles.decode(storage) }

    /// 与全局身份相同的档案。
    private var current: UserProfile? {
        profiles.first { $0.name == model.configuration.userName && $0.email == model.configuration.userEmail }
    }

    /// 头像按钮：点开是身份档案菜单。
    private var avatar: some View {
        Menu {
            profileMenu
        } label: {
            InitialsAvatar(
                name: model.configuration.userName ?? "",
                email: model.configuration.userEmail,
                size: Self.avatarSize
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(AppLocalization.text("profiles.menu"))
    }

    /// 档案逐项列出并勾选与全局身份相同的一项；全局身份没有对应档案时可以存成档案，最后是档案管理入口。
    @ViewBuilder
    private var profileMenu: some View {
        ForEach(profiles) { profile in
            Toggle(
                profile.name + " <" + profile.email + "> (" + profile.title + ")",
                isOn: Binding(get: { profile == current }, set: { _ in apply(profile) })
            )
            .disabled(profile == current)
        }

        if !profiles.isEmpty {
            Divider()
        }

        if current == nil, let userName = model.configuration.userName {
            Button(AppLocalization.text("profiles.addCurrent", model.configuration.userEmail ?? "")) {
                guard let window = NSApp.keyWindow else { return }

                UserProfiles.add(
                    name: userName,
                    email: model.configuration.userEmail ?? "",
                    signingKey: model.configuration.signingKey,
                    in: window
                )
            }
        }

        Button(AppLocalization.text("profiles.manage")) { SettingsWindowController.show(.userProfiles) }
    }

    /// 右对齐的标签。
    private func label(_ key: String) -> some View {
        Text(AppLocalization.text(key))
            .gridColumnAlignment(.trailing)
    }

    /// 让出头像位置的输入框；回车或失去焦点时写入有变化的值。
    private func field(_ text: Binding<String>, key: String, label: String) -> some View {
        TextField("", text: text)
            .focused($focusedKey, equals: key)
            .frame(width: 278 - 8 - Self.avatarSize)
            .frame(width: 278, alignment: .leading)
            .accessibilityLabel(AppLocalization.text(label))
            .onSubmit { save(text.wrappedValue, for: key) }
            .onChange(of: focusedKey == key) { _, focused in
                if !focused {
                    save(text.wrappedValue, for: key)
                }
            }
    }

    /// 档案的姓名与邮箱写进全局配置；档案带签名密钥时同时写入密钥与对应的签名格式。
    private func apply(_ profile: UserProfile) {
        let signing = profile.signingKey.map {
            [
                (key: GlobalGitConfiguration.Key.signingKey, value: Optional($0)),
                (key: GlobalGitConfiguration.Key.signingFormat, value: Optional(SigningFormat(key: $0).rawValue)),
            ]
        }

        let entries: [(key: String, value: String?)] = [
            (GlobalGitConfiguration.Key.userName, profile.name),
            (GlobalGitConfiguration.Key.userEmail, profile.email),
        ]

        Task { await model.write(entries + (signing ?? [])) }
    }

    /// 去掉首尾空白后与已有值不同时写入；空值删除这个键。
    private func save(_ text: String, for key: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = key == GlobalGitConfiguration.Key.userName
            ? model.configuration.userName
            : model.configuration.userEmail

        guard model.isLoaded, value != (current ?? "") else {
            return
        }

        Task { await model.write([(key, value.isEmpty ? nil : value)]) }
    }
}
