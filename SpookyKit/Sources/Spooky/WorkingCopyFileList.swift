import AppKit
import SpookyKit
import SwiftUI

/// 原生文件树支持多选勾选框、空格暂存与固定行高。
struct WorkingCopyFileList: NSViewRepresentable {
    /// 所有入口共享同一会话状态。
    let session: RepositorySession

    /// 全局记忆的显示模式；0 为平铺，1 为树形。
    @AppStorage("workingCopyViewMode") private var mode = 0

    /// 构建事件与模型桥接器。
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    /// 表格固定状态列宽、行高与目录缩进。
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
        outline.toggleSelection = { context.coordinator.toggleSelection() }
        let menu = NSMenu()
        menu.delegate = context.coordinator
        outline.menu = menu
        context.coordinator.outline = outline

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = outline
        return scroll
    }

    /// 数据变化才重建树，普通选区变化不打断键盘焦点。
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(mode: mode)
    }

    /// 文件树节点同时保留相对路径与叶子状态。
    final class Node: NSObject {
        /// 相对路径，也是目录的稳定身份。
        let path: String

        /// 文件节点对应的 Git 状态。
        var entry: StatusEntry?

        /// 子节点按路径排序。
        var children: [Node] = []

        /// 建立目录或文件节点。
        init(path: String, entry: StatusEntry? = nil) {
            self.path = path
            self.entry = entry
        }

        /// 目录勾选作用于当前显示的全部后代文件。
        var entries: [StatusEntry] {
            entry.map { [$0] } ?? children.flatMap(\.entries)
        }
    }

    /// 只接管空格键，其它键盘行为交给系统列表。
    final class FileOutlineView: NSOutlineView {
        /// 空格对应当前选中项的暂存切换。
        var toggleSelection: (() -> Void)?

        /// 默认动作是 Toggle staging；Quick Look 在对应里程碑接入。
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 49, event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                toggleSelection?()
                return
            }

            super.keyDown(with: event)
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

    /// 将原生列表事件转换为业务动作，不在 UI 拼接 Git 命令。
    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate {
        /// 当前会话。
        let session: RepositorySession

        /// 对原生列表的非持有引用。
        weak var outline: NSOutlineView?

        /// 树形或平铺的顶层节点。
        private var roots: [Node] = []

        /// 上次渲染的数据与锁定状态，用于避免无关重载。
        private var renderKey = ""

        /// 当前视图是否为树形。
        private var tree = false

        /// 恢复选区期间不回写会话。
        private var updating = false

        /// 右键菜单作用的条目。
        private var menuEntries: [StatusEntry] = []

        /// 初始化原生事件桥接。
        init(session: RepositorySession) { self.session = session }

        /// 根据 Git 模型和乐观状态重建行，目录按显示模式组织。
        func update(mode: Int) {
            guard let outline else { return }
            let entries = (session.status?.entries ?? []).filter { !session.onlyConflicts || $0.kind == .conflicted }
            let key = String(describing: entries) + String(describing: session.stagingOverrides)
                + "\(mode):\(session.canWrite):\(outline.sortDescriptors)"
            guard key != renderKey else { return }
            renderKey = key
            updating = true
            defer { updating = false }
            tree = mode == 1
            outline.indentationPerLevel = tree ? 16 : 0
            roots = []

            for entry in entries {
                if !tree {
                    roots.append(Node(path: entry.path, entry: entry))
                    continue
                }

                let components = entry.path.split(separator: "/").map(String.init)
                var parent: Node?
                var prefix = ""

                for (index, component) in components.enumerated() {
                    prefix += (prefix.isEmpty ? "" : "/") + component
                    let siblings = parent?.children ?? roots
                    let leaf = index == components.count - 1
                    let node = siblings.first { $0.path == prefix && $0.entry == nil }
                        ?? Node(path: prefix, entry: leaf ? entry : nil)

                    if !siblings.contains(where: { $0 === node }) {
                        if let parent { parent.children.append(node) }
                        else { roots.append(node) }
                    }

                    parent = node
                }
            }

            sortNodes()
            outline.reloadData()
            if tree { outline.expandItem(nil, expandChildren: true) }
            let selection = IndexSet((0..<outline.numberOfRows).filter { row in
                guard let node = outline.item(atRow: row) as? Node, let entry = node.entry else { return false }
                return session.selectedIDs.contains(StatusRowID(path: entry.path, kind: entry.kind))
            })
            outline.selectRowIndexes(selection, byExtendingSelection: false)
        }

        /// 根节点与目录子项均直接取当前显示模型。
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Node)?.children.count ?? roots.count
        }

        /// 系统按索引索取节点。
        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            ((item as? Node)?.children ?? roots)[index]
        }

        /// 只有目录显示展开三角。
        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            (item as? Node)?.children.isEmpty == false
        }

        /// 平铺不留展开控件，树形仅为目录提供三角。
        func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
            tree && (item as? Node)?.children.isEmpty == false
        }

        /// 冲突状态不只通过文字颜色表达。
        func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            (item as? Node)?.entry?.kind == .conflicted ? ConflictRowView() : nil
        }

        /// 状态列为三态勾选和徽标，文件列保留路径的中间截断。
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? Node else { return nil }

            if tableColumn?.identifier.rawValue == "status" {
                let button = StagingButton(checkboxWithTitle: "", target: self, action: #selector(toggle(_:)))
                button.node = node
                button.allowsMixedState = true
                let states = node.entries.map { entry -> Int in
                    if let override = session.stagingOverrides[StatusRowID(path: entry.path, kind: entry.kind)] {
                        return override ? 1 : 0
                    }

                    if entry.hasStagedChanges { return entry.hasUnstagedChanges ? -1 : 1 }
                    return 0
                }
                button.state = states.allSatisfy { $0 == 1 } ? .on : (states.allSatisfy { $0 == 0 } ? .off : .mixed)
                button.isEnabled = session.canWrite
                button.setAccessibilityLabel(AppLocalization.text("working.staging", node.path))
                var views: [NSView] = [button]
                if let entry = node.entry { views.append(NSHostingView(rootView: FileStatusView(entry: entry))) }
                let stack = NSStackView(views: views)
                stack.spacing = 3
                return stack
            }

            let label = NSTextField(labelWithString: tree ? (node.path as NSString).lastPathComponent : node.path)
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingMiddle
            label.toolTip = node.path
            let symbol = node.entry?.kind == .conflicted
                ? "exclamationmark.circle.fill"
                : (node.entry == nil ? "folder" : "doc")
            let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!)
            icon.contentTintColor = node.entry?.kind == .conflicted ? .systemRed : .secondaryLabelColor
            icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
            let stack = NSStackView(views: [icon, label])
            stack.spacing = 8
            return stack
        }

        /// 多选显示独立空状态，单选驱动 Diff。
        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !updating, let outline else { return }
            let entries = outline.selectedRowIndexes.flatMap { (outline.item(atRow: $0) as? Node)?.entries ?? [] }
            session.selectedIDs = Set(entries.map { StatusRowID(path: $0.path, kind: $0.kind) })
            session.selectedID = entries.count == 1 ? session.selectedIDs.first : nil
        }

        /// 表头排序改变后按相同模型恢复选择。
        func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            renderKey = ""
            update(mode: tree ? 1 : 0)
        }

        /// 右键点击已选行时作用于整个选区，否则只处理该行。
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let outline, let node = outline.item(atRow: outline.clickedRow) as? Node else { return }
            menuEntries = outline.isRowSelected(outline.clickedRow) ? session.selectedEntries : node.entries
            add(
                "working.stage",
                action: #selector(stageMenu),
                enabled: session.canStage(menuEntries),
                menu: menu
            )
            add(
                "working.unstage",
                action: #selector(unstageMenu),
                enabled: session.canUnstage(menuEntries),
                menu: menu
            )

            if menuEntries.contains(where: { $0.kind == .conflicted }) {
                add("working.ours", action: #selector(ours), enabled: session.canResolve(menuEntries), menu: menu)
                add("working.theirs", action: #selector(theirs), enabled: session.canResolve(menuEntries), menu: menu)
                add("working.resolved", action: #selector(stageMenu), enabled: session.canResolve(menuEntries), menu: menu)
            }

            menu.addItem(.separator())
            add("working.discard", action: #selector(discardMenu), enabled: session.canDiscard(menuEntries), menu: menu)
            menu.addItem(.separator())
            add("action.copyPath", action: #selector(copyAbsolute), enabled: true, menu: menu)
            add("working.copyRelative", action: #selector(copyRelative), enabled: true, menu: menu)
            add("action.revealFinder", action: #selector(reveal), enabled: session.repository?.localURL != nil, menu: menu)
            add("action.openTerminal", action: #selector(terminal), enabled: true, menu: menu)
        }

        /// 空格沿用 “存在可暂存项则全部暂存” 的规则。
        func toggleSelection() {
            let entries = session.selectedEntries
            if entries.isEmpty { NSSound.beep(); return }
            session.stage(entries, staged: entries.contains(where: \.hasUnstagedChanges))
        }

        /// 勾选框的目标状态按 Git 模型计算，不采用系统对 mixed 的默认轮转。
        @objc private func toggle(_ sender: StagingButton) {
            guard let node = sender.node, let outline else { return }
            let entries = outline.isRowSelected(outline.row(forItem: node)) ? session.selectedEntries : node.entries
            session.stage(entries, staged: entries.contains(where: \.hasUnstagedChanges))
            outline.window?.makeFirstResponder(outline)
        }

        /// 菜单暂存所选条目。
        @objc private func stageMenu() { session.stage(menuEntries, staged: true) }

        /// 菜单取消暂存所选条目。
        @objc private func unstageMenu() { session.stage(menuEntries, staged: false) }

        /// 丢弃必须经过会话的确认入口。
        @objc private func discardMenu() { session.discard(menuEntries) }

        /// 采用索引中的 ours 一侧。
        @objc private func ours() { session.resolve(menuEntries, theirs: false) }

        /// 采用索引中的 theirs 一侧。
        @objc private func theirs() { session.resolve(menuEntries, theirs: true) }

        /// 复制远端路径时保留主机前缀。
        @objc private func copyAbsolute() {
            guard let repository = session.repository else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                menuEntries.map { repository.displayPath + "/" + $0.path }.joined(separator: "\n"),
                forType: .string
            )
        }

        /// 相对路径适合提交信息与终端中的仓库内引用。
        @objc private func copyRelative() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(menuEntries.map(\.path).joined(separator: "\n"), forType: .string)
        }

        /// 只有本机条目才交给 Finder。
        @objc private func reveal() {
            guard let root = session.repository?.localURL else { return }
            NSWorkspace.shared.activateFileViewerSelecting(menuEntries.map { root.appending(path: $0.path) })
        }

        /// 终端沿用当前仓库已实现的应用选择。
        @objc private func terminal() {
            NSApp.sendAction(#selector(RepositoryWindowController.openInTerminal), to: nil, from: outline)
        }

        /// 递归排序使目录与文件使用相同的用户选项。
        private func sortNodes() {
            let descriptor = outline?.sortDescriptors.first
            let ascending = descriptor?.ascending ?? true

            /// 目录内部沿用相同排序，不把平铺的比较结果跨层混用。
            func sorted(_ nodes: [Node]) -> [Node] {
                for node in nodes { node.children = sorted(node.children) }
                return nodes.sorted {
                    let left = descriptor?.key == "status" ? String($0.entry?.staged?.rawValue ?? ".") + $0.path : $0.path
                    let right = descriptor?.key == "status" ? String($1.entry?.staged?.rawValue ?? ".") + $1.path : $1.path
                    return ascending ? left < right : left > right
                }
            }

            roots = sorted(roots)
        }

        /// 菜单可用性由当前会话决定，不依赖响应链的隐式校验。
        private func add(_ key: String, action: Selector, enabled: Bool, menu: NSMenu) {
            menu.autoenablesItems = false
            let item = NSMenuItem(title: AppLocalization.text(key), action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = enabled
            menu.addItem(item)
        }
    }
}
