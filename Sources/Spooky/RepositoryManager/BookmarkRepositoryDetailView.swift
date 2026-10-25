import SpookyKit
import SwiftUI

// MARK: - BookmarkRepositoryDetailView

/// 选中一个仓库时的详情：头部是图标与名称，下面是设置表格风格的位置、当前分支、最后提交、最近打开、提交人、描述与远端。
///
/// 位置与最近打开时间来自书签，其余在选中后读取；服务器仓库经它自己的主连接读取。
struct BookmarkRepositoryDetailView: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 选中的仓库书签。
    let bookmark: Bookmark

    /// 提交日期的写法，与历史共用。
    @AppStorage(CommitDateFormat.key)
    private var dateFormat = CommitDateFormat.absolute

    /// 头部固定 52 pt，表格可滚动。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    rows
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Layout

extension BookmarkRepositoryDetailView {
    /// 32 pt 图标与次级色的仓库名。
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: bookmark.symbolName)
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(bookmark.displayName)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// 按读取状态排出各行；读到之前只有书签自己的位置与最近打开时间。
    @ViewBuilder
    private var rows: some View {
        if case .missing = manager.detailState {
            warningRow(AppLocalization.text("bookmarks.detail.missing"))
        }

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.location"),
            value: bookmark.location?.displayPath ?? ""
        )

        switch manager.detailState {
        case .loaded(let summary):
            summaryRows(summary)

        case .failed(let failure):
            lastOpenedRow

            FailureDetailsView(failure: failure, retry: manager.reloadDetail)
                .padding(20)

        case .missing:
            lastOpenedRow

        case .loading, nil:
            lastOpenedRow

            RemoteSettingRow(label: AppLocalization.text("bookmarks.detail.loading"), value: "")
        }
    }

    /// 最近一次在窗口中打开的时间；没打开过的写明。
    private var lastOpenedRow: some View {
        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.lastOpened"),
            value: bookmark.lastOpened.map { dateFormat.string(from: $0) }
                ?? AppLocalization.text("bookmarks.detail.neverOpened")
        )
    }

    /// 读到的概况：当前分支、最后提交、最近打开、提交人、描述与远端。
    @ViewBuilder
    private func summaryRows(_ summary: RepositorySummary) -> some View {
        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.branch"),
            value: summary.branch ?? AppLocalization.text("branch.detachedShort")
        )

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.lastCommit"),
            value: summary.lastCommit?.subject ?? AppLocalization.text("bookmarks.detail.noCommits")
        )

        if let commit = summary.lastCommit {
            RemoteSettingRow(label: "", value: dateFormat.string(from: commit.date), secondary: true)
        }

        lastOpenedRow

        BookmarkIdentityRow(manager: manager, summary: summary)

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.description"),
            value: summary.description?.trimmingCharacters(in: .newlines) ?? "",
            actions: [
                RemoteSettingAction(
                    title: AppLocalization.text("bookmarks.detail.edit"),
                    isEnabled: manager.canEditDetail,
                    perform: manager.editDescription
                ),
            ]
        )

        remoteRows(summary.remotes)
    }

    /// 远端分组：每个远端的获取地址与在浏览器中打开的按钮；地址换算不出网页时按钮禁用。
    @ViewBuilder
    private func remoteRows(_ remotes: [RemoteConfiguration]) -> some View {
        RemoteSettingsGroup(title: AppLocalization.text("bookmarks.detail.remotes"))

        if remotes.isEmpty {
            RemoteSettingRow(label: AppLocalization.text("bookmarks.detail.noRemotes"), value: "")
        }

        ForEach(remotes) { remote in
            RemoteSettingRow(
                label: remote.name,
                value: remote.url ?? "",
                small: true,
                actions: [
                    RemoteSettingAction(
                        title: AppLocalization.text("bookmarks.detail.viewInBrowser"),
                        isEnabled: remote.webURL != nil
                    ) {
                        if let url = remote.webURL {
                            NSWorkspace.shared.open(url)
                        }
                    },
                ]
            )
        }
    }

    /// 铺警告底色、左缩进 20 pt 的提示行。
    private func warningRow(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(AppPalette.color("general_warning_bg_color"))
    }
}
