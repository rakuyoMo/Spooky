import SwiftUI

// MARK: - BookmarkDropZoneView

/// 没有选中或选中文件夹时的拖放页：虚线框里是图标与两行提示，下面是添加、添加服务器仓库与新建的按钮。
///
/// 只接受本机文件夹；选中文件夹时添加的仓库放进那个文件夹。
struct BookmarkDropZoneView: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 拖动经过时虚线框换成强调色。
    @State
    private var isTargeted = false

    /// 368 pt 宽的区域在详情区居中。
    var body: some View {
        VStack(spacing: 20) {
            dropZone

            HStack(spacing: 8) {
                Button(AppLocalization.text("bookmarks.dropZone.add"), action: manager.addRepositories)
                    .accessibilityIdentifier("add-repository")

                Button(AppLocalization.text("action.addRemote"), action: manager.addServerRepository)
                    .accessibilityIdentifier("add-remote-repository")

                Button(AppLocalization.text("bookmarks.dropZone.create"), action: manager.createRepository)
                    .accessibilityIdentifier("create-repository")
            }
        }
        .padding(20)
        .frame(width: 368)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.color("general_background_color"))
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter {
                $0.isFileURL && ((try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
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

    /// 虚线圆角框，图标在上，两行 18 pt 的提示在下。
    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64, weight: .ultraLight))
                .frame(width: 128, height: 100)
                .accessibilityHidden(true)

            Text(AppLocalization.text("bookmarks.dropZone.title"))
            Text(AppLocalization.text("bookmarks.dropZone.subtitle"))
        }
        .font(.system(size: 18))
        .foregroundStyle(Color.primary.opacity(0.25))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(height: 279)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        }
        .accessibilityElement(children: .combine)
    }
}
