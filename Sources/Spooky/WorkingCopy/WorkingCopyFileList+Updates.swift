import AppKit
import SpookyKit

// MARK: - Updates

extension WorkingCopyFileList.Coordinator {
    /// 一层子节点从旧顺序变到新顺序的一步，按顺序交给表格执行。
    enum RowStep: Equatable {
        /// 一次删掉旧顺序里这些位置的行。
        case remove(IndexSet)

        /// 把当前位置的行移到新位置，其余行顺次让开。
        case move(from: Int, to: Int)

        /// 在这些最终位置插入新行。
        case insert(IndexSet)
    }

    /// 一层子节点从旧顺序变到新顺序的步骤：先一次删掉不再出现的行，再按新顺序逐个移动或插入；相邻的插入合成一步。
    ///
    /// - Parameters:
    ///   - old: 旧顺序里各行的身份。
    ///   - new: 新顺序里各行的身份，沿用旧行的节点身份相同。
    static func steps<ID: Hashable>(from old: [ID], to new: [ID]) -> [RowStep] {
        let kept = Set(new)
        let removed = IndexSet(old.indices.filter { !kept.contains(old[$0]) })

        var current = old.filter { kept.contains($0) }
        var pending = Set(current)
        var steps: [RowStep] = removed.isEmpty ? [] : [.remove(removed)]

        // 逐个确定新顺序的每个位置：之前的位置都已就绪，旧行从后面移上来，新行就地插入
        for (index, id) in new.enumerated() {
            guard pending.remove(id) != nil else {
                current.insert(id, at: index)

                if case .insert(var indexes)? = steps.last {
                    indexes.insert(index)
                    steps[steps.count - 1] = .insert(indexes)
                } else {
                    steps.append(.insert(IndexSet(integer: index)))
                }

                continue
            }

            guard current[index] != id, let from = current[index...].firstIndex(of: id) else { continue }

            current.remove(at: from)
            current.insert(id, at: index)
            steps.append(.move(from: from, to: index))
        }

        return steps
    }

    /// 按条目身份把新节点对应到旧节点：路径与类别都相同的优先，其次是同路径、还没有对应的文件；目录只对应同路径的目录。
    ///
    /// 暂存把未跟踪文件变成已跟踪文件时仍是同一行，选择与展开随之保留。
    static func match(
        _ nodes: [WorkingCopyFileList.Node],
        to old: [WorkingCopyFileList.Node]
    ) -> [WorkingCopyFileList.Node?] {
        var files: [StatusRowID: WorkingCopyFileList.Node] = [:]
        var directories: [String: WorkingCopyFileList.Node] = [:]

        for node in old {
            if let entry = node.entry {
                files[StatusRowID(path: entry.path, kind: entry.kind)] = node
            } else {
                directories[node.path] = node
            }
        }

        var used = Set<ObjectIdentifier>()

        // 第一轮按路径与类别对应
        var matches = nodes.map { node -> WorkingCopyFileList.Node? in
            guard let entry = node.entry else { return directories[node.path] }

            guard let found = files[StatusRowID(path: entry.path, kind: entry.kind)] else { return nil }

            used.insert(ObjectIdentifier(found))
            return found
        }

        // 第二轮在还没有对应的旧文件里按路径找
        var byPath: [String: [WorkingCopyFileList.Node]] = [:]

        for node in old where node.entry != nil && !used.contains(ObjectIdentifier(node)) {
            byPath[node.path, default: []].append(node)
        }

        for (index, node) in nodes.enumerated() where matches[index] == nil && node.entry != nil {
            matches[index] = byPath[node.path]?.popLast()
        }

        return matches
    }

    /// 选中项全部消失后改选的节点：从原来第一个选中行起，先向下、再向上，取第一个仍在列表里的行；都不在时为 nil。
    ///
    /// - Parameters:
    ///   - row: 原来第一个选中行的行号。
    ///   - rows: 更新前按行排列的节点。
    ///   - isPresent: 节点在更新后的列表里仍有行。
    static func neighbor(
        of row: Int,
        in rows: [WorkingCopyFileList.Node],
        isPresent: (WorkingCopyFileList.Node) -> Bool
    ) -> WorkingCopyFileList.Node? {
        guard rows.indices.contains(row) else { return nil }

        let below = rows[(row + 1)...].first(where: isPresent)
        return below ?? rows[..<row].last(where: isPresent)
    }

    /// 增量合并新的节点，再刷新已显示的行；只看改动的树形里新出现的目录同样展开。
    func applyChanges(_ target: [WorkingCopyFileList.Node], mode: WorkingCopyListMode) {
        guard let outline else { return }

        outline.beginUpdates()
        merge(target, into: nil)
        outline.endUpdates()

        if mode == .tree {
            outline.expandItem(nil, expandChildren: true)
        }

        reloadVisibleRows()
    }

    /// 更新前选中的行全部消失、恢复出的选择为空时，改选原位置附近仍在的行，并在这一轮更新之后同步给会话。
    ///
    /// - Parameters:
    ///   - row: 更新前第一个选中行的行号。
    ///   - rows: 更新前按行排列的节点。
    func selectNeighbor(of row: Int, in rows: [WorkingCopyFileList.Node]) {
        guard let outline, outline.selectedRowIndexes.isEmpty else { return }

        let neighbor = Self.neighbor(of: row, in: rows) { outline.row(forItem: $0) >= 0 }

        guard let neighbor else { return }

        outline.selectRowIndexes(IndexSet(integer: outline.row(forItem: neighbor)), byExtendingSelection: false)

        // 会话在视图更新之后才修改，避免在更新视图的过程中改变被观察的状态
        Task { @MainActor [weak self] in
            self?.syncSelection()
        }
    }

    /// 把新算出的节点逐层合进现有的树：身份相同的节点沿用，删除向上收起、插入向下展开、顺序变化用行移动动画。
    ///
    /// 每一步之前先把这一层的模型改成表格将要看到的样子，表格向数据源取到的总是已经改好的那一层。
    private func merge(_ target: [WorkingCopyFileList.Node], into parent: WorkingCopyFileList.Node?) {
        guard let outline else { return }

        let old = parent?.children ?? roots
        let matches = Self.match(target, to: old)

        // 沿用的节点换上新的状态，子节点留到这一层排好之后再合并
        let final = zip(target, matches).map { node, match in
            guard let match else { return node }

            match.entry = node.entry
            return match
        }

        var current = old

        for step in Self.steps(from: old.map(ObjectIdentifier.init), to: final.map(ObjectIdentifier.init)) {
            switch step {
            case .remove(let indexes):
                current = current.indices.filter { !indexes.contains($0) }.map { current[$0] }
                setChildren(current, of: parent)
                outline.removeItems(at: indexes, inParent: parent, withAnimation: .slideUp)

            case .move(let from, let to):
                current.insert(current.remove(at: from), at: to)
                setChildren(current, of: parent)
                outline.moveItem(at: from, inParent: parent, to: to, inParent: parent)

            case .insert(let indexes):
                for index in indexes {
                    current.insert(final[index], at: index)
                }

                setChildren(current, of: parent)
                outline.insertItems(at: indexes, inParent: parent, withAnimation: .slideDown)
            }
        }

        // 沿用的目录按新的子节点继续合并下一层
        for (node, match) in zip(target, matches) {
            guard let match, node.entry == nil else { continue }

            merge(node.children, into: match)
        }
    }

    /// 结构改好之后刷新已经显示的行：单元格按新状态重建，行背景跟着冲突状态，选择与滚动位置不变。
    private func reloadVisibleRows() {
        guard let outline, outline.numberOfRows > 0 else { return }

        outline.reloadData(
            forRowIndexes: IndexSet(integersIn: 0 ..< outline.numberOfRows),
            columnIndexes: IndexSet(integersIn: 0 ..< outline.numberOfColumns)
        )

        outline.enumerateAvailableRowViews { rowView, row in
            let node = outline.item(atRow: row) as? WorkingCopyFileList.Node
            (rowView as? WorkingCopyFileList.FileRowView)?.isConflicted = node?.entry?.kind == .conflicted
        }
    }

    /// 把一层的子节点写回模型：顶层写进根节点，其余写进上层目录。
    private func setChildren(_ nodes: [WorkingCopyFileList.Node], of parent: WorkingCopyFileList.Node?) {
        if let parent {
            parent.children = nodes
        } else {
            roots = nodes
        }
    }
}
