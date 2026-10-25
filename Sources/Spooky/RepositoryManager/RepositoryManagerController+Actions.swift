import AppKit
import SpookyKit
import SwiftUI

// MARK: - Opening

extension RepositoryManagerController {
    /// 打开仓库书签；失效的同样经打开流程重试。
    ///
    /// - Parameters:
    ///   - id: 仓库书签。
    ///   - inNewWindow: 是否显式在新窗口打开。
    func open(_ id: Bookmark.ID, inNewWindow: Bool) {
        guard let location = bookmarks.bookmark(id)?.location else {
            return
        }

        coordinator?.openRepository(at: location, from: window, inNewWindow: inNewWindow)
    }

    /// 在 Finder 中显示本机仓库。
    func revealInFinder(_ id: Bookmark.ID) {
        guard let url = bookmarks.bookmark(id)?.location?.localURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 复制带主机前缀的服务器路径，避免与本机目录混淆。
    func copyPath(_ id: Bookmark.ID) {
        guard let location = bookmarks.bookmark(id)?.location else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(location.displayPath, forType: .string)
    }

    /// 在所选终端程序中打开；服务器仓库经 SSH 进入远端路径。
    func openInTerminal(_ id: Bookmark.ID) {
        guard let location = bookmarks.bookmark(id)?.location else {
            return
        }

        window?.openLocationInTerminal(location)
    }
}

// MARK: - Adding

extension RepositoryManagerController {
    /// 新建文件夹：有选中时放在第一个选中项之后，否则放在最外层的最前面；建好后选中并进入改名。
    func newGroup() {
        let anchor = selection.first.flatMap(bookmarks.bookmark)
        let parent = anchor.flatMap { bookmarks.parent(of: $0.id) }
        let index = anchor.flatMap { anchor in
            bookmarks.items.children(of: parent).firstIndex { $0.id == anchor.id }
        }

        let id = bookmarks.addFolder(
            named: AppLocalization.text("bookmarks.newGroup"),
            into: parent,
            at: index.map { $0 + 1 } ?? 0
        )

        selection = [id]
        renameRequest = id
    }

    /// 选择一个或多个本机目录加入书签；选中文件夹时放进那个文件夹。
    func addRepositories() {
        guard let source = window, let sheetParent = source.window, sheetParent.attachedSheet == nil else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = AppLocalization.text("bookmarks.add.prompt")
        panel.message = AppLocalization.text("repositories.panel.message")
        let folder = selectedFolder

        panel.beginSheetModal(for: sheetParent) { [weak self] response in
            guard response == .OK, !panel.urls.isEmpty, let self, let source = window else {
                return
            }

            coordinator?.addRepositories(panel.urls, from: source, into: folder)
        }
    }

    /// 从 Finder 拖入的目录加到指定的文件夹与位置。
    ///
    /// - Parameters:
    ///   - urls: 拖入的本机目录。
    ///   - folder: 目标文件夹；nil 表示最外层。
    ///   - index: 在文件夹里的位置；nil 表示放到最后。
    func addDropped(_ urls: [URL], into folder: Bookmark.ID?, at index: Int?) {
        guard let source = window else {
            return
        }

        coordinator?.addRepositories(urls, from: source, into: folder, at: index)
    }

    /// 添加服务器仓库的表单。
    func addServerRepository() {
        window?.addRemoteRepository()
    }

    /// 新建本机仓库的对话框；建好的仓库放进选中的文件夹。
    func createRepository() {
        let folder = selectedFolder

        window?.presentDialog { [weak self] close in
            CreateRepositoryDialog(close: close) { [weak self] path in
                guard let self, let source = window else {
                    return
                }

                coordinator?.createRepository(at: path, from: source, into: folder, opening: true)
            }
        }
    }
}

// MARK: - Editing

extension RepositoryManagerController {
    /// 确认后删除书签；只移除记录，不动磁盘或服务器上的仓库。
    func confirmDelete(_ ids: [Bookmark.ID]) {
        let targets = ids.compactMap(bookmarks.bookmark)

        guard let sheetParent = window?.window, sheetParent.attachedSheet == nil, !targets.isEmpty else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = targets.count == 1
            ? AppLocalization.text("bookmarks.delete.title", targets[0].displayName)
            : AppLocalization.text("bookmarks.delete.titleMultiple", targets.count)
        alert.informativeText = AppLocalization.text("bookmarks.delete.message")
        alert.addButton(withTitle: AppLocalization.text("bookmarks.delete.submit"))
        alert.addButton(withTitle: AppLocalization.text("action.cancel"))

        alert.beginSheetModal(for: sheetParent) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else {
                return
            }

            bookmarks.delete(targets.map(\.id))
            selection.removeAll { bookmarks.bookmark($0) == nil }
        }
    }

    /// 文件夹的子项按名称排序。
    func sortChildren(of id: Bookmark.ID) {
        bookmarks.sortChildren(of: id)
    }

    /// 书签所在的文件夹按名称排序；在最外层时排最外层。
    func sortParentFolder(of id: Bookmark.ID) {
        bookmarks.sortChildren(of: bookmarks.parent(of: id))
    }
}
