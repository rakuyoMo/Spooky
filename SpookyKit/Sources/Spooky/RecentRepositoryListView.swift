import AppKit
import SpookyKit
import SwiftUI

/// 仓库管理的最近记录列表；双击、回车和右键共用同一个打开动作。
struct RecentRepositoryListView: View {
    /// 当前窗口状态。
    @Bindable
    var session: RepositorySession

    /// 跨窗口共享的最近记录。
    let recent: RecentRepositories

    /// 普通打开或显式在新窗口打开。
    let open: (RepositoryLocation, Bool) -> Void

    /// 系统目录选择器入口。
    let choose: () -> Void

    /// 添加服务器仓库的表单入口。
    let addRemote: () -> Void

    /// 在选定终端打开当前记录。
    let openTerminal: (RepositoryLocation) -> Void

    /// 从 Finder 拖入目录后添加记录。
    let addFolders: ([URL]) -> Void

    /// source list 布局与底部添加入口。
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $session.selectedRecentLocation) {
                Section(AppLocalization.text("repositories.recent")) {
                    ForEach(recent.locations, id: \.self) { path in
                        recordRow(path)
                    }
                }
            }
            .listStyle(.sidebar)
            .onKeyPress(.return) {
                guard let path = session.selectedRecentLocation else {
                    return .ignored
                }

                open(path, false)
                return .handled
            }

            Divider()

            bottomBar
        }
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
        }
    }

    /// 底部添加入口：打开本机仓库或添加服务器仓库。
    private var bottomBar: some View {
        HStack {
            Menu {
                Button(AppLocalization.text("action.openLocal"), action: choose)
                Button(AppLocalization.text("action.addRemote"), action: addRemote)
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(AppLocalization.text("action.openLocal"))
            .accessibilityLabel(AppLocalization.text("action.openLocal"))

            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    /// 一条最近记录：位置图标、名称与校验状态，双击打开，右键提供其它入口。
    private func recordRow(_ path: RepositoryLocation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: path.host == nil ? "folder" : "server.rack")
                .accessibilityHidden(true)

            Text(path.name)
                .lineLimit(1)

            Spacer(minLength: 4)

            // 校验中与失效都配有文字，不只依靠图标或颜色区分。
            if recent.checking.contains(path) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                Text(AppLocalization.text("repositories.checking"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if recent.unavailable.contains(path) {
                Image(systemName: "exclamationmark.triangle")
                    .accessibilityHidden(true)
                Text(AppLocalization.text("repositories.unavailableShort"))
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(recent.unavailable.contains(path) ? .secondary : .primary)
        .tag(path)
        .help(path.displayPath)
        .onTapGesture(count: 2) { open(path, false) }
        .contextMenu { recordMenu(path) }
    }

    /// 最近记录的右键菜单：打开、新窗口打开、终端、Finder 与复制路径。
    @ViewBuilder
    private func recordMenu(_ path: RepositoryLocation) -> some View {
        Button(AppLocalization.text("action.open")) { open(path, false) }
        Button(AppLocalization.text("action.openNewWindow")) { open(path, true) }
        Divider()
        Button(AppLocalization.text("action.openTerminal")) { openTerminal(path) }

        Button(AppLocalization.text("action.revealFinder")) {
            if let url = path.localURL {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .disabled(path.localURL == nil)

        Button(AppLocalization.text("action.copyPath")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path.displayPath, forType: .string)
        }
    }
}
