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

    /// 是否只显示冲突文件，全局偏好。
    @AppStorage(WorkingCopyPreferences.showOnlyConflicts)
    private var onlyConflicts = false

    /// 文件名的字号档位。
    @AppStorage(WorkingCopyPreferences.fontSize)
    private var fontSize = WorkingCopyPreferences.FontSize.medium

    /// 长文件名的截断位置。
    @AppStorage(WorkingCopyPreferences.truncation)
    private var truncation = WorkingCopyPreferences.Truncation.beginning

    /// 构建事件与模型桥接器。
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    /// 表格固定状态列宽、行高与目录缩进，行间有分隔线，文件可以拖出到其它程序。
    func makeNSView(context: Context) -> NSScrollView {
        let outline = FileOutlineView()
        outline.delegate = context.coordinator
        outline.dataSource = context.coordinator
        outline.rowHeight = 28
        outline.intercellSpacing = .zero
        outline.style = .inset

        // 行与行之间画系统分隔线
        outline.gridStyleMask = .solidHorizontalGridLineMask
        outline.gridColor = .separatorColor

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
        path.minWidth = 40
        path.sortDescriptorPrototype = NSSortDescriptor(key: "path", ascending: true)
        outline.addTableColumn(path)
        outline.outlineTableColumn = path
        outline.sortDescriptors = WorkingCopyPreferences.sortDescriptors()

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

    /// 数据或显示选项变化才重建树，普通选区变化不打断键盘焦点；提交成功后列表接过焦点。
    func updateNSView(_: NSScrollView, context: Context) {
        let listing = WorkingCopyListing(
            mode: session.listMode,
            showsIgnored: showsIgnored,
            showsAssumeUnchanged: showsAssumeUnchanged,
            conflictPaths: onlyConflicts ? session.conflictPaths : nil,
            resolvedPaths: session.context?.progress?.resolvedPaths ?? [],
            filter: session.searchText
        )

        let coordinator = context.coordinator
        coordinator.update(listing: listing, style: Style(fontSize: fontSize, truncation: truncation))

        // 焦点等这一轮更新结束再交，信息框的失焦回调不在视图更新中途改状态
        if coordinator.focusRequest != session.fileListFocusRequest {
            coordinator.focusRequest = session.fileListFocusRequest

            DispatchQueue.main.async { [weak outline = coordinator.outline] in
                outline?.window?.makeFirstResponder(outline)
            }
        }
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

        /// 勾选框能否点。
        var canToggleStaging: Bool

        /// 整个仓库被写操作占用，图标与文件名变灰。
        var locked: Bool

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

    /// 接管空格与 ⌘⌫，并把 Quick Look 面板的控制权交给桥接器。
    final class FileOutlineView: NSOutlineView {
        /// 处理按键与 Quick Look 的桥接器。
        weak var coordinator: Coordinator?

        /// 空格按偏好切换暂存或打开 Quick Look；⌘⌫ 删除所选文件。
        override func keyDown(with event: NSEvent) {
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])

            switch (event.keyCode, flags) {
            case (49, []):
                coordinator?.spacePressed()

            case (51, [.command]):
                coordinator?.deletePressed()

            default:
                super.keyDown(with: event)
            }
        }

        /// 列表成为第一响应者时接管系统 Quick Look 面板。
        override func acceptsPreviewPanelControl(_: QLPreviewPanel?) -> Bool { true }

        /// 面板开始显示本列表的所选文件；Quick Look 只在主线程回调。
        override func beginPreviewPanelControl(_ panel: QLPreviewPanel?) {
            MainActor.assumeIsolated {
                coordinator?.quickLook.begin(panel)
            }
        }

        /// 面板不再由本列表控制；Quick Look 只在主线程回调。
        override func endPreviewPanelControl(_ panel: QLPreviewPanel?) {
            MainActor.assumeIsolated {
                coordinator?.quickLook.end(panel)
            }
        }
    }

    /// 勾选框保存所属节点，避免复用行号后指向错误文件。
    final class StagingButton: NSButton {
        /// 此次点击对应的文件或目录。
        var node: Node?
    }

    /// 文件列表的行：未解决的冲突行各画一块浅红圆角底，选中时仍由系统绘制选区；行间分隔线在背景之后绘制，不被浅红盖住。
    final class FileRowView: NSTableRowView {
        /// 这一行是未解决的冲突；行被复用或条目状态变化时由列表更新。
        var isConflicted = false {
            didSet {
                guard isConflicted != oldValue else { return }

                needsDisplay = true
            }
        }

        /// 冲突行的底左右各内缩 10、圆角 8；深浅外观分别使用 20% 与 10% 的系统红色。
        override func drawBackground(in dirtyRect: NSRect) {
            super.drawBackground(in: dirtyRect)

            guard isConflicted else { return }

            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            NSColor.systemRed.withAlphaComponent(dark ? 0.2 : 0.1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 0), xRadius: 8, yRadius: 8).fill()
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

        /// 已处理的焦点请求。
        var focusRequest: Int

        /// 右键菜单作用的行：点在选区内或空白处时是整个选区，点在选区外时只有被点的行；树形里一个目录算一项。
        var menuTargets: [Node] = []

        /// 右键菜单作用的条目：作用的行展开成的文件，菜单构建时算出一次，执行时不再回读选区。
        var menuEntries: [StatusEntry] = []

        /// 树形或平铺的顶层节点。
        var roots: [Node] = []

        /// 上次渲染的输入，用于避免无关重载。
        private(set) var renderState: RenderState?

        /// 恢复选区期间不回写会话。
        private var updating = false

        /// 初始化原生事件桥接；创建前的焦点请求视为已处理，列表出现时不抢焦点。
        init(session: RepositorySession) {
            self.session = session
            focusRequest = session.fileListFocusRequest
            quickLook = WorkingCopyQuickLook(session: session)
        }

        /// 根据 Git 模型、补充清单、显示选项和乐观状态更新行。
        ///
        /// 同一显示模式与样式下按条目身份增量更新并播放行动画；首次显示、切换模式或样式时整表重载。
        func update(listing: WorkingCopyListing, style: Style) {
            guard let outline else { return }

            let entries = listing.entries(status: session.status?.entries ?? [], files: session.workingTreeFiles)
            let state = RenderState(
                entries: entries,
                overrides: session.stagingOverrides,
                listing: listing,
                marked: session.workingTreeFiles.assumeUnchanged,
                canToggleStaging: session.canToggleStaging,
                locked: session.isRepositoryLocked,
                sort: outline.sortDescriptors,
                style: style
            )

            guard state != renderState else { return }

            // 记下更新前的行与选择，选中项全部消失时据此找邻行；展开着的目录供整表重载后恢复
            let previous = renderState
            let rows = (0 ..< outline.numberOfRows).compactMap { outline.item(atRow: $0) as? Node }
            let selectedRow = outline.selectedRowIndexes.first
            let expanded = expandedPaths()

            renderState = state
            updating = true
            defer { updating = false }

            // 平铺每个条目一行；树形按目录组织并缩进
            outline.indentationPerLevel = listing.mode.isTree ? 16 : 0

            let target = Self.sorted(
                listing.mode.isTree ? Self.tree(entries) : entries.map { Node(path: $0.path, entry: $0) },
                by: outline.sortDescriptors
            )

            if let previous, previous.listing.mode == listing.mode, previous.style == style {
                applyChanges(target, mode: listing.mode)
            } else {
                roots = target
                outline.reloadData()
                restoreExpansion(mode: listing.mode, expanded: expanded)
            }

            // 恢复会话里的选区；只是数据变化而选中项全部消失时改选邻行，搜索过滤掉的选择随后取消
            restoreSelection()

            if let selectedRow, previous?.listing.hasSameOptions(as: listing) ?? false {
                selectNeighbor(of: selectedRow, in: rows)
            }

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

        /// 冲突状态不只通过文字颜色表达，未解决的冲突行另画浅红底。
        func outlineView(_: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            let row = FileRowView()
            row.isConflicted = (item as? Node)?.entry?.kind == .conflicted
            return row
        }

        /// 状态列为三态勾选和徽标，文件列为图标与按偏好截断的路径。
        func outlineView(_: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? Node else { return nil }

            if tableColumn?.identifier.rawValue == "status" {
                return statusCell(node)
            }

            return pathCell(node)
        }

        /// 用户改变选择后同步给会话；恢复选区期间不回写。
        func outlineViewSelectionDidChange(_: Notification) {
            guard !updating else { return }

            syncSelection()
        }

        /// 把列表里的选择写回会话：单独选中一个目录时右栏显示目录说明，单选文件驱动 Diff，多选显示独立空状态。
        func syncSelection() {
            guard let outline else { return }

            let nodes = outline.selectedRowIndexes.compactMap { outline.item(atRow: $0) as? Node }
            let entries = nodes.flatMap(\.entries)
            let directory = nodes.count == 1 && nodes[0].entry == nil ? nodes[0].path : nil

            session.selectedIDs = Set(entries.map { StatusRowID(path: $0.path, kind: $0.kind) })
            session.selectedDirectory = directory
            session.selectedID = directory == nil && entries.count == 1 ? session.selectedIDs.first : nil
            quickLook.selectionChanged()
        }

        /// 表头排序改变后记下新的排序，再按相同模型恢复选择；首次显示前载入保存的排序时不回写。
        func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
            guard let state = renderState else { return }

            WorkingCopyPreferences.storeSortDescriptors(outlineView.sortDescriptors)
            renderState = nil
            update(listing: state.listing, style: state.style)
        }
    }
}
