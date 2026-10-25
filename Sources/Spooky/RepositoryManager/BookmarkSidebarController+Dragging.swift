import AppKit
import SpookyKit

// MARK: - Dragging

extension BookmarkSidebarController {
    /// 书签行写出自己的身份；分组标题不能拖动。
    func outlineView(_: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
        guard let id = (item as? BookmarkOutlineItem)?.id else {
            return nil
        }

        let writer = NSPasteboardItem()
        writer.setString(id.uuidString, forType: .spookyBookmark)
        return writer
    }

    /// 书签只能落到分组标题或文件夹里、或者它们的子项之间，文件夹不能落进它自己；Finder 拖来的文件夹另外允许落在列表空白处。
    func outlineView(
        _: NSOutlineView,
        validateDrop info: any NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard

        if pasteboard.availableType(from: [.spookyBookmark]) != nil {
            guard let folder = destination(of: item) else {
                return []
            }

            return manager.bookmarks.canMove(draggedIDs(pasteboard), into: folder) ? .move : []
        }

        guard !droppedFolders(pasteboard).isEmpty else {
            return []
        }

        return item == nil && index == NSOutlineViewDropOnItemIndex || destination(of: item) != nil
            ? .copy
            : []
    }

    /// 书签按落点移动；Finder 的文件夹经打开检查后加进落点。
    func outlineView(
        _: NSOutlineView,
        acceptDrop info: any NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        let pasteboard = info.draggingPasteboard
        let position = index == NSOutlineViewDropOnItemIndex ? nil : index
        let folder = destination(of: item) ?? nil

        if pasteboard.availableType(from: [.spookyBookmark]) != nil {
            manager.bookmarks.move(draggedIDs(pasteboard), into: folder, at: position)
            return true
        }

        let folders = droppedFolders(pasteboard)

        guard !folders.isEmpty else {
            return false
        }

        manager.addDropped(folders, into: folder, at: item == nil ? nil : position)
        return true
    }
}

// MARK: - Private

extension BookmarkSidebarController {
    /// 落点对应的文件夹：外层为 nil 表示不能落在这里，内层为 nil 表示最外层。
    ///
    /// 分组标题代表最外层；落在仓库行上不接受。
    private func destination(of item: Any?) -> Bookmark.ID?? {
        guard let item = item as? BookmarkOutlineItem else {
            return nil
        }

        guard let id = item.id else {
            return .some(nil)
        }

        guard manager.bookmarks.bookmark(id)?.isFolder ?? false else {
            return nil
        }

        return .some(id)
    }

    /// 拖动中的书签身份。
    private func draggedIDs(_ pasteboard: NSPasteboard) -> [Bookmark.ID] {
        (pasteboard.pasteboardItems ?? []).compactMap {
            $0.string(forType: .spookyBookmark).flatMap(UUID.init(uuidString:))
        }
    }

    /// 拖来的本机文件夹；文件不算。
    private func droppedFolders(_ pasteboard: NSPasteboard) -> [URL] {
        // 剪贴板只能按 Objective-C 类读出对象
        // swiftlint:disable:next legacy_objc_type
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]

        return (urls ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
    }
}
