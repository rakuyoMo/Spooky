import AppKit
import SpookyKit
import SwiftUI

/// 历史头部与原生可复用列表，滚到底时自动读取下一页。
struct HistoryListView: View {
    /// 当前仓库会话。
    let session: RepositorySession

    /// 从所选提交新建分支，参数由窗口对话框收集。
    let createBranch: (String) -> Void

    /// 双击切换整页详情。
    let openCommit: () -> Void

    /// 提交图可见性跨仓库记忆。
    @AppStorage("historyShowGraph") private var showGraph = true

    /// 0 为中号，1 为小号。
    @AppStorage("historySmallRows") private var smallRows = false

    /// 40 pt 表头、24 / 46 pt 列表行和持续可见的取消入口。
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(session.history.title)
                    .lineLimit(1)
                    .help(session.repository?.displayPath ?? "")
                if let id = session.history.selectedReference, let counts = session.history.divergence[id] {
                    Text("↑ \(counts.ahead) ↓ \(counts.behind)")
                        .font(.system(size: 11))
                }
                Spacer(minLength: 4)
                Menu {
                    Toggle(AppLocalization.text("history.showGraph"), isOn: $showGraph)
                    Button(AppLocalization.text("history.medium")) { smallRows = false }
                        .disabled(!showGraph)
                    Button(AppLocalization.text("history.small")) { smallRows = true }
                        .disabled(!showGraph)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(AppLocalization.text("history.viewOptions"))
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(.bar)
            Divider()

            if session.history.commits.isEmpty, !session.history.isLoading {
                EmptyStateView(title: AppLocalization.text("history.empty"), message: "", symbol: "clock")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HistoryCommitTable(
                    session: session,
                    showGraph: showGraph,
                    smallRows: smallRows,
                    createBranch: createBranch,
                    openCommit: openCommit
                )
            }

            if let failure = session.history.failure {
                Text(failure.title + "\n" + failure.details)
                    .font(.system(size: 11))
                    .textSelection(.enabled)
                    .padding(12)
                Button(AppLocalization.text("action.refresh")) { session.history.reloadCommits() }
                    .padding(.bottom, 8)
            }
            if session.history.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(AppLocalization.text("history.loading"))
                    Button(AppLocalization.text("action.cancel")) { session.history.cancelPage() }
                }
                .font(.system(size: 11))
                .padding(8)
            }
        }
        .frame(minWidth: 300)
    }
}

/// NSTableView 提供固定行高、多选、复制和只限应用内的提交拖动。
private struct HistoryCommitTable: NSViewRepresentable {
    /// 当前仓库及历史模型。
    let session: RepositorySession

    /// 当前图可见性。
    let showGraph: Bool

    /// 当前行高档位。
    let smallRows: Bool

    /// 新建分支入口。
    let createBranch: (String) -> Void

    /// 整页详情入口。
    let openCommit: () -> Void

    /// 建立数据源桥接。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 原生表格保留键盘与 VoiceOver 选择语义。
    func makeNSView(context: Context) -> NSScrollView {
        let table = CommitTableView()
        table.addTableColumn(NSTableColumn(identifier: .init("commit")))
        table.headerView = nil
        table.style = .inset
        table.intercellSpacing = .zero
        table.allowsMultipleSelection = true
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.doubleClick)
        table.copySelection = { context.coordinator.copyHashes() }
        table.setDraggingSourceOperationMask(.copy, forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)
        table.setAccessibilityIdentifier("history-commits")
        let menu = NSMenu()
        menu.delegate = context.coordinator
        table.menu = menu
        context.coordinator.table = table
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        return scroll
    }

    /// 数据不变时不 reload，避免进度和选择更新打断滚动。
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(self)
    }

    /// 响应链上的 ⌘C 复制完整哈希。
    final class CommitTableView: NSTableView {
        /// 当前选择对应的复制动作。
        var copySelection: (() -> Void)?

        /// 文本焦点位于表格时响应系统复制菜单。
        @objc func copy(_ sender: Any?) { copySelection?() }
    }

    /// 表格委托把事件交给历史状态，不组装 Git 参数。
    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        /// 当前 SwiftUI 输入。
        var parent: HistoryCommitTable

        /// 原生列表的弱引用。
        weak var table: NSTableView?

        /// 已显示的提交身份，决定是否重载。
        private var displayed: [String] = []

        /// 引用变化也需要更新徽标。
        private var snapshot: ReferenceSnapshot?

        /// 两侧归属变化时刷新相同行的进度标记。
        private var trackingMarkers: [Set<String>] = []

        /// 选中背景与引用徽标保持一致。
        private var selection = Set<String>()

        /// 程序恢复选区时忽略表格的中间通知，防止 reloadData 清空业务选择。
        private var isUpdating = false

        /// 建立会话绑定。
        init(_ parent: HistoryCommitTable) { self.parent = parent }

        /// 选择单独同步，图与行高变化时才重新构建可见行。
        func update(_ parent: HistoryCommitTable) {
            let changedStyle =
                self.parent.showGraph != parent.showGraph || self.parent.smallRows != parent.smallRows
            self.parent = parent
            guard let table else { return }
            isUpdating = true
            defer { isUpdating = false }
            let ids = parent.session.history.commits.map(\.id)
            let markers = [parent.session.history.unpushed, parent.session.history.unpulled]
            if displayed != ids || changedStyle || snapshot != parent.session.history.snapshot
                || trackingMarkers != markers || selection != parent.session.history.selectedIDs
            {
                displayed = ids
                snapshot = parent.session.history.snapshot
                trackingMarkers = markers
                selection = parent.session.history.selectedIDs
                table.rowHeight = parent.smallRows ? 24 : 46
                table.reloadData()
            }
            let indexes = IndexSet(
                ids.indices.filter { parent.session.history.selectedIDs.contains(ids[$0]) }
            )
            if table.selectedRowIndexes != indexes {
                table.selectRowIndexes(indexes, byExtendingSelection: false)
            }
        }

        /// 行数只来自当前已完成的页。
        func numberOfRows(in tableView: NSTableView) -> Int { parent.session.history.commits.count }

        /// 行内容按需复用，最后一行触发续页。
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let history = parent.session.history
            guard history.commits.indices.contains(row) else { return nil }
            let commit = history.commits[row]
            let view = HistoryCommitRow(
                commit: commit,
                graph: parent.showGraph ? history.graphRows[commit.id] : nil,
                references: history.snapshot?.references.filter { $0.objectID == commit.id } ?? [],
                isHead: history.branch?.oid == commit.id,
                small: parent.smallRows,
                unpushed: history.unpushed.contains(commit.id),
                unpulled: history.unpulled.contains(commit.id),
                selected: history.selectedIDs.contains(commit.id)
            )
            let identifier = NSUserInterfaceItemIdentifier("history-commit")
            let cell =
                tableView.makeView(withIdentifier: identifier, owner: nil) as? NSHostingView<HistoryCommitRow>
                ?? NSHostingView(rootView: view)
            cell.rootView = view
            cell.identifier = identifier
            if row == history.commits.count - 1, history.hasMore {
                Task { @MainActor in history.loadNextPage() }
            }
            return cell
        }

        /// 单选与多选共享完整哈希，视图刷新后可以恢复选择。
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isUpdating, let table else { return }
            let commits = parent.session.history.commits
            parent.session.history.selectedIDs = Set(
                table.selectedRowIndexes.compactMap {
                    commits.indices.contains($0) ? commits[$0].id : nil
                }
            )
        }

        /// 拖出单个提交，侧边栏的 Branches 标题接受新建分支动作。
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (
            any NSPasteboardWriting
        )? {
            guard let location = parent.session.repository,
                parent.session.history.commits.indices.contains(row)
            else { return nil }
            let item = NSPasteboardItem()
            let payload = RepositoryDragPayload(
                repository: location,
                kind: .commit,
                reference: parent.session.history.commits[row].id
            )
            RepositoryDragContext.shared.payload = payload
            guard let data = try? JSONEncoder().encode(payload) else { return nil }
            item.setData(data, forType: .init(RepositoryDragPayload.type))
            return item
        }

        /// 右键在选区外时只作用于该行。
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let table else { return }
            if table.clickedRow >= 0, !table.selectedRowIndexes.contains(table.clickedRow) {
                table.selectRowIndexes(IndexSet(integer: table.clickedRow), byExtendingSelection: false)
            }
            let copy = NSMenuItem(
                title: AppLocalization.text("history.copyHash"),
                action: #selector(copyHashes),
                keyEquivalent: ""
            )
            copy.target = self
            copy.isEnabled = !parent.session.history.selectedIDs.isEmpty
            menu.addItem(copy)
            let create = NSMenuItem(
                title: AppLocalization.text("branch.createFromCommit"),
                action: #selector(create),
                keyEquivalent: ""
            )
            create.target = self
            create.isEnabled = parent.session.canWrite && parent.session.history.selectedCommit != nil
            menu.addItem(create)
            menu.autoenablesItems = false
        }

        /// 多选复制按照列表顺序换行连接。
        @objc func copyHashes() {
            let history = parent.session.history
            let hashes = history.commits.filter { history.selectedIDs.contains($0.id) }.map(\.id)
            guard !hashes.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hashes.joined(separator: "\n"), forType: .string)
        }

        /// 从单个提交打开有预填起点的分支对话框。
        @objc private func create() {
            guard let commit = parent.session.history.selectedCommit else { return }
            parent.createBranch(commit.id)
        }

        /// 双击进入整页提交详情，保持相同 First Parent 比较语义。
        @objc func doubleClick() {
            guard parent.session.history.selectedCommit != nil else { return }
            parent.openCommit()
        }
    }
}

/// 提交行提供中号双行和小号单行两种布局。
private struct HistoryCommitRow: View {
    /// 当前提交元信息。
    let commit: HistoryCommit

    /// 单行独立绘制模型。
    let graph: CommitGraphRow?

    /// 指向当前提交的完整引用。
    let references: [RepositoryReference]

    /// HEAD 作为独立蓝色徽标显示。
    let isHead: Bool

    /// 小号行高为 24 pt。
    let small: Bool

    /// 未推送提交在行尾显示上箭头。
    let unpushed: Bool

    /// 未拉取提交显示下箭头与弱化背景。
    let unpulled: Bool

    /// 被选中时文本和徽标采用选中配色。
    let selected: Bool

    /// 图在最左侧，标题和元信息按固定行高排列。
    var body: some View {
        HStack(spacing: 8) {
            if let graph {
                HistoryGraphView(row: graph)
                    .frame(width: CGFloat(graph.columnCount) * 10 + 7)
                    .accessibilityHidden(true)
            }
            if small {
                hash
                badges
                Text(commit.subject).lineLimit(1)
                Spacer(minLength: 0)
                Text(commit.author).foregroundStyle(selected ? Color.white : .secondary).lineLimit(1)
                date
            } else {
                Text(String(commit.author.prefix(1)))
                    .frame(width: 32, height: 32)
                    .background(.quaternary, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(commit.author).foregroundStyle(selected ? Color.white : .secondary).lineLimit(1)
                        badges
                        Spacer(minLength: 0)
                        date
                    }
                    HStack(spacing: 8) {
                        hash
                        Text(commit.subject).lineLimit(1)
                    }
                }
            }
            if unpushed || unpulled {
                Image(systemName: unpushed ? "arrow.up" : "arrow.down")
                    .font(.system(size: small ? 10 : 12))
                    .accessibilityLabel(
                        AppLocalization.text(unpushed ? "history.unpushed" : "history.unpulled")
                    )
            }
        }
        .font(.system(size: small ? 11 : 12))
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(selected ? Color.white : (unpulled ? .secondary : .primary))
        .background(
            unpulled && !selected ? AppPalette.color("general_alternate_row_background_color") : .clear
        )
        .help(commit.id + "\n" + commit.subject)
    }

    /// 哈希使用等宽字体，动作仍使用完整 ID。
    private var hash: some View {
        Text(commit.shortID)
            .font(.system(size: small ? 10 : 12, design: .monospaced))
            .foregroundStyle(selected ? Color.white : .secondary)
    }

    /// 列表显示提交人日期，完整两种日期在详情中展示。
    private var date: some View {
        Text(commit.commitDate, format: .dateTime.year().month().day())
            .foregroundStyle(selected ? Color.white : .secondary)
            .lineLimit(1)
            .layoutPriority(1)
    }

    /// 引用名只读展示，后续里程碑的标签动作不在此暴露。
    private var badges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                if isHead { badge("HEAD", color: "blue") }
                ForEach(references) { ref in
                    badge(ref.name, color: ref.isLocal ? "blue" : (ref.isRemote ? "gray" : "yellow"))
                }
            }
            if isHead || !references.isEmpty { badge("…", color: "gray") }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }

    /// 引用徽标使用 11 pt 文本和 4 pt 圆角。
    private func badge(_ title: String, color: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(AppPalette.color((selected ? "selected" : color) + "_badge_text_color"))
            .background(
                AppPalette.color((selected ? "selected" : color) + "_badge_background_color"),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }
}

/// 每行一个原生画布，线段跨行拼接，点击穿透给列表。
private struct HistoryGraphView: NSViewRepresentable {
    /// 当前行的图模型。
    let row: CommitGraphRow

    /// 建立轻量画布。
    func makeNSView(context: Context) -> GraphCanvas { GraphCanvas() }

    /// 分页只更新对应行的几何模型。
    func updateNSView(_ view: GraphCanvas, context: Context) {
        view.row = row
        view.needsDisplay = true
    }

    /// 10 pt 列距、2 pt 线宽与 7 pt 圆点的原生绘制。
    final class GraphCanvas: NSView {
        /// 无模型时保持空画布。
        var row: CommitGraphRow?

        /// 上沿接上一提交，采用从上向下的坐标系。
        override var isFlipped: Bool { true }

        /// 图不接管点击，列表保留选择和双击语义。
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        /// 线段换列时在中间三分之一使用贝塞尔过渡。
        override func draw(_ dirtyRect: NSRect) {
            guard let row else { return }
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let colors =
                dark
                ? [
                    "#98989D", "#0091FF", "#FF375F", "#30D158", "#FFD600", "#FF9230", "#6D7CFF", "#FF4245",
                    "#00D2E0", "#DB34F2",
                ]
                : [
                    "#8E8E93", "#0088FF", "#FF2D55", "#34C759", "#FFCC00", "#FF8D28", "#6155F5", "#FF383C",
                    "#00C3D0", "#CB30E0",
                ]

            for segment in row.segments {
                let start = NSPoint(
                    x: CGFloat(segment.start) * 10 + 7,
                    y: segment.startsAtCommit ? bounds.midY : 0
                )
                let end = NSPoint(
                    x: CGFloat(segment.end) * 10 + 7,
                    y: segment.endsAtCommit ? bounds.midY : bounds.height
                )
                let distance = (end.y - start.y) / 3
                let path = NSBezierPath()
                path.lineWidth = 2
                path.move(to: start)
                path.line(to: NSPoint(x: start.x, y: start.y + distance))
                path.curve(
                    to: NSPoint(x: end.x, y: end.y - distance),
                    controlPoint1: NSPoint(x: start.x, y: start.y + distance * 1.5),
                    controlPoint2: NSPoint(x: end.x, y: end.y - distance * 1.5)
                )
                path.line(to: end)
                PaletteColor(hex: colors[segment.line % 10], alpha: 1).nsColor.setStroke()
                path.stroke()
            }

            // 圆点最后覆盖连接线，外圈厚度为 1.5 pt。
            let dot = NSBezierPath(
                ovalIn: NSRect(x: CGFloat(row.column) * 10 + 3.5, y: bounds.midY - 3.5, width: 7, height: 7)
            )
            dot.lineWidth = 3
            (dark ? NSColor(white: 0.867, alpha: 1) : NSColor(white: 0.4, alpha: 1)).setStroke()
            dot.stroke()
            (dark ? NSColor(white: 0.133, alpha: 1) : .white).setFill()
            dot.fill()
        }
    }
}
