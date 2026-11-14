import AppKit
import SpookyKit
import SwiftUI

// MARK: - Rows

extension WorkingCopyFileList.Coordinator {
    /// 本次渲染已知的 assume-unchanged 路径。
    private var renderMarked: Set<String> { renderState?.marked ?? [] }

    /// 本次渲染时进行中的操作已经解决的冲突路径。
    private var renderResolved: Set<String> { renderState?.listing.resolvedPaths ?? [] }

    /// 勾选框与状态徽标；不能暂存的未改动、被忽略文件隐藏勾选框。
    func statusCell(_ node: WorkingCopyFileList.Node) -> NSView {
        let entries = node.entries.filter(\.isStageable)
        let button = WorkingCopyFileList.StagingButton(
            checkboxWithTitle: "",
            target: self,
            action: #selector(toggle(_:))
        )
        button.node = node
        button.allowsMixedState = true

        // 正在暂存的行显示目标状态并禁用，其它行在暂存期间仍可点，新的请求排在后面
        let pending = entries.contains {
            session.stagingOverrides[StatusRowID(path: $0.path, kind: $0.kind)] != nil
        }

        // 不能暂存的行隐藏勾选框但保留位置，各行的徽标保持对齐
        button.alphaValue = entries.isEmpty ? 0 : 1
        button.isEnabled = session.canToggleStaging && !entries.isEmpty && !pending
        button.setAccessibilityElement(!entries.isEmpty)
        button.setAccessibilityLabel(AppLocalization.text("working.staging", node.path))

        // 勾选状态按 Git 模型计算，点击后的临时状态优先
        let states = entries.map { entry -> Int in
            if let override = session.stagingOverrides[StatusRowID(path: entry.path, kind: entry.kind)] {
                return override ? 1 : 0
            }

            if entry.hasStagedChanges { return entry.hasUnstagedChanges ? -1 : 1 }
            return 0
        }

        button.state = states.allSatisfy { $0 == 1 } ? .on : (states.allSatisfy { $0 == 0 } ? .off : .mixed)

        // 勾选框距左 3，徽标区贴着单元格右缘，两者不一起左对齐
        let cell = NSView()
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        // 文件行画自身的徽标，目录行按列汇总其下当前显示的条目
        let badges: NSView =
            if let entry = node.entry {
                NSHostingView(rootView: FileStatusView(
                    entry: entry,
                    assumeUnchanged: renderMarked.contains(entry.path),
                    untrackedCopy: node.untrackedCopy != nil
                ))
            } else {
                NSHostingView(rootView: DirectoryStatusView(entries: node.entries))
            }

        badges.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(badges)

        NSLayoutConstraint.activate([
            badges.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            badges.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            badges.widthAnchor.constraint(equalToConstant: 42),
            badges.heightAnchor.constraint(equalToConstant: 16),
        ])

        return cell
    }

    /// 图标与文件名：树形只显示末级名称，完整路径放在提示中；被忽略、assume-unchanged 与解决成与 HEAD 相同的文件变灰，
    /// 整个仓库被写操作占用时所有行变灰。
    ///
    /// 图标 16 × 16、距左 9，文字与图标相隔 8、距右 8；冲突与已解决的文件在图标右上叠标记。
    func pathCell(_ node: WorkingCopyFileList.Node) -> NSView {
        let style = renderState?.style ?? WorkingCopyFileList.Style(fontSize: .medium, truncation: .beginning)
        let tree = renderState?.listing.mode.isTree ?? false
        let entry = node.entry
        let resolved = entry.map { $0.kind != .conflicted && renderResolved.contains($0.path) } ?? false

        // 整个仓库被写操作占用时所有行一起变灰
        let dimmed = renderState?.locked ?? false
            || entry.map { entry in
                entry.kind == .ignored
                    || renderMarked.contains(entry.path)
                    || (resolved && entry.kind == .unchanged)
            } ?? false

        let label = NSTextField(labelWithString: Self.pathTitle(node, tree: tree))
        label.font = .systemFont(ofSize: style.fontSize.pointSize)
        label.lineBreakMode = style.truncation.lineBreakMode
        label.textColor = dimmed ? .secondaryLabelColor : .controlTextColor
        label.toolTip = Self.pathTitle(node, tree: false)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // 目录与被忽略或未跟踪的整个目录用文件夹图标，本机文件取实际图标，服务器文件按名称取；变灰的行图标同样变暗
        let icon = NSImageView(
            image: WorkingCopyFileHeader.icon(
                path: node.path,
                isFolder: entry == nil || node.path.hasSuffix("/"),
                root: session.repository?.localURL
            )
        )
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.isEnabled = !dimmed

        let cell = NSView()

        for view in [icon, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(view)
        }

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 9),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        if entry?.kind == .conflicted || resolved {
            Self.addConflictMark(resolved: resolved, over: icon, in: cell)
        }

        return cell
    }

    /// 重建前展开着的目录路径。
    func expandedPaths() -> Set<String> {
        guard let outline else { return [] }

        return Set(
            (0 ..< outline.numberOfRows).compactMap { row in
                guard let node = outline.item(atRow: row) as? WorkingCopyFileList.Node else { return nil }
                return outline.isItemExpanded(node) ? node.path : nil
            }
        )
    }

    /// 只看改动时目录全部展开；显示全部文件时只恢复用户展开过的目录。
    func restoreExpansion(mode: WorkingCopyListMode, expanded: Set<String>) {
        guard let outline, mode.isTree else { return }

        guard mode == .allFiles else {
            outline.expandItem(nil, expandChildren: true)
            return
        }

        /// 自上而下展开，子目录在父目录展开后才有行。
        func expand(_ nodes: [WorkingCopyFileList.Node]) {
            for node in nodes where !node.children.isEmpty && expanded.contains(node.path) {
                outline.expandItem(node)
                expand(node.children)
            }
        }

        expand(roots)
    }

    /// 恢复会话里的选区：单独选中的目录恢复目录行，其余恢复文件行。
    func restoreSelection() {
        guard let outline else { return }

        let rows = (0 ..< outline.numberOfRows).filter { row in
            guard let node = outline.item(atRow: row) as? WorkingCopyFileList.Node else { return false }

            if let directory = session.selectedDirectory {
                return node.entry == nil && node.path == directory
            }

            guard let entry = node.entry else { return false }
            return session.selectedIDs.contains(StatusRowID(path: entry.path, kind: entry.kind))
        }

        outline.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
    }

    /// 搜索把选中的文件过滤掉后取消这些选择，菜单与快捷键不会作用于看不见的文件。
    ///
    /// 会话在视图更新之后才修改，避免在更新视图的过程中改变被观察的状态。
    func dropHiddenSelection(visible entries: [StatusEntry], filtered: Bool) {
        guard filtered, session.status != nil else { return }

        let visible = Set(entries.map { StatusRowID(path: $0.path, kind: $0.kind) })
        let directoryHidden = session.selectedDirectory.map { directory in
            !entries.contains { $0.path.hasPrefix(directory + "/") }
        } ?? false

        guard !session.selectedIDs.isSubset(of: visible) || directoryHidden else { return }

        Task { @MainActor [session] in
            session.selectedIDs.formIntersection(visible)

            if directoryHidden {
                session.selectedDirectory = nil
            }

            if let selected = session.selectedID, !visible.contains(selected) {
                session.selectedID = nil
            }
        }
    }

    /// 勾选框作用于整个选区或这一行；目标状态按 Git 模型计算，不采用系统对 mixed 的默认轮转。
    @objc
    func toggle(_ sender: WorkingCopyFileList.StagingButton) {
        guard let node = sender.node, let outline else { return }

        // 正在收起的已删除行不再响应，动作不会落到过期的路径上
        let row = outline.row(forItem: node)

        guard row >= 0 else { return }

        let entries = outline.isRowSelected(row) ? session.selectedEntries : node.entries
        let stageable = entries.filter(\.isStageable)
        session.stage(stageable, staged: stageable.contains(where: \.hasUnstagedChanges))
        outline.window?.makeFirstResponder(outline)
    }
}

// MARK: - Tree

extension WorkingCopyFileList.Coordinator {
    /// 行的标题：树形只显示末级名称；重命名在列表与树形里都写出完整的旧路径与新路径。
    static func pathTitle(_ node: WorkingCopyFileList.Node, tree: Bool) -> String {
        guard
            let entry = node.entry,
            entry.staged == .renamed || entry.unstaged == .renamed,
            let original = entry.originalPath
        else { return tree ? node.name : node.path }

        return "\(original) → \(node.path)"
    }

    /// 按表头的各级排序排列节点；目录内部沿用相同排序，不把平铺的比较结果跨层混用。
    static func sorted(
        _ nodes: [WorkingCopyFileList.Node],
        by descriptors: [NSSortDescriptor]
    ) -> [WorkingCopyFileList.Node] {
        for node in nodes {
            node.children = sorted(node.children, by: descriptors)
        }

        return nodes.sorted { ordered($0, $1, by: descriptors) }
    }

    /// 两个节点的先后：路径不区分大小写，状态按两位状态码；各级都相同时按路径原文，结果不随输入顺序变化。
    private static func ordered(
        _ lhs: WorkingCopyFileList.Node,
        _ rhs: WorkingCopyFileList.Node,
        by descriptors: [NSSortDescriptor]
    ) -> Bool {
        for descriptor in descriptors {
            let result: ComparisonResult

            if descriptor.key == "status" {
                let ranks = (statusRank(lhs), statusRank(rhs))

                result =
                    if ranks.0 == ranks.1 {
                        .orderedSame
                    } else {
                        ranks.0 < ranks.1 ? .orderedAscending : .orderedDescending
                    }
            } else {
                result = lhs.path.localizedCaseInsensitiveCompare(rhs.path)
            }

            guard result != .orderedSame else { continue }

            return descriptor.ascending == (result == .orderedAscending)
        }

        return lhs.path < rhs.path
    }

    /// 状态列排序的档次，数值大的在按状态降序时排在前面：已暂存（含部分暂存）→ 已跟踪文件与冲突的未暂存改动 → 未跟踪文件
    /// → 未改动与被忽略的文件；同一档内不再按状态细分。
    ///
    /// 目录没有状态，低于所有文件。
    private static func statusRank(_ node: WorkingCopyFileList.Node) -> Int {
        guard let entry = node.entry else { return 0 }

        if entry.hasStagedChanges {
            return 4
        }

        return switch entry.kind {
        case .tracked, .conflicted: 3
        case .untracked: 2
        case .unchanged, .ignored: 1
        }
    }

    /// 平铺的文件行：每个条目一行，停止跟踪后同一路径的未跟踪记录并进暂存为删除的那一行。
    static func fileNodes(_ entries: [StatusEntry]) -> [WorkingCopyFileList.Node] {
        let copies = Dictionary(
            entries.untrackedCopies.map { ($0.path, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return entries.compactMap { entry in
            guard entry.kind != .untracked || copies[entry.path] == nil else { return nil }

            let copy = entry.isStagedDeletion ? copies[entry.path] : nil
            return WorkingCopyFileList.Node(path: entry.path, entry: entry, untrackedCopy: copy)
        }
    }

    /// 按目录组织文件行：目录节点只建一次，文件挂在所在目录下；被忽略或未跟踪的整个目录本身是一个叶子。
    static func tree(_ entries: [StatusEntry]) -> [WorkingCopyFileList.Node] {
        var roots: [WorkingCopyFileList.Node] = []
        var directories: [String: WorkingCopyFileList.Node] = [:]

        for file in fileNodes(entries) {
            let trimmed = file.path.hasSuffix("/") ? String(file.path.dropLast()) : file.path
            var parent: WorkingCopyFileList.Node?
            var prefix = ""

            // 逐级找到或建立上层目录，用字典查找，文件很多时不必反复遍历兄弟节点
            for component in trimmed.split(separator: "/").dropLast() {
                prefix += (prefix.isEmpty ? "" : "/") + component

                if let existing = directories[prefix] {
                    parent = existing
                    continue
                }

                let directory = WorkingCopyFileList.Node(path: prefix)
                directories[prefix] = directory
                append(directory, to: parent, roots: &roots)
                parent = directory
            }

            append(file, to: parent, roots: &roots)
        }

        return roots
    }

    /// 把节点挂到上层目录，没有上层目录时作为顶层节点。
    private static func append(
        _ node: WorkingCopyFileList.Node,
        to parent: WorkingCopyFileList.Node?,
        roots: inout [WorkingCopyFileList.Node]
    ) {
        if let parent {
            parent.children.append(node)
        } else {
            roots.append(node)
        }
    }
}

// MARK: - StatusEntry

extension StatusEntry {
    /// 可以勾选暂存或取消暂存：未改动与被忽略的文件没有可暂存的内容。
    var isStageable: Bool {
        kind != .unchanged && kind != .ignored
    }

    /// 只在暂存区里删除、工作区一侧没有记录的已跟踪文件，如停止跟踪后的文件。
    var isStagedDeletion: Bool {
        kind == .tracked && staged == .deleted && unstaged == nil
    }
}

// MARK: - [StatusEntry]

extension [StatusEntry] {
    /// 停止跟踪后的同一路径：暂存为删除，工作区里又是未跟踪文件；返回其中未跟踪的那些记录。
    ///
    /// 列表、勾选、右键与改动数都把这样的两条记录算作一条。
    var untrackedCopies: [StatusEntry] {
        let deleted = Set(filter(\.isStagedDeletion).map(\.path))
        return filter { $0.kind == .untracked && deleted.contains($0.path) }
    }
}

// MARK: - Private

extension WorkingCopyFileList.Coordinator {
    /// 在文件图标右上叠冲突标记：未解决是红色叹号，已解决是蓝色对勾；原图标保留。
    ///
    /// 标记宽 15、宽高比 0.8889，左缘压进图标 10，底边比图标顶边低 12。
    private static func addConflictMark(resolved: Bool, over icon: NSView, in cell: NSView) {
        let symbol = resolved ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        let mark = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())

        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.contentTintColor = resolved ? .systemBlue : .systemRed
        mark.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(mark)

        NSLayoutConstraint.activate([
            mark.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: -10),
            mark.bottomAnchor.constraint(equalTo: icon.topAnchor, constant: 12),
            mark.widthAnchor.constraint(equalToConstant: 15),
            mark.heightAnchor.constraint(equalTo: mark.widthAnchor, multiplier: 1 / 0.8889),
        ])
    }
}
