import AppKit
import SpookyKit

// MARK: - Add Menu

extension BookmarkSidebarController {
    /// 底栏 “+” 的下拉菜单：新建文件夹；添加本机或服务器仓库、新建仓库；克隆；在目录里寻找仓库。
    func makeAddMenu() -> NSMenu {
        let menu = NSMenu()

        // 下拉按钮的第一项只作按钮外观
        let title = NSMenuItem(title: "", action: nil, keyEquivalent: "")
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
    ///
    /// - Parameter object: 菜单项作用的对象：打开与系统一组是仓库的位置，其余是书签身份。
    private func menuItem(
        _ key: String,
        action: Selector,
        object: Any? = nil,
        arguments: [CVarArg] = []
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: AppLocalization.text(key, arguments: arguments),
            action: action,
            keyEquivalent: ""
        )

        item.target = self
        item.representedObject = object
        return item
    }
}

// MARK: - BookmarkSidebarController + NSMenuDelegate

extension BookmarkSidebarController: NSMenuDelegate {
    /// 右键菜单按点中的行生成：点中的书签行已选中时作用于全部选中的书签，否则只作用于点中的那一项；工作树行只有它自己的菜单。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clicked = outlineView.clickedRow
        let clickedItem = outlineView.item(atRow: clicked)

        if let worktree = clickedItem as? BookmarkWorktreeItem {
            for item in worktreeMenuItems(for: worktree) {
                menu.addItem(item)
            }

            return
        }

        guard let bookmark = bookmark(for: clickedItem) else {
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

    /// 一项书签的菜单：打开、在新窗口打开；Finder、复制路径、终端；改名、删除；两种按名称排序。
    func singleItems(for bookmark: Bookmark) -> [NSMenuItem] {
        let isRepository = !bookmark.isFolder
        let name = bookmark.displayName

        let location = bookmark.location

        let open = isRepository
            ? menuItem("bookmarks.open", action: #selector(openRepository), object: location, arguments: [name])
            : menuItem("bookmarks.openRepository", action: #selector(openRepository))
        let openNew = isRepository
            ? menuItem("bookmarks.openNewWindow", action: #selector(openInNewWindow), object: location, arguments: [name])
            : menuItem("bookmarks.openRepositoryNewWindow", action: #selector(openInNewWindow))

        let reveal = menuItem("action.revealFinder", action: #selector(revealInFinder), object: location)
        let copy = menuItem("action.copyPath", action: #selector(copyPath), object: location)
        let terminal = menuItem("action.openTerminal", action: #selector(openInTerminal), object: location)

        for item in [open, openNew, reveal, copy, terminal] {
            item.isEnabled = isRepository
        }

        // 本机仓库的目录已不存在时，没有可以在 Finder 或终端里打开的目录；路径照样可以复制
        if bookmark.isLocalDirectoryGone {
            reveal.isEnabled = false
            terminal.isEnabled = false
        }

        let delete = isRepository
            ? menuItem("bookmarks.delete", action: #selector(deleteBookmarks), object: bookmark.id, arguments: [name])
            : menuItem("bookmarks.deleteFolder", action: #selector(deleteBookmarks), object: bookmark.id)
        let sortChildren = menuItem("bookmarks.sortChildren", action: #selector(sortChildren), object: bookmark.id)
        sortChildren.isEnabled = bookmark.isFolder

        return [
            open, openNew, .separator(),
            reveal, copy, terminal, .separator(),
            menuItem("bookmarks.rename", action: #selector(renameBookmark), object: bookmark.id), delete, .separator(),
            sortChildren, menuItem("bookmarks.sortParent", action: #selector(sortParentFolder), object: bookmark.id),
        ]
    }

    /// 一个工作树的菜单：打开、在新窗口打开；Finder、复制路径、终端。失效的工作树没有可以打开的位置，各项都不可用。
    func worktreeMenuItems(for item: BookmarkWorktreeItem) -> [NSMenuItem] {
        let name = item.worktree.name
        let location = item.location

        let items = [
            menuItem("bookmarks.open", action: #selector(openRepository), object: location, arguments: [name]),
            menuItem("bookmarks.openNewWindow", action: #selector(openInNewWindow), object: location, arguments: [name]),
            .separator(),
            menuItem("action.revealFinder", action: #selector(revealInFinder), object: location),
            menuItem("action.copyPath", action: #selector(copyPath), object: location),
            menuItem("action.openTerminal", action: #selector(openInTerminal), object: location),
        ]

        for entry in items {
            entry.isEnabled = location != nil
        }

        return items
    }
}

// MARK: - Menu Actions

extension BookmarkSidebarController {
    /// 菜单项带的书签身份。
    private func target(of sender: NSMenuItem) -> Bookmark.ID? {
        sender.representedObject as? Bookmark.ID
    }

    /// 菜单项带的仓库位置。
    private func location(of sender: NSMenuItem) -> RepositoryLocation? {
        sender.representedObject as? RepositoryLocation
    }

    /// 在当前窗口打开。
    @objc
    private func openRepository(_ sender: NSMenuItem) {
        location(of: sender).map { manager.open($0, inNewWindow: false) }
    }

    /// 在新窗口打开。
    @objc
    private func openInNewWindow(_ sender: NSMenuItem) {
        location(of: sender).map { manager.open($0, inNewWindow: true) }
    }

    /// 在 Finder 中显示。
    @objc
    private func revealInFinder(_ sender: NSMenuItem) {
        location(of: sender).map(manager.revealInFinder)
    }

    /// 复制路径：本机仓库是绝对路径，服务器仓库带主机前缀。
    @objc
    private func copyPath(_ sender: NSMenuItem) {
        location(of: sender).map(manager.copyPath)
    }

    /// 在终端中打开。
    @objc
    private func openInTerminal(_ sender: NSMenuItem) {
        location(of: sender).map(manager.openInTerminal)
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
