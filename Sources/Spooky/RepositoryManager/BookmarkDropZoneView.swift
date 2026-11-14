import SwiftUI

// MARK: - BookmarkDropZoneView

/// 没有选中或选中文件夹时的拖放页：虚线框里是图标与两行提示，下面是添加、添加服务器仓库、新建与克隆的按钮。
///
/// 拖进本机文件夹时添加仓库，拖进远端地址时打开克隆对话框；选中文件夹时仓库放进那个文件夹。
struct BookmarkDropZoneView: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 拖动经过时虚线框换成强调色。
    @State
    private var isTargeted = false

    /// 326 pt 宽的虚线框与下方 20 pt 的按钮行在详情区居中；按钮行按各按钮文字的宽度排开，不截断。
    /// 底色与选中书签时的详情页相同。
    var body: some View {
        VStack(spacing: 20) {
            dropZone
                .frame(width: 326)

            HStack(spacing: 8) {
                Button(AppLocalization.text("bookmarks.dropZone.add"), action: manager.addRepositories)
                    .accessibilityIdentifier("add-repository")

                Button(AppLocalization.text("action.addRemote"), action: manager.addServerRepository)
                    .accessibilityIdentifier("add-remote-repository")

                Button(AppLocalization.text("bookmarks.dropZone.create"), action: manager.createRepository)
                    .accessibilityIdentifier("create-repository")

                Button(AppLocalization.text("bookmarks.dropZone.clone")) { manager.cloneRepository() }
                    .accessibilityIdentifier("clone-repository")
            }
            .fixedSize()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter {
                $0.isFileURL && ((try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
            }

            // 远端地址只取第一个，在克隆对话框里预填
            if folders.isEmpty, let remote = urls.first(where: { !$0.isFileURL }) {
                manager.cloneRepository(url: remote.absoluteString)
                return true
            }

            guard !folders.isEmpty else {
                return false
            }

            manager.addDropped(folders, into: manager.selectedFolder, at: nil)
            return true
        } isTargeted: {
            isTargeted = $0
        }
    }

    /// 虚线圆角框，高度随内容：上缘到图标 73 pt，图标下是一段两行的 18 pt 提示，提示底到下缘 72 pt。
    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64, weight: .ultraLight))
                .frame(width: 128, height: 100)
                .accessibilityHidden(true)

            // 两行在同一段文字里，按 18 pt 的默认行距排
            Text(
                AppLocalization.text("bookmarks.dropZone.title")
                    + "\n"
                    + AppLocalization.text("bookmarks.dropZone.subtitle")
            )
        }
        .font(.system(size: 18))
        .foregroundStyle(Color.primary.opacity(0.25))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 18)
        .padding(.top, 73)
        .padding(.bottom, 72)
        .frame(maxWidth: .infinity)
        .overlay {
            // 虚线 2 pt 粗、6 pt 实 8 pt 空，平时是 `bookmarks_drop_zone_border_color` 的灰色，拖动经过时换成强调色
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    isTargeted ? Color.accentColor : AppPalette.color("bookmarks_drop_zone_border_color"),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 8])
                )
        }
        .accessibilityElement(children: .combine)
    }
}
