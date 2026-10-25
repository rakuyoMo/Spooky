import SwiftUI

// MARK: - NoRepositoryFoundDialog

/// 添加的目录里没有 Git 仓库时的询问：在这个目录新建仓库，或者取消。只有头部与底栏。
struct NoRepositoryFoundDialog: View {
    /// 添加的目录。
    let directory: URL

    /// 关闭对话框。
    let close: () -> Void

    /// 在目录里新建仓库。
    let create: () -> Void

    /// 标题、说明与两个按钮。
    var body: some View {
        DialogLayout(
            title: AppLocalization.text("bookmarks.noRepository.title"),
            message: AppLocalization.text("bookmarks.noRepository.message", directory.path),
            submitTitle: AppLocalization.text("bookmarks.noRepository.create"),
            error: nil,
            canSubmit: true,
            cancel: close,
            submit: {
                close()
                create()
            }
        ) {
            EmptyView()
        }
    }
}
