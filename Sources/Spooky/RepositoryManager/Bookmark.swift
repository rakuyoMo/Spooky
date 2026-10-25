import Foundation
import SpookyKit

// MARK: - Bookmark

/// 仓库管理里的一项书签：一个本机或服务器仓库，或者一个装着其它书签的文件夹。
struct Bookmark: Codable, Hashable, Identifiable {
    /// 书签的身份，改名与移动后不变。
    let id: UUID

    /// 用户可以改的名称；服务器仓库显示时另加主机前缀。
    var name: String

    /// 仓库位置；文件夹没有位置。
    var location: RepositoryLocation?

    /// 文件夹里的书签，按手动调整的顺序排列；仓库没有子项。
    var children: [Self] = []

    /// 最近一次在窗口中打开的时间；文件夹与没有打开过的仓库没有。
    var lastOpened: Date?

    /// 是否是文件夹。
    var isFolder: Bool { location == nil }

    /// 列表、详情与菜单显示的名称：服务器仓库带主机前缀，避免与本机同名仓库混淆。
    var displayName: String { (location?.host.map { $0 + ":" } ?? "") + name }

    /// 列表与详情头部的系统符号：文件夹、本机仓库与服务器仓库各一种。
    var symbolName: String {
        guard let location else {
            return "folder"
        }

        return location.host == nil ? "internaldrive" : "server.rack"
    }

    /// 一个仓库书签，名称默认取工作区的目录名。
    static func repository(_ location: RepositoryLocation) -> Self {
        Self(id: UUID(), name: URL(fileURLWithPath: location.path).lastPathComponent, location: location)
    }

    /// 一个空文件夹。
    static func folder(named name: String) -> Self {
        Self(id: UUID(), name: name)
    }
}

// MARK: - Tree

extension [Bookmark] {
    /// 按树的先序排列的全部仓库书签。
    var repositories: [Bookmark] {
        flatMap { $0.isFolder ? $0.children.repositories : [$0] }
    }

    /// 按树的先序排列的全部书签，文件夹与仓库都算。
    var flattened: [Bookmark] {
        flatMap { [$0] + $0.children.flattened }
    }

    /// 找到指定的书签，文件夹里的也算。
    func bookmark(_ id: Bookmark.ID) -> Bookmark? {
        for item in self {
            if item.id == id {
                return item
            }

            if let found = item.children.bookmark(id) {
                return found
            }
        }

        return nil
    }

    /// 书签所在的文件夹：外层为 nil 的结果表示没有这个书签，内层为 nil 表示它在最外层。
    func parent(of id: Bookmark.ID, in folder: Bookmark.ID? = nil) -> Bookmark.ID?? {
        for item in self {
            if item.id == id {
                return .some(folder)
            }

            if let found = item.children.parent(of: id, in: item.id) {
                return found
            }
        }

        return nil
    }

    /// 一个文件夹的子项；nil 表示最外层。
    func children(of folder: Bookmark.ID?) -> [Bookmark] {
        guard let folder else {
            return self
        }

        return bookmark(folder)?.children ?? []
    }

    /// `id` 是否在文件夹 `folder` 里面，不论隔着几层。
    func isInside(_ id: Bookmark.ID, folder: Bookmark.ID) -> Bool {
        bookmark(folder)?.children.bookmark(id) != nil
    }

    /// 只改一个书签；找不到时什么也不做。
    mutating func update(_ id: Bookmark.ID, _ change: (inout Bookmark) -> Void) {
        for index in indices {
            if self[index].id == id {
                change(&self[index])
                return
            }

            self[index].children.update(id, change)
        }
    }

    /// 改一个文件夹的子项列表；nil 表示最外层。
    mutating func updateChildren(of folder: Bookmark.ID?, _ change: (inout [Bookmark]) -> Void) {
        guard let folder else {
            change(&self)
            return
        }

        update(folder) { change(&$0.children) }
    }

    /// 移除指定的书签并按树的先序返回它们；文件夹连同里面的书签一起移除，里面被单独选中的不再重复返回。
    mutating func remove(_ ids: Set<Bookmark.ID>) -> [Bookmark] {
        var removed: [Bookmark] = []
        var kept: [Bookmark] = []

        for var item in self {
            if ids.contains(item.id) {
                removed.append(item)
                continue
            }

            // 没被选中的文件夹继续往里找，它自己留在原处
            removed += item.children.remove(ids)
            kept.append(item)
        }

        self = kept
        return removed
    }
}
