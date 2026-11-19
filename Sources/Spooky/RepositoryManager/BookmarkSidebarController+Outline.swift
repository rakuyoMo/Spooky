import AppKit
import SpookyKit
import SwiftUI

// MARK: - Configuration

extension BookmarkSidebarController {
    /// source list 样式的单列大纲，分组行不浮动；双击、回车打开，删除键删除选中的书签，接受书签与 Finder 文件夹的拖放。
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
            guard let self, outlineView.selectedRowIndexes.count == 1 else {
                return
            }

            openRow(outlineView.item(atRow: outlineView.selectedRow))
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

    /// 在当前窗口打开一行：仓库行打开仓库，工作树行打开工作树、失效时响铃；文件夹与分组标题不响应。
    func openRow(_ item: Any?) {
        if let worktree = item as? BookmarkWorktreeItem {
            guard let location = worktree.location else {
                NSSound.beep()
                return
            }

            manager.open(location, inNewWindow: false)
            return
        }

        if let location = bookmark(for: item)?.location {
            manager.open(location, inNewWindow: false)
        }
    }

    /// 双击一行在当前窗口打开。
    @objc
    private func openClickedRow() {
        openRow(outlineView.item(atRow: outlineView.clickedRow))
    }
}

// MARK: - BookmarkSidebarController + NSOutlineViewDataSource

extension BookmarkSidebarController: NSOutlineViewDataSource {
    /// 最外层只有根分组标题。
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? 1 : childItems(of: item).count
    }

    /// 子项对应的行对象。
    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard item != nil else {
            return header
        }

        return childItems(of: item)[index]
    }

    /// 根分组标题与文件夹可以展开；列出工作树时，读到别的工作树的仓库同样可以。
    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let bookmark = bookmark(for: item) else {
            return (item as? BookmarkOutlineItem) === header
        }

        return bookmark.isFolder || !worktreeItems(of: bookmark).isEmpty
    }

    /// 文件夹与仓库的展开状态按书签身份保存；仓库的工作树另由 `BookmarkWorktrees` 记下，读到后再展开。
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
        (item as? BookmarkOutlineItem) === header
    }

    /// 根分组标题一行 20 pt；书签与工作树行随系统 “侧边栏图标大小” 取 24、28、32 pt，与仓库窗口的侧边栏相同。
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard (item as? BookmarkOutlineItem) !== header else {
            return 20
        }

        let size: SidebarRowSize =
            switch outlineView.effectiveRowSizeStyle {
            case .small: .small
            case .large: .large
            default: .medium
            }

        return size.rowHeight
    }

    /// 根分组标题不能选中。
    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? BookmarkOutlineItem) !== header
    }

    /// 分组标题用自己的单元格，书签与工作树共用书签的单元格。
    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        if let worktree = item as? BookmarkWorktreeItem {
            let cell = outlineView.makeView(withIdentifier: BookmarkCellView.identifier, owner: self) as? BookmarkCellView
                ?? BookmarkCellView()
            cell.configure(worktree.worktree, in: worktree.repository)
            return cell
        }

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
            clone: bookmark.location.flatMap { manager.coordinator?.clones.unfinished(at: $0) },
            showsHost: displayOptions.hostAliases
        )
        cell.textField?.delegate = self
        return cell
    }

    /// 用户改变选择后写回模型，详情区随之切换；只选了工作树行时模型里没有选择，详情区与选中分组时相同。
    func outlineViewSelectionDidChange(_: Notification) {
        guard !isRestoringSelection else {
            return
        }

        manager.selection = selectedIDs
    }

    /// 展开文件夹后读取露出来的仓库的工作树；仓库展开工作树时记下。
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let bookmark = bookmark(for: notification.userInfo?["NSObject"]) else {
            return
        }

        if bookmark.isFolder {
            loadWorktrees()
        } else {
            worktrees.setExpanded(bookmark.id, true)
        }
    }

    /// 仓库收起工作树时记下；不列工作树时仓库不能展开，这时的收起不算。
    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard
            displayOptions.worktrees,
            let bookmark = bookmark(for: notification.userInfo?["NSObject"]),
            !bookmark.isFolder
        else {
            return
        }

        worktrees.setExpanded(bookmark.id, false)
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
