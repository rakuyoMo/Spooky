import AppKit
import SpookyKit
import SwiftUI

// MARK: - LaunchView

/// 启动窗口的内容：左栏是 App 名称、版本与打开仓库的入口，右栏列出最近打开的仓库书签，双击或回车打开所选。
struct LaunchView: View {
    /// App 的对外版本号。
    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// 仓库书签，列出其中打开过的仓库。
    let bookmarks: RepositoryBookmarks

    /// 打开所选仓库。
    let open: (RepositoryLocation) -> Void

    /// 选择本机仓库。
    let openLocal: () -> Void

    /// 添加服务器仓库。
    let addRemote: () -> Void

    /// 列表里选中的书签。
    @State
    private var selection: Bookmark.ID?

    /// 左右两栏铺在系统的玻璃材质上，整块可以拖动窗口。
    var body: some View {
        HStack(spacing: 0) {
            introduction
                .frame(width: 260)

            Divider()

            repositoryList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: LaunchWindowController.size.width, height: LaunchWindowController.size.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    /// 左栏：图标、名称、版本与两个打开入口。
    private var introduction: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(AppLocalization.text("app.name"))
                .font(.system(size: 26, weight: .semibold))
                .padding(.top, 8)

            Text(AppLocalization.text("launch.version", Self.version))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                actionButton(AppLocalization.text("action.openLocal"), symbol: "folder", action: openLocal)
                actionButton(AppLocalization.text("action.addRemote"), symbol: "server.rack", action: addRemote)
            }

            Spacer()
        }
        .padding(24)
    }

    /// 右栏：最近打开的仓库，最近的在前；还没有打开过仓库时显示空状态。
    @ViewBuilder
    private var repositoryList: some View {
        let recent = bookmarks.recentlyOpened

        if recent.isEmpty {
            Text(AppLocalization.text("launch.empty"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        } else {
            List(recent, selection: $selection) { bookmark in
                if let location = bookmark.location {
                    repositoryRow(bookmark, at: location)
                }
            }
            .scrollContentBackground(.hidden)
            .onKeyPress(.return) {
                guard let location = selection.flatMap({ bookmarks.bookmark($0)?.location }) else {
                    return .ignored
                }

                open(location)
                return .handled
            }
        }
    }

    /// 一行仓库：位置图标、书签名与带主机前缀的路径；失效的书签变淡，双击打开。
    private func repositoryRow(_ bookmark: Bookmark, at location: RepositoryLocation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: bookmark.symbolName)
                .font(.system(size: 16))
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(location.displayPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 4)
        .foregroundStyle(bookmarks.isMissing(location) ? .secondary : .primary)
        .tag(bookmark.id)
        .help(location.displayPath)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { open(location) }
    }

    /// 左栏的打开入口：图标加标题的无边框按钮。
    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
