import SpookyKit
import SwiftUI

// MARK: - BookmarkIdentityRow

/// 详情区的提交人一行：标签、带身份档案菜单的头像、姓名与邮箱，以及悬停或获得键盘焦点时出现的 Edit、Unset。
///
/// Unset 只在仓库本地配置写了身份时出现；VoiceOver 把整行读作一个元素，操作经辅助功能动作执行。
struct BookmarkIdentityRow: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 读到的仓库概况。
    let summary: RepositorySummary

    /// 全部身份档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

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

            Menu {
                profileItems
            } label: {
                InitialsAvatar(name: name, email: summary.committer?.email, size: 40)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!manager.canEditDetail)
            .accessibilityLabel(AppLocalization.text("profiles.menu"))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                Text(summary.committer?.email ?? "")
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
        .accessibilityValue(name + " " + (summary.committer?.email ?? ""))
        .accessibilityActions {
            ForEach(actions.filter(\.isEnabled)) { action in
                Button(action.title, action: action.perform)
            }
        }
    }
}

// MARK: - Private

extension BookmarkIdentityRow {
    /// 提交人的姓名；身份无法确定时写明未设置。
    private var name: String {
        summary.committer?.name ?? AppLocalization.text("bookmarks.detail.noIdentity")
    }

    /// Edit 总在；仓库本地写了身份时另有 Unset。
    private var actions: [RemoteSettingAction] {
        let edit = RemoteSettingAction(
            title: AppLocalization.text("bookmarks.detail.edit"),
            isEnabled: manager.canEditDetail,
            perform: manager.editIdentity
        )

        guard summary.hasRepositoryIdentity else {
            return [edit]
        }

        let unset = RemoteSettingAction(
            title: AppLocalization.text("bookmarks.detail.unset"),
            isEnabled: manager.canEditDetail,
            perform: manager.clearIdentity
        )
        return [edit, unset]
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

    /// 档案逐项列出并勾选与当前提交人一致的那个，最后是管理档案的入口。
    @ViewBuilder
    private var profileItems: some View {
        let profiles = UserProfiles.decode(storage)

        ForEach(profiles) { profile in
            Toggle(
                profile.menuTitle,
                isOn: Binding(
                    get: { isCurrent(profile) },
                    set: { _ in manager.applyProfile(profile) }
                )
            )
            .disabled(isCurrent(profile))
        }

        if !profiles.isEmpty {
            Divider()
        }

        Button(AppLocalization.text("profiles.manage")) { SettingsWindowController.show(.userProfiles) }
    }

    /// 档案的姓名与邮箱是否就是当前提交人。
    private func isCurrent(_ profile: UserProfile) -> Bool {
        profile.name == summary.committer?.name && profile.email == summary.committer?.email
    }
}
