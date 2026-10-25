import AppKit
import SpookyKit
import SwiftUI

// MARK: - UserProfile

/// 一组可以套用到仓库的提交人身份，保存在本机偏好里，本机与服务器仓库共用。
struct UserProfile: Codable, Identifiable, Equatable {
    /// 档案的稳定标识。
    var id = UUID()

    /// 列表与菜单中显示的档案标题。
    var title: String

    /// 写入 `user.name` 的姓名。
    var name: String

    /// 写入 `user.email` 的邮箱。
    var email: String

    /// 写入 `user.signingkey` 的签名密钥；为 nil 时套用档案不改动签名配置。
    var signingKey: String?

    /// 身份菜单里的一项：姓名、尖括号里的邮箱与圆括号里的档案标题。
    var menuTitle: String {
        "\(name) <\(email)> (\(title))"
    }
}

// MARK: - UserProfiles

/// 身份档案的存取；设置页与提交区的身份菜单读写同一偏好键。
enum UserProfiles {
    /// 偏好键，值为档案数组的 JSON。
    static let key = "userProfiles"

    /// 解码偏好中的档案；内容损坏时视为没有档案。
    static func decode(_ data: Data) -> [UserProfile] {
        (try? JSONDecoder().decode([UserProfile].self, from: data)) ?? []
    }

    /// 编码后写回偏好。
    static func encode(_ profiles: [UserProfile]) -> Data {
        (try? JSONEncoder().encode(profiles)) ?? Data()
    }

    /// 签名密钥的简短写法：字面 SSH 公钥换成指纹，OpenPGP 指纹取末 16 位，其它写法原样显示。
    ///
    /// - Parameter value: `user.signingkey` 的值。
    static func keyDescription(_ value: String) -> String {
        if let fingerprint = SigningKeys.fingerprint(ofLiteral: value) {
            return fingerprint
        }

        guard value.count > 16, value.allSatisfy(\.isHexDigit) else {
            return value
        }

        return value.suffix(16).uppercased()
    }

    /// 签名密钥菜单里一把密钥的名称：OpenPGP 是签名人与短指纹，SSH 是注释与指纹。
    ///
    /// SSH 的注释是现有文件的路径时把家目录缩写成 `~`，没有注释时用密钥类型。
    static func title(of key: SigningKey) -> String {
        #warning(
            "TODO: 签名密钥菜单项的写法是推断：OpenPGP 为 “签名人 (指纹末 16 位)”，SSH 为 “注释 (SHA256 指纹)”。核实方式：在编辑档案的对话框里打开签名密钥菜单，对照 GPG 与 SSH 密钥各一项的文字；只影响菜单项文字。"
        )

        guard key.format == .ssh else {
            return (key.signer.map { $0 + " " } ?? "") + "(" + keyDescription(key.value) + ")"
        }

        let type = key.value.dropFirst("key::".count).split(separator: " ").first.map(String.init) ?? ""
        let comment = key.comment ?? ""
        let home = FileManager.default.homeDirectoryForCurrentUser.path + "/"
        let name = FileManager.default.fileExists(atPath: comment) && comment.hasPrefix(home)
            ? "~/" + comment.dropFirst(home.count)
            : comment

        return (name.isEmpty ? type : name) + " (" + key.fingerprint + ")"
    }
}

// MARK: - UserProfilesSettingsView

/// User Profiles 设置页：左侧档案列表与增删按钮，右侧所选档案的详情与编辑入口。
struct UserProfilesSettingsView: View {
    /// 全部档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 列表中选中的档案。
    @State
    private var selection: UserProfile.ID?

    /// 正在编辑的档案；新建时是尚未加入列表的空档案。
    @State
    private var editing: UserProfile?

    /// 本机可用的签名密钥，供详情显示签名人与编辑时选择。
    @State
    private var keys: [SigningKey] = []

    /// 等待确认删除的档案。
    @State
    private var deleting: UserProfile?

    /// 250 pt 列表、8 pt 间距与带边框的详情，底部是说明文字。
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                profileList
                    .frame(width: 250)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppPalette.color("general_border_color")))
            }

            Text(AppLocalization.text("profiles.help"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 900, height: 381)
        .sheet(item: $editing) { profile in
            UserProfileEditor(
                profile: profile,
                isNew: !profiles.contains { $0.id == profile.id },
                otherTitles: Set(profiles.filter { $0.id != profile.id }.map(\.title)),
                keys: keys
            ) { save($0) }
        }
        .alert(
            AppLocalization.text("profiles.delete.title"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { profile in
            Button(AppLocalization.text("profiles.delete.submit"), role: .destructive) { delete(profile) }
            Button(AppLocalization.text("action.cancel"), role: .cancel) { deleting = nil }
        } message: { profile in
            Text(AppLocalization.text("profiles.delete.message", profile.title))
        }
        .task(id: editing == nil) {
            // 打开页面与每次打开、关闭编辑框时重新列出密钥，agent 里的密钥可能随时增减。
            keys = await SigningKeys.local()
        }
    }
}

// MARK: - Private

extension UserProfilesSettingsView {
    /// 解码后的档案。
    private var profiles: [UserProfile] { UserProfiles.decode(storage) }

    /// 单列表格与贴在底部的 + / − 操作条。
    private var profileList: some View {
        VStack(spacing: 0) {
            Table(profiles, selection: $selection) {
                TableColumn(AppLocalization.text("settings.profiles")) { profile in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.title)
                        Text(profile.name + " <" + profile.email + ">")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
            }
            .alternatingRowBackgrounds(.disabled)
            .accessibilityIdentifier("user-profiles")

            Divider()
            listActions
        }
        .overlay(Rectangle().stroke(AppPalette.color("general_border_color")))
    }

    /// 列表底部 20 pt 的 + / − 操作条；没有选中档案时 − 不可用。
    private var listActions: some View {
        HStack(spacing: 0) {
            Button {
                editing = UserProfile(title: AppLocalization.text("profiles.newProfile"), name: "", email: "")
            } label: {
                Image(systemName: "plus").frame(width: 24, height: 20)
            }
            .accessibilityLabel(AppLocalization.text("profiles.add"))

            Button {
                deleting = profiles.first { $0.id == selection }
            } label: {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(selection == nil)
            .accessibilityLabel(AppLocalization.text("profiles.remove"))

            Spacer(minLength: 0)
        }
        .buttonStyle(.borderless)
    }

    /// 所选档案：首字母头像、粗体标题、分隔线下的身份、签名密钥与签名人，右下角为编辑按钮；没有选中时只留空白边框。
    private var detail: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            if let profile = profiles.first(where: { $0.id == selection }) {
                profileDetail(profile)
            }
        }
    }

    /// 一个档案的详情。
    private func profileDetail(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                InitialsAvatar(name: profile.name, size: 48)
                Text(profile.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .help(profile.title)
            }

            Divider()

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
                detailRow("profiles.userName", value: profile.name)
                detailRow("profiles.email", value: profile.email)

                if let key = profile.signingKey {
                    detailRow("profiles.signingKey", value: UserProfiles.keyDescription(key))
                }

                // 签名人是本机钥匙环里这把 OpenPGP 密钥的用户标识；SSH 密钥与本机找不到的密钥没有这一行。
                if
                    let key = profile.signingKey,
                    let signer = keys.first(where: { $0.format == .openpgp && $0.matches(key) })?.signer
                {
                    detailRow("profiles.signer", value: signer)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                Button(AppLocalization.text("profiles.edit")) { editing = profile }
            }
        }
        .padding(20)
    }

    /// 次级文字色的标签与可选中的值。
    private func detailRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(AppLocalization.text(label))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }

    /// 已有档案原位替换，新档案追加到末尾并选中。
    /// 确认后删除档案；删除只改档案列表，不动任何 Git 配置。
    private func delete(_ profile: UserProfile) {
        storage = UserProfiles.encode(profiles.filter { $0.id != profile.id })
        deleting = nil

        if selection == profile.id {
            selection = nil
        }
    }

    /// 新建的档案追加到列表末尾，已有的档案原位更新，并选中它。
    private func save(_ profile: UserProfile) {
        var current = profiles

        if let index = current.firstIndex(where: { $0.id == profile.id }) {
            current[index] = profile
        } else {
            current.append(profile)
        }

        storage = UserProfiles.encode(current)
        selection = profile.id
    }
}

// MARK: - UserProfileEditor

/// 新建或更新档案的对话框：标题、姓名、邮箱与签名密钥；签名密钥从本机的密钥里选，或不带密钥。
///
/// 标题、姓名与邮箱都不能为空，标题不能与其它档案重名。
private struct UserProfileEditor: View {
    /// 编辑中的副本。
    @State
    private var profile: UserProfile

    /// 新建档案；否则是更新已有的档案。
    let isNew: Bool

    /// 其它档案的标题，用来检查重名。
    let otherTitles: Set<String>

    /// 本机可用的签名密钥。
    let keys: [SigningKey]

    /// 保存回调。
    let onSave: (UserProfile) -> Void

    /// 打开时档案里的签名密钥；本机找不到它时仍作为一项留在菜单里。
    private let configuredKey: String?

    /// 关闭 sheet。
    @Environment(\.dismiss)
    private var dismiss

    /// 对话框骨架里放标签右对齐的四行表单。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text(isNew ? "profiles.create.title" : "profiles.update.title"),
            message: AppLocalization.text(isNew ? "profiles.create.message" : "profiles.update.message"),
            submitTitle: AppLocalization.text(isNew ? "profiles.create.submit" : "profiles.update.submit"),
            error: titleExists ? AppLocalization.text("profiles.titleExists") : nil,
            canSubmit: !titleExists
                && ![profile.title, profile.name, profile.email]
                .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty },
            cancel: { dismiss() },
            submit: {
                var saved = profile
                saved.title = profile.title.trimmingCharacters(in: .whitespaces)
                saved.signingKey = selectedKey.wrappedValue
                onSave(saved)
                dismiss()
            }
        ) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
                field("profiles.title", text: $profile.title)
                field("profiles.userName", text: $profile.name)
                field("profiles.email", text: $profile.email)
                signingKeyRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    /// 以档案的副本创建编辑框。
    init(
        profile: UserProfile,
        isNew: Bool,
        otherTitles: Set<String>,
        keys: [SigningKey],
        onSave: @escaping (UserProfile) -> Void
    ) {
        _profile = State(initialValue: profile)
        self.isNew = isNew
        self.otherTitles = otherTitles
        self.keys = keys
        self.onSave = onSave
        configuredKey = profile.signingKey
    }
}

// MARK: - UserProfileEditor Private

extension UserProfileEditor {
    /// 去掉首尾空格后的标题与其它档案重名。
    private var titleExists: Bool {
        otherTitles.contains(profile.title.trimmingCharacters(in: .whitespaces))
    }

    /// 本机找不到的已配置密钥，菜单里显示为不可选的一项。
    private var unknownKey: String? {
        configuredKey.flatMap { value in keys.contains { $0.matches(value) } ? nil : value }
    }

    /// 菜单的选中项：档案的密钥能对上本机的某把密钥时选中那一把，保存时写入它的完整写法。
    private var selectedKey: Binding<String?> {
        Binding(
            get: { profile.signingKey.map { value in keys.first { $0.matches(value) }?.value ?? value } },
            set: { profile.signingKey = $0 }
        )
    }

    /// 签名密钥的弹出菜单：本机的 OpenPGP 与 SSH 密钥，找不到的已配置密钥，最后是不带密钥；本机没有密钥时整行不可用。
    private var signingKeyRow: some View {
        GridRow {
            Text(AppLocalization.text("profiles.signingKey"))
                .foregroundStyle(keys.isEmpty ? Color(nsColor: .disabledControlTextColor) : Color.primary)
                .fixedSize()
                .gridColumnAlignment(.trailing)

            Picker(AppLocalization.text("profiles.signingKey"), selection: selectedKey) {
                ForEach(keys, id: \.value) { key in
                    Text(UserProfiles.title(of: key))
                        .tag(Optional(key.value))
                }

                if let unknownKey {
                    Text(UserProfiles.keyDescription(unknownKey))
                        .tag(Optional(unknownKey))
                        .disabled(true)
                }

                Text(AppLocalization.text("signing.none"))
                    .tag(String?.none)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(keys.isEmpty)
            .accessibilityLabel(AppLocalization.text("profiles.signingKey"))
        }
    }

    /// 一行不折行的标签与占满余下宽度的输入框；标签列按最长的标签加宽。
    private func field(_ label: String, text: Binding<String>) -> some View {
        GridRow {
            Text(AppLocalization.text(label))
                .fixedSize()
                .gridColumnAlignment(.trailing)

            TextField("", text: text)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(AppLocalization.text(label))
        }
    }
}
