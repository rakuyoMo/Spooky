import AppKit
import SpookyKit

// MARK: - Worktrees

extension BookmarkSidebarController {
    /// 接上工作树的读取：读完一个仓库后重新载入它的行；服务器仓库读完交还连接，详情区正显示它时留给详情区，由详情区换走时交还。
    func configureWorktrees() {
        worktrees.onLoad = { [weak self] location in
            self?.showWorktrees(of: location)
        }

        worktrees.onFinish = { [weak manager = self.manager, weak coordinator = self.manager.coordinator] location in
            guard manager?.detailLocation != location else {
                return
            }

            coordinator?.releaseConnection(location)
        }
    }

    /// 列出工作树时读取列表里看得到的仓库：所在的文件夹都展开着。
    func loadWorktrees() {
        guard displayOptions.worktrees else {
            return
        }

        worktrees.load(visibleRepositories(in: manager.bookmarks.items).compactMap(\.location))
    }

    /// 读到别的工作树、上次展开着的仓库照样展开。
    ///
    /// - Parameter repositories: 要看的仓库书签。
    func expandRememberedWorktrees(of repositories: [Bookmark]) {
        for bookmark in repositories where worktrees.isExpanded(bookmark.id) && !worktreeItems(of: bookmark).isEmpty {
            outlineView.expandItem(item(for: bookmark.id))
        }
    }

    /// 一个仓库的工作树读完后重新载入它的行；正在改名时不打断，改名结束后的重新载入会补上。
    private func showWorktrees(of location: RepositoryLocation) {
        guard outlineView.currentEditor() == nil else {
            return
        }

        let repositories = manager.bookmarks.items.repositories.filter { $0.location == location }

        for bookmark in repositories {
            outlineView.reloadItem(item(for: bookmark.id), reloadChildren: true)
        }

        expandRememberedWorktrees(of: repositories)
    }

    /// 列表里看得到的仓库书签：收起的文件夹里的不算。
    private func visibleRepositories(in bookmarks: [Bookmark]) -> [Bookmark] {
        bookmarks.flatMap { bookmark -> [Bookmark] in
            guard bookmark.isFolder else {
                return [bookmark]
            }

            return outlineView.isItemExpanded(item(for: bookmark.id)) ? visibleRepositories(in: bookmark.children) : []
        }
    }
}
