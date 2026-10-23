import AppKit
import QuickLookUI
import SpookyKit
import SwiftUI

// MARK: - WorkingCopyFileList

/// 原生文件树支持多选勾选框、空格暂存、拖出文件、Quick Look 与固定行高。
struct WorkingCopyFileList: NSViewRepresentable {
    /// 所有入口共享同一会话状态。
    let session: RepositorySession

    /// 是否显示被忽略的文件，全局偏好。
    @AppStorage(WorkingCopyPreferences.showIgnored)
    private var showsIgnored = false

    /// 是否显示 assume-unchanged 文件，全局偏好。
    @AppStorage(WorkingCopyPreferences.showAssumeUnchanged)
    private var showsAssumeUnchanged = false

    /// 文件名的字号档位。
    @AppStorage(WorkingCopyPreferences.fontSize)
    private var fontSize = WorkingCopyPreferences.FontSize.regular

    /// 长文件名的截断位置。
    @AppStorage(WorkingCopyPreferences.truncation)
    private var truncation = WorkingCopyPreferences.Truncation.middle

    /// 构建事件与模型桥接器。
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    /// 表格固定状态列宽、行高与目录缩进，文件可以拖出到其它程序。
    func makeNSView(context: Context) -> NSScrollView {
        let outline = FileOutlineView()
        outline.delegate = context.coordinator
        outline.dataSource = context.coordinator
        outline.rowHeight = 28
        outline.intercellSpacing = .zero
        outline.style = .inset
        outline.allowsMultipleSelection = true
        outline.indentationPerLevel = 16
        outline.autoresizesOutlineColumn = false
        outline.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outline.setAccessibilityIdentifier("working-copy-status")

        let status = NSTableColumn(identifier: .init("status"))
        status.title = AppLocalization.text("status.column")
        status.width = 68
        status.minWidth = 68
        status.maxWidth = 68
        status.sortDescriptorPrototype = NSSortDescriptor(key: "status", ascending: true)
        outline.addTableColumn(status)

        let path = NSTableColumn(identifier: .init("path"))
        path.title = AppLocalization.text("status.filename")
        path.minWidth = 100
        path.sortDescriptorPrototype = NSSortDescriptor(key: "path", ascending: true)
        outline.addTableColumn(path)
        outline.outlineTableColumn = path
        outline.sortDescriptors = [NSSortDescriptor(key: "path", ascending: true)]

        // 键盘、双击、拖出与 Quick Look 都交给桥接器按偏好处理
        outline.coordinator = context.coordinator
        outline.target = context.coordinator
        outline.doubleAction = #selector(Coordinator.doubleClicked(_:))
        outline.setDraggingSourceOperationMask(.copy, forLocal: false)
        outline.setDraggingSourceOperationMask(.copy, forLocal: true)

        let menu = NSMenu()
        menu.delegate = context.coordinator
        outline.menu = menu
        context.coordinator.outline = outline

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = outline
        return scroll
    }

    /// 数据或显示选项变化才重建树，普通选区变化不打断键盘焦点。
    func updateNSView(_: NSScrollView, context: Context) {
        let listing = WorkingCopyListing(
            mode: session.listMode,
            showsIgnored: showsIgnored,
            showsAssumeUnchanged: showsAssumeUnchanged,
            onlyConflicts: session.onlyConflicts,
            filter: session.searchText
        )

        context.coordinator.update(listing: listing, style: Style(fontSize: fontSize, truncation: truncation))
    }
}

// MARK: - Nested Types

extension WorkingCopyFileList {
    /// 文件名的字号与截断方式。
    struct Style: Equatable {
        /// 字号档位。
        var fontSize: WorkingCopyPreferences.FontSize

        /// 截断位置。
        var truncation: WorkingCopyPreferences.Truncation
    }

    /// 决定是否需要重建树的全部输入。
    struct RenderState: Equatable {
        /// 列表里的条目。
        var entries: [StatusEntry]

        /// 勾选框的临时状态。
        var overrides: [StatusRowID: Bool]

        /// 显示选项。
        var listing: WorkingCopyListing

        /// 标记了 assume-unchanged 的路径。
        var marked: Set<String>

        /// 仓库是否可写。
        var canWrite: Bool

        /// 表头排序。
        var sort: [NSSortDescriptor]

        /// 字号与截断方式。
        var style: Style
    }

    /// 文件树节点同时保留相对路径与叶子状态。
    final class Node: NSObject {
        /// 相对路径，也是目录的稳定身份。
        let path: String

        /// 文件节点对应的 Git 状态。
        var entry: StatusEntry?

        /// 子节点按路径排序。
        var children: [Node] = []

        /// 目录勾选作用于当前显示的全部后代文件。
        var entries: [StatusEntry] {
            entry.map { [$0] } ?? children.flatMap(\.entries)
        }

        /// 末级名称。
        var name: String { WorkingCopyFileList.fileName(of: path) }

        /// 建立目录或文件节点。
        init(path: String, entry: StatusEntry? = nil) {
            self.path = path
            self.entry = entry
        }
    }

    /// 接管空格、⌘⌫ 与回车，并把 Quick Look 面板的控制权交给桥接器。
    final class FileOutlineView: NSOutlineView {
        /// 处理按键与 Quick Look 的桥接器。
        weak var coordinator: Coordinator?

        /// 空格按偏好切换暂存或打开 Quick Look；⌘⌫ 删除所选文件；回车与双击执行同一个动作。
        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])

            switch (event.keyCode, flags) {
            case (49, []):
                coordinator?.spacePressed()

            case (51, [.command]):
                coordinator?.deletePressed()

            case (36, []):
                #warning("TODO: 回车键与双击执行同一个动作是推断的键盘入口，核实工作区列表里打开文件的按键；只影响列表获得焦点时的回车键")
                coordinator?.openPressed()

            default:
                super.keyDown(with: event)
            }
        }

        /// 列表成为第一响应者时接管系统 Quick Look 面板。
        override func acceptsPreviewPanelControl(_: QLPreviewPanel?) -> Bool { true }

        /// 面板开始显示本列表的所选文件。
        override func beginPreviewPanelControl(_ panel: QLPreviewPanel?) {
            coordinator?.quickLook.begin(panel)
        }

        /// 面板不再由本列表控制。
        override func endPreviewPanelControl(_ panel: QLPreviewPanel?) {
            coordinator?.quickLook.end(panel)
        }
    }

    /// 勾选框保存所属节点，避免复用行号后指向错误文件。
    final class StagingButton: NSButton {
        /// 此次点击对应的文件或目录。
        var node: Node?
    }

    /// 冲突行以浅红背景辅助 U 徽标，选中时仍由系统绘制选区。
    final class ConflictRowView: NSTableRowView {
        /// 深浅外观分别使用 20% 与 10% 的系统红色。
        override func drawBackground(in dirtyRect: NSRect) {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            NSColor.systemRed.withAlphaComponent(dark ? 0.2 : 0.1).setFill()
            dirtyRect.fill()
        }
    }

    /// 路径的末级名称；被忽略的整个目录去掉末尾的 “/”。
    nonisolated static func fileName(of path: String) -> String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        return trimmed.split(separator: "/").last.map(String.init) ?? trimmed
    }
}

// MARK: WorkingCopyFileList.Coordinator

extension WorkingCopyFileList {
    /// 将原生列表事件转换为业务动作，不在 UI 拼接 Git 命令。
    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate {
        /// 当前会话。
        let session: RepositorySession

        /// 对原生列表的非持有引用。
        weak var outline: NSOutlineView?

        /// 本列表的 Quick Look 面板数据源。
        let quickLook: WorkingCopyQuickLook

        /// 右键菜单作用的条目。
        var menuEntries: [StatusEntry] = []

        /// 树形或平铺的顶层节点。
        var roots: [Node] = []

        /// 上次渲染的输入，用于避免无关重载。
        private(set) var renderState: RenderState?

        /// 恢复选区期间不回写会话。
        private var updating = false

        /// 初始化原生事件桥接。
        init(session: RepositorySession) {
            self.session = session
            quickLook = WorkingCopyQuickLook(session: session)
        }

        /// 根据 Git 模型、补充清单、显示选项和乐观状态重建行。
        func update(listing: WorkingCopyListing, style: Style) {
            guard let outline else { return }

            let entries = listing.entries(status: session.status?.entries ?? [], files: session.workingTreeFiles)
            let state = RenderState(
                entries: entries,
                overrides: session.stagingOverrides,
                listing: listing,
                marked: session.workingTreeFiles.assumeUnchanged,
                canWrite: session.canWrite,
                sort: outline.sortDescriptors,
                style: style
            )

            guard state != renderState else { return }

            let expanded = expandedPaths()
            renderState = state
            updating = true
            defer { updating = false }

            outline.indentationPerLevel = listing.mode.isTree ? 16 : 0
            roots = listing.mode.isTree ? Self.tree(entries) : entries.map { Node(path: $0.path, entry: $0) }
            sortNodes()
            outline.reloadData()
            restoreExpansion(mode: listing.mode, expanded: expanded)
            restoreSelection()
            dropHiddenSelection(visible: entries, filtered: !listing.filter.isEmpty)
        }

        /// 根节点与目录子项均直接取当前显示模型。
        func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Node)?.children.count ?? roots.count
        }

        /// 系统按索引索取节点。
        func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            ((item as? Node)?.children ?? roots)[index]
        }

        /// 只有目录显示展开三角。
        func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? Node else { return false }

            return !node.children.isEmpty
        }

        /// 平铺不留展开控件，树形仅为目录提供三角。
        func outlineView(_: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
            guard renderState?.listing.mode.isTree ?? false, let node = item as? Node else { return false }

            return !node.children.isEmpty
        }

        /// 冲突状态不只通过文字颜色表达。
        func outlineView(_: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            (item as? Node)?.entry?.kind == .conflicted ? ConflictRowView() : nil
        }

        /// 状态列为三态勾选和徽标，文件列为图标与按偏好截断的路径。
        func outlineView(_: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? Node else { return nil }

            if tableColumn?.identifier.rawValue == "status" {
                return statusCell(node)
            }

            return pathCell(node)
        }

        /// 单独选中一个目录时右栏显示目录说明，单选文件驱动 Diff，多选显示独立空状态。
        func outlineViewSelectionDidChange(_: Notification) {
            guard !updating, let outline else { return }

            let nodes = outline.selectedRowIndexes.compactMap { outline.item(atRow: $0) as? Node }
            let entries = nodes.flatMap(\.entries)
            let directory = nodes.count == 1 && nodes[0].entry == nil ? nodes[0].path : nil

            session.selectedIDs = Set(entries.map { StatusRowID(path: $0.path, kind: $0.kind) })
            session.selectedDirectory = directory
            session.selectedID = directory == nil && entries.count == 1 ? session.selectedIDs.first : nil
            quickLook.selectionChanged()
        }

        /// 表头排序改变后按相同模型恢复选择。
        func outlineView(_: NSOutlineView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
            guard let state = renderState else { return }

            renderState = nil
            update(listing: state.listing, style: state.style)
        }
    }
}
