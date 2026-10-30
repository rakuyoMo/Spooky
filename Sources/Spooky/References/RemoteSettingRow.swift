import SpookyKit
import SwiftUI

// MARK: - RemoteSettingAction

/// 设置表格一行的一个操作按钮。
struct RemoteSettingAction: Identifiable {
    /// 按钮标题，也是操作的身份。
    let title: String

    /// 仓库不可写时禁用。
    let isEnabled: Bool

    /// 点按后的动作。
    let perform: () -> Void

    /// 一行里的标题各不相同。
    var id: String { title }
}

// MARK: - RemoteSettingRow

/// 设置表格的一行：240 pt 宽的次级色标签、可选中的值，以及悬停或获得键盘焦点时出现的操作按钮。
///
/// 按钮淡出时仍在原处，用 Tab 可以移到它们上面；VoiceOver 把整行读作一个元素，操作经辅助功能动作执行。
struct RemoteSettingRow: View {
    /// 左侧标签；空字符串表示延续上一行的标签。
    let label: String

    /// 值；地址、refspec 与哈希用 11 pt。
    let value: String

    /// 是否用 11 pt 显示值。
    var small = false

    /// 值是否用次级色，如沿用获取地址的推送地址。
    var secondary = false

    /// 行尾的操作按钮。
    var actions: [RemoteSettingAction] = []

    /// 鼠标是否在行内。
    @State
    private var isHovering = false

    /// 获得键盘焦点的操作按钮。
    @FocusState
    private var focusedAction: String?

    /// 标签、值与操作按钮横向排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 240, alignment: .leading)

            Text(value)
                .font(.system(size: small ? 11 : 13))
                .foregroundStyle(secondary ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(actions) { action in
                    Button(action.title, action: action.perform)
                        .controlSize(.small)
                        .disabled(!action.isEnabled)
                        .focused($focusedAction, equals: action.id)
                }
            }
            .opacity(isHovering || focusedAction != nil ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 30)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityActions {
            ForEach(actions.filter(\.isEnabled)) { action in
                Button(action.title, action: action.perform)
            }
        }
    }
}

// MARK: - IdentitySettingRow

/// 设置表格的提交人一行：标签、带身份档案菜单的 40 pt 头像、上下两行的姓名与邮箱，以及悬停或获得键盘焦点时出现的操作按钮。
///
/// 仓库管理的详情与仓库设置共用；VoiceOver 把整行读作一个元素，操作经辅助功能动作执行。
struct IdentitySettingRow<ProfileMenu: View>: View {
    /// 提交人；身份无法确定时为 nil，姓名一行写明未设置。
    let identity: RepositorySummary.Identity?

    /// 头像菜单是否可用。
    let isMenuEnabled: Bool

    /// 行尾的操作按钮。
    let actions: [RemoteSettingAction]

    /// 头像弹出的身份档案菜单。
    @ViewBuilder
    let menu: () -> ProfileMenu

    /// 鼠标是否在行内。
    @State
    private var isHovering = false

    /// 获得键盘焦点的操作按钮。
    @FocusState
    private var focusedAction: String?

    /// 标签、头像菜单、姓名与邮箱、操作按钮横向排列。
    var body: some View {
        HStack(spacing: 0) {
            Text(AppLocalization.text("bookmarks.detail.identity"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 240, alignment: .leading)

            Menu(content: menu) {
                InitialsAvatar(name: name, email: identity?.email, size: 40)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!isMenuEnabled)
            .accessibilityLabel(AppLocalization.text("profiles.menu"))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                Text(identity?.email ?? "")
            }
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.tail)
            .textSelection(.enabled)
            .padding(.leading, 6)

            Spacer(minLength: 8)

            actionButtons
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("bookmarks.detail.identity"))
        .accessibilityValue(name + " " + (identity?.email ?? ""))
        .accessibilityActions {
            ForEach(actions.filter(\.isEnabled)) { action in
                Button(action.title, action: action.perform)
            }
        }
    }
}

// MARK: - RemoteSettingsGroup

/// 设置表格的分组标题：大写的组名，以及悬停或获得键盘焦点时出现的操作按钮。
struct RemoteSettingsGroup: View {
    /// 组名，显示为大写。
    let title: String

    /// 分组的操作按钮。
    var actions: [RemoteSettingAction] = []

    /// 组名与操作按钮共用一行的样式。
    var body: some View {
        RemoteSettingRow(label: title.uppercased(), value: "", actions: actions)
            .fontWeight(.semibold)
            .padding(.top, 12)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - SettingWarningRow

/// 状态提示行：缩进 20 pt 的提示文字与可选的常显按钮，铺警告底色。
struct SettingWarningRow: View {
    /// 提示文字。
    let text: String

    /// 行尾的按钮；为 nil 时只有文字。
    var action: RemoteSettingAction?

    /// 文字与按钮横向排列。
    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let action {
                Button(action.title, action: action.perform)
                    .controlSize(.small)
                    .disabled(!action.isEnabled)
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 20)
        .padding(.vertical, 6)
        .frame(minHeight: 30)
        .background(AppPalette.color("general_warning_bg_color"))
    }
}

// MARK: - Private

extension IdentitySettingRow {
    /// 提交人的姓名；身份无法确定时写明未设置。
    private var name: String {
        identity?.name ?? AppLocalization.text("bookmarks.detail.noIdentity")
    }

    /// 悬停或获得焦点时淡入的按钮；淡出时仍在原处，Tab 可以移到它们上面。
    private var actionButtons: some View {
        HStack(spacing: 4) {
            ForEach(actions) { action in
                Button(action.title, action: action.perform)
                    .controlSize(.small)
                    .disabled(!action.isEnabled)
                    .focused($focusedAction, equals: action.id)
            }
        }
        .opacity(isHovering || focusedAction != nil ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}
