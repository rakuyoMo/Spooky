import SpookyKit
import SwiftUI

// MARK: - BookmarkIdentityRow

/// 详情区的提交人一行：带身份档案菜单的头像、姓名与邮箱，以及悬停或获得键盘焦点时出现的 Edit、Unset。
///
/// Unset 只在仓库本地配置写了身份时出现。
struct BookmarkIdentityRow: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 读到的仓库概况。
    let summary: RepositorySummary

    /// 全部身份档案的 JSON。
    @AppStorage(UserProfiles.key)
    private var storage = Data()

    /// 设置表格样式的提交人一行；不能编辑详情时头像菜单禁用。
    var body: some View {
        IdentitySettingRow(
            identity: summary.committer,
            isMenuEnabled: manager.canEditDetail,
            actions: actions
        ) {
            profileItems
        }
    }
}

// MARK: - Private

extension BookmarkIdentityRow {
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
