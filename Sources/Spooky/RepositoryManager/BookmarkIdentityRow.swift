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

    /// 本机可用的签名密钥，供身份菜单写出签名密钥的简述。
    @State
    private var keys: [SigningKey] = []

    /// 设置表格样式的提交人一行；不能编辑详情时头像菜单禁用。
    var body: some View {
        IdentitySettingRow(
            identity: summary.committer,
            isMenuEnabled: manager.canEditDetail,
            actions: actions
        ) {
            IdentityProfileMenu(
                name: summary.committer?.name ?? "",
                email: summary.committer?.email ?? "",
                signingKey: summary.signingKey,
                keys: keys,
                canApply: manager.canEditDetail,
                apply: manager.applyProfile
            )
        }
        .task { keys = await SigningKeys.local() }
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
}
