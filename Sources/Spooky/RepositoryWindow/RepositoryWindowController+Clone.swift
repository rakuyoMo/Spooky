import AppKit
import SpookyKit
import SwiftUI

// MARK: - Clone

extension RepositoryWindowController {
    /// 弹出克隆对话框；开始后克隆在后台进行，书签立即出现在仓库管理里。
    ///
    /// - Parameters:
    ///   - url: 预填的远端地址，如拖进来的 URL。
    ///   - folder: 书签放进的文件夹；nil 表示最外层。
    func presentClone(url: String = "", into folder: Bookmark.ID? = nil) {
        guard let coordinator else {
            return
        }

        let hosts = ServerCloneDirectories.hosts(in: coordinator.bookmarks)

        presentDialog { close in
            CloneRepositoryDialog(url: url, hosts: hosts, close: close) { clone in
                coordinator.clones.start(clone, into: folder)
            }
        }
    }

    /// 打开还在克隆的仓库时，整个窗口换成克隆进度页；完成后在本窗口打开仓库。
    func showCloneProgress(_ activity: CloneActivity) {
        let page = NSHostingController(rootView: CloneProgressView(
            activity: activity,
            retry: { [weak self] in self?.coordinator?.clones.restart(activity) },
            finished: { [weak self] in
                guard let self else {
                    return
                }

                coordinator?.openRepository(at: activity.clone.destination, from: self, inNewWindow: false)
            }
        ))
        page.sizingOptions = [.minSize]

        showPage(page, title: activity.name)
    }
}
