import AppKit
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

    /// 把当前提交人身份存成新档案：只询问标题，姓名、邮箱与签名密钥取自仓库。
    @MainActor
    static func add(name: String, email: String, signingKey: String?, in window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = AppLocalization.text("profiles.add")
        alert.informativeText = name + " <" + email + ">"
        alert.addButton(withTitle: AppLocalization.text("profiles.save"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        let field = NSTextField(string: AppLocalization.text("profiles.newProfile"))
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.setAccessibilityLabel(AppLocalization.text("profiles.title"))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.beginSheetModal(for: window.attachedSheet ?? window) { response in
            let title = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !title.isEmpty else { return }

            // 只追加新档案，已有档案原样保留。
            let defaults = UserDefaults.standard
            let profiles = decode(defaults.data(forKey: key) ?? Data())
                + [UserProfile(title: title, name: name, email: email, signingKey: signingKey)]
            defaults.set(encode(profiles), forKey: key)
        }
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
            UserProfileEditor(profile: profile) { save($0) }
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
                storage = UserProfiles.encode(profiles.filter { $0.id != selection })
                selection = nil
            } label: {
                Image(systemName: "minus").frame(width: 24, height: 20)
            }
            .disabled(selection == nil)
            .accessibilityLabel(AppLocalization.text("profiles.remove"))

            Spacer(minLength: 0)
        }
        .buttonStyle(.borderless)
    }

    /// 所选档案：首字母头像、粗体标题、分隔线下的身份与签名密钥，右下角为编辑按钮；没有选中时只留空白边框。
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
                    detailRow("profiles.signingKey", value: key)
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

/// 编辑档案的对话框：标题、姓名、邮箱与签名密钥；签名密钥留空表示档案不带密钥。
private struct UserProfileEditor: View {
    /// 编辑中的副本。
    @State
    var profile: UserProfile

    /// 保存回调。
    let onSave: (UserProfile) -> Void

    /// 关闭 sheet。
    @Environment(\.dismiss)
    private var dismiss

    /// 标签右对齐的四行表单，底部取消与保存。
    var body: some View {
        VStack(alignment: .trailing, spacing: 20) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 8) {
                field("profiles.title", text: $profile.title)
                field("profiles.userName", text: $profile.name)
                field("profiles.email", text: $profile.email)
                field("profiles.signingKey", text: Binding(
                    get: { profile.signingKey ?? "" },
                    set: { profile.signingKey = $0.isEmpty ? nil : $0 }
                ), placeholder: "signing.none")
            }

            HStack {
                Button(AppLocalization.text("action.cancel"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AppLocalization.text("profiles.save")) {
                    onSave(profile)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    [profile.title, profile.name, profile.email]
                        .contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
                )
            }
        }
        .padding(20)
        .frame(width: 448)
    }

    /// 一行标签与 328 pt 输入框。
    private func field(_ label: String, text: Binding<String>, placeholder: String? = nil) -> some View {
        GridRow {
            Text(AppLocalization.text(label))
                .gridColumnAlignment(.trailing)
            TextField(placeholder.map { AppLocalization.text($0) } ?? "", text: text)
                .frame(width: 328)
                .accessibilityLabel(AppLocalization.text(label))
        }
    }
}

// MARK: - SettingsWindowController

extension SettingsWindowController {
    /// 打开设置窗口并切到 User Profiles 页，供身份菜单的 “Manage User Profiles…” 使用。
    static func showUserProfiles() {
        (NSApp.delegate as? SpookyApplicationController)?.showSettings()

        let tabs = NSApp.windows
            .first { $0.windowController is SettingsWindowController }?
            .contentViewController as? NSTabViewController
        let label = AppLocalization.text("settings.profiles")

        if let index = tabs?.tabViewItems.firstIndex(where: { $0.label == label }) {
            tabs?.selectedTabViewItemIndex = index
        }
    }
}
