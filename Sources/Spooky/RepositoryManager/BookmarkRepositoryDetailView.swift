import SpookyKit
import SwiftUI

// MARK: - BookmarkRepositoryDetailView

/// 选中一个仓库时的详情：头部是图标与名称，下面的设置表格分 REPOSITORY、WORKING COPY 与 REMOTES 三组。
///
/// 位置与最近打开时间来自书签，其余在选中后读取；服务器仓库经它自己的主连接读取。
struct BookmarkRepositoryDetailView: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 选中的仓库书签。
    let bookmark: Bookmark

    /// 头部固定 52 pt，表格可滚动。
    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                SettingTable {
                    rows
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    /// 详情里的日期时间：今天写成 “Today at 2:57 PM”，其它日子写长日期加时间，如 “October 20, 2026 at 10:00 AM”。
    ///
    /// - Parameter date: 要写的时间。
    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = Calendar.current.isDateInToday(date)
        return formatter.string(from: date)
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

        RemoteSettingsGroup(title: AppLocalization.text("bookmarks.detail.repository"), actions: repositoryActions)

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.location"),
            location: bookmark.location,
            canReveal: !bookmark.isLocalDirectoryGone
        )

        lastOpenedRow

        switch manager.detailState {
        case .loaded(let summary, let changedFiles):
            summaryRows(summary, changedFiles: changedFiles)

        case .failed(let failure):
            FailureDetailsView(failure: failure, retry: manager.reloadDetail)
                .padding(20)

        case .missing:
            EmptyView()

        case .loading, nil:
            RemoteSettingRow(label: AppLocalization.text("bookmarks.detail.loading"), value: "")
        }
    }

    /// REPOSITORY 组的 Open 与 Delete。
    private var repositoryActions: [RemoteSettingAction] {
        [
            RemoteSettingAction(title: AppLocalization.text("action.open"), isEnabled: true) {
                manager.open(bookmark.id, inNewWindow: false)
            },
            RemoteSettingAction(title: AppLocalization.text("bookmarks.multiple.delete"), isEnabled: true) {
                manager.confirmDelete([bookmark.id])
            },
        ]
    }

    /// 最近一次在窗口中打开的时间；没打开过的写明。
    private var lastOpenedRow: some View {
        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.lastOpened"),
            value: bookmark.lastOpened.map(Self.dateText)
                ?? AppLocalization.text("bookmarks.detail.neverOpened")
        )
    }

    /// 读到的概况：最后提交的时间、描述与提交人，WORKING COPY 组的当前分支与改动数，以及远端。
    @ViewBuilder
    private func summaryRows(_ summary: RepositorySummary, changedFiles: Int) -> some View {
        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.lastCommit"),
            value: summary.lastCommit.map { Self.dateText($0.date) }
                ?? AppLocalization.text("bookmarks.detail.noCommits")
        )

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

        BookmarkIdentityRow(manager: manager, summary: summary)

        RemoteSettingsGroup(title: AppLocalization.text("workspace.title"))

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.branch"),
            value: summary.branch ?? AppLocalization.text("branch.detachedShort")
        )

        RemoteSettingRow(
            label: AppLocalization.text("bookmarks.detail.status"),
            value: changedFiles == 0
                ? AppLocalization.text("bookmarks.detail.noChanges")
                : ChangesetSummaryBar.fileCount(changedFiles)
        )

        remoteRows(summary.remotes)
    }

    /// 远端分组：每个远端的名字与获取地址，以及在浏览器中打开的按钮；地址换算不出网页时按钮禁用。
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
