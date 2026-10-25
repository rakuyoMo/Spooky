import SpookyKit
import SwiftUI

// MARK: - RepositoryManagerDetailView

/// 仓库管理的详情区：按侧边栏的选择显示拖放页、仓库详情或多选页；打开仓库期间底部显示进度。
struct RepositoryManagerDetailView: View {
    /// 所在窗口的仓库管理。
    let manager: RepositoryManagerController

    /// 内容占满详情区，进度叠在底部。
    var body: some View {
        content
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if manager.session.isOpening {
                    ProgressView(AppLocalization.text("loading.open"))
                        .controlSize(.small)
                        .padding(12)
                }
            }
    }

    /// 选择对应的页面。
    @ViewBuilder
    private var content: some View {
        switch manager.content {
        case .dropZone:
            BookmarkDropZoneView(manager: manager)

        case .repository(let bookmark):
            BookmarkRepositoryDetailView(manager: manager, bookmark: bookmark)

        case .multiple(let count):
            VStack(spacing: 16) {
                EmptyStateView(
                    title: AppLocalization.text("bookmarks.multiple.title"),
                    message: AppLocalization.text("bookmarks.multiple.message", count),
                    symbol: "square.stack"
                )

                Button(AppLocalization.text("bookmarks.multiple.delete")) {
                    manager.confirmDelete(manager.selection)
                }
                .accessibilityIdentifier("delete-bookmarks")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppPalette.color("general_background_color"))
        }
    }
}
