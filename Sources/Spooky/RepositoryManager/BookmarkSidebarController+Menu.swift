import AppKit
import SpookyKit

// MARK: - Add Menu

extension BookmarkSidebarController {
    /// 底栏 “+” 的下拉菜单：新建文件夹；添加本机或服务器仓库、新建仓库；克隆；在目录里寻找仓库。
    func makeAddMenu() -> NSMenu {
        let menu = NSMenu()

        // 下拉按钮的第一项只作按钮外观
        let title = NSMenuItem()
        title.image = NSImage(named: NSImage.touchBarAddDetailTemplateName)
        menu.addItem(title)

        menu.addItem(menuItem("bookmarks.newGroup", action: #selector(newGroup)))
        menu.addItem(.separator())
        menu.addItem(menuItem("bookmarks.add", action: #selector(addRepositories)))
        menu.addItem(menuItem("action.addRemote", action: #selector(addServerRepository)))
        menu.addItem(menuItem("bookmarks.create", action: #selector(createRepository)))
        menu.addItem(.separator())
        menu.addItem(menuItem("clone.menu", action: #selector(cloneRepository)))
        menu.addItem(.separator())
        menu.addItem(menuItem("scan.menu", action: #selector(scanRepositories)))
        return menu
    }

    /// 新建文件夹并进入改名。
    @objc
    private func newGroup() {
        manager.newGroup()
    }

    /// 选择本机目录加入书签。
    @objc
    private func addRepositories() {
        manager.addRepositories()
    }

    /// 添加服务器仓库的表单。
    @objc
    private func addServerRepository() {
        manager.addServerRepository()
    }

    /// 新建本机仓库的对话框。
    @objc
    private func createRepository() {
        manager.createRepository()
    }

    /// 克隆对话框。
    @objc
    private func cloneRepository() {
        manager.cloneRepository()
    }

    /// 在目录里寻找仓库的对话框。
    @objc
    private func scanRepositories() {
        manager.scanRepositories()
    }

    /// 一个目标为侧边栏的菜单项。
    private func menuItem(_ key: String, action: Selector, id: Bookmark.ID? = nil, arguments: [CVarArg] = []) -> NSMenuItem {
        let title = String(format: AppLocalization.text(key), locale: Locale.current, arguments: arguments)
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = id
        return item
    }
}

// MARK: - BookmarkSidebarController + NSMenuDelegate

extension BookmarkSidebarController: NSMenuDelegate {
    /// 右键菜单按点中的行生成：点中的行已选中时作用于全部选中项，否则只作用于点中的那一项。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clicked = outlineView.clickedRow

        guard let bookmark = bookmark(for: outlineView.item(atRow: clicked)) else {
            return
        }

        let ids = outlineView.selectedRowIndexes.contains(clicked) ? selectedIDs : [bookmark.id]

        guard ids.count == 1 else {
            let item = menuItem("bookmarks.deleteMultiple", action: #selector(deleteBookmarks), arguments: [ids.count])
            item.representedObject = ids
            menu.addItem(item)
            return
        }

        for item in singleItems(for: bookmark) {
            menu.addItem(item)
        }
    }

    /// 一项书签的菜单：打开、在新窗口打开；Finder 或复制路径、终端；改名、删除；两种按名称排序。
    private func singleItems(for bookmark: Bookmark) -> [NSMenuItem] {
        let isRepository = !bookmark.isFolder
        let name = bookmark.displayName

        let open = isRepository
            ? menuItem("bookmarks.open", action: #selector(openBookmark), id: bookmark.id, arguments: [name])
            : menuItem("bookmarks.openRepository", action: #selector(openBookmark), id: bookmark.id)
        let openNew = isRepository
            ? menuItem("bookmarks.openNewWindow", action: #selector(openInNewWindow), id: bookmark.id, arguments: [name])
            : menuItem("bookmarks.openRepositoryNewWindow", action: #selector(openInNewWindow), id: bookmark.id)

        // 服务器仓库不能在 Finder 中显示，换成复制带主机前缀的路径
        let locate = bookmark.location?.host == nil
            ? menuItem("action.revealFinder", action: #selector(revealInFinder), id: bookmark.id)
            : menuItem("action.copyPath", action: #selector(copyPath), id: bookmark.id)
        let terminal = menuItem("action.openTerminal", action: #selector(openInTerminal), id: bookmark.id)

        for item in [open, openNew, locate, terminal] {
            item.isEnabled = isRepository
        }

        let delete = isRepository
            ? menuItem("bookmarks.delete", action: #selector(deleteBookmarks), id: bookmark.id, arguments: [name])
            : menuItem("bookmarks.deleteFolder", action: #selector(deleteBookmarks), id: bookmark.id)
        let sortChildren = menuItem("bookmarks.sortChildren", action: #selector(sortChildren), id: bookmark.id)
        sortChildren.isEnabled = bookmark.isFolder

        return [
            open, openNew, .separator(),
            locate, terminal, .separator(),
            menuItem("bookmarks.rename", action: #selector(renameBookmark), id: bookmark.id), delete, .separator(),
            sortChildren, menuItem("bookmarks.sortParent", action: #selector(sortParentFolder), id: bookmark.id),
        ]
    }
}

// MARK: - Menu Actions

extension BookmarkSidebarController {
    /// 菜单项带的书签身份。
    private func target(of sender: NSMenuItem) -> Bookmark.ID? {
        sender.representedObject as? Bookmark.ID
    }

    /// 在当前窗口打开。
    @objc
    private func openBookmark(_ sender: NSMenuItem) {
        target(of: sender).map { manager.open($0, inNewWindow: false) }
    }

    /// 在新窗口打开。
    @objc
    private func openInNewWindow(_ sender: NSMenuItem) {
        target(of: sender).map { manager.open($0, inNewWindow: true) }
    }

    /// 在 Finder 中显示。
    @objc
    private func revealInFinder(_ sender: NSMenuItem) {
        target(of: sender).map(manager.revealInFinder)
    }

    /// 复制带主机前缀的路径。
    @objc
    private func copyPath(_ sender: NSMenuItem) {
        target(of: sender).map(manager.copyPath)
    }

    /// 在终端中打开。
    @objc
    private func openInTerminal(_ sender: NSMenuItem) {
        target(of: sender).map(manager.openInTerminal)
    }

    /// 原地改名。
    @objc
    private func renameBookmark(_ sender: NSMenuItem) {
        target(of: sender).map(beginRename)
    }

    /// 确认后删除一项或多项。
    @objc
    private func deleteBookmarks(_ sender: NSMenuItem) {
        let ids = (sender.representedObject as? [Bookmark.ID]) ?? target(of: sender).map { [$0] } ?? []
        manager.confirmDelete(ids)
    }

    /// 文件夹的子项按名称排序。
    @objc
    private func sortChildren(_ sender: NSMenuItem) {
        target(of: sender).map(manager.sortChildren)
    }

    /// 书签所在的文件夹按名称排序。
    @objc
    private func sortParentFolder(_ sender: NSMenuItem) {
        target(of: sender).map(manager.sortParentFolder)
    }
}
