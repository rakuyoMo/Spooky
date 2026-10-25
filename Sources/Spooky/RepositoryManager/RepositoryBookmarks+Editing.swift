import Foundation
import SpookyKit

// MARK: - Adding

extension RepositoryBookmarks {
    /// 加入一个仓库书签；同一位置已有书签时不重复加入，返回已有的那个。
    ///
    /// - Parameters:
    ///   - location: 已验证的仓库位置。
    ///   - folder: 放进的文件夹；nil 表示最外层。
    ///   - index: 在文件夹里的位置；nil 表示放到最后。
    /// - Returns: 新书签或已有书签的身份。
    @discardableResult
    func add(_ location: RepositoryLocation, into folder: Bookmark.ID? = nil, at index: Int? = nil) -> Bookmark.ID {
        if let existing = bookmark(for: location) {
            return existing.id
        }

        let bookmark = Bookmark.repository(location)
        insert([bookmark], into: folder, at: index)
        return bookmark.id
    }

    /// 新建文件夹并返回它的身份。
    ///
    /// - Parameters:
    ///   - name: 文件夹名。
    ///   - folder: 所在的文件夹；nil 表示最外层。
    ///   - index: 在文件夹里的位置；nil 表示放到最后。
    @discardableResult
    func addFolder(named name: String, into folder: Bookmark.ID? = nil, at index: Int? = nil) -> Bookmark.ID {
        let bookmark = Bookmark.folder(named: name)
        insert([bookmark], into: folder, at: index)
        return bookmark.id
    }

    /// 记下仓库在窗口中打开的时间并去掉失效标记；还没有书签的仓库加到最外层的最后。
    ///
    /// - Parameters:
    ///   - location: Git 确认后的仓库位置。
    ///   - date: 打开的时间。
    func recordOpened(_ location: RepositoryLocation, at date: Date = Date()) {
        let id = add(location)
        change { $0.update(id) { $0.lastOpened = date } }
        markAvailable(location)
    }

    /// 书签里的位置经 Git 确认是另一个位置时（子目录、符号链接），书签改指向确认后的位置。
    ///
    /// 确认后的位置已有自己的书签时不改动。
    ///
    /// - Parameters:
    ///   - location: 书签原来的位置。
    ///   - canonical: Git 确认后的工作区位置。
    func relocate(_ location: RepositoryLocation, to canonical: RepositoryLocation) {
        guard
            location != canonical,
            bookmark(for: canonical) == nil,
            let original = bookmark(for: location)
        else {
            return
        }

        let defaultName = Bookmark.repository(location).name

        change { items in
            items.update(original.id) {
                $0.location = canonical

                // 用户没改过的名字随新位置更新
                if $0.name == defaultName {
                    $0.name = Bookmark.repository(canonical).name
                }
            }
        }
    }
}

// MARK: - Editing

extension RepositoryBookmarks {
    /// 改名；去掉首尾空白后为空的名字不接受。
    func rename(_ id: Bookmark.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        change { $0.update(id) { $0.name = trimmed } }
    }

    /// 能否把这些书签移进指定的文件夹：目标必须是现有的文件夹，文件夹不能移进它自己或它里面的文件夹。
    func canMove(_ ids: [Bookmark.ID], into folder: Bookmark.ID?) -> Bool {
        guard let folder else {
            return true
        }

        guard items.bookmark(folder)?.isFolder ?? false else {
            return false
        }

        return !ids.contains { $0 == folder || items.isInside(folder, folder: $0) }
    }

    /// 移动书签，保持它们原来的先后顺序。
    ///
    /// - Parameters:
    ///   - ids: 要移动的书签；文件夹里同时被选中的书签随文件夹一起移动。
    ///   - folder: 目标文件夹；nil 表示最外层。
    ///   - index: 移动前目标文件夹里的插入位置；nil 表示放到最后。
    func move(_ ids: [Bookmark.ID], into folder: Bookmark.ID?, at index: Int?) {
        guard canMove(ids, into: folder) else {
            return
        }

        let moving = Set(ids)
        let siblings = items.children(of: folder)
        let target = min(index ?? siblings.count, siblings.count)

        // 插入位置前面被移走的同级书签要扣掉，否则会往后错位
        let shift = siblings.prefix(target).filter { moving.contains($0.id) }.count

        change { items in
            let removed = items.remove(moving)

            items.updateChildren(of: folder) {
                $0.insert(contentsOf: removed, at: target - shift)
            }
        }
    }

    /// 删除书签；文件夹连同里面的书签一起删除。只移除记录，不动磁盘或服务器上的仓库。
    func delete(_ ids: [Bookmark.ID]) {
        change { _ = $0.remove(Set(ids)) }
    }

    /// 文件夹的子项按显示名排序，不进入下一层；nil 表示最外层。
    func sortChildren(of folder: Bookmark.ID?) {
        change { items in
            items.updateChildren(of: folder) {
                $0.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            }
        }
    }

    /// 放进文件夹的指定位置并写回偏好；文件夹已不存在时放到最外层的最后。
    private func insert(_ bookmarks: [Bookmark], into folder: Bookmark.ID?, at index: Int?) {
        let destination = folder.flatMap { (items.bookmark($0)?.isFolder ?? false) ? $0 : nil }
        let position = destination == folder ? index : nil

        change { items in
            items.updateChildren(of: destination) {
                $0.insert(contentsOf: bookmarks, at: min(position ?? $0.count, $0.count))
            }
        }
    }
}
