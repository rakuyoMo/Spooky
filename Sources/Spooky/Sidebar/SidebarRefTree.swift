import Foundation
import SpookyKit

// MARK: - SidebarNodeID

/// 侧边栏树节点的身份；与选择用的字符串身份不同类型，`ForEach` 不会把节点身份当成可选中的标签。
struct SidebarNodeID: Hashable {
    /// 所在分组与节点路径拼成的唯一值。
    let value: String

    /// 远端节点的身份，也是远端下各节点身份的前缀。
    static func remote(_ name: String) -> Self {
        Self(value: "remote|" + name)
    }
}

// MARK: - SidebarRefNode

/// 侧边栏一组引用按 “/” 折叠后的节点：文件夹或引用。
struct SidebarRefNode: Identifiable, Equatable {
    /// 节点身份：文件夹为 “分组|folder|路径”，引用为 “分组|完整引用名”。
    let id: SidebarNodeID

    /// 显示的名字：折叠时是最后一段，不折叠时是完整名。
    let name: String

    /// 引用节点的引用；文件夹为 nil。
    let reference: RepositoryReference?

    /// 文件夹的子节点；引用节点为空。
    let children: [Self]

    /// 是否为文件夹。
    var isFolder: Bool { reference == nil }
}

// MARK: - SidebarRefTree

/// 把引用整理成侧边栏的树：按 “/” 折叠、文件夹置前、过滤与只留最新的若干个。
enum SidebarRefTree {
    /// 侧边栏的一条引用与它的显示名。
    struct Entry: Equatable {
        /// 引用。
        let reference: RepositoryReference

        /// 显示名；远端分支不含远端名。
        let name: String
    }

    /// 按显示名里的 “/” 折叠成文件夹；只有一个子项的前缀同样生成文件夹。
    ///
    /// - Parameters:
    ///   - entries: 已按显示顺序排好的引用；文件夹出现在它第一个子项的位置。
    ///   - grouped: 是否折叠；不折叠时每条引用显示完整名。
    ///   - foldersFirst: 同一级里文件夹是否排在引用前面。
    ///   - scope: 所在分组的标识，让不同分组里的同名文件夹与同一引用各有身份。
    static func nodes(
        for entries: [Entry],
        grouped: Bool,
        foldersFirst: Bool,
        scope: String
    ) -> [SidebarRefNode] {
        guard grouped else {
            return entries.map { leaf($0, name: $0.name, scope: scope) }
        }

        let paths = entries.map { ($0, $0.name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)) }
        return level(paths, prefix: [], foldersFirst: foldersFirst, scope: scope)
    }

    /// 树里全部文件夹的身份，过滤时用来展开全部文件夹。
    static func folderIDs(in nodes: [SidebarRefNode]) -> Set<SidebarNodeID> {
        var result = Set<SidebarNodeID>()

        for node in nodes where node.isFolder {
            result.insert(node.id)
            result.formUnion(folderIDs(in: node.children))
        }

        return result
    }

    /// 模糊匹配：过滤文字的每个字符按顺序出现在名字里即算匹配，不区分大小写与变音符号；空文字匹配一切。
    #warning("TODO: 过滤按字符顺序的子序列匹配，未核实是否还应匹配单词首字母或容许错字；核实方式：输入跳字与错字比对结果；影响侧边栏过滤后留下哪些引用")
    static func matches(_ name: String, filter: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        let pattern = filter.folding(options: options, locale: nil)
        var remaining = Substring(name.folding(options: options, locale: nil))

        for character in pattern {
            guard let index = remaining.firstIndex(of: character) else {
                return false
            }

            remaining = remaining[remaining.index(after: index)...]
        }

        return true
    }

    /// 只留最新的若干个引用，再补上必须显示的引用（如当前选中的），保持原有顺序。
    ///
    /// - Parameters:
    ///   - references: 待筛选的引用。
    ///   - limit: 保留的个数，0 表示全部。
    ///   - including: 无论新旧都保留的完整引用名。
    static func newest(
        _ references: [RepositoryReference],
        limit: Int,
        including: Set<String>
    ) -> [RepositoryReference] {
        guard limit > 0, references.count > limit else {
            return references
        }

        // 时间相同或读不到时间时按引用名决定先后，结果不随输入顺序变化
        let kept = references
            .sorted { lhs, rhs in
                let left = lhs.date ?? .distantPast
                let right = rhs.date ?? .distantPast
                return left == right ? lhs.id < rhs.id : left > right
            }
            .prefix(limit)
            .map(\.id)

        let keep = Set(kept).union(including)
        return references.filter { keep.contains($0.id) }
    }

    /// 标签按名称排序；名字里的数字按数值比较，v1.10 排在 v1.9 之后。
    #warning("TODO: 标签名称按数值感知的本地化规则比较，未核实是否应按字典序；核实方式：建 v1.9 与 v1.10 两个标签比对顺序；只影响标签分组的顺序")
    static func sortedTags(_ tags: [RepositoryReference], order: SidebarPreferences.TagOrder) -> [RepositoryReference] {
        tags.sorted { lhs, rhs in
            let result = lhs.name.localizedStandardCompare(rhs.name)

            // 名字比较相等时按引用名稳定排序
            if result == .orderedSame {
                return lhs.id < rhs.id
            }

            return order == .nameAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    /// 一组本地分支的条目：过滤时只留名字匹配的，显示名是分支名。
    static func branchEntries(_ branches: [RepositoryReference], filter: String) -> [Entry] {
        branches
            .filter { matches($0.name, filter: filter) }
            .map { Entry(reference: $0, name: $0.name) }
    }

    /// 一个远端的远端分支条目：按最长前缀判断归属，显示名去掉远端名。
    ///
    /// 过滤时列出全部匹配的分支；没有过滤时只留最新的 `limit` 个，`including` 里的总会留下。
    static func remoteEntries(
        of remote: RepositoryRemote,
        in snapshot: ReferenceSnapshot,
        filter: String,
        limit: Int,
        including: Set<String>
    ) -> [Entry] {
        // 远端名带斜杠时，最长前缀保证不会混入其它远端的分支；符号引用只用来标记默认分支
        let references = snapshot.references.filter {
            $0.isRemote && $0.symbolicTarget == nil && snapshot.remote(for: $0)?.name == remote.name
        }

        let shown =
            filter.isEmpty
                ? newest(references, limit: limit, including: including)
                : references.filter { matches($0.name, filter: filter) }

        let prefix = "refs/remotes/" + remote.name + "/"
        return shown.map { Entry(reference: $0, name: String($0.id.dropFirst(prefix.count))) }
    }

    /// 标签条目：过滤与数量限制同远端分支，最后按名称排序。
    static func tagEntries(
        in snapshot: ReferenceSnapshot,
        filter: String,
        limit: Int,
        including: Set<String>,
        order: SidebarPreferences.TagOrder
    ) -> [Entry] {
        let tags = snapshot.references.filter(\.isTag)

        let shown =
            filter.isEmpty
                ? newest(tags, limit: limit, including: including)
                : tags.filter { matches($0.name, filter: filter) }

        return sortedTags(shown, order: order).map { Entry(reference: $0, name: $0.name) }
    }
}

// MARK: - Private

extension SidebarRefTree {
    /// 生成一级节点：只剩一段的是引用，其余按第一段归入文件夹，文件夹放在它第一个子项出现的位置。
    private static func level(
        _ paths: [(Entry, [String])],
        prefix: [String],
        foldersFirst: Bool,
        scope: String
    ) -> [SidebarRefNode] {
        var order: [String] = []
        var leaves: [String: SidebarRefNode] = [:]
        var folders: [String: [(Entry, [String])]] = [:]

        for (entry, components) in paths {
            guard let first = components.first else {
                continue
            }

            if components.count == 1 {
                order.append("leaf:" + entry.reference.id)
                leaves[entry.reference.id] = leaf(entry, name: first, scope: scope)
                continue
            }

            if folders[first] == nil {
                order.append("folder:" + first)
            }

            folders[first, default: []].append((entry, Array(components.dropFirst())))
        }

        let nodes = order.compactMap { key -> SidebarRefNode? in
            if key.hasPrefix("leaf:") {
                return leaves[String(key.dropFirst(5))]
            }

            let name = String(key.dropFirst(7))
            let path = prefix + [name]

            return SidebarRefNode(
                id: SidebarNodeID(value: scope + "|folder|" + path.joined(separator: "/")),
                name: name,
                reference: nil,
                children: level(folders[name] ?? [], prefix: path, foldersFirst: foldersFirst, scope: scope)
            )
        }

        guard foldersFirst else {
            return nodes
        }

        return nodes.filter(\.isFolder) + nodes.filter { !$0.isFolder }
    }

    /// 引用节点。
    private static func leaf(_ entry: Entry, name: String, scope: String) -> SidebarRefNode {
        SidebarRefNode(
            id: SidebarNodeID(value: scope + "|" + entry.reference.id),
            name: name,
            reference: entry.reference,
            children: []
        )
    }
}
