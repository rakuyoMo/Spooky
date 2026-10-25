import AppKit
import SpookyKit

// MARK: - Configuration

extension BookmarkSidebarController {
    /// source list 样式的单列大纲，分组行不浮动；双击、回车打开，删除键删除，接受书签与 Finder 文件夹的拖放。
    func configureOutlineView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Bookmarks"))
        column.isEditable = true
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.floatsGroupRows = false
        outlineView.allowsMultipleSelection = true
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.setAccessibilityLabel(AppLocalization.text("repositories.title"))

        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(openClickedRow)

        outlineView.onOpen = { [weak self] in
            guard let self, let id = manager.selectedRepository?.id else {
                return
            }

            manager.open(id, inNewWindow: false)
        }

        outlineView.onDelete = { [weak self] in
            guard let self, !manager.selection.isEmpty else {
                return
            }

            manager.confirmDelete(manager.selection)
        }

        // 菜单项的可用状态按书签种类逐项设置
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        outlineView.menu = menu

        outlineView.registerForDraggedTypes([.spookyBookmark, .fileURL])
        outlineView.draggingDestinationFeedbackStyle = .sourceList
    }

    /// 双击仓库行在当前窗口打开；文件夹与分组标题不响应。
    @objc
    private func openClickedRow() {
        guard
            let bookmark = bookmark(for: outlineView.item(atRow: outlineView.clickedRow)),
            !bookmark.isFolder
        else {
            return
        }

        manager.open(bookmark.id, inNewWindow: false)
    }
}

// MARK: - BookmarkSidebarController + NSOutlineViewDataSource

extension BookmarkSidebarController: NSOutlineViewDataSource {
    /// 最外层只有根分组标题。
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? 1 : children(of: item).count
    }

    /// 子项对应的行对象。
    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard item != nil else {
            return header
        }

        return self.item(for: children(of: item)[index].id)
    }

    /// 根分组标题与文件夹可以展开。
    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? BookmarkOutlineItem)?.id == nil || (bookmark(for: item)?.isFolder ?? false)
    }

    /// 展开状态按书签身份保存。
    func outlineView(_: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        (item as? BookmarkOutlineItem)?.id?.uuidString
    }

    /// 由保存的身份找回行对象。
    func outlineView(_: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        guard let text = object as? String, let id = UUID(uuidString: text), manager.bookmarks.bookmark(id) != nil else {
            return nil
        }

        return item(for: id)
    }
}

// MARK: - BookmarkSidebarController + NSOutlineViewDelegate

extension BookmarkSidebarController: NSOutlineViewDelegate {
    /// 根分组标题是分组行。
    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? BookmarkOutlineItem)?.id == nil
    }

    /// 根分组标题不能选中。
    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? BookmarkOutlineItem)?.id != nil
    }

    /// 分组标题与书签各用自己的单元格。
    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let bookmark = bookmark(for: item) else {
            let cell = NSTableCellView()
            let title = NSTextField(labelWithString: AppLocalization.text("repositories.title"))
            title.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(title)
            cell.textField = title

            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
                title.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])

            return cell
        }

        let cell = outlineView.makeView(withIdentifier: BookmarkCellView.identifier, owner: self) as? BookmarkCellView
            ?? BookmarkCellView()
        cell.configure(
            bookmark,
            isMissing: bookmark.location.map(manager.bookmarks.isMissing) ?? false,
            clone: bookmark.location.flatMap { manager.coordinator?.clones.unfinished(at: $0) }
        )
        cell.textField?.delegate = self
        return cell
    }

    /// 用户改变选择后写回模型，详情区随之切换。
    func outlineViewSelectionDidChange(_: Notification) {
        guard !isRestoringSelection else {
            return
        }

        manager.selection = selectedIDs
    }
}

// MARK: - BookmarkSidebarController + NSTextFieldDelegate

extension BookmarkSidebarController: NSTextFieldDelegate {
    /// 去掉首尾空白后为空的名字不能结束编辑。
    func control(_: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        !fieldEditor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 结束编辑后改名；名字没变时模型不变，列表照常重新载入。
    func controlTextDidEndEditing(_ notification: Notification) {
        guard
            let field = notification.object as? NSTextField,
            let bookmark = bookmark(for: outlineView.item(atRow: outlineView.row(for: field)))
        else {
            return
        }

        if field.stringValue != bookmark.name {
            manager.bookmarks.rename(bookmark.id, to: field.stringValue)
        } else {
            reload()
        }
    }
}

// MARK: - Pasteboard Type

extension NSPasteboard.PasteboardType {
    /// 应用内拖动书签时的类型，值为书签身份。
    static let spookyBookmark = Self("com.rakuyo.spooky.bookmark")
}
