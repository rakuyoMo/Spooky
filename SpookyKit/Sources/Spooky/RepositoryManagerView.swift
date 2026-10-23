import AppKit
import SpookyKit
import SwiftUI

/// 仓库管理右侧显示所选路径，未选时给出打开与拖放入口。
struct RepositoryManagerView: View {
    /// 当前窗口状态。
    let session: RepositorySession

    /// 最近记录的可用状态。
    let recent: RecentRepositories

    /// 系统目录选择器入口。
    let choose: () -> Void

    /// 打开所选记录。
    let open: (RepositoryLocation, Bool) -> Void

    /// 服务器仓库的独立表单入口。
    let addRemote: () -> Void

    /// 将拖入的目录验证后加入仓库管理。
    let addFolders: ([URL]) -> Void

    /// 拖放悬停状态。
    @State
    private var isDropTarget = false

    /// 路径详情或居中的空状态。
    var body: some View {
        VStack(spacing: 20) {
            if let path = session.selectedRecentLocation, recent.locations.contains(path) {
                recordDetails(path)
            } else {
                openEntries
            }

            if session.isOpening {
                ProgressView(AppLocalization.text("loading.open"))
                    .controlSize(.small)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.color("general_background_color"))
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter {
                $0.isFileURL
                    && ((try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
            }

            guard !folders.isEmpty else {
                return false
            }

            addFolders(folders)
            return true
        } isTargeted: {
            isDropTarget = $0
        }
    }

    /// 未选记录时的拖放区域，以及打开本机仓库与添加服务器仓库的按钮。
    @ViewBuilder
    private var openEntries: some View {
        EmptyStateView(
            title: AppLocalization.text("repositories.empty.title"),
            message: AppLocalization.text("repositories.empty.message"),
            symbol: "folder.badge.plus"
        )
        .frame(maxWidth: 368)
        .padding(20)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTarget ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
        }

        HStack(spacing: 8) {
            Button(AppLocalization.text("action.openLocal"), action: choose)
                .accessibilityIdentifier("open-local-repository")
            Button(AppLocalization.text("action.addRemote"), action: addRemote)
                .accessibilityIdentifier("add-remote-repository")
        }
    }

    /// 所选记录的名称、路径、可用状态与打开按钮。
    @ViewBuilder
    private func recordDetails(_ path: RepositoryLocation) -> some View {
        Image(systemName: "folder")
            .font(.system(size: 52))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

        Text(path.name)
            .font(.system(size: 18))

        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("repositories.path"))
                .foregroundStyle(.secondary)

            Text(path.displayPath)
                .textSelection(.enabled)
                .font(.system(size: 13))
        }

        if recent.unavailable.contains(path) {
            Label(
                AppLocalization.text("repositories.unavailable"),
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 8) {
            Button(AppLocalization.text("action.open")) { open(path, false) }
            Button(AppLocalization.text("action.openNewWindow")) { open(path, true) }
        }
    }
}
