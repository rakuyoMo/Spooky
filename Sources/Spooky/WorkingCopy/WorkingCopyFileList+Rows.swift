import AppKit
import SpookyKit
import SwiftUI

// MARK: - Rows

extension WorkingCopyFileList.Coordinator {
    /// 本次渲染已知的 assume-unchanged 路径。
    private var renderMarked: Set<String> { renderState?.marked ?? [] }

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

        // 不能暂存的行隐藏勾选框但保留位置，各行的徽标保持对齐
        button.alphaValue = entries.isEmpty ? 0 : 1
        button.isEnabled = session.canWrite && !entries.isEmpty
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

        var views: [NSView] = [button]

        if let entry = node.entry {
            let marked = renderMarked.contains(entry.path)
            views.append(NSHostingView(rootView: FileStatusView(entry: entry, assumeUnchanged: marked)))
        }

        let stack = NSStackView(views: views)
        stack.spacing = 3
        return stack
    }

    /// 图标与文件名：树形只显示末级名称，完整路径放在提示中；被忽略与 assume-unchanged 的文件变灰。
    func pathCell(_ node: WorkingCopyFileList.Node) -> NSView {
        let style = renderState?.style ?? WorkingCopyFileList.Style(fontSize: .regular, truncation: .middle)
        let tree = renderState?.listing.mode.isTree ?? false
        let entry = node.entry
        let dimmed = entry?.kind == .ignored || entry.map { renderMarked.contains($0.path) } ?? false

        let label = NSTextField(labelWithString: tree ? node.name : node.path)
        label.font = .systemFont(ofSize: style.fontSize.pointSize)
        label.lineBreakMode = style.truncation.lineBreakMode
        label.textColor = dimmed ? .secondaryLabelColor : .controlTextColor
        label.toolTip = node.path

        // 冲突、目录与文件使用各自的系统符号；符号不可用时保留空白图标位
        let symbol = entry?.kind == .conflicted
            ? "exclamationmark.circle.fill"
            : (entry == nil || node.path.hasSuffix("/") ? "folder" : "doc")
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = entry?.kind == .conflicted
            ? .systemRed
            : (dimmed ? .tertiaryLabelColor : .secondaryLabelColor)
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let stack = NSStackView(views: [icon, label])
        stack.spacing = 8
        return stack
    }

    /// 递归排序使目录与文件使用相同的用户选项。
    func sortNodes() {
        let descriptor = outline?.sortDescriptors.first
        let ascending = descriptor?.ascending ?? true

        /// 目录内部沿用相同排序，不把平铺的比较结果跨层混用。
        func sorted(_ nodes: [WorkingCopyFileList.Node]) -> [WorkingCopyFileList.Node] {
            for node in nodes { node.children = sorted(node.children) }

            return nodes.sorted {
                let left = descriptor?.key == "status" ? String($0.entry?.staged?.rawValue ?? ".") + $0.path : $0.path
                let right = descriptor?.key == "status" ? String($1.entry?.staged?.rawValue ?? ".") + $1.path : $1.path
                return ascending ? left < right : left > right
            }
        }

        roots = sorted(roots)
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

        let entries = outline.isRowSelected(outline.row(forItem: node)) ? session.selectedEntries : node.entries
        let stageable = entries.filter(\.isStageable)
        session.stage(stageable, staged: stageable.contains(where: \.hasUnstagedChanges))
        outline.window?.makeFirstResponder(outline)
    }
}

// MARK: - Tree

extension WorkingCopyFileList.Coordinator {
    /// 按目录组织条目：目录节点只建一次，文件挂在所在目录下；被忽略的整个目录本身是一个叶子。
    static func tree(_ entries: [StatusEntry]) -> [WorkingCopyFileList.Node] {
        var roots: [WorkingCopyFileList.Node] = []
        var directories: [String: WorkingCopyFileList.Node] = [:]

        for entry in entries {
            let trimmed = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
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

            append(WorkingCopyFileList.Node(path: entry.path, entry: entry), to: parent, roots: &roots)
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
}
